//! Minimal HTTP/1.1 test server with controllable failure modes.

#![allow(dead_code)]

use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

#[derive(Default)]
pub struct Behavior {
    pub content_type: &'static str,
    pub support_ranges: bool,
    /// Answer 503 to the first N requests.
    pub fail_first: AtomicUsize,
    /// Fixed status for every request (e.g. 404).
    pub status: Option<u16>,
    /// Close the connection after sending this many body bytes (once).
    pub cut_after: Mutex<Option<usize>>,
    /// Delay between 16 KiB chunks.
    pub chunk_delay: Duration,
    /// ETag sent with every answer; `If-Range` must match it.
    pub etag: Mutex<Option<String>>,
    /// Last-Modified sent with every answer (used when there is no ETag).
    pub last_modified: Option<&'static str>,
    /// Served instead of the body once set (the remote file changed).
    pub replacement: Mutex<Option<Vec<u8>>>,
    /// If-Range header of each request, in order.
    pub if_ranges: Mutex<Vec<Option<String>>>,
}

pub struct TestServer {
    pub base: String,
    pub body: Arc<Vec<u8>>,
    pub behavior: Arc<Behavior>,
    pub requests: Arc<Mutex<Vec<Option<String>>>>,
    pub active: Arc<AtomicUsize>,
    pub max_active: Arc<AtomicUsize>,
}

impl TestServer {
    pub fn url(&self, path: &str) -> String {
        format!("{}{path}", self.base)
    }

    /// Range header of each request received, in order.
    pub fn ranges(&self) -> Vec<Option<String>> {
        self.requests.lock().unwrap().clone()
    }
}

pub fn body(len: usize) -> Vec<u8> {
    (0..len).map(|i| (i * 31 % 251) as u8).collect()
}

pub async fn serve(body: Vec<u8>, behavior: Behavior) -> TestServer {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let base = format!("http://{}", listener.local_addr().unwrap());
    let server = TestServer {
        base,
        body: Arc::new(body),
        behavior: Arc::new(behavior),
        requests: Arc::default(),
        active: Arc::default(),
        max_active: Arc::default(),
    };
    let (body, behavior, requests, active, max_active) = (
        server.body.clone(),
        server.behavior.clone(),
        server.requests.clone(),
        server.active.clone(),
        server.max_active.clone(),
    );
    tokio::spawn(async move {
        loop {
            let Ok((mut socket, _)) = listener.accept().await else {
                return;
            };
            let (body, behavior, requests, active, max_active) = (
                body.clone(),
                behavior.clone(),
                requests.clone(),
                active.clone(),
                max_active.clone(),
            );
            tokio::spawn(async move {
                let now = active.fetch_add(1, Ordering::SeqCst) + 1;
                max_active.fetch_max(now, Ordering::SeqCst);
                let _ = handle(&mut socket, &body, &behavior, &requests).await;
                active.fetch_sub(1, Ordering::SeqCst);
            });
        }
    });
    server
}

async fn handle(
    socket: &mut tokio::net::TcpStream,
    body: &[u8],
    behavior: &Behavior,
    requests: &Mutex<Vec<Option<String>>>,
) -> std::io::Result<()> {
    let mut buf = Vec::new();
    let mut tmp = [0u8; 1024];
    while !buf.windows(4).any(|w| w == b"\r\n\r\n") {
        let n = socket.read(&mut tmp).await?;
        if n == 0 {
            return Ok(());
        }
        buf.extend_from_slice(&tmp[..n]);
    }
    let head = String::from_utf8_lossy(&buf).to_string();
    let range = head
        .lines()
        .find_map(|l| {
            l.strip_prefix("range: ")
                .or_else(|| l.strip_prefix("Range: "))
        })
        .map(|v| v.trim().to_owned());
    requests.lock().unwrap().push(range.clone());
    let if_range = head
        .lines()
        .find_map(|l| {
            l.strip_prefix("if-range: ")
                .or_else(|| l.strip_prefix("If-Range: "))
        })
        .map(|v| v.trim().to_owned());
    behavior.if_ranges.lock().unwrap().push(if_range.clone());
    let replaced = behavior.replacement.lock().unwrap().clone();
    let body: &[u8] = replaced.as_deref().unwrap_or(body);
    let etag = behavior.etag.lock().unwrap().clone();
    let validator = etag.clone().or(behavior.last_modified.map(str::to_owned));
    // If-Range: the range only applies to the same representation.
    let range = match (&if_range, &validator) {
        (Some(sent), Some(current)) if sent != current => None,
        _ => range,
    };
    let mut validators = String::new();
    if let Some(etag) = &etag {
        validators.push_str(&format!("etag: {etag}\r\n"));
    }
    if let Some(lm) = behavior.last_modified {
        validators.push_str(&format!("last-modified: {lm}\r\n"));
    }

    let content_type = if behavior.content_type.is_empty() {
        "video/mp4"
    } else {
        behavior.content_type
    };
    if let Some(status) = behavior.status {
        let resp = format!("HTTP/1.1 {status} X\r\ncontent-length: 0\r\nconnection: close\r\n\r\n");
        return socket.write_all(resp.as_bytes()).await;
    }
    if behavior
        .fail_first
        .try_update(Ordering::SeqCst, Ordering::SeqCst, |n| n.checked_sub(1))
        .is_ok()
    {
        let resp = "HTTP/1.1 503 Busy\r\ncontent-length: 0\r\nconnection: close\r\n\r\n";
        return socket.write_all(resp.as_bytes()).await;
    }

    let total = body.len();
    let start = range
        .as_deref()
        .filter(|_| behavior.support_ranges)
        .and_then(|r| r.strip_prefix("bytes="))
        .and_then(|r| r.split('-').next())
        .and_then(|s| s.parse::<usize>().ok());
    let end_req = range
        .as_deref()
        .filter(|_| behavior.support_ranges)
        .and_then(|r| r.split('-').nth(1))
        .and_then(|s| s.parse::<usize>().ok());

    let (status, slice, extra) = match start {
        Some(s) if s >= total => {
            let resp = format!(
                "HTTP/1.1 416 Range Not Satisfiable\r\ncontent-range: bytes */{total}\r\ncontent-length: 0\r\nconnection: close\r\n\r\n"
            );
            return socket.write_all(resp.as_bytes()).await;
        }
        Some(s) => {
            let e = end_req.map(|e| e.min(total - 1)).unwrap_or(total - 1);
            (
                "206 Partial Content",
                &body[s..=e],
                format!("content-range: bytes {s}-{e}/{total}\r\n"),
            )
        }
        None => ("200 OK", body, String::new()),
    };
    let accept = if behavior.support_ranges {
        "accept-ranges: bytes\r\n"
    } else {
        ""
    };
    let head = format!(
        "HTTP/1.1 {status}\r\ncontent-type: {content_type}\r\ncontent-length: {}\r\n{accept}{validators}{extra}connection: close\r\n\r\n",
        slice.len()
    );
    socket.write_all(head.as_bytes()).await?;

    let cut = behavior.cut_after.lock().unwrap().take();
    let mut sent = 0;
    for chunk in slice.chunks(16 * 1024) {
        if let Some(limit) = cut
            && sent + chunk.len() > limit
        {
            socket.write_all(&chunk[..limit - sent]).await?;
            socket.flush().await?;
            return Ok(()); // drop the connection mid-body
        }
        socket.write_all(chunk).await?;
        sent += chunk.len();
        if !behavior.chunk_delay.is_zero() {
            tokio::time::sleep(behavior.chunk_delay).await;
        }
    }
    socket.flush().await
}

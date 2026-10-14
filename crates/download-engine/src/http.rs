//! Direct HTTP(S) downloads of media files.

use std::path::Path;
use std::time::{Duration, Instant};

use futures_util::FutureExt;
use futures_util::future::BoxFuture;
use media_core::ValidatedUrl;
use reqwest::header::{
    ACCEPT_RANGES, CONTENT_DISPOSITION, CONTENT_LENGTH, CONTENT_RANGE, CONTENT_TYPE, HeaderMap,
    RANGE,
};
use reqwest::{Client, Response, StatusCode};
use serde::Serialize;
use tokio::io::{AsyncWriteExt, BufWriter};
use tokio_util::sync::CancellationToken;

use crate::engine::{DownloadJob, Engine, Outcome, ProgressFn};
use crate::fsops::{ensure_space, finalize_no_clobber};
use crate::progress::{SpeedMeter, Throttle};
use crate::{EngineError, Progress};

const USER_AGENT: &str = concat!("MiarinaMedia/", env!("CARGO_PKG_VERSION"));
const WRITE_BUFFER: usize = 256 * 1024;
const MEDIA_EXTENSIONS: [&str; 14] = [
    "mp4", "m4v", "webm", "mkv", "mov", "avi", "m4a", "mp3", "flac", "ogg", "opus", "wav", "aac",
    "oga",
];

/// What a direct link points to.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectMedia {
    /// Untrusted name suggested by the server or the URL path.
    pub suggested_name: String,
    pub content_type: Option<String>,
    pub total_bytes: Option<u64>,
    pub supports_resume: bool,
}

#[derive(Clone)]
pub struct HttpEngine {
    client: Client,
}

impl HttpEngine {
    pub fn new() -> Result<Self, EngineError> {
        let client = Client::builder()
            .user_agent(USER_AGENT)
            .connect_timeout(Duration::from_secs(15))
            // Applies per read: a stalled transfer fails instead of hanging.
            .read_timeout(Duration::from_secs(30))
            .redirect(reqwest::redirect::Policy::limited(10))
            .build()
            .map_err(EngineError::network)?;
        Ok(Self { client })
    }

    /// Checks that the link is a media file without downloading its body.
    pub async fn probe(&self, url: &ValidatedUrl) -> Result<DirectMedia, EngineError> {
        let response = self
            .client
            .get(url.as_str())
            .header(RANGE, "bytes=0-0")
            .send()
            .await
            .map_err(EngineError::from_reqwest)?;
        let status = response.status();
        if !status.is_success() {
            return Err(EngineError::Http {
                status: status.as_u16(),
            });
        }
        let headers = response.headers();
        let content_type = header_str(headers, CONTENT_TYPE).map(|v| v.to_ascii_lowercase());
        let suggested_name = suggested_name(headers, response.url());
        if !looks_like_media(content_type.as_deref(), &suggested_name) {
            return Err(EngineError::NotMedia);
        }
        let (total_bytes, supports_resume) = if status == StatusCode::PARTIAL_CONTENT {
            (content_range_total(headers), true)
        } else {
            (content_length(headers), accepts_ranges(headers))
        };
        Ok(DirectMedia {
            suggested_name,
            content_type,
            total_bytes,
            supports_resume,
        })
    }

    async fn run(
        &self,
        job: &DownloadJob,
        progress: ProgressFn<'_>,
        cancel: CancellationToken,
    ) -> Result<Outcome, EngineError> {
        let existing = tokio::fs::metadata(&job.part_path)
            .await
            .map(|m| m.len())
            .unwrap_or(0);

        let mut request = self.client.get(job.url.as_str());
        if existing > 0 {
            request = request.header(RANGE, format!("bytes={existing}-"));
        }
        let response = tokio::select! {
            _ = cancel.cancelled() => return Err(EngineError::Canceled),
            r = request.send() => r.map_err(EngineError::from_reqwest)?,
        };

        let status = response.status();
        let headers = response.headers().clone();
        let (offset, total, supports_resume) = match status {
            StatusCode::PARTIAL_CONTENT if existing > 0 => {
                if content_range_start(&headers) != Some(existing) {
                    return Err(EngineError::network("unexpected Content-Range from server"));
                }
                (existing, content_range_total(&headers), true)
            }
            StatusCode::RANGE_NOT_SATISFIABLE if existing > 0 => {
                // Either the part is already complete, or the remote file
                // changed: restart from zero in the latter case.
                if content_range_total(&headers) == Some(existing) {
                    let final_path =
                        finalize_no_clobber(&job.part_path, &job.dest_dir, &job.file_name)?;
                    return Ok(Outcome {
                        final_path,
                        bytes: existing,
                        supports_resume: true,
                    });
                }
                tokio::fs::remove_file(&job.part_path)
                    .await
                    .map_err(EngineError::from_io)?;
                return Err(EngineError::network("remote file changed, restarting"));
            }
            s if s.is_success() => (0, content_length(&headers), accepts_ranges(&headers)),
            s => return Err(EngineError::Http { status: s.as_u16() }),
        };

        if let Some(total) = total {
            ensure_space(&job.dest_dir, total.saturating_sub(offset))?;
        }

        let file = tokio::fs::OpenOptions::new()
            .create(true)
            .write(true)
            .append(offset > 0)
            .truncate(offset == 0)
            .open(&job.part_path)
            .await
            .map_err(EngineError::from_io)?;
        let mut writer = BufWriter::with_capacity(WRITE_BUFFER, file);

        let downloaded = stream_body(
            response,
            &mut writer,
            offset,
            total,
            supports_resume,
            job.progress_interval,
            progress,
            &cancel,
        )
        .await;
        // Flush what was received even on failure so a resume starts from it.
        let flushed = writer.flush().await.map_err(EngineError::from_io);
        let downloaded = downloaded?;
        flushed?;
        writer
            .get_ref()
            .sync_all()
            .await
            .map_err(EngineError::from_io)?;
        drop(writer);

        if let Some(total) = total
            && downloaded != total
        {
            return Err(EngineError::network(format!(
                "connection closed after {downloaded} of {total} bytes"
            )));
        }

        let final_path = finalize_no_clobber(&job.part_path, &job.dest_dir, &job.file_name)?;
        Ok(Outcome {
            final_path,
            bytes: downloaded,
            supports_resume,
        })
    }
}

#[allow(clippy::too_many_arguments)]
async fn stream_body(
    mut response: Response,
    writer: &mut BufWriter<tokio::fs::File>,
    offset: u64,
    total: Option<u64>,
    supports_resume: bool,
    interval: Duration,
    progress: ProgressFn<'_>,
    cancel: &CancellationToken,
) -> Result<u64, EngineError> {
    let started = Instant::now();
    let mut downloaded = offset;
    let mut meter = SpeedMeter::new(started, offset);
    let mut throttle = Throttle::new(interval);
    let report = |downloaded: u64, rate: f64| {
        progress(Progress {
            downloaded,
            total,
            bytes_per_sec: rate,
            supports_resume,
            stage: crate::Stage::Downloading,
        })
    };
    report(downloaded, 0.0);

    loop {
        let chunk = tokio::select! {
            _ = cancel.cancelled() => return Err(EngineError::Canceled),
            c = response.chunk() => c.map_err(EngineError::from_reqwest)?,
        };
        let Some(chunk) = chunk else { break };
        // Never write past the announced size (defends against bad servers).
        if let Some(total) = total
            && downloaded + chunk.len() as u64 > total
        {
            return Err(EngineError::network("server sent more data than announced"));
        }
        writer
            .write_all(&chunk)
            .await
            .map_err(EngineError::from_io)?;
        downloaded += chunk.len() as u64;

        let now = Instant::now();
        let rate = meter.update(now, downloaded);
        if throttle.ready(now) {
            report(downloaded, rate);
        }
    }
    report(downloaded, meter.update(Instant::now(), downloaded));
    Ok(downloaded)
}

impl Engine for HttpEngine {
    fn id(&self) -> &'static str {
        "http"
    }

    fn download<'a>(
        &'a self,
        job: &'a DownloadJob,
        progress: ProgressFn<'a>,
        cancel: CancellationToken,
    ) -> BoxFuture<'a, Result<Outcome, EngineError>> {
        self.run(job, progress, cancel).boxed()
    }
}

fn header_str(headers: &HeaderMap, name: reqwest::header::HeaderName) -> Option<&str> {
    headers.get(name)?.to_str().ok()
}

fn content_length(headers: &HeaderMap) -> Option<u64> {
    header_str(headers, CONTENT_LENGTH)?.trim().parse().ok()
}

fn accepts_ranges(headers: &HeaderMap) -> bool {
    header_str(headers, ACCEPT_RANGES).is_some_and(|v| v.trim().eq_ignore_ascii_case("bytes"))
}

/// `Content-Range: bytes 100-199/1000` → 1000.
fn content_range_total(headers: &HeaderMap) -> Option<u64> {
    header_str(headers, CONTENT_RANGE)?
        .rsplit('/')
        .next()?
        .trim()
        .parse()
        .ok()
}

/// `Content-Range: bytes 100-199/1000` → 100.
fn content_range_start(headers: &HeaderMap) -> Option<u64> {
    let value = header_str(headers, CONTENT_RANGE)?.trim();
    let range = value.strip_prefix("bytes")?.trim_start();
    range.split('-').next()?.trim().parse().ok()
}

fn suggested_name(headers: &HeaderMap, url: &url::Url) -> String {
    let from_header = header_str(headers, CONTENT_DISPOSITION).and_then(|v| {
        v.split(';').find_map(|part| {
            let part = part.trim();
            part.strip_prefix("filename=")
                .map(|n| n.trim_matches('"').to_owned())
        })
    });
    from_header
        .or_else(|| {
            url.path_segments()?
                .next_back()
                .filter(|s| !s.is_empty())
                .map(percent_decode)
        })
        .unwrap_or_default()
}

fn percent_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    let hex = |b: u8| (b as char).to_digit(16).map(|d| d as u8);
    while i < bytes.len() {
        if bytes[i] == b'%'
            && i + 2 < bytes.len()
            && let (Some(hi), Some(lo)) = (hex(bytes[i + 1]), hex(bytes[i + 2]))
        {
            out.push(hi << 4 | lo);
            i += 3;
        } else {
            out.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn extension(name: &str) -> Option<String> {
    Path::new(name)
        .extension()
        .and_then(|e| e.to_str())
        .map(str::to_ascii_lowercase)
}

fn looks_like_media(content_type: Option<&str>, name: &str) -> bool {
    let has_media_extension =
        extension(name).is_some_and(|e| MEDIA_EXTENSIONS.contains(&e.as_str()));
    match content_type.map(|c| c.split(';').next().unwrap_or("").trim()) {
        Some(ct) if ct.starts_with("video/") || ct.starts_with("audio/") => true,
        Some("application/octet-stream" | "binary/octet-stream") | None => has_media_extension,
        _ => false,
    }
}

/// Lower-case media extension of a probed file, used to name the download.
pub fn media_extension(media: &DirectMedia) -> Option<String> {
    extension(&media.suggested_name).filter(|e| MEDIA_EXTENSIONS.contains(&e.as_str()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use reqwest::header::HeaderValue;

    #[test]
    fn media_detection() {
        assert!(looks_like_media(Some("video/mp4"), "x"));
        assert!(looks_like_media(Some("audio/mpeg; charset=binary"), ""));
        assert!(looks_like_media(
            Some("application/octet-stream"),
            "film.MKV"
        ));
        assert!(!looks_like_media(
            Some("application/octet-stream"),
            "setup.exe"
        ));
        assert!(!looks_like_media(
            Some("text/html; charset=utf-8"),
            "watch.mp4"
        ));
        assert!(looks_like_media(None, "a.flac"));
    }

    #[test]
    fn content_range_parsing() {
        let mut headers = HeaderMap::new();
        headers.insert(
            CONTENT_RANGE,
            HeaderValue::from_static("bytes 100-199/1000"),
        );
        assert_eq!(content_range_start(&headers), Some(100));
        assert_eq!(content_range_total(&headers), Some(1000));
        headers.insert(CONTENT_RANGE, HeaderValue::from_static("bytes */1000"));
        assert_eq!(content_range_total(&headers), Some(1000));
        assert_eq!(content_range_start(&headers), None);
    }

    #[test]
    fn suggested_names() {
        let url =
            url::Url::parse("https://cdn.example.org/files/Tears%20of%20Steel.mp4?t=1").unwrap();
        assert_eq!(
            suggested_name(&HeaderMap::new(), &url),
            "Tears of Steel.mp4"
        );
        let mut headers = HeaderMap::new();
        headers.insert(
            CONTENT_DISPOSITION,
            HeaderValue::from_static("attachment; filename=\"../../evil.mp4\""),
        );
        // Returned as-is (untrusted); sanitized later by media-core.
        assert_eq!(suggested_name(&headers, &url), "../../evil.mp4");
    }

    #[test]
    fn percent_decoding_is_lossless_or_lossy_but_safe() {
        assert_eq!(percent_decode("a%20b"), "a b");
        assert_eq!(percent_decode("100%"), "100%");
        assert_eq!(percent_decode("%zz"), "%zz");
        assert_eq!(percent_decode("%é1"), "%é1");
        assert_eq!(percent_decode("caf%C3%A9"), "café");
    }
}

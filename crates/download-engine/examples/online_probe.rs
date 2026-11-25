//! Online listening check (decision 0011): searches YouTube and resolves
//! the first result's audio stream with the real extractor.
//!
//! `cargo run -p download-engine --example online_probe -- <tools dir> <query>`
//! where `<tools dir>` holds the bundled tools (`<id>/<sha prefix>/…`), for
//! example `%LOCALAPPDATA%\Miarina Media\tools`. Prints timings, never the
//! stream URL itself (it carries tokens).

use std::time::Instant;

use download_engine::components::Components;
use download_engine::ytdlp::YtDlpEngine;
use tokio_util::sync::CancellationToken;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let mut args = std::env::args().skip(1);
    let (Some(tools), Some(query)) = (args.next(), args.next()) else {
        eprintln!("usage: online_probe <tools dir> <query>");
        std::process::exit(2);
    };
    let root = std::env::temp_dir().join("miarina-online-probe");
    let components = Components::new(root)
        .expect("components")
        .with_bundled(tools.into());
    let engine = YtDlpEngine::new(components);
    assert!(engine.available(), "yt-dlp not found in the tools dir");
    let cancel = CancellationToken::new();

    let started = Instant::now();
    let hits = engine.search(&query, 10, &cancel).await.expect("search");
    println!("search: {} hits in {:?}", hits.len(), started.elapsed());
    for h in &hits {
        println!(
            "  {}  {:>4.0}s  {}  — {}",
            h.video_id,
            h.duration,
            h.title,
            h.channel.as_deref().unwrap_or("?")
        );
    }
    let Some(first) = hits.first() else { return };

    let started = Instant::now();
    let stream = engine
        .resolve_audio(&first.video_id, &cancel)
        .await
        .expect("resolve");
    let host = url::Url::parse(&stream.url)
        .ok()
        .and_then(|u| u.host_str().map(str::to_owned))
        .unwrap_or_default();
    println!(
        "resolve: {:?} · host {host} · {} {} {:?} kbit/s · expires in {} min · {} headers",
        started.elapsed(),
        stream.ext.as_deref().unwrap_or("?"),
        stream.codec.as_deref().unwrap_or("?"),
        stream.bitrate,
        stream.expires_at.saturating_sub(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs()
        ) / 60,
        stream.http_headers.len()
    );
}

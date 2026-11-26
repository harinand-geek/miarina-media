//! Lyrics lookup check (decision 0011, lot 7): cleans a YouTube title and
//! asks LRCLIB, as the app does.
//!
//! `cargo run -p download-engine --example lyrics_probe -- "<title>" [channel] [seconds]`

use download_engine::HttpEngine;
use download_engine::lyrics::{
    MAX_LYRICS_BYTES, clean_title, lrclib_get_url, lrclib_search_url, pick_lrclib,
};
use media_core::validate_media_url;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let mut args = std::env::args().skip(1);
    let Some(raw) = args.next() else {
        eprintln!("usage: lyrics_probe <title> [channel] [seconds]");
        std::process::exit(2);
    };
    let channel = args.next().filter(|c| !c.is_empty());
    let duration: Option<f64> = args.next().and_then(|d| d.parse().ok());
    let (artist, title) = clean_title(&raw, channel.as_deref());
    println!("cleaned: artist={artist:?} title={title:?}");
    let http = HttpEngine::new().expect("http");
    let mut urls = Vec::new();
    if let Some(a) = artist.as_deref() {
        urls.push(("get", lrclib_get_url(a, &title, duration)));
    }
    urls.push(("search", lrclib_search_url(artist.as_deref(), &title)));
    for (kind, url) in urls {
        let Some(url) = url.and_then(|u| validate_media_url(u.as_str()).ok()) else {
            continue;
        };
        match http.fetch_text(&url, MAX_LYRICS_BYTES).await {
            Ok(Some(json)) => match pick_lrclib(&json, duration) {
                Some(lrc) => {
                    println!("{kind}: found, {} lines", lrc.lines().count());
                    for line in lrc.lines().take(3) {
                        println!("  {line}");
                    }
                    return;
                }
                None => println!("{kind}: no synchronised lyrics"),
            },
            Ok(None) => println!("{kind}: not found"),
            Err(e) => println!("{kind}: error {e}"),
        }
    }
}

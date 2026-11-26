//! Lyrics lookup check (decision 0011, lot 7): cleans a YouTube title and
//! asks LRCLIB, as the app does.
//!
//! `cargo run -p download-engine --example lyrics_probe -- "<title>" [channel] [seconds]`

use download_engine::HttpEngine;
use download_engine::lyrics::{
    MAX_LYRICS_BYTES, best_tononkira_hit, clean_title, lrclib_get_url, lrclib_search_url,
    pick_lrclib, tononkira_hits, tononkira_lyrics, tononkira_merge, tononkira_search_url,
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
    // Tononkira: plain lyrics of Malagasy songs.
    let Some(url) = tononkira_search_url(&title, artist.as_deref())
        .and_then(|u| validate_media_url(u.as_str()).ok())
    else {
        return;
    };
    let Ok(Some(html)) = http.fetch_text(&url, MAX_LYRICS_BYTES * 2).await else {
        println!("tononkira: search failed");
        return;
    };
    let hits = tononkira_hits(&html);
    println!("tononkira: {} hits", hits.len());
    let Some(hit) = best_tononkira_hit(&hits, &title) else {
        return;
    };
    let Ok(page) = validate_media_url(&hit.url) else {
        return;
    };
    // Read twice and keep the shared words, as the app does.
    let read = || async {
        let html = http.fetch_text(&page, MAX_LYRICS_BYTES * 2).await.ok()??;
        tononkira_lyrics(&html)
    };
    let (Some(a), Some(b)) = (read().await, read().await) else {
        println!("tononkira: page unread");
        return;
    };
    let text = tononkira_merge(&a, &b);
    println!(
        "tononkira: {} — {:?}, {} lines",
        hit.title,
        hit.artist,
        text.lines().count()
    );
    println!("{text}");
}

//! Lyrics found online (decision 0011, lot 7), for a track without a `.lrc`
//! next to it: the subtitles uploaded with its YouTube clip, then LRCLIB.
//! Only the title, artist and duration leave the device (to lrclib.net);
//! nothing when the owner's setting is off (checked by the app).

use std::time::Duration;

use download_engine::lyrics::{
    MAX_LYRICS_BYTES, clean_title, lrclib_get_url, lrclib_search_url, pick_lrclib, vtt_to_lrc,
};
use media_core::validate_media_url;

use super::get::thumbnail_fetcher;
use super::online::cached_subtitles;

/// One lookup gives up after this (the player does not wait for it).
const LOOKUP_TIMEOUT: Duration = Duration::from_secs(20);

pub struct LyricsQuery {
    pub title: String,
    /// The artist, or for an online track its channel.
    pub artist: Option<String>,
    pub duration_secs: Option<f64>,
    /// An online track: its uploaded subtitles are tried first.
    pub video_id: Option<String>,
}

pub struct FoundLyrics {
    /// Synchronised LRC text.
    pub lrc: String,
    /// `youtube` or `lrclib`.
    pub source: String,
}

/// Subtitle languages tried first: the songs this app plays most.
const PREFERRED: [&str; 3] = ["mg", "fr", "en"];

/// Synchronised lyrics for a track, or `None` (nothing found, no network,
/// Obtenir not started). Blocking: runs on the download runtime.
pub fn lyrics_find(query: LyricsQuery) -> Option<FoundLyrics> {
    let (http, _, runtime) = thumbnail_fetcher().ok()?;
    runtime.block_on(async {
        tokio::time::timeout(LOOKUP_TIMEOUT, async {
            if let Some(id) = query.video_id.as_deref() {
                let mut subs = cached_subtitles(id);
                subs.sort_by_key(|(lang, _)| {
                    PREFERRED
                        .iter()
                        .position(|p| lang == p || lang.starts_with(&format!("{p}-")))
                        .unwrap_or(PREFERRED.len())
                });
                for (_, url) in subs {
                    let Ok(url) = validate_media_url(&url) else {
                        continue;
                    };
                    if let Ok(Some(vtt)) = http.fetch_text(&url, MAX_LYRICS_BYTES).await
                        && let Some(lrc) = vtt_to_lrc(&vtt)
                    {
                        return Some(FoundLyrics {
                            lrc,
                            source: "youtube".into(),
                        });
                    }
                }
            }
            let (artist, title) = clean_title(&query.title, query.artist.as_deref());
            if title.is_empty() {
                return None;
            }
            let ask = |url: Option<url::Url>| {
                let http = &http;
                async move {
                    let url = validate_media_url(url?.as_str()).ok()?;
                    http.fetch_text(&url, MAX_LYRICS_BYTES).await.ok()?
                }
            };
            if let Some(artist) = artist.as_deref()
                && let Some(json) = ask(lrclib_get_url(artist, &title, query.duration_secs)).await
                && let Some(lrc) = pick_lrclib(&json, query.duration_secs)
            {
                return Some(FoundLyrics {
                    lrc,
                    source: "lrclib".into(),
                });
            }
            let json = ask(lrclib_search_url(artist.as_deref(), &title)).await?;
            pick_lrclib(&json, query.duration_secs).map(|lrc| FoundLyrics {
                lrc,
                source: "lrclib".into(),
            })
        })
        .await
        .ok()
        .flatten()
    })
}

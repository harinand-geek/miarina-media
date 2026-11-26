//! Lyrics found online (decision 0011, lot 7), for a track without a `.lrc`
//! next to it: the subtitles uploaded with its YouTube clip, then LRCLIB
//! (synchronised), then Tononkira (Malagasy songs, plain text). Only the
//! title, artist and duration leave the device (to lrclib.net, and title
//! and artist to tononkira.serasera.org); nothing when the owner's setting
//! is off (checked by the app).

use std::time::Duration;

use download_engine::HttpEngine;
use download_engine::lyrics::{
    MAX_LYRICS_BYTES, TONONKIRA, TononkiraHit, best_tononkira_hit, clean_title, lrclib_get_url,
    lrclib_hits, lrclib_query_url, lrclib_search_url, pick_lrclib, tononkira_hits,
    tononkira_lyrics, tononkira_merge, tononkira_search_url, vtt_to_lrc,
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
    /// LRC text when [synced], else plain lines.
    pub lrc: String,
    /// `youtube`, `lrclib` or `tononkira`.
    pub source: String,
    /// Timed lines (LRC); false for plain text (Tononkira).
    pub synced: bool,
}

/// Tononkira's results for a title, by artist first, then by title alone
/// (the site may spell the artist otherwise).
async fn tononkira_search(
    http: &HttpEngine,
    title: &str,
    artist: Option<&str>,
) -> Vec<TononkiraHit> {
    for artist in [artist, None] {
        let Some(url) =
            tononkira_search_url(title, artist).and_then(|u| validate_media_url(u.as_str()).ok())
        else {
            continue;
        };
        if let Ok(Some(html)) = http.fetch_text(&url, MAX_LYRICS_BYTES * 2).await {
            let hits = tononkira_hits(&html);
            if !hits.is_empty() {
                return hits;
            }
        }
        if artist.is_none() {
            break;
        }
    }
    Vec::new()
}

/// The lyrics on a Tononkira song page (its address checked), read twice
/// at once: the site slips random words into each load, and only the words
/// both readings share are kept (`tononkira_merge`).
async fn tononkira_page(http: &HttpEngine, url: &str) -> Option<String> {
    if !url.starts_with(&format!("{TONONKIRA}/hira/")) {
        return None;
    }
    let url = validate_media_url(url).ok()?;
    let read = || async {
        let html = http.fetch_text(&url, MAX_LYRICS_BYTES * 2).await.ok()??;
        tononkira_lyrics(&html)
    };
    let (first, second) = tokio::join!(read(), read());
    match (first, second) {
        (Some(a), Some(b)) => Some(tononkira_merge(&a, &b)),
        (one, other) => one.or(other),
    }
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
                            synced: true,
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
                    synced: true,
                });
            }
            if let Some(json) = ask(lrclib_search_url(artist.as_deref(), &title)).await
                && let Some(lrc) = pick_lrclib(&json, query.duration_secs)
            {
                return Some(FoundLyrics {
                    lrc,
                    source: "lrclib".into(),
                    synced: true,
                });
            }
            // Every word, in any field.
            let words = [artist.as_deref().unwrap_or_default(), title.as_str()].join(" ");
            if let Some(json) = ask(lrclib_query_url(words.trim())).await
                && let Some(lrc) = pick_lrclib(&json, query.duration_secs)
            {
                return Some(FoundLyrics {
                    lrc,
                    source: "lrclib".into(),
                    synced: true,
                });
            }
            // Last: Tononkira, the Malagasy songs, as plain text.
            let hits = tononkira_search(&http, &title, artist.as_deref()).await;
            let hit = best_tononkira_hit(&hits, &title)?;
            let text = tononkira_page(&http, &hit.url).await?;
            Some(FoundLyrics {
                lrc: text,
                source: "tononkira".into(),
                synced: false,
            })
        })
        .await
        .ok()
        .flatten()
    })
}

/// One result of a lyrics search the user runs, to choose from.
pub struct LyricsChoice {
    pub track: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub duration_secs: Option<f64>,
    /// `lrclib` (synchronised, [lrc] given) or `tononkira` (plain text,
    /// fetched from [url] when chosen: `lyrics_fetch`).
    pub source: String,
    pub lrc: Option<String>,
    pub url: Option<String>,
}

/// The plain lyrics of a Tononkira choice; `None` when the page has none
/// or is not on tononkira.serasera.org.
pub fn lyrics_fetch(url: String) -> Option<String> {
    let (http, _, runtime) = thumbnail_fetcher().ok()?;
    runtime.block_on(async {
        tokio::time::timeout(LOOKUP_TIMEOUT, tononkira_page(&http, &url))
            .await
            .ok()
            .flatten()
    })
}

/// « Chercher les paroles »: LRCLIB results (synchronised) for the title
/// and artist the user typed (not cleaned), the closest to [duration_secs]
/// first, then Tononkira's (plain text); at most 20 of each. Empty when
/// nothing is found or offline.
pub fn lyrics_search(
    title: String,
    artist: Option<String>,
    duration_secs: Option<f64>,
) -> Vec<LyricsChoice> {
    let Some((http, _, runtime)) = thumbnail_fetcher().ok() else {
        return Vec::new();
    };
    let title = title.trim().to_owned();
    let artist = artist
        .map(|a| a.trim().to_owned())
        .filter(|a| !a.is_empty());
    if title.is_empty() {
        return Vec::new();
    }
    runtime.block_on(async {
        let ask = |url: Option<url::Url>| {
            let http = &http;
            async move {
                let url = validate_media_url(url?.as_str()).ok()?;
                http.fetch_text(&url, MAX_LYRICS_BYTES).await.ok()?
            }
        };
        let search = async {
            let mut hits = match ask(lrclib_search_url(artist.as_deref(), &title)).await {
                Some(json) => lrclib_hits(&json, duration_secs, 20),
                None => Vec::new(),
            };
            if hits.is_empty() {
                let words = [artist.as_deref().unwrap_or_default(), title.as_str()].join(" ");
                if let Some(json) = ask(lrclib_query_url(words.trim())).await {
                    hits = lrclib_hits(&json, duration_secs, 20);
                }
            }
            let mut choices: Vec<LyricsChoice> = hits
                .into_iter()
                .map(|h| LyricsChoice {
                    track: h.track,
                    artist: h.artist,
                    album: h.album,
                    duration_secs: h.duration,
                    source: "lrclib".into(),
                    lrc: Some(h.lrc),
                    url: None,
                })
                .collect();
            let tk = tononkira_search(&http, &title, artist.as_deref()).await;
            choices.extend(tk.into_iter().take(20).map(|h| LyricsChoice {
                track: h.title,
                artist: h.artist,
                album: None,
                duration_secs: None,
                source: "tononkira".into(),
                lrc: None,
                url: Some(h.url),
            }));
            choices
        };
        tokio::time::timeout(LOOKUP_TIMEOUT, search)
            .await
            .unwrap_or_default()
    })
}

//! Online listening (decision 0011): YouTube search and the audio stream of
//! one video, played directly without a file. Everything runs on the device
//! with the bundled extractor; nothing is stored on disk. Stream URLs carry
//! tokens: they are kept in memory only and never logged.
//!
//! Errors reach Dart as `"<code>: <detail>"`, the code being one of
//! `tools` (extractor missing), `network`, `blocked` (the source refuses or
//! limits requests), `unavailable` (private, removed, protected, live…),
//! `canceled` (a newer search replaced this one) or `other`.

use std::collections::{HashMap, VecDeque};
use std::sync::Mutex;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use anyhow::{Result, anyhow};
use download_engine::EngineError;
use download_engine::ytdlp::{self, FormatSpec, OnlineHit, OnlineStream};
use tokio::sync::Semaphore;
use tokio_util::sync::CancellationToken;

use super::get::{extractor, thumbnail_fetcher};
use super::library::{LibraryItem, item, with_db};

/// Results kept per query, and for how long.
const SEARCH_CACHE_LEN: usize = 50;
const SEARCH_CACHE_TTL: Duration = Duration::from_secs(10 * 60);
/// A cached stream is dropped this long before its URL expires.
const STREAM_MARGIN_SECS: u64 = 5 * 60;
const STREAM_CACHE_LEN: usize = 100;
/// A picture slower than this is shown as the placeholder.
const THUMBNAIL_TIMEOUT: Duration = Duration::from_secs(15);

static SEARCH_CACHE: Mutex<VecDeque<(String, Instant, Vec<OnlineTrack>)>> =
    Mutex::new(VecDeque::new());
static STREAM_CACHE: Mutex<Option<HashMap<String, OnlineStream>>> = Mutex::new(None);
/// The running search: a newer one cancels it (its process is killed).
static CURRENT_SEARCH: Mutex<Option<CancellationToken>> = Mutex::new(None);
/// Stream resolutions at once: the track to play and the next one.
/// The track the listener is waiting for: a newer one cancels it (its
/// process is killed), so a click never waits behind an older click.
static CURRENT_RESOLVE: Mutex<Option<(String, CancellationToken)>> = Mutex::new(None);
/// Streams found ahead (the next track, the first result): one at a time,
/// and never in the way of the one the listener waits for.
static AHEAD_SLOT: Semaphore = Semaphore::const_new(1);
/// Searches nobody typed (the En ligne page's grids): one at a time, and
/// they neither cancel nor are cancelled by the user's search.
static BACKGROUND_SEARCH: Semaphore = Semaphore::const_new(1);

pub struct OnlineTrack {
    pub video_id: String,
    pub title: String,
    pub channel: Option<String>,
    pub duration_secs: f64,
    /// Picture published by the site (https URL), for the list and the
    /// player's artwork.
    pub thumbnail: Option<String>,
}

pub struct OnlineResults {
    pub query: String,
    pub tracks: Vec<OnlineTrack>,
}

pub struct OnlineHeader {
    pub name: String,
    pub value: String,
}

pub struct OnlineStreamInfo {
    pub video_id: String,
    /// Short-lived: open it now, never store it.
    pub url: String,
    pub http_headers: Vec<OnlineHeader>,
    /// Unix milliseconds after which `url` stops working.
    pub expires_at_ms: i64,
    pub duration_secs: Option<f64>,
    pub ext: Option<String>,
    pub codec: Option<String>,
    pub bitrate_kbps: Option<f64>,
}

/// The extractor is installed and Obtenir has started.
#[flutter_rust_bridge::frb(sync)]
pub fn online_available() -> bool {
    extractor().is_ok_and(|(engine, _)| engine.available())
}

/// The video's page, for Obtenir. `None` for a malformed id.
#[flutter_rust_bridge::frb(sync)]
pub fn online_watch_url(video_id: String) -> Option<String> {
    ytdlp::watch_url(&video_id)
}

/// Videos matching `query`, at most `limit` (1–30). A newer call cancels
/// this one (`canceled`). Blocking: runs on the download runtime.
/// `background`: a search nobody typed (the page's grids), see
/// `BACKGROUND_SEARCH`.
pub fn online_search(query: String, limit: u32, background: bool) -> Result<OnlineResults> {
    let key = format!("{limit}:{}", cache_key(&query));
    if let Some(tracks) = cached_search(&key) {
        return Ok(OnlineResults { query, tracks });
    }
    let (engine, runtime) = extractor().map_err(|_| coded("tools", "Obtenir has not started"))?;
    if !engine.available() {
        return Err(coded("tools", "the media extractor is not installed"));
    }
    let cancel = CancellationToken::new();
    if !background
        && let Ok(mut current) = CURRENT_SEARCH.lock()
        && let Some(previous) = current.replace(cancel.clone())
    {
        previous.cancel();
    }
    let hits = runtime.block_on(async {
        let _slot = if background {
            Some(
                BACKGROUND_SEARCH
                    .acquire()
                    .await
                    .map_err(|_| EngineError::Canceled)?,
            )
        } else {
            None
        };
        // Another call may have run the same search meanwhile.
        if let Some(tracks) = cached_search(&key) {
            return Ok(Err(tracks));
        }
        engine.search(&query, limit, &cancel).await.map(Ok)
    });
    let hits = match hits.map_err(|e| engine_error(&e))? {
        Ok(hits) => hits,
        Err(tracks) => return Ok(OnlineResults { query, tracks }),
    };
    let tracks: Vec<OnlineTrack> = hits.into_iter().map(track).collect();
    remember_search(key, &tracks);
    Ok(OnlineResults { query, tracks })
}

/// The audio stream to open for `video_id`. `fresh`: ignore the cached
/// one (the player was refused with it, e.g. HTTP 403 after a long pause).
/// `ahead`: found before it is needed (the next track, the first result),
/// one at a time; otherwise the listener waits for it, and it cancels the
/// previous such request for another video (`canceled`).
pub fn online_resolve(video_id: String, fresh: bool, ahead: bool) -> Result<OnlineStreamInfo> {
    if !ytdlp::is_video_id(&video_id) {
        return Err(coded("unavailable", "this is not a valid video id"));
    }
    if !fresh && let Some(stream) = cached_stream(&video_id) {
        return Ok(stream_info(stream));
    }
    let (engine, runtime) = extractor().map_err(|_| coded("tools", "Obtenir has not started"))?;
    if !engine.available() {
        return Err(coded("tools", "the media extractor is not installed"));
    }
    let cancel = CancellationToken::new();
    if !ahead
        && let Ok(mut current) = CURRENT_RESOLVE.lock()
        && let Some((previous, token)) = current.replace((video_id.clone(), cancel.clone()))
        && previous != video_id
    {
        token.cancel();
    }
    let stream = runtime.block_on(async {
        let _slot = if ahead {
            Some(
                AHEAD_SLOT
                    .acquire()
                    .await
                    .map_err(|_| EngineError::Canceled)?,
            )
        } else {
            None
        };
        // Another call may have resolved it while this one waited.
        if !fresh && let Some(stream) = cached_stream(&video_id) {
            return Ok(stream);
        }
        engine.resolve_audio(&video_id, &cancel).await
    });
    let stream = stream.map_err(|e| engine_error(&e))?;
    remember_stream(stream.clone());
    Ok(stream_info(stream))
}

/// The result's picture as a local file (the UI never loads remote
/// images), cached with the source thumbnails. Only YouTube's picture
/// hosts are fetched; anything else, or a failure, gives `None`.
pub fn online_thumbnail(url: String) -> Option<String> {
    let url = media_core::validate_media_url(&url).ok()?;
    if !is_picture_host(&url) {
        return None;
    }
    let (http, dir, runtime) = thumbnail_fetcher().ok()?;
    let path = runtime
        .block_on(async {
            tokio::time::timeout(THUMBNAIL_TIMEOUT, http.fetch_thumbnail(&url, &dir)).await
        })
        .ok()?
        .ok()?;
    Some(path.to_string_lossy().into_owned())
}

/// `https://i.ytimg.com/…`, `https://i9.ytimg.com/…`: where YouTube
/// serves its thumbnails.
fn is_picture_host(url: &media_core::ValidatedUrl) -> bool {
    url.as_str().starts_with("https://")
        && (url.host() == "ytimg.com" || url.host().ends_with(".ytimg.com"))
}

/// A format Obtenir offers for an online result (decision 0011):
/// `original` (the source's audio, no conversion), `mp3-320`, `mp3-128`.
pub struct OnlineOffer {
    pub key: String,
    /// Engine format spec for `get_start_download`.
    pub format_id: String,
    pub label: String,
    pub extension: String,
}

/// The formats Obtenir offers for online results. Without FFmpeg, only the
/// source's own audio (nothing can be converted).
#[flutter_rust_bridge::frb(sync)]
pub fn online_obtain_offers() -> Vec<OnlineOffer> {
    let ffmpeg = extractor().is_ok_and(|(engine, _)| engine.has_ffmpeg());
    obtain_offers(ffmpeg)
}

fn obtain_offers(ffmpeg: bool) -> Vec<OnlineOffer> {
    let offer = |key: &str, label: &str, extension: &str, spec: FormatSpec| OnlineOffer {
        key: key.into(),
        format_id: spec.encode(),
        label: label.into(),
        extension: extension.into(),
    };
    let mp3 = |kbps: u32| FormatSpec {
        selector: "ba/b".into(),
        merge: None,
        extract_audio: Some("mp3".into()),
        audio_kbps: Some(kbps),
        subtitles: None,
    };
    let mut offers = vec![offer(
        "original",
        "M4A",
        "m4a",
        FormatSpec {
            selector: "ba[ext=m4a]/ba".into(),
            merge: None,
            extract_audio: None,
            audio_kbps: None,
            subtitles: None,
        },
    )];
    if ffmpeg {
        offers.push(offer("mp3-320", "MP3 · 320 kbps", "mp3", mp3(320)));
        offers.push(offer("mp3-128", "MP3 · 128 kbps", "mp3", mp3(128)));
    }
    offers
}

/// A result already obtained: its library entry, played instead of the
/// stream (works offline).
pub struct OnlineLocal {
    pub video_id: String,
    pub item: LibraryItem,
}

/// Which of `video_ids` are in the library (obtained from their page,
/// file present). Malformed ids are ignored.
pub fn online_local(db_path: String, video_ids: Vec<String>) -> Result<Vec<OnlineLocal>> {
    let pages: Vec<(String, String)> = video_ids
        .into_iter()
        .take(100)
        .filter_map(|id| ytdlp::watch_url(&id).map(|url| (id, url)))
        .collect();
    if pages.is_empty() {
        return Ok(Vec::new());
    }
    let urls: Vec<String> = pages.iter().map(|(_, url)| url.clone()).collect();
    with_db(&db_path, |db| {
        let found = db.media_by_source_urls(&urls)?;
        let mut local = Vec::new();
        for (id, url) in &pages {
            // The newest copy when the same page was obtained twice.
            if let Some(m) = found.iter().find(|m| m.source_url.as_deref() == Some(url)) {
                local.push(OnlineLocal {
                    video_id: id.clone(),
                    item: item(m.clone()),
                });
            }
        }
        Ok(local)
    })
}

fn track(hit: OnlineHit) -> OnlineTrack {
    OnlineTrack {
        video_id: hit.video_id,
        title: hit.title,
        channel: hit.channel,
        duration_secs: hit.duration,
        thumbnail: hit.thumbnail,
    }
}

fn stream_info(stream: OnlineStream) -> OnlineStreamInfo {
    OnlineStreamInfo {
        video_id: stream.video_id,
        url: stream.url,
        http_headers: stream
            .http_headers
            .into_iter()
            .map(|(name, value)| OnlineHeader { name, value })
            .collect(),
        expires_at_ms: i64::try_from(stream.expires_at.saturating_mul(1000)).unwrap_or(i64::MAX),
        duration_secs: stream.duration,
        ext: stream.ext,
        codec: stream.codec,
        bitrate_kbps: stream.bitrate,
    }
}

fn coded(code: &str, detail: &str) -> anyhow::Error {
    anyhow!("{code}: {detail}")
}

/// The UI's error code for an extractor failure. Details never carry the
/// stream URL (the extractor's messages are about the page).
fn engine_error(error: &EngineError) -> anyhow::Error {
    match error {
        EngineError::Canceled => coded("canceled", ""),
        // The extractor waited too long (a slow source, other downloads
        // at once): not a lost connection.
        EngineError::Network { message } if message.contains("too long") => coded("slow", message),
        EngineError::Network { message } => coded("network", &short(message)),
        EngineError::Http { status: 403 | 429 } => {
            coded("blocked", "the source refused the request")
        }
        EngineError::Http { status } => coded("network", &format!("HTTP {status}")),
        EngineError::Unsupported { reason } if reason.contains("not installed") => {
            coded("tools", reason)
        }
        EngineError::Unsupported { reason } => coded("unavailable", reason),
        other => coded("other", &other.to_string()),
    }
}

/// An extractor message for the details: one line, bounded. It is about
/// the page, never the stream URL.
fn short(message: &str) -> String {
    message
        .lines()
        .next()
        .unwrap_or_default()
        .chars()
        .take(200)
        .collect()
}

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs())
}

/// Case and spacing do not make a different search.
fn cache_key(query: &str) -> String {
    query
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

fn cached_search(key: &str) -> Option<Vec<OnlineTrack>> {
    let cache = SEARCH_CACHE.lock().ok()?;
    cache
        .iter()
        .find(|(k, at, _)| k == key && at.elapsed() < SEARCH_CACHE_TTL)
        .map(|(_, _, tracks)| tracks.iter().map(copy_track).collect())
}

fn remember_search(key: String, tracks: &[OnlineTrack]) {
    if let Ok(mut cache) = SEARCH_CACHE.lock() {
        cache.retain(|(k, at, _)| *k != key && at.elapsed() < SEARCH_CACHE_TTL);
        cache.push_front((key, Instant::now(), tracks.iter().map(copy_track).collect()));
        cache.truncate(SEARCH_CACHE_LEN);
    }
}

fn copy_track(t: &OnlineTrack) -> OnlineTrack {
    OnlineTrack {
        video_id: t.video_id.clone(),
        title: t.title.clone(),
        channel: t.channel.clone(),
        duration_secs: t.duration_secs,
        thumbnail: t.thumbnail.clone(),
    }
}

/// The uploaded subtitles of a video whose stream is cached (it played or
/// is about to): `(language, URL)`, for its lyrics.
pub(crate) fn cached_subtitles(video_id: &str) -> Vec<(String, String)> {
    cached_stream(video_id)
        .map(|s| s.subtitles)
        .unwrap_or_default()
}

fn fresh_enough(stream: &OnlineStream, now: u64) -> bool {
    stream.expires_at > now + STREAM_MARGIN_SECS
}

fn cached_stream(video_id: &str) -> Option<OnlineStream> {
    let cache = STREAM_CACHE.lock().ok()?;
    let stream = cache.as_ref()?.get(video_id)?;
    fresh_enough(stream, now_secs()).then(|| stream.clone())
}

fn remember_stream(stream: OnlineStream) {
    let Ok(mut cache) = STREAM_CACHE.lock() else {
        return;
    };
    let cache = cache.get_or_insert_with(HashMap::new);
    let now = now_secs();
    cache.retain(|_, s| fresh_enough(s, now));
    if cache.len() >= STREAM_CACHE_LEN
        && let Some(oldest) = cache
            .iter()
            .min_by_key(|(_, s)| s.expires_at)
            .map(|(id, _)| id.clone())
    {
        cache.remove(&oldest);
    }
    cache.insert(stream.video_id.clone(), stream);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stream(id: &str, expires_at: u64) -> OnlineStream {
        OnlineStream {
            video_id: id.to_owned(),
            url: "https://h.example/a".to_owned(),
            http_headers: vec![("User-Agent".to_owned(), "x".to_owned())],
            expires_at,
            duration: Some(10.0),
            ext: Some("m4a".to_owned()),
            codec: None,
            bitrate: None,
            subtitles: Vec::new(),
        }
    }

    #[test]
    fn queries_differing_by_case_or_spaces_share_a_cache_entry() {
        assert_eq!(cache_key("  Sakaté   BOY "), cache_key("sakaté boy"));
        assert_ne!(cache_key("sakaté boy"), cache_key("sakate boy"));
    }

    #[test]
    fn streams_close_to_expiry_are_not_reused() {
        let now = now_secs();
        remember_stream(stream("AAAAAAAAAAA", now + 3600));
        remember_stream(stream("BBBBBBBBBBB", now + 60));
        assert!(cached_stream("AAAAAAAAAAA").is_some());
        assert!(cached_stream("BBBBBBBBBBB").is_none());
        assert!(cached_stream("CCCCCCCCCCC").is_none());
    }

    #[test]
    fn errors_carry_a_code_the_ui_can_read() {
        let code = |e: EngineError| engine_error(&e).to_string();
        assert!(code(EngineError::Canceled).starts_with("canceled:"));
        assert!(
            code(EngineError::Network {
                message: "x".into()
            })
            .starts_with("network:")
        );
        assert!(code(EngineError::Http { status: 429 }).starts_with("blocked:"));
        let slow = code(EngineError::Network {
            message: "the source took too long to answer".into(),
        });
        assert_eq!(slow, "slow: the source took too long to answer");
        let lost = code(EngineError::Network {
            message: "[Errno 11001] getaddrinfo failed\nmore".into(),
        });
        assert_eq!(lost, "network: [Errno 11001] getaddrinfo failed");
        assert!(code(EngineError::Http { status: 403 }).starts_with("blocked:"));
        assert!(code(EngineError::Http { status: 500 }).starts_with("network:"));
        assert!(
            code(EngineError::Unsupported {
                reason: "the media extractor (yt-dlp) is not installed".into()
            })
            .starts_with("tools:")
        );
        assert!(
            code(EngineError::Unsupported {
                reason: "this media requires an account or is private".into()
            })
            .starts_with("unavailable:")
        );
    }

    #[test]
    fn invalid_ids_are_refused_before_any_work() {
        let err = online_resolve("../etc/passwd".into(), false, false)
            .err()
            .unwrap();
        assert!(err.to_string().starts_with("unavailable:"));
    }

    #[test]
    fn only_youtube_pictures_are_fetched() {
        let ok = |u: &str| is_picture_host(&media_core::validate_media_url(u).unwrap());
        assert!(ok("https://i.ytimg.com/vi/AAAAAAAAAAA/hq720.jpg?sqp=x"));
        assert!(ok("https://i9.ytimg.com/vi/AAAAAAAAAAA/default.jpg"));
        assert!(!ok("http://i.ytimg.com/vi/AAAAAAAAAAA/hq720.jpg"));
        assert!(!ok("https://ytimg.com.evil.example/a.jpg"));
        assert!(!ok("https://evilytimg.com/a.jpg"));
        assert!(!ok("https://example.com/a.jpg"));
    }

    #[test]
    fn obtain_offers_convert_only_with_ffmpeg() {
        let keys =
            |ffmpeg| -> Vec<String> { obtain_offers(ffmpeg).into_iter().map(|o| o.key).collect() };
        assert_eq!(keys(true), ["original", "mp3-320", "mp3-128"]);
        assert_eq!(keys(false), ["original"]);
        for o in obtain_offers(true) {
            let spec = FormatSpec::decode(&o.format_id).unwrap();
            assert_eq!(spec.extract_audio.is_some(), o.extension == "mp3");
        }
        let mp3 = FormatSpec::decode(&obtain_offers(true)[2].format_id).unwrap();
        assert_eq!(mp3.audio_kbps, Some(128));
    }

    #[test]
    fn stream_expiry_is_given_in_milliseconds() {
        let info = stream_info(stream("AAAAAAAAAAA", 1_764_100_000));
        assert_eq!(info.expires_at_ms, 1_764_100_000_000);
        assert_eq!(info.http_headers[0].name, "User-Agent");
    }
}

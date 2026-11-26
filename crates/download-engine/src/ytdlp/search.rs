//! Online listening (decision 0011): YouTube search results and the audio
//! stream of one video, both from untrusted extractor output. Nothing here
//! downloads: the stream URL is handed to the player and never stored.

use std::collections::{BTreeMap, HashSet};
use std::time::{SystemTime, UNIX_EPOCH};

use media_core::validate_media_url;
use serde::Deserialize;

use super::info::RawInfo;
use super::playlist::entry_thumbnail;

/// Results asked for at most (`ytsearch<N>:`).
pub const MAX_SEARCH_RESULTS: u32 = 30;
/// Characters of a query kept; longer ones are cut.
pub const MAX_QUERY_CHARS: usize = 200;
/// Response headers kept for the player, and their bounds.
const KEPT_HEADERS: [&str; 6] = [
    "user-agent",
    "accept",
    "accept-language",
    "referer",
    "origin",
    "sec-fetch-mode",
];
const MAX_HEADER_VALUE: usize = 1024;
/// Lifetime assumed when the stream URL does not say when it expires.
const DEFAULT_LIFETIME_SECS: u64 = 3600;

/// The query in the form yt-dlp searches: control characters removed,
/// spaces collapsed, length bounded. `None` for an empty query.
pub fn search_term(query: &str, limit: u32) -> Option<String> {
    let cleaned: String = query
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .chars()
        .take(MAX_QUERY_CHARS)
        .collect();
    let cleaned = cleaned.trim();
    if cleaned.is_empty() {
        return None;
    }
    let limit = limit.clamp(1, MAX_SEARCH_RESULTS);
    Some(format!("ytsearch{limit}:{cleaned}"))
}

/// A YouTube video id: 11 characters of the URL-safe base64 alphabet.
pub fn is_video_id(id: &str) -> bool {
    id.len() == 11
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

/// The canonical page of a video, built here so that callers can never
/// make the extractor open an arbitrary URL.
pub fn watch_url(id: &str) -> Option<String> {
    is_video_id(id).then(|| format!("https://www.youtube.com/watch?v={id}"))
}

#[derive(Debug, Clone, PartialEq)]
pub struct OnlineHit {
    pub video_id: String,
    pub title: String,
    /// Channel or uploader, as published.
    pub channel: Option<String>,
    /// Seconds.
    pub duration: f64,
    /// Picture published by the site (untrusted URL, validated scheme).
    pub thumbnail: Option<String>,
}

/// The playable videos of a search result, in the source's order: live,
/// upcoming, duplicated or malformed entries are left out.
pub fn hits_of(info: &RawInfo) -> Vec<OnlineHit> {
    let mut seen = HashSet::new();
    info.entries
        .as_deref()
        .unwrap_or_default()
        .iter()
        .filter(|e| e.kind.as_deref().is_none_or(|k| k == "url"))
        .filter(|e| {
            !matches!(
                e.live_status.as_deref(),
                Some("is_live" | "is_upcoming" | "post_live")
            )
        })
        .filter_map(|e| {
            let id = e.id.as_deref().filter(|id| is_video_id(id))?;
            let duration = e.duration.filter(|d| d.is_finite() && *d > 0.0)?;
            let title = e
                .title
                .as_deref()
                .map(str::trim)
                .filter(|t| !t.is_empty())?;
            if !seen.insert(id.to_owned()) {
                return None;
            }
            Some(OnlineHit {
                video_id: id.to_owned(),
                title: title.to_owned(),
                channel: [e.channel.as_deref(), e.uploader.as_deref()]
                    .into_iter()
                    .flatten()
                    .map(str::trim)
                    .find(|c| !c.is_empty())
                    .map(str::to_owned),
                duration,
                thumbnail: entry_thumbnail(e).filter(|u| {
                    validate_media_url(u).is_ok_and(|v| v.as_str().starts_with("https://"))
                }),
            })
        })
        .collect()
}

/// `yt-dlp -f bestaudio --dump-single-json` output (untrusted): the chosen
/// format's fields are at the top level.
#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawStream {
    pub id: Option<String>,
    pub url: Option<String>,
    pub protocol: Option<String>,
    pub ext: Option<String>,
    pub acodec: Option<String>,
    pub vcodec: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub abr: Option<f64>,
    #[serde(default, deserialize_with = "lenient")]
    pub duration: Option<f64>,
    #[serde(default, deserialize_with = "lenient")]
    pub http_headers: Option<BTreeMap<String, String>>,
    #[serde(default, deserialize_with = "lenient")]
    pub is_live: Option<bool>,
    pub live_status: Option<String>,
    pub has_drm: Option<serde_json::Value>,
    /// Subtitles uploaded with the video (not the automatic captions), by
    /// language.
    #[serde(default, deserialize_with = "lenient")]
    pub subtitles: Option<BTreeMap<String, Vec<RawSubtitleTrack>>>,
    /// Every format; the HLS ones carry the master playlist (the clip,
    /// video and sound together).
    #[serde(default, deserialize_with = "lenient")]
    pub formats: Option<Vec<RawManifestFormat>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawManifestFormat {
    pub protocol: Option<String>,
    pub manifest_url: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawSubtitleTrack {
    pub ext: Option<String>,
    pub url: Option<String>,
}

fn lenient<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: serde::de::DeserializeOwned,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(serde_json::from_value(value).ok())
}

#[derive(Debug, Clone, PartialEq)]
pub struct OnlineStream {
    pub video_id: String,
    /// Short-lived; never stored or logged.
    pub url: String,
    /// Headers the player must send with its requests.
    pub http_headers: Vec<(String, String)>,
    /// Unix seconds after which the URL no longer works.
    pub expires_at: u64,
    pub duration: Option<f64>,
    pub ext: Option<String>,
    pub codec: Option<String>,
    /// kbit/s.
    pub bitrate: Option<f64>,
    /// WebVTT subtitles uploaded with the clip, `(language, URL)`: often
    /// the lyrics. The URLs expire with the stream's.
    pub subtitles: Vec<(String, String)>,
    /// The clip: YouTube's HLS master playlist (video and sound, 144p to
    /// 1080p), when offered. Expires with the stream.
    pub hls: Option<String>,
}

/// The HLS master playlist, served by googlevideo.com over https.
fn hls_manifest(formats: Option<Vec<RawManifestFormat>>) -> Option<String> {
    formats
        .unwrap_or_default()
        .into_iter()
        .filter(|f| f.protocol.as_deref().is_some_and(|p| p.starts_with("m3u8")))
        .find_map(|f| {
            let url = validate_media_url(f.manifest_url.as_deref()?).ok()?;
            let host = url.host();
            (url.as_str().starts_with("https://")
                && (host == "googlevideo.com" || host.ends_with(".googlevideo.com")))
            .then(|| url.as_str().to_owned())
        })
}

/// Uploaded WebVTT subtitles served by YouTube (https), live chat left out.
fn uploaded_subtitles(
    raw: Option<BTreeMap<String, Vec<RawSubtitleTrack>>>,
) -> Vec<(String, String)> {
    raw.unwrap_or_default()
        .into_iter()
        .filter(|(lang, _)| lang != "live_chat")
        .filter_map(|(lang, tracks)| {
            let url = tracks
                .into_iter()
                .filter(|t| t.ext.as_deref() == Some("vtt"))
                .find_map(|t| {
                    let url = validate_media_url(t.url.as_deref()?).ok()?;
                    let host = url.host();
                    (url.as_str().starts_with("https://")
                        && (host == "youtube.com" || host.ends_with(".youtube.com")))
                    .then(|| url.as_str().to_owned())
                })?;
            Some((lang, url))
        })
        .collect()
}

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs())
}

/// When a stream URL expires: its `expire` query parameter, or the
/// `/expire/<n>/` path segment some hosts use.
pub fn expiry_of(url: &url::Url) -> Option<u64> {
    let from_query = url
        .query_pairs()
        .find(|(k, _)| k == "expire")
        .and_then(|(_, v)| v.parse().ok());
    from_query.or_else(|| {
        let mut segments = url.path_segments()?;
        segments.find(|s| *s == "expire")?;
        segments.next()?.parse().ok()
    })
}

/// The audio stream the player opens, or why there is none. `expected_id`
/// guards against the extractor answering for another video.
pub fn stream_of(bytes: &[u8], expected_id: &str) -> Result<OnlineStream, String> {
    let raw: RawStream =
        serde_json::from_slice(bytes).map_err(|_| "the extractor gave an unreadable answer")?;
    if raw.id.as_deref() != Some(expected_id) {
        return Err("the extractor answered for another media".into());
    }
    if raw.is_live == Some(true)
        || matches!(raw.live_status.as_deref(), Some("is_live" | "is_upcoming"))
    {
        return Err("live streams are not supported".into());
    }
    let drm = match &raw.has_drm {
        Some(serde_json::Value::Bool(b)) => *b,
        Some(serde_json::Value::String(s)) => s != "false",
        _ => false,
    };
    if drm {
        return Err("this media is protected (DRM) and cannot be played".into());
    }
    let has = |c: &Option<String>| c.as_deref().is_some_and(|c| c != "none" && !c.is_empty());
    if !has(&raw.acodec) && raw.acodec.is_some() {
        return Err("no audio stream was found".into());
    }
    let url = raw
        .url
        .as_deref()
        .ok_or("no audio stream was found")
        .and_then(|u| validate_media_url(u).map_err(|_| "the audio stream address is invalid"))?;
    let parsed =
        url::Url::parse(url.as_str()).map_err(|_| "the audio stream address is invalid")?;
    if parsed.scheme() != "https" {
        return Err("the audio stream is not served securely".into());
    }
    let http_headers = raw
        .http_headers
        .unwrap_or_default()
        .into_iter()
        .filter(|(k, _)| KEPT_HEADERS.contains(&k.to_ascii_lowercase().as_str()))
        .filter(|(_, v)| v.len() <= MAX_HEADER_VALUE && !v.chars().any(char::is_control))
        .collect();
    Ok(OnlineStream {
        video_id: expected_id.to_owned(),
        expires_at: expiry_of(&parsed).unwrap_or_else(|| now_secs() + DEFAULT_LIFETIME_SECS),
        url: url.as_str().to_owned(),
        http_headers,
        duration: raw.duration.filter(|d| d.is_finite() && *d > 0.0),
        ext: raw.ext,
        codec: raw.acodec.filter(|c| c != "none"),
        bitrate: raw.abr.filter(|b| b.is_finite() && *b > 0.0),
        subtitles: uploaded_subtitles(raw.subtitles),
        hls: hls_manifest(raw.formats),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn search_term_cleans_and_bounds() {
        assert_eq!(
            search_term("  Sakaté \n Boy\t", 20).as_deref(),
            Some("ytsearch20:Sakaté Boy")
        );
        assert_eq!(search_term("a", 0).as_deref(), Some("ytsearch1:a"));
        assert_eq!(search_term("a", 999).as_deref(), Some("ytsearch30:a"));
        assert_eq!(search_term(" \u{7}\n ", 10), None);
        let long = "é".repeat(500);
        let term = search_term(&long, 5).unwrap();
        assert_eq!(term.chars().count(), "ytsearch5:".len() + MAX_QUERY_CHARS);
    }

    #[test]
    fn a_query_that_looks_like_an_option_stays_a_query() {
        // Passed after `--` and prefixed, it can never become a flag.
        assert_eq!(
            search_term("--exec calc", 3).as_deref(),
            Some("ytsearch3:--exec calc")
        );
    }

    #[test]
    fn video_ids_are_strict() {
        assert!(is_video_id("dQw4w9WgXcQ"));
        assert!(is_video_id("a-b_c-d_e-f"));
        assert!(!is_video_id("dQw4w9WgXc"));
        assert!(!is_video_id("dQw4w9WgXcQQ"));
        assert!(!is_video_id("dQw4w9WgX/Q"));
        assert!(!is_video_id("dQw4w9WgX Q"));
        assert_eq!(
            watch_url("dQw4w9WgXcQ").as_deref(),
            Some("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        );
        assert_eq!(watch_url("../../etc"), None);
    }

    const SEARCH: &str = r#"{
      "_type": "playlist", "id": "sakate", "title": "sakate",
      "entries": [
        {"_type": "url", "ie_key": "Youtube", "id": "AAAAAAAAAAA",
         "url": "https://www.youtube.com/watch?v=AAAAAAAAAAA",
         "title": " Sakaté Boy - Zanak Antesaka ", "duration": 237.0,
         "channel": " Sakaté Boy Officiel ",
         "thumbnails": [
           {"url": "https://i.ytimg.com/vi/AAAAAAAAAAA/hq720.jpg", "width": 720},
           {"url": "https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg", "width": 480},
           {"url": "https://i.ytimg.com/vi/AAAAAAAAAAA/default.jpg", "width": 120}
         ]},
        {"_type": "url", "id": "BBBBBBBBBBB", "title": "Live 24/7",
         "live_status": "is_live", "duration": null},
        {"_type": "url", "id": "CCCCCCCCCCC", "title": "Premiere",
         "live_status": "is_upcoming", "duration": 200},
        {"_type": "url", "id": "AAAAAAAAAAA", "title": "Duplicate", "duration": 10},
        {"_type": "url", "id": "not-an-id", "title": "Bad", "duration": 10},
        {"_type": "url", "id": "DDDDDDDDDDD", "title": "", "duration": 10},
        {"_type": "playlist", "id": "EEEEEEEEEEE", "title": "A mix", "duration": 10},
        {"_type": "url", "id": "FFFFFFFFFFF", "title": "No channel",
         "duration": "oops", "uploader": "Someone"},
        {"_type": "url", "id": "GGGGGGGGGGG", "title": "Plain",
         "duration": 61.5, "uploader": "Uploader",
         "thumbnail": "http://insecure.example/x.jpg"}
      ]
    }"#;

    #[test]
    fn hits_keep_only_playable_videos() {
        let info = RawInfo::parse(SEARCH.as_bytes()).unwrap();
        let hits = hits_of(&info);
        let ids: Vec<&str> = hits.iter().map(|h| h.video_id.as_str()).collect();
        assert_eq!(ids, ["AAAAAAAAAAA", "GGGGGGGGGGG"]);
        let first = &hits[0];
        assert_eq!(first.title, "Sakaté Boy - Zanak Antesaka");
        assert_eq!(first.channel.as_deref(), Some("Sakaté Boy Officiel"));
        assert_eq!(first.duration, 237.0);
        assert_eq!(
            first.thumbnail.as_deref(),
            Some("https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg")
        );
        // Uploader stands in for the channel; an http picture is dropped.
        assert_eq!(hits[1].channel.as_deref(), Some("Uploader"));
        assert_eq!(hits[1].thumbnail, None);
    }

    #[test]
    fn an_empty_search_gives_no_hits() {
        let info = RawInfo::parse(br#"{"_type":"playlist","entries":[]}"#).unwrap();
        assert!(hits_of(&info).is_empty());
        let info = RawInfo::parse(br#"{"_type":"playlist"}"#).unwrap();
        assert!(hits_of(&info).is_empty());
    }

    fn stream_json(extra: &str) -> String {
        format!(
            r#"{{"id":"AAAAAAAAAAA","ext":"m4a","acodec":"mp4a.40.2","vcodec":"none",
               "abr":129.5,"duration":237,
               "url":"https://rr1.googlevideo.com/videoplayback?expire=1764100000&id=x",
               "http_headers":{{"User-Agent":"Mozilla/5.0","Accept":"*/*",
                 "Cookie":"secret=1","X-Evil":"a\r\nInjected: b"}}{extra}}}"#
        )
    }

    #[test]
    fn stream_keeps_safe_headers_and_reads_expiry() {
        let s = stream_of(stream_json("").as_bytes(), "AAAAAAAAAAA").unwrap();
        assert_eq!(s.expires_at, 1_764_100_000);
        assert_eq!(s.ext.as_deref(), Some("m4a"));
        assert_eq!(s.codec.as_deref(), Some("mp4a.40.2"));
        assert_eq!(s.bitrate, Some(129.5));
        assert_eq!(s.duration, Some(237.0));
        assert_eq!(
            s.http_headers,
            vec![
                ("Accept".to_owned(), "*/*".to_owned()),
                ("User-Agent".to_owned(), "Mozilla/5.0".to_owned()),
            ]
        );
    }

    #[test]
    fn stream_refuses_what_must_not_play() {
        let wrong_id = stream_of(stream_json("").as_bytes(), "BBBBBBBBBBB");
        assert!(wrong_id.is_err());
        let live = stream_json(r#","is_live":true"#);
        assert!(stream_of(live.as_bytes(), "AAAAAAAAAAA").is_err());
        let drm = stream_json(r#","has_drm":"maybe""#);
        assert!(stream_of(drm.as_bytes(), "AAAAAAAAAAA").is_err());
        let insecure = r#"{"id":"AAAAAAAAAAA","acodec":"opus","url":"http://x.example/a"}"#;
        assert!(stream_of(insecure.as_bytes(), "AAAAAAAAAAA").is_err());
        let file = r#"{"id":"AAAAAAAAAAA","acodec":"opus","url":"file:///C:/x"}"#;
        assert!(stream_of(file.as_bytes(), "AAAAAAAAAAA").is_err());
        let video_only = r#"{"id":"AAAAAAAAAAA","acodec":"none","url":"https://x.example/a"}"#;
        assert!(stream_of(video_only.as_bytes(), "AAAAAAAAAAA").is_err());
        assert!(stream_of(b"not json", "AAAAAAAAAAA").is_err());
    }

    #[test]
    fn uploaded_subtitles_are_kept_when_vtt_from_youtube() {
        let raw = r#"{"id":"AAAAAAAAAAA","acodec":"opus","url":"https://h.example/a",
          "subtitles":{
            "mg":[{"ext":"json3","url":"https://www.youtube.com/api/timedtext?f=j"},
                  {"ext":"vtt","url":"https://www.youtube.com/api/timedtext?f=v"}],
            "fr":[{"ext":"vtt","url":"https://evil.example/x.vtt"}],
            "live_chat":[{"ext":"vtt","url":"https://www.youtube.com/live"}]}}"#;
        let s = stream_of(raw.as_bytes(), "AAAAAAAAAAA").unwrap();
        assert_eq!(
            s.subtitles,
            vec![(
                "mg".to_owned(),
                "https://www.youtube.com/api/timedtext?f=v".to_owned()
            )]
        );
    }

    #[test]
    fn the_clip_is_the_hls_master_playlist() {
        let raw = r#"{"id":"AAAAAAAAAAA","acodec":"opus","url":"https://h.example/a",
          "formats":[{"protocol":"https","manifest_url":null},
            {"protocol":"m3u8_native","manifest_url":"https://evil.example/m.m3u8"},
            {"protocol":"m3u8_native","manifest_url":"https://manifest.googlevideo.com/api/manifest/hls_variant/x"}]}"#;
        let s = stream_of(raw.as_bytes(), "AAAAAAAAAAA").unwrap();
        assert_eq!(
            s.hls.as_deref(),
            Some("https://manifest.googlevideo.com/api/manifest/hls_variant/x")
        );
        let none = r#"{"id":"AAAAAAAAAAA","acodec":"opus","url":"https://h.example/a"}"#;
        assert_eq!(stream_of(none.as_bytes(), "AAAAAAAAAAA").unwrap().hls, None);
    }

    #[test]
    fn expiry_from_path_or_default() {
        let path =
            url::Url::parse("https://h.example/videoplayback/expire/1764200000/id/x").unwrap();
        assert_eq!(expiry_of(&path), Some(1_764_200_000));
        let none = url::Url::parse("https://h.example/a?b=c").unwrap();
        assert_eq!(expiry_of(&none), None);
        let raw = r#"{"id":"AAAAAAAAAAA","acodec":"opus","url":"https://h.example/a"}"#;
        let s = stream_of(raw.as_bytes(), "AAAAAAAAAAA").unwrap();
        assert!(s.expires_at > now_secs());
    }
}

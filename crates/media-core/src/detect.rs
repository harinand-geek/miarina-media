//! Media detection for the built-in browser.
//!
//! Inputs come from the visited page (network responses seen by the WebView,
//! `<video>`/`<audio>` sources) and are untrusted: everything is classified,
//! filtered, deduplicated and capped here before reaching the UI.

use serde::Serialize;
use url::Url;

/// Detected items kept per page (a page cannot flood the UI).
pub const MAX_DETECTIONS: usize = 50;
/// Direct audio/video responses smaller than this are interface sounds,
/// previews or probes, not media worth offering.
pub const MIN_DIRECT_BYTES: u64 = 256 * 1024;
const MAX_URL_LEN: usize = 4096;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum DetectedKind {
    Video,
    Audio,
    /// HLS playlist (`.m3u8`).
    Hls,
    /// DASH manifest (`.mpd`).
    Dash,
}

/// Where a detection came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum DetectedVia {
    Network,
    Page,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DetectedMedia {
    pub kind: DetectedKind,
    pub url: String,
    pub host: String,
    /// Last path segment, for display.
    pub name: String,
    pub size_bytes: Option<u64>,
    pub via: DetectedVia,
}

/// Classifies a response by content type and URL path. Stream segments
/// (`.ts`, `.m4s`) are parts of a manifest and never reported on their own.
pub fn classify(content_type: &str, url: &Url) -> Option<DetectedKind> {
    let mime = content_type
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase();
    let path = url.path().to_ascii_lowercase();
    if matches!(mime.as_str(), "video/mp2t" | "video/iso.segment")
        || path.ends_with(".ts")
        || path.ends_with(".m4s")
    {
        return None;
    }
    if matches!(
        mime.as_str(),
        "application/vnd.apple.mpegurl"
            | "application/x-mpegurl"
            | "audio/mpegurl"
            | "audio/x-mpegurl"
    ) || path.ends_with(".m3u8")
    {
        return Some(DetectedKind::Hls);
    }
    if mime == "application/dash+xml" || path.ends_with(".mpd") {
        return Some(DetectedKind::Dash);
    }
    if mime.starts_with("video/") {
        return Some(DetectedKind::Video);
    }
    if mime.starts_with("audio/") {
        return Some(DetectedKind::Audio);
    }
    // The extension only decides for untyped or generic content: a web page
    // whose path ends in ".webm" is still a web page.
    if !matches!(
        mime.as_str(),
        "" | "application/octet-stream" | "binary/octet-stream"
    ) {
        return None;
    }
    const EXTENSIONS: [(&str, DetectedKind); 11] = [
        (".mp4", DetectedKind::Video),
        (".webm", DetectedKind::Video),
        (".mkv", DetectedKind::Video),
        (".mov", DetectedKind::Video),
        (".m4v", DetectedKind::Video),
        (".mp3", DetectedKind::Audio),
        (".m4a", DetectedKind::Audio),
        (".ogg", DetectedKind::Audio),
        (".oga", DetectedKind::Audio),
        (".opus", DetectedKind::Audio),
        (".flac", DetectedKind::Audio),
    ];
    EXTENSIONS
        .iter()
        .find(|(ext, _)| path.ends_with(ext))
        .map(|(_, kind)| *kind)
}

/// Media found on the current page.
#[derive(Debug, Default, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Detections {
    items: Vec<DetectedMedia>,
    /// The page plays media through Media Source Extensions (`blob:`): the
    /// file is not reachable directly, only the page URL can be analyzed.
    pub stream_player: bool,
}

impl Detections {
    pub fn items(&self) -> &[DetectedMedia] {
        &self.items
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty() && !self.stream_player
    }

    pub fn clear(&mut self) {
        self.items.clear();
        self.stream_player = false;
    }

    /// Records a network response. `total_size` is the whole resource size
    /// when known (`Content-Length` of a 200, total of a 206 `Content-Range`);
    /// `fetch_dest` is the request's `Sec-Fetch-Dest`. Returns `true` when the
    /// list changed.
    pub fn add_response(
        &mut self,
        url: &str,
        content_type: &str,
        status: u16,
        total_size: Option<u64>,
        fetch_dest: Option<&str>,
    ) -> bool {
        if !(200..300).contains(&status) {
            return false;
        }
        let Some(url) = web_url(url) else {
            return false;
        };
        let Some(kind) = classify(content_type, &url) else {
            return false;
        };
        // Manifests are fetched by script players (hls.js, dash.js): always kept.
        if !matches!(kind, DetectedKind::Video | DetectedKind::Audio) {
            return self.insert(url, kind, None, DetectedVia::Network);
        }
        // A file opened directly is what the user is looking at.
        let navigation = matches!(fetch_dest, Some("document" | "iframe"));
        // Otherwise only sizeable files: interface sounds (often `Audio()`
        // objects or service-worker caches, without a size) and script
        // fetches (stream segments) are not offered. Media in the page's DOM
        // is found by the element scan anyway.
        let element = matches!(fetch_dest, None | Some("video" | "audio"));
        let sizeable = total_size.is_some_and(|n| n >= MIN_DIRECT_BYTES);
        if !(navigation || element && sizeable) {
            return false;
        }
        self.insert(url, kind, total_size, DetectedVia::Network)
    }

    /// Records a `<video>`/`<audio>` source reported by the page.
    /// Returns `true` when the list changed.
    pub fn add_element(&mut self, tag: &str, src: &str) -> bool {
        if src.starts_with("blob:") {
            let changed = !self.stream_player;
            self.stream_player = true;
            return changed;
        }
        let Some(url) = web_url(src) else {
            return false;
        };
        let fallback = if tag.eq_ignore_ascii_case("audio") {
            DetectedKind::Audio
        } else {
            DetectedKind::Video
        };
        let kind = classify("", &url).unwrap_or(fallback);
        self.insert(url, kind, None, DetectedVia::Page)
    }

    fn insert(
        &mut self,
        url: Url,
        kind: DetectedKind,
        size: Option<u64>,
        via: DetectedVia,
    ) -> bool {
        let key = dedup_key(&url);
        if let Some(existing) = self.items.iter_mut().find(|m| dedup_key_str(&m.url) == key) {
            // Keep the first sighting; only learn the size later.
            if existing.size_bytes.is_none() && size.is_some() {
                existing.size_bytes = size;
                return true;
            }
            return false;
        }
        if self.items.len() >= MAX_DETECTIONS {
            return false;
        }
        let host = url.host_str().unwrap_or_default().to_owned();
        let name = url
            .path_segments()
            .and_then(|mut s| s.next_back())
            .map(|s| s.chars().take(200).collect())
            .unwrap_or_default();
        self.items.push(DetectedMedia {
            kind,
            url: url.into(),
            host,
            name,
            size_bytes: size,
            via,
        });
        true
    }
}

fn web_url(raw: &str) -> Option<Url> {
    if raw.len() > MAX_URL_LEN {
        return None;
    }
    let mut url = Url::parse(raw).ok()?;
    if !matches!(url.scheme(), "http" | "https") || url.host_str().is_none() {
        return None;
    }
    url.set_fragment(None);
    Some(url)
}

/// Range requests and cache-busting queries hit the same resource.
fn dedup_key(url: &Url) -> String {
    format!("{}{}", url.host_str().unwrap_or_default(), url.path())
}

fn dedup_key_str(url: &str) -> String {
    Url::parse(url).map(|u| dedup_key(&u)).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn url(s: &str) -> Url {
        Url::parse(s).unwrap()
    }

    #[test]
    fn classifies_by_type_then_extension() {
        assert_eq!(
            classify("video/webm", &url("https://a.org/x")),
            Some(DetectedKind::Video)
        );
        assert_eq!(
            classify("audio/mpeg; charset=x", &url("https://a.org/x")),
            Some(DetectedKind::Audio)
        );
        assert_eq!(
            classify("application/vnd.apple.mpegURL", &url("https://a.org/live")),
            Some(DetectedKind::Hls)
        );
        assert_eq!(
            classify("", &url("https://a.org/v/master.m3u8?t=1")),
            Some(DetectedKind::Hls)
        );
        assert_eq!(
            classify("application/dash+xml", &url("https://a.org/m")),
            Some(DetectedKind::Dash)
        );
        assert_eq!(
            classify("", &url("https://a.org/clip.MP4")),
            Some(DetectedKind::Video)
        );
        assert_eq!(classify("text/html", &url("https://a.org/page")), None);
    }

    #[test]
    fn segments_are_never_media() {
        assert_eq!(classify("video/mp2t", &url("https://a.org/seg1")), None);
        assert_eq!(
            classify("video/mp4", &url("https://a.org/chunk-3.m4s")),
            None
        );
        assert_eq!(classify("", &url("https://a.org/seg_00042.ts")), None);
    }

    #[test]
    fn small_sounds_and_errors_are_ignored() {
        let mut d = Detections::default();
        let small = Some(9_000);
        assert!(!d.add_response("https://yt.com/s/open.mp3", "audio/mpeg", 200, small, None));
        assert!(!d.add_response(
            "https://a.org/v.mp4",
            "video/mp4",
            404,
            Some(10_000_000),
            None
        ));
        assert!(d.add_response(
            "https://a.org/v.mp4",
            "video/mp4",
            200,
            Some(10_000_000),
            None
        ));
        assert_eq!(d.items()[0].size_bytes, Some(10_000_000));
        // A range response carries the total size (Content-Range).
        assert!(d.add_response(
            "https://a.org/w.webm",
            "video/webm",
            206,
            Some(80_000_000),
            Some("video")
        ));
        assert_eq!(d.items()[1].size_bytes, Some(80_000_000));
    }

    #[test]
    fn interface_sounds_and_script_fetches_are_not_offered() {
        let mut d = Detections::default();
        // YouTube: Audio() objects served by a service worker, no size, no type.
        assert!(!d.add_response("https://yt.com/s/open.mp3", "", 206, None, Some("audio")));
        // Fetched by script: segments or sounds.
        let big = Some(50_000_000);
        assert!(!d.add_response("https://a.org/v.mp4", "video/mp4", 200, big, Some("empty")));
        // A manifest loaded by a script player is a stream.
        assert!(d.add_response("https://cdn.org/master.m3u8", "", 200, None, Some("empty")));
        // A file opened directly, even without a size.
        assert!(d.add_response(
            "https://a.org/d.mp4",
            "video/mp4",
            200,
            None,
            Some("document")
        ));
        assert_eq!(d.items().len(), 2);
    }

    #[test]
    fn typed_pages_are_not_media_by_extension() {
        let page = url("https://commons.wikimedia.org/wiki/File:Bunny.webm");
        assert_eq!(classify("text/html; charset=UTF-8", &page), None);
        assert_eq!(
            classify("application/octet-stream", &page),
            Some(DetectedKind::Video)
        );
    }

    #[test]
    fn deduplicates_ranges_and_queries() {
        let mut d = Detections::default();
        let total = Some(5_000_000);
        assert!(d.add_response(
            "https://cdn.org/v.mp4?range=0-100",
            "video/mp4",
            206,
            total,
            None
        ));
        assert!(!d.add_response(
            "https://cdn.org/v.mp4?range=100-200",
            "video/mp4",
            206,
            total,
            None
        ));
        assert!(!d.add_element("video", "https://cdn.org/v.mp4#t=10"));
        assert_eq!(d.items().len(), 1);
        assert_eq!(d.items()[0].size_bytes, Some(5_000_000));
        // A page element seen first learns its size from the network later.
        assert!(d.add_element("video", "https://cdn.org/w.webm"));
        assert!(d.add_response(
            "https://cdn.org/w.webm",
            "video/webm",
            206,
            total,
            Some("video")
        ));
        assert_eq!(d.items()[1].size_bytes, Some(5_000_000));
    }

    #[test]
    fn page_elements_and_stream_players() {
        let mut d = Detections::default();
        assert!(d.is_empty());
        assert!(d.add_element("video", "blob:https://site.org/1b2c"));
        assert!(!d.add_element("video", "blob:https://site.org/other"));
        assert!(d.stream_player && !d.is_empty());
        assert!(d.add_element("audio", "https://a.org/stream?id=4"));
        assert_eq!(d.items()[0].kind, DetectedKind::Audio);
        assert_eq!(d.items()[0].via, DetectedVia::Page);
        d.clear();
        assert!(d.is_empty());
    }

    #[test]
    fn untrusted_sources_are_rejected_and_capped() {
        let mut d = Detections::default();
        assert!(!d.add_element("video", "file:///C:/x.mp4"));
        assert!(!d.add_element("video", "data:video/mp4;base64,AAAA"));
        assert!(!d.add_element("video", "javascript:alert(1)"));
        assert!(!d.add_element("video", &format!("https://a.org/{}", "x".repeat(5000))));
        for i in 0..(MAX_DETECTIONS + 10) {
            d.add_element("video", &format!("https://a.org/{i}.mp4"));
        }
        assert_eq!(d.items().len(), MAX_DETECTIONS);
    }
}

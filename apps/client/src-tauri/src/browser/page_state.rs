//! Android browser state (`mobile.rs`), kept free of platform code so it is
//! tested on every host. Everything here comes from the visited page through
//! `BrowserPlugin.kt` and is untrusted: bounded, filtered and classified
//! before it reaches the interface.

use media_core::detect::{DetectedMedia, Detections};
use serde::{Deserialize, Serialize};
use tauri::Url;

const MAX_TITLE_CHARS: usize = 300;
/// Longest floating button label ("Download · 12").
pub const MAX_FAB_LABEL: usize = 40;

/// What `BrowserPlugin.poll` returns.
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Poll {
    pub generation: i64,
    pub progress: i64,
    pub loading: bool,
    pub title: String,
    pub url: String,
    pub can_go_back: bool,
    pub can_go_forward: bool,
    /// "tap" or "hold" on the floating button since the last poll.
    pub fab: Option<String>,
    pub observations: Vec<Observation>,
}

/// Something the page revealed: a `<video>`/`<audio>` source ("element") or
/// a file it offered for download ("download").
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Observation {
    #[serde(rename = "type")]
    pub kind: String,
    pub url: String,
    pub generation: i64,
    pub tag: String,
    pub mime: String,
    pub size: Option<u64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum FabAction {
    Tap,
    Hold,
}

/// Same shape as the desktop `BrowserSnapshot`, plus load progress and the
/// floating button gesture (the button is native on Android).
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PageSnapshot {
    pub url: String,
    pub title: String,
    pub loading: bool,
    pub progress: u8,
    pub can_go_back: bool,
    pub can_go_forward: bool,
    pub start_page: bool,
    pub sheet: bool,
    pub media: Vec<DetectedMedia>,
    pub stream_player: bool,
    pub fab: Option<FabAction>,
}

/// Detections of the current page; `generation` changes on every committed
/// navigation.
#[derive(Debug, Default)]
pub struct PageState {
    generation: i64,
    detections: Detections,
}

impl PageState {
    pub fn apply(&mut self, poll: Poll) -> PageSnapshot {
        if poll.generation != self.generation {
            self.generation = poll.generation;
            self.detections.clear();
        }
        // Observations queued before the last navigation belong to the old page.
        for o in poll
            .observations
            .iter()
            .filter(|o| o.generation == self.generation)
        {
            match o.kind.as_str() {
                "element" => {
                    self.detections.add_element(&o.tag, &o.url);
                }
                // The page offered the file itself: like opening it directly.
                "download" => {
                    self.detections
                        .add_response(&o.url, &o.mime, 200, o.size, Some("document"));
                }
                _ => {}
            }
        }
        let url = web_page(&poll.url);
        let start_page = url.is_none();
        PageSnapshot {
            title: if start_page {
                String::new()
            } else {
                poll.title.trim().chars().take(MAX_TITLE_CHARS).collect()
            },
            url: url.map(String::from).unwrap_or_default(),
            loading: poll.loading && !start_page,
            progress: poll.progress.clamp(0, 100) as u8,
            can_go_back: poll.can_go_back,
            can_go_forward: poll.can_go_forward,
            start_page,
            sheet: false,
            // The APK includes an extractor. Manifests and blob players are
            // candidates for analysis, never proof that a stream is downloadable.
            media: self.detections.items().to_vec(),
            stream_player: self.detections.stream_player || youtube_video(&poll.url),
            fab: match poll.fab.as_deref() {
                Some("tap") => Some(FabAction::Tap),
                Some("hold") => Some(FabAction::Hold),
                _ => None,
            },
        }
    }
}

fn youtube_video(raw: &str) -> bool {
    let Ok(url) = Url::parse(raw) else {
        return false;
    };
    if !matches!(url.scheme(), "https" | "http") {
        return false;
    }
    match url.host_str().unwrap_or_default() {
        "youtu.be" => url.path().trim_matches('/').len() == 11,
        "youtube.com" | "www.youtube.com" | "m.youtube.com" => {
            (url.path() == "/watch" && url.query_pairs().any(|(k, v)| k == "v" && v.len() == 11))
                || url
                    .path()
                    .strip_prefix("/shorts/")
                    .is_some_and(|id| id.trim_matches('/').len() == 11)
        }
        _ => false,
    }
}

/// The page address shown to the user: http(s) only (`about:blank` is the
/// start page).
fn web_page(url: &str) -> Option<&str> {
    let parsed = Url::parse(url).ok()?;
    (matches!(parsed.scheme(), "http" | "https") && parsed.host_str().is_some()).then_some(url)
}

/// A floating button label from the interface: short, one line.
pub fn valid_fab_label(label: &str) -> bool {
    !label.trim().is_empty()
        && label.chars().count() <= MAX_FAB_LABEL
        && !label.chars().any(char::is_control)
}

/// A page-area rectangle in CSS pixels.
pub fn valid_rect(values: [f64; 4]) -> bool {
    const MAX_CSS_PX: f64 = 20_000.0;
    values
        .iter()
        .all(|v| v.is_finite() && (-MAX_CSS_PX..=MAX_CSS_PX).contains(v))
        && values[2] >= 0.0
        && values[3] >= 0.0
}

/// A page picture from `BrowserPlugin.frame`, shown under the app's sheets.
pub fn valid_snapshot(data: &str) -> bool {
    const MAX_SNAPSHOT: usize = 4 * 1024 * 1024;
    data.len() <= MAX_SNAPSHOT
        && data
            .strip_prefix("data:image/jpeg;base64,")
            .is_some_and(|b64| {
                b64.bytes()
                    .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'+' | b'/' | b'='))
            })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn element(generation: i64, tag: &str, url: &str) -> Observation {
        Observation {
            kind: "element".into(),
            url: url.into(),
            generation,
            tag: tag.into(),
            ..Observation::default()
        }
    }

    fn page(generation: i64, url: &str, observations: Vec<Observation>) -> Poll {
        Poll {
            generation,
            url: url.into(),
            title: "  Sprite Fright  ".into(),
            progress: 140,
            loading: true,
            observations,
            ..Poll::default()
        }
    }

    #[test]
    fn page_media_are_detected_and_kept_until_the_next_navigation() {
        let mut state = PageState::default();
        let snap = state.apply(page(
            1,
            "https://studio.blender.org/films/sprite-fright",
            vec![
                element(1, "video", "https://example.org/film.mp4"),
                element(1, "audio", "https://example.org/theme.mp3"),
                element(0, "video", "https://example.org/old-page.mp4"),
            ],
        ));
        assert_eq!(snap.media.len(), 2);
        assert_eq!(snap.title, "Sprite Fright");
        assert_eq!(snap.progress, 100);
        assert!(!snap.start_page);

        // Same page, nothing new: still there.
        assert_eq!(
            state
                .apply(page(1, "https://studio.blender.org/x", vec![]))
                .media
                .len(),
            2
        );
        // Next page: cleared.
        assert!(
            state
                .apply(page(2, "https://studio.blender.org/y", vec![]))
                .media
                .is_empty()
        );
    }

    #[test]
    fn streams_and_page_players_are_sent_to_the_extractor() {
        let mut state = PageState::default();
        let snap = state.apply(page(
            1,
            "https://example.org/",
            vec![
                element(1, "video", "blob:https://example.org/1234"),
                element(1, "video", "https://example.org/live.m3u8"),
            ],
        ));
        assert_eq!(snap.media.len(), 1);
        assert!(snap.stream_player);
    }

    #[test]
    fn youtube_candidates_do_not_require_playback_and_reject_lookalike_hosts() {
        assert!(youtube_video("https://m.youtube.com/watch?v=aqz-KE-bpKQ"));
        assert!(youtube_video("https://youtu.be/aqz-KE-bpKQ"));
        assert!(!youtube_video(
            "https://youtube.com.evil.test/watch?v=aqz-KE-bpKQ"
        ));
        assert!(!youtube_video(
            "https://www.youtube.com/results?search_query=video"
        ));
    }

    #[test]
    fn offered_downloads_are_media_only() {
        let mut state = PageState::default();
        let download = |url: &str, mime: &str| Observation {
            kind: "download".into(),
            url: url.into(),
            generation: 1,
            mime: mime.into(),
            size: Some(1_000),
            ..Observation::default()
        };
        let snap = state.apply(page(
            1,
            "https://archive.org/details/x",
            vec![
                download("https://archive.org/download/x/x.mp4", "video/mp4"),
                download("https://archive.org/download/x/x.zip", "application/zip"),
            ],
        ));
        assert_eq!(snap.media.len(), 1);
        assert_eq!(snap.media[0].size_bytes, Some(1_000));
    }

    #[test]
    fn only_web_pages_are_shown_as_the_address() {
        let mut state = PageState::default();
        for url in ["about:blank", "", "file:///sdcard/x", "javascript:alert(1)"] {
            let snap = state.apply(page(1, url, vec![]));
            assert!(snap.start_page, "{url}");
            assert_eq!(snap.url, "");
            assert_eq!(snap.title, "");
            assert!(!snap.loading);
        }
    }

    #[test]
    fn floating_button_gestures_are_checked() {
        let mut state = PageState::default();
        let mut poll = page(1, "https://example.org/", vec![]);
        poll.fab = Some("hold".into());
        assert_eq!(state.apply(poll).fab, Some(FabAction::Hold));
        let mut poll = page(1, "https://example.org/", vec![]);
        poll.fab = Some("click()".into());
        assert_eq!(state.apply(poll).fab, None);
    }

    #[test]
    fn interface_inputs_are_checked() {
        assert!(valid_fab_label("Download · 3"));
        assert!(!valid_fab_label(""));
        assert!(!valid_fab_label("line\nbreak"));
        assert!(!valid_fab_label(&"x".repeat(41)));
        assert!(valid_rect([0.0, 60.0, 412.0, 700.0]));
        assert!(!valid_rect([0.0, f64::NAN, 412.0, 700.0]));
        assert!(!valid_rect([0.0, 0.0, -1.0, 700.0]));
        assert!(valid_snapshot("data:image/jpeg;base64,/9j/4AAQ=="));
        assert!(!valid_snapshot("data:text/html;base64,PGI+"));
        assert!(!valid_snapshot("data:image/jpeg;base64,\"><script>"));
    }
}

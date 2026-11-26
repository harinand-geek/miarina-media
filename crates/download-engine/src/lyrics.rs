//! Lyrics found online (decision 0011, lot 7): YouTube subtitles uploaded
//! with a clip, converted to synchronised LRC, and LRCLIB
//! (https://lrclib.net, public, no account), asked with a track's title,
//! artist and duration. Everything here is pure (parsing, cleaning, URLs);
//! the requests go through `HttpEngine::fetch_text`.

use std::fmt::Write as _;

use serde::Deserialize;

use crate::EngineError;
use crate::http::HttpEngine;
use media_core::ValidatedUrl;

/// Upper bound for a subtitle file or an LRCLIB answer.
pub const MAX_LYRICS_BYTES: usize = 512 * 1024;

const LRCLIB: &str = "https://lrclib.net/api";

/// Seconds of difference accepted between a track and an LRCLIB entry.
const DURATION_SLACK: f64 = 4.0;

impl HttpEngine {
    /// A small text document (lyrics, subtitles), bounded in size.
    pub async fn fetch_text(
        &self,
        url: &ValidatedUrl,
        max_bytes: usize,
    ) -> Result<Option<String>, EngineError> {
        let mut response = self
            .client()
            .get(url.as_str())
            .send()
            .await
            .map_err(EngineError::from_reqwest)?;
        // « Not found » is an answer: nothing there.
        if response.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(None);
        }
        if !response.status().is_success() {
            return Err(EngineError::Http {
                status: response.status().as_u16(),
            });
        }
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(EngineError::from_reqwest)? {
            if body.len() + chunk.len() > max_bytes {
                return Err(EngineError::Unsupported {
                    reason: "the answer is too large".into(),
                });
            }
            body.extend_from_slice(&chunk);
        }
        Ok(Some(String::from_utf8_lossy(&body).into_owned()))
    }
}

/// `[mm:ss.xx]` for an LRC line.
fn stamp(ms: u64) -> String {
    let cs = (ms % 1000) / 10;
    let s = (ms / 1000) % 60;
    let m = ms / 60_000;
    format!("[{m:02}:{s:02}.{cs:02}]")
}

/// `00:01:02.345` or `01:02.345` (WebVTT), in milliseconds.
fn vtt_time(t: &str) -> Option<u64> {
    let t = t.trim();
    let (clock, fraction) = t.split_once('.').unwrap_or((t, "0"));
    // « .05 » is 50 ms, « .5 » 500 ms: the digits are the first of three.
    let digits: String = fraction.chars().take(3).collect();
    if digits.is_empty() || !digits.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let ms: u64 = format!("{digits:0<3}").parse().ok()?;
    let parts: Vec<u64> = clock
        .split(':')
        .map(|p| p.parse().ok())
        .collect::<Option<_>>()?;
    let secs = match parts.as_slice() {
        [h, m, s] => h * 3600 + m * 60 + s,
        [m, s] => m * 60 + s,
        _ => return None,
    };
    Some(secs * 1000 + ms)
}

/// Cue text without markup: tags (`<c>`, `<i>`, `<00:01.000>`), entities,
/// music notes alone.
fn cue_text(lines: &[&str]) -> String {
    let joined = lines.join(" ");
    let mut out = String::new();
    let mut in_tag = false;
    for ch in joined.chars() {
        match ch {
            '<' => in_tag = true,
            '>' if in_tag => in_tag = false,
            _ if !in_tag => out.push(ch),
            _ => {}
        }
    }
    let out = out
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&nbsp;", " ")
        .replace("&#39;", "'")
        .replace("&quot;", "\"");
    let out = out.split_whitespace().collect::<Vec<_>>().join(" ");
    if out
        .chars()
        .all(|c| matches!(c, '♪' | '♫' | '♬' | '♩' | '-' | ' '))
    {
        return String::new();
    }
    out
}

/// A WebVTT subtitle file as synchronised LRC: one line per cue, at its
/// start. `None` when no cue has text.
pub fn vtt_to_lrc(vtt: &str) -> Option<String> {
    let lines: Vec<&str> = vtt.lines().collect();
    let mut out = String::new();
    // The last cue written and when it ended.
    let mut last: Option<(String, u64)> = None;
    let mut i = 0;
    while i < lines.len() {
        let line = lines[i];
        if let Some((start, end)) = line.split_once("-->") {
            let Some(ms) = vtt_time(start) else {
                i += 1;
                continue;
            };
            let end_ms = end
                .split_whitespace()
                .next()
                .and_then(vtt_time)
                .unwrap_or(ms);
            let mut text = Vec::new();
            i += 1;
            while i < lines.len() && !lines[i].trim().is_empty() && !lines[i].contains("-->") {
                text.push(lines[i].trim());
                i += 1;
            }
            let text = cue_text(&text);
            // A cue continuing the same line right where it ended (rolling
            // captions) is kept once; a chorus coming back is kept.
            let continues = last
                .as_ref()
                .is_some_and(|(t, e)| *t == text && ms <= e + 50);
            if text.is_empty() {
                last = None;
            } else if continues {
                last = Some((text, end_ms));
            } else {
                let _ = writeln!(out, "{}{}", stamp(ms), text);
                last = Some((text, end_ms));
            }
            continue;
        }
        i += 1;
    }
    (!out.is_empty()).then_some(out)
}

/// Words that mark a clip's title rather than the song's.
const NOISE: [&str; 22] = [
    "clip",
    "officiel",
    "officielle",
    "official",
    "video",
    "vidéo",
    "lyrics",
    "lyric",
    "paroles",
    "audio",
    "4k",
    "hd",
    "fhd",
    "nouveauté",
    "nouveaute",
    "gasy",
    "music",
    "visualizer",
    "prod",
    "live",
    "version",
    "remix",
];

/// Artist and title of a YouTube title: « Artist - Title (Clip officiel
/// 2026) » → (Artist, Title). Brackets, the year and what follows « | » or
/// « @ » go; without a dash, the channel is taken as the artist (« … -
/// Topic », « VEVO » removed).
pub fn clean_title(raw: &str, channel: Option<&str>) -> (Option<String>, String) {
    // Brackets of any kind, with what they hold.
    let mut text = String::new();
    let mut depth = 0usize;
    for ch in raw.chars() {
        match ch {
            '(' | '[' | '{' | '【' | '「' => depth += 1,
            ')' | ']' | '}' | '】' | '」' => depth = depth.saturating_sub(1),
            _ if depth == 0 => text.push(ch),
            _ => {}
        }
    }
    for cut in ['|', '@', '#'] {
        if let Some(i) = text.find(cut) {
            text.truncate(i);
        }
    }
    let text = text.replace(['"', '“', '”', '«', '»'], " ");
    let (artist, title) = ['-', '–', '—', ':']
        .iter()
        .find_map(|d| {
            let (a, t) = text.split_once(&format!(" {d} ")).or_else(|| {
                // « Artist- Title » / « Artist -Title ».
                text.split_once(*d)
                    .filter(|(a, t)| !a.trim().is_empty() && !t.trim().is_empty())
            })?;
            Some((Some(a.to_owned()), t.to_owned()))
        })
        .unwrap_or_else(|| (None, text.clone()));
    let tidy = |s: &str| -> String {
        s.split_whitespace()
            .filter(|w| {
                let l = w.to_lowercase();
                let year =
                    l.len() == 4 && l.starts_with("20") && l.chars().all(|c| c.is_ascii_digit());
                !year && !NOISE.contains(&l.trim_matches(|c: char| !c.is_alphanumeric()))
            })
            .collect::<Vec<_>>()
            .join(" ")
            .trim_matches(|c: char| c == '-' || c == ',' || c.is_whitespace())
            .to_owned()
    };
    let main_artist = |s: &str| -> String {
        let lower = s.to_lowercase();
        let cut = [" feat", " ft.", " ft ", " x ", " & ", ",", " avec "]
            .iter()
            .filter_map(|m| lower.find(m))
            .min()
            .unwrap_or(s.len());
        tidy(&s[..cut])
    };
    let artist = artist
        .map(|a| main_artist(&a))
        .or_else(|| {
            channel.map(|c| {
                let c = c
                    .trim()
                    .trim_end_matches(" - Topic")
                    .trim_end_matches("VEVO")
                    .trim_end_matches("Officiel")
                    .trim_end_matches("Official");
                main_artist(c)
            })
        })
        .filter(|a| !a.is_empty());
    let title = {
        let lower = title.to_lowercase();
        let cut = [" feat", " ft.", " ft "]
            .iter()
            .filter_map(|m| lower.find(m))
            .min()
            .unwrap_or(title.len());
        tidy(&title[..cut])
    };
    (artist, title)
}

/// LRCLIB's exact lookup.
pub fn lrclib_get_url(artist: &str, title: &str, duration: Option<f64>) -> Option<url::Url> {
    let mut params = vec![
        ("track_name", title.to_owned()),
        ("artist_name", artist.to_owned()),
    ];
    if let Some(d) = duration.filter(|d| d.is_finite() && *d > 0.0) {
        params.push(("duration", format!("{}", d.round() as u64)));
    }
    url::Url::parse_with_params(&format!("{LRCLIB}/get"), &params).ok()
}

/// LRCLIB's search, for a title without a reliable artist.
pub fn lrclib_search_url(artist: Option<&str>, title: &str) -> Option<url::Url> {
    let mut params = vec![("track_name", title.to_owned())];
    if let Some(a) = artist {
        params.push(("artist_name", a.to_owned()));
    }
    url::Url::parse_with_params(&format!("{LRCLIB}/search"), &params).ok()
}

#[derive(Debug, Deserialize)]
struct LrclibEntry {
    #[serde(rename = "syncedLyrics")]
    synced: Option<String>,
    duration: Option<f64>,
    #[serde(default)]
    instrumental: bool,
}

/// Synchronised lyrics from an LRCLIB answer (an entry or a list), the
/// first whose duration is close to [duration] when it is known.
pub fn pick_lrclib(json: &str, duration: Option<f64>) -> Option<String> {
    let entries: Vec<LrclibEntry> = serde_json::from_str::<Vec<LrclibEntry>>(json)
        .or_else(|_| serde_json::from_str::<LrclibEntry>(json).map(|e| vec![e]))
        .ok()?;
    entries
        .into_iter()
        .filter(|e| !e.instrumental)
        .filter(|e| match (duration, e.duration) {
            (Some(d), Some(x)) => (d - x).abs() <= DURATION_SLACK,
            _ => true,
        })
        .find_map(|e| e.synced.filter(|s| s.contains('[') && s.trim().len() > 10))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vtt_cues_become_lrc_lines() {
        let vtt = "WEBVTT\nKind: captions\nLanguage: mg\n\n00:00:12.340 --> 00:00:15.000\nTiako ianao\n\n00:00:15.000 --> 00:00:18.500 align:start\n<c>Mila anao</c> &amp; izaho\n\n00:00:18.500 --> 00:00:20.000\n♪\n\n00:01:02.050 --> 00:01:04.000\nMila anao &amp; izaho\n";
        let lrc = vtt_to_lrc(vtt).unwrap();
        assert_eq!(
            lrc,
            "[00:12.34]Tiako ianao\n[00:15.00]Mila anao & izaho\n[01:02.05]Mila anao & izaho\n"
        );
        assert_eq!(vtt_to_lrc("WEBVTT\n\n"), None);
        // Short clock form and a rolling repeat kept once.
        let rolling = "WEBVTT\n\n00:01.000 --> 00:02.000\nA\n\n00:02.000 --> 00:03.000\nA\n";
        assert_eq!(vtt_to_lrc(rolling).unwrap(), "[00:01.00]A\n");
    }

    #[test]
    fn youtube_titles_are_cleaned() {
        let c = |t: &str, ch: Option<&str>| clean_title(t, ch);
        assert_eq!(
            c("SAKATÉ BOY - Zanak'Antesaka (Clip Officiel 2026) 🇲🇬", None),
            (Some("SAKATÉ BOY".into()), "Zanak'Antesaka 🇲🇬".into())
        );
        assert_eq!(
            c(
                "Lema Palega feat. Black Nadia - Samy Jao (Video Lyrics - Nouveauté Gasy 2026)",
                None
            ),
            (Some("Lema Palega".into()), "Samy Jao".into())
        );
        assert_eq!(
            c(
                "JOHANE - Fitia Mifamaly  (Official Music Video) I 2026",
                None
            ),
            (Some("JOHANE".into()), "Fitia Mifamaly I".into())
        );
        assert_eq!(
            c("Havagna", Some("Lema Palega - Topic")),
            (Some("Lema Palega".into()), "Havagna".into())
        );
        assert_eq!(
            c(
                "Keen'v feat Lorelei B - la vie du bon coté ( clip officiel )",
                None
            ),
            (Some("Keen'v".into()), "la vie du bon coté".into())
        );
        assert_eq!(
            c(
                "DORENJY - Tefihaja & Bob tobias ft Lion Hill | @YouYes",
                None
            ),
            (Some("DORENJY".into()), "Tefihaja & Bob tobias".into())
        );
        assert_eq!(c("Song", None), (None, "Song".into()));
    }

    #[test]
    fn lrclib_urls_are_encoded() {
        let u = lrclib_get_url("Sakaté Boy", "Zanak'Antesaka", Some(237.6)).unwrap();
        assert_eq!(u.host_str(), Some("lrclib.net"));
        assert!(u.as_str().contains("artist_name=Sakat%C3%A9+Boy"));
        assert!(u.as_str().contains("duration=238"));
        let s = lrclib_search_url(None, "A & B").unwrap();
        assert!(s.as_str().ends_with("track_name=A+%26+B"));
    }

    #[test]
    fn lrclib_answers_are_picked_by_duration() {
        let one =
            r#"{"syncedLyrics":"[00:01.00]Hello world line","duration":200,"instrumental":false}"#;
        assert!(pick_lrclib(one, Some(201.0)).is_some());
        assert!(pick_lrclib(one, Some(260.0)).is_none());
        let list = r#"[{"syncedLyrics":null,"duration":200},
                       {"syncedLyrics":"[00:02.00]Second entry text","duration":203},
                       {"syncedLyrics":"[00:03.00]Instrumental","duration":203,"instrumental":true}]"#;
        assert_eq!(
            pick_lrclib(list, Some(204.0)).unwrap(),
            "[00:02.00]Second entry text"
        );
        assert!(pick_lrclib("not json", None).is_none());
        assert!(pick_lrclib("[]", None).is_none());
    }
}

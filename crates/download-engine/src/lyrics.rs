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
/// A bracketed part that belongs to the clip, not the song: a clip word, a
/// year, a featuring, a producer. « (I Told You I Like You) » stays.
fn clip_noise(part: &str) -> bool {
    part.split_whitespace().any(|w| {
        let l = w.to_lowercase();
        let l = l.trim_matches(|c: char| !c.is_alphanumeric());
        let year = l.len() == 4 && l.starts_with("20") && l.chars().all(|c| c.is_ascii_digit());
        year || NOISE.contains(&l) || matches!(l, "feat" | "ft" | "featuring" | "with" | "by")
    })
}

/// Artist names that mean « none » (the app's own label for a file
/// without one).
const NO_ARTIST: [&str; 3] = [
    "artiste inconnu",
    "unknown artist",
    "mpanakanto tsy fantatra",
];

pub fn clean_title(raw: &str, channel: Option<&str>) -> (Option<String>, String) {
    let channel = channel.filter(|c| !NO_ARTIST.contains(&c.trim().to_lowercase().as_str()));
    // Bracketed parts: those of the clip go, the song's stay.
    let mut text = String::new();
    let mut part = String::new();
    let mut depth = 0usize;
    for ch in raw.chars() {
        match ch {
            '(' | '[' | '{' | '【' | '「' => {
                depth += 1;
                if depth > 1 {
                    part.push(' ');
                }
            }
            ')' | ']' | '}' | '】' | '」' if depth > 0 => {
                depth -= 1;
                if depth == 0 {
                    let kept = part.trim();
                    if !kept.is_empty() && !clip_noise(kept) {
                        text.push_str(&format!("({kept})"));
                    }
                    part.clear();
                }
            }
            _ if depth == 0 => text.push(ch),
            _ => part.push(ch),
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

/// LRCLIB's full-text search (any field), the last resort.
pub fn lrclib_query_url(q: &str) -> Option<url::Url> {
    url::Url::parse_with_params(&format!("{LRCLIB}/search"), &[("q", q)]).ok()
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
    #[serde(rename = "trackName")]
    track: Option<String>,
    #[serde(rename = "artistName")]
    artist: Option<String>,
    #[serde(rename = "albumName")]
    album: Option<String>,
}

/// One LRCLIB result with synchronised lyrics, for the user to choose.
#[derive(Debug, Clone, PartialEq)]
pub struct LrclibHit {
    pub track: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub duration: Option<f64>,
    pub lrc: String,
}

/// The synchronised results of an LRCLIB search, at most [limit], those
/// closest to [duration] first when it is known.
pub fn lrclib_hits(json: &str, duration: Option<f64>, limit: usize) -> Vec<LrclibHit> {
    let Ok(entries) = serde_json::from_str::<Vec<LrclibEntry>>(json) else {
        return Vec::new();
    };
    let mut hits: Vec<LrclibHit> = entries
        .into_iter()
        .filter(|e| !e.instrumental)
        .filter_map(|e| {
            let lrc = e
                .synced
                .filter(|s| s.contains('[') && s.trim().len() > 10)?;
            Some(LrclibHit {
                track: e.track.filter(|t| !t.trim().is_empty())?,
                artist: e.artist,
                album: e.album,
                duration: e.duration,
                lrc,
            })
        })
        .collect();
    if let Some(d) = duration {
        hits.sort_by(|a, b| {
            let da = a.duration.map_or(f64::MAX, |x| (x - d).abs());
            let db = b.duration.map_or(f64::MAX, |x| (x - d).abs());
            da.total_cmp(&db)
        });
    }
    hits.truncate(limit);
    hits
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

/// Tononkira (https://tononkira.serasera.org), the reference for Malagasy
/// lyrics, suggested by the owner: plain text, no timing. Read from its
/// public pages (search, then the song's page).
pub const TONONKIRA: &str = "https://tononkira.serasera.org";

/// Tononkira's search by title (`lohateny`) and artist (`mpihira`).
pub fn tononkira_search_url(title: &str, artist: Option<&str>) -> Option<url::Url> {
    let mut params = vec![("lohateny", title.to_owned())];
    if let Some(a) = artist {
        params.push(("mpihira", a.to_owned()));
    }
    url::Url::parse_with_params(&format!("{TONONKIRA}/tononkira"), &params).ok()
}

/// One song in Tononkira's results.
#[derive(Debug, Clone, PartialEq)]
pub struct TononkiraHit {
    pub title: String,
    pub artist: Option<String>,
    /// The song's page, on tononkira.serasera.org.
    pub url: String,
}

/// HTML entities that matter in song titles and lyrics.
fn unescape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(i) = rest.find('&') {
        out.push_str(&rest[..i]);
        rest = &rest[i..];
        let Some(end) = rest.find(';').filter(|e| *e <= 10) else {
            out.push('&');
            rest = &rest[1..];
            continue;
        };
        let name = &rest[1..end];
        let ch = match name {
            "amp" => Some('&'),
            "lt" => Some('<'),
            "gt" => Some('>'),
            "quot" => Some('"'),
            "apos" => Some('\''),
            "nbsp" => Some(' '),
            _ => name
                .strip_prefix("#x")
                .and_then(|h| u32::from_str_radix(h, 16).ok())
                .or_else(|| name.strip_prefix('#').and_then(|d| d.parse().ok()))
                .and_then(char::from_u32),
        };
        match ch {
            Some(c) => {
                out.push(c);
                rest = &rest[end + 1..];
            }
            None => {
                out.push('&');
                rest = &rest[1..];
            }
        }
    }
    out.push_str(rest);
    out
}

/// Text without tags.
fn strip_tags(html: &str) -> String {
    let mut out = String::new();
    let mut in_tag = false;
    for ch in html.chars() {
        match ch {
            '<' => in_tag = true,
            '>' if in_tag => in_tag = false,
            _ if !in_tag => out.push(ch),
            _ => {}
        }
    }
    out
}

/// A link's address and text: `<a href="…">text</a>` at the start of
/// [html].
fn link(html: &str) -> Option<(String, String, &str)> {
    let start = html.find("<a ")?;
    let html = &html[start..];
    let href_at = html.find("href=\"")? + 6;
    let href_end = href_at + html[href_at..].find('"')?;
    let text_at = href_end + html[href_end..].find('>')? + 1;
    let text_end = text_at + html[text_at..].find("</a>")?;
    Some((
        html[href_at..href_end].to_owned(),
        unescape(strip_tags(&html[text_at..text_end]).trim()),
        &html[text_end + 4..],
    ))
}

/// The songs of a Tononkira results page, in its order.
pub fn tononkira_hits(html: &str) -> Vec<TononkiraHit> {
    let song = format!("{TONONKIRA}/hira/");
    let singer = format!("{TONONKIRA}/mpihira/");
    let mut hits = Vec::new();
    for block in html.split("<div class=\"border p-2 mb-3\">").skip(1) {
        let block = block.split("</div>").next().unwrap_or_default();
        let Some((href, title, rest)) = link(block) else {
            continue;
        };
        // /hira/<artist>/<song>, not its « ankafizo » (like) link.
        let ok = href
            .strip_prefix(&song)
            .is_some_and(|p| p.split('/').filter(|s| !s.is_empty()).count() == 2);
        if !ok || title.is_empty() {
            continue;
        }
        let artist = link(rest)
            .filter(|(h, _, _)| h.starts_with(&singer))
            .map(|(_, a, _)| a)
            .filter(|a| !a.is_empty());
        hits.push(TononkiraHit {
            title,
            artist,
            url: href,
        });
    }
    hits
}

/// The lyrics of a Tononkira song page: its lines, blank lines between
/// verses kept (one at most). `None` when the page has none.
pub fn tononkira_lyrics(html: &str) -> Option<String> {
    let mark = html.find("Nalaina tao amin")?;
    let after = &html[mark..];
    let div = after.find("<div id=")?;
    let body = &after[div..];
    let open = body.find('>')? + 1;
    let close = open + body[open..].find("</div>")?;
    // Line ends in the HTML are only spaces; <br> makes the lines.
    let raw = body[open..close]
        .replace(['\r', '\n'], " ")
        .replace("<br />", "\n")
        .replace("<br/>", "\n")
        .replace("<br>", "\n");
    let text = unescape(&strip_tags(&raw));
    let mut lines: Vec<String> = Vec::new();
    for line in text.lines() {
        // The site's own address, slipped into the text as a watermark.
        let line = line
            .split_whitespace()
            .filter(|w| !w.to_lowercase().contains("serasera"))
            .collect::<Vec<_>>()
            .join(" ");
        if line.is_empty() && lines.last().is_none_or(|l| l.is_empty()) {
            continue;
        }
        lines.push(line);
    }
    while lines.last().is_some_and(|l| l.is_empty()) {
        lines.pop();
    }
    let words = lines.iter().filter(|l| !l.is_empty()).count();
    (words >= 2).then(|| lines.join("\n"))
}

/// The words two readings of a line share, in order (longest common
/// subsequence): Tononkira slips random words into its pages, different at
/// each load, so a word in only one reading is noise.
fn common_words(a: &str, b: &str) -> String {
    let a: Vec<&str> = a.split(' ').filter(|w| !w.is_empty()).collect();
    let b: Vec<&str> = b.split(' ').filter(|w| !w.is_empty()).collect();
    let mut len = vec![vec![0u16; b.len() + 1]; a.len() + 1];
    for i in (0..a.len()).rev() {
        for j in (0..b.len()).rev() {
            len[i][j] = if a[i] == b[j] {
                len[i + 1][j + 1] + 1
            } else {
                len[i + 1][j].max(len[i][j + 1])
            };
        }
    }
    let (mut i, mut j, mut out) = (0, 0, Vec::new());
    while i < a.len() && j < b.len() {
        if a[i] == b[j] {
            out.push(a[i]);
            i += 1;
            j += 1;
        } else if len[i + 1][j] >= len[i][j + 1] {
            i += 1;
        } else {
            j += 1;
        }
    }
    out.join(" ")
}

/// Tononkira lyrics without the noise: the words found in both readings
/// of the page, line by line. Readings of different shapes (the page
/// changed between them): the first one as it is.
pub fn tononkira_merge(first: &str, second: &str) -> String {
    let a: Vec<&str> = first.lines().collect();
    let b: Vec<&str> = second.lines().collect();
    if a.len() != b.len() {
        return first.to_owned();
    }
    a.iter()
        .zip(&b)
        .map(|(x, y)| common_words(x, y))
        .collect::<Vec<_>>()
        .join(
            "
",
        )
}

/// Lower case letters and digits only, for comparing titles.
fn plain_key(s: &str) -> String {
    s.chars()
        .filter(|c| c.is_alphanumeric())
        .flat_map(char::to_lowercase)
        .collect()
}

/// The hit whose title matches [title] best: the same letters first, then
/// one containing the other; `None` when none is close.
pub fn best_tononkira_hit<'a>(hits: &'a [TononkiraHit], title: &str) -> Option<&'a TononkiraHit> {
    let want = plain_key(title);
    if want.is_empty() {
        return None;
    }
    hits.iter()
        .find(|h| plain_key(&h.title) == want)
        .or_else(|| {
            hits.iter().find(|h| {
                let k = plain_key(&h.title);
                !k.is_empty() && (k.contains(&want) || want.contains(&k))
            })
        })
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
        // The song's own brackets stay; « Artiste inconnu » is no artist.
        assert_eq!(
            c(
                "Johnny Orlando, kenzie - What If (I Told You I Like You)",
                Some("Artiste inconnu")
            ),
            (
                Some("Johnny Orlando".into()),
                "What If (I Told You I Like You)".into()
            )
        );
        assert_eq!(
            c("keen'v - DIS MOI OUI (MARINA) Clip Officiel", None),
            (Some("keen'v".into()), "DIS MOI OUI (MARINA)".into())
        );
        assert_eq!(
            c("Havagna", Some("Unknown artist")),
            (None, "Havagna".into())
        );
        assert_eq!(
            c("Zanak'antesaka ( vasia label 2026 )", Some("Kenny")),
            (Some("Kenny".into()), "Zanak'antesaka".into())
        );
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

    const TK_RESULTS: &str = r#"<form method="get"></form>
        <div class="border p-2 mb-3">
            1. <a href="https://tononkira.serasera.org/hira/sakat%C3%A9-boy/zanakantesaka">Zanak&#039;antesaka</a> - <a href="https://tononkira.serasera.org/mpihira/sakat%C3%A9-boy">Sakaté Boy</a> <a href="https://tononkira.serasera.org/hira/sakat%C3%A9-boy/zanakantesaka/ankafizo"><i class="bi-heart-fill"></i> 0</a>
        </div>
        <div class="border p-2 mb-3">
            2. <a href="https://tononkira.serasera.org/hira/x/zanaka">Zanaka</a> - <a href="https://evil.example/mpihira/x">X</a>
        </div>
        <div class="border p-2 mb-3">3. <a href="https://evil.example/hira/a/b">Bad</a></div>"#;

    #[test]
    fn tononkira_results_are_read() {
        let hits = tononkira_hits(TK_RESULTS);
        assert_eq!(
            hits[0],
            TononkiraHit {
                title: "Zanak'antesaka".into(),
                artist: Some("Sakaté Boy".into()),
                url: "https://tononkira.serasera.org/hira/sakat%C3%A9-boy/zanakantesaka".into(),
            }
        );
        assert_eq!(hits[1].artist, None, "artist link elsewhere ignored");
        assert_eq!(hits.len(), 2, "links off the site ignored");
        assert_eq!(
            best_tononkira_hit(&hits, "Zanak'Antesaka").unwrap().title,
            "Zanak'antesaka"
        );
        assert_eq!(best_tononkira_hit(&hits, "zanaka").unwrap().title, "Zanaka");
        assert!(best_tononkira_hit(&hits, "Havagna").is_none());
        let u = tononkira_search_url("Zanak'antesaka", Some("Sakaté Boy")).unwrap();
        assert_eq!(u.host_str(), Some("tononkira.serasera.org"));
        assert!(u.as_str().contains("lohateny=Zanak%27antesaka"));
        assert!(u.as_str().contains("mpihira=Sakat%C3%A9+Boy"));
    }

    #[test]
    fn tononkira_lyrics_are_read() {
        let page = r#"<h2>Zanak&#039;antesaka</h2>
        <div class="print my-3 fst-italic">
            (Nalaina tao amin'ny tononkira.serasera.org)
        </div>

        <div id="6b08606387908">
        Gne carisme vaňy fombafombanay<br />
Sakaté boy, tononkira.serasera.org zanak'i Vangai!<br />
<br />
<br />
 Somary nagnotaniany aho hoe,<br />
&nbsp;&nbsp;Zanak'antesaka a,<br />
        </div>
        <div>Other</div>"#;
        assert_eq!(
            tononkira_lyrics(page).unwrap(),
            "Gne carisme vaňy fombafombanay\nSakaté boy, zanak'i Vangai!\n\nSomary nagnotaniany aho hoe,\nZanak'antesaka a,"
        );
        assert!(tononkira_lyrics("<html>no lyrics</html>").is_none());
        assert_eq!(
            unescape("a &amp; b &#039;c&#x27; &bogus; &"),
            "a & b 'c' &bogus; &"
        );
    }

    #[test]
    fn tononkira_noise_is_removed_by_two_readings() {
        let a = "Atao nbvj fitia kuhakflu mifamaly ny antsika 2 dia milamina ny fo

Ref:
Adala ny xrnt fo";
        let b = "Atao fitia mifamaly ny antsika 2 tononkira.serasera.org dia milamina ny nilduv fo

Ref:
Adala ny fo";
        assert_eq!(
            tononkira_merge(a, b),
            "Atao fitia mifamaly ny antsika 2 dia milamina ny fo

Ref:
Adala ny fo"
        );
        // A repeated word stays when both readings have it.
        assert_eq!(
            common_words("tia tia ianao", "tia tia qq ianao"),
            "tia tia ianao"
        );
        // Different shapes: the first reading.
        assert_eq!(
            tononkira_merge(
                "a b
c", "a b"
            ),
            "a b
c"
        );
    }

    #[test]
    fn lrclib_hits_are_listed_closest_first() {
        let list = r#"[{"trackName":"Far","artistName":"A","duration":300,"syncedLyrics":"[00:01.00]far far away"},
                       {"trackName":"Plain","duration":200,"syncedLyrics":null},
                       {"trackName":"Near","artistName":"B","albumName":"X","duration":201,"syncedLyrics":"[00:01.00]near and dear"}]"#;
        let hits = lrclib_hits(list, Some(200.0), 10);
        assert_eq!(
            hits.iter().map(|h| h.track.as_str()).collect::<Vec<_>>(),
            ["Near", "Far"]
        );
        assert_eq!(hits[0].album.as_deref(), Some("X"));
        assert_eq!(lrclib_hits(list, None, 1).len(), 1);
        assert!(lrclib_hits("{}", None, 5).is_empty());
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

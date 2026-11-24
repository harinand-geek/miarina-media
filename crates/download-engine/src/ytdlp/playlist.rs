//! Playlists (CDC DL-07): the entries listed flat by the extractor, and the
//! qualities offered for all of them at once. Each chosen entry becomes an
//! ordinary download task (its failure is retried on its own).

use media_core::validate_media_url;

use super::info::{RawEntry, RawInfo};
use super::offers::{AUDIO_BITRATES, FormatSpec, Offer, Offers};

/// Entries listed at most (`--playlist-items 1-<MAX + 1>`: one more tells
/// that the playlist is longer).
pub const MAX_PLAYLIST_ITEMS: usize = 200;

/// Heights offered for a playlist's videos, the first recommended.
const VIDEO_HEIGHTS: [u32; 4] = [1080, 720, 480, 360];

/// Titles the extractor gives to entries that cannot be downloaded.
const UNAVAILABLE_TITLES: [&str; 4] = [
    "[private video]",
    "[deleted video]",
    "[unavailable video]",
    "[private]",
];

#[derive(Debug, Clone, PartialEq)]
pub struct PlaylistItem {
    /// Position in the playlist, from 1.
    pub index: u32,
    /// The entry's page; `None` when it cannot be downloaded.
    pub url: Option<String>,
    pub title: Option<String>,
    pub duration: Option<f64>,
    /// Picture published by the site (untrusted URL).
    pub thumbnail: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Playlist {
    pub items: Vec<PlaylistItem>,
    /// The source has more entries than those listed.
    pub truncated: bool,
    /// Entries in the whole playlist, when the source says.
    pub count: Option<u64>,
}

impl Playlist {
    pub fn available(&self) -> usize {
        self.items.iter().filter(|i| i.url.is_some()).count()
    }
}

/// The page of an entry, when it is a single downloadable media.
fn entry_url(entry: &RawEntry) -> Option<String> {
    // A playlist inside the playlist (a channel's tabs) is not one media.
    if entry.kind.as_deref() == Some("playlist")
        || entry
            .ie_key
            .as_deref()
            .is_some_and(|k| k.ends_with("Tab") || k.ends_with("Playlist"))
    {
        return None;
    }
    if entry
        .title
        .as_deref()
        .is_some_and(|t| UNAVAILABLE_TITLES.contains(&t.trim().to_lowercase().as_str()))
    {
        return None;
    }
    [entry.url.as_deref(), entry.webpage_url.as_deref()]
        .into_iter()
        .flatten()
        .find_map(|u| validate_media_url(u).ok())
        .map(|u| u.as_str().to_owned())
}

/// The largest picture of an entry not wider than a list thumbnail needs.
fn entry_thumbnail(entry: &RawEntry) -> Option<String> {
    let listed = entry.thumbnails.as_deref().unwrap_or_default();
    listed
        .iter()
        .filter(|t| t.url.is_some())
        .filter(|t| t.width.is_none_or(|w| w <= 480))
        .max_by_key(|t| t.width.unwrap_or(0))
        .or_else(|| listed.iter().rfind(|t| t.url.is_some()))
        .and_then(|t| t.url.clone())
        .or_else(|| entry.thumbnail.clone())
}

/// The entries of a playlist result, in the playlist's order.
pub fn playlist_of(info: &RawInfo) -> Playlist {
    let entries = info.entries.as_deref().unwrap_or_default();
    let items = entries
        .iter()
        .take(MAX_PLAYLIST_ITEMS)
        .enumerate()
        .map(|(i, entry)| PlaylistItem {
            index: i as u32 + 1,
            url: entry_url(entry),
            title: entry.title.clone(),
            duration: entry.duration.filter(|d| d.is_finite() && *d > 0.0),
            thumbnail: entry_thumbnail(entry),
        })
        .collect();
    Playlist {
        items,
        truncated: entries.len() > MAX_PLAYLIST_ITEMS
            || info
                .playlist_count
                .is_some_and(|n| n > MAX_PLAYLIST_ITEMS as u64),
        count: info.playlist_count,
    }
}

/// Qualities offered for every entry of a playlist: the entries' own
/// formats are not read (that would mean analysing each of them), so each
/// choice is a selector the extractor resolves per entry, falling back to
/// the best format available below it.
pub fn playlist_offers(ffmpeg: bool) -> Offers {
    let video = VIDEO_HEIGHTS
        .iter()
        .enumerate()
        .map(|(i, h)| Offer {
            spec: if ffmpeg {
                FormatSpec {
                    selector: format!(
                        "bv*[height<={h}][ext=mp4]+ba[ext=m4a]/bv*[height<={h}]+ba/b[height<={h}]/b"
                    ),
                    merge: Some("mp4".into()),
                    extract_audio: None,
                    audio_kbps: None,
                    subtitles: None,
                }
            } else {
                FormatSpec {
                    selector: format!("b[height<={h}]/b"),
                    merge: None,
                    extract_audio: None,
                    audio_kbps: None,
                    subtitles: None,
                }
            },
            quality: format!("{h}p"),
            detail: "MP4".into(),
            size_bytes: None,
            extension: "mp4".into(),
            tag: (i == 0).then_some("Recommended"),
        })
        .collect();
    let audio = if ffmpeg {
        [AUDIO_BITRATES[0], AUDIO_BITRATES[2]]
            .into_iter()
            .map(|kbps| Offer {
                spec: FormatSpec {
                    selector: "ba/b".into(),
                    merge: None,
                    extract_audio: Some("mp3".into()),
                    audio_kbps: Some(kbps),
                    subtitles: None,
                },
                quality: format!("MP3 · {kbps} kbps"),
                detail: "MP3".into(),
                size_bytes: None,
                extension: "mp3".into(),
                tag: (kbps == AUDIO_BITRATES[0]).then_some("Recommended"),
            })
            .chain(std::iter::once(Offer {
                spec: FormatSpec {
                    selector: "ba[ext=m4a]/ba/b".into(),
                    merge: None,
                    extract_audio: Some("m4a".into()),
                    audio_kbps: None,
                    subtitles: None,
                },
                quality: "M4A".into(),
                detail: "M4A".into(),
                size_bytes: None,
                extension: "m4a".into(),
                tag: None,
            }))
            .collect()
    } else {
        // Without FFmpeg: the source's own audio stream, as it is.
        vec![Offer {
            spec: FormatSpec {
                selector: "ba[ext=m4a]/ba".into(),
                merge: None,
                extract_audio: None,
                audio_kbps: None,
                subtitles: None,
            },
            quality: "M4A".into(),
            detail: "M4A".into(),
            size_bytes: None,
            extension: "m4a".into(),
            tag: Some("Recommended"),
        }]
    };
    Offers {
        video,
        audio,
        subtitles: Vec::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(json: &str) -> RawInfo {
        RawInfo::parse(json.as_bytes()).unwrap()
    }

    #[test]
    fn entries_keep_their_order_and_unavailable_ones_are_marked() {
        let info = parse(
            r#"{"_type":"playlist","title":"Mix","playlist_count":4,"entries":[
              {"_type":"url","ie_key":"Youtube","url":"https://www.youtube.com/watch?v=a1","title":"One","duration":61,
               "thumbnails":[{"url":"https://i.ytimg.com/a1/small.jpg","width":168},{"url":"https://i.ytimg.com/a1/big.jpg","width":336},{"url":"https://i.ytimg.com/a1/max.jpg","width":1280}]},
              {"_type":"url","ie_key":"Youtube","url":"https://www.youtube.com/watch?v=b2","title":"[Private video]","duration":null},
              {"_type":"url","ie_key":"YoutubeTab","url":"https://www.youtube.com/@x/shorts","title":"Shorts"},
              {"_type":"url","url":"file:///C:/secret","title":"Local"}
            ]}"#,
        );
        let list = playlist_of(&info);
        assert_eq!(list.items.len(), 4);
        assert_eq!(list.available(), 1);
        assert!(!list.truncated);
        let first = &list.items[0];
        assert_eq!(first.index, 1);
        assert_eq!(
            first.url.as_deref(),
            Some("https://www.youtube.com/watch?v=a1")
        );
        assert_eq!(first.duration, Some(61.0));
        assert_eq!(
            first.thumbnail.as_deref(),
            Some("https://i.ytimg.com/a1/big.jpg")
        );
        assert!(list.items[1..].iter().all(|i| i.url.is_none()));
        assert_eq!(list.items[3].index, 4);
    }

    #[test]
    fn long_playlists_are_bounded() {
        let entries: Vec<String> = (0..MAX_PLAYLIST_ITEMS + 1)
            .map(|i| format!(r#"{{"url":"https://example.com/v/{i}","title":"V{i}"}}"#))
            .collect();
        let info = parse(&format!(
            r#"{{"_type":"playlist","entries":[{}]}}"#,
            entries.join(",")
        ));
        let list = playlist_of(&info);
        assert_eq!(list.items.len(), MAX_PLAYLIST_ITEMS);
        assert!(list.truncated);
        assert_eq!(list.items.last().unwrap().index, MAX_PLAYLIST_ITEMS as u32);
    }

    #[test]
    fn offers_are_valid_specs_for_every_entry() {
        for ffmpeg in [true, false] {
            let offers = playlist_offers(ffmpeg);
            assert_eq!(offers.video.len(), VIDEO_HEIGHTS.len());
            assert!(!offers.audio.is_empty());
            for offer in offers.video.iter().chain(&offers.audio) {
                let decoded = FormatSpec::decode(&offer.spec.encode()).unwrap();
                assert_eq!(&decoded, &offer.spec);
            }
            assert_eq!(offers.video[0].tag, Some("Recommended"));
            assert!(offers.video[0].spec.selector.contains("height<=1080"));
        }
        // Conversions only with FFmpeg.
        assert!(
            playlist_offers(false)
                .audio
                .iter()
                .all(|o| o.spec.extract_audio.is_none())
        );
        assert_eq!(
            playlist_offers(true).audio[0].spec.extract_audio.as_deref(),
            Some("mp3")
        );
    }
}

//! Music tags read and written with lofty (ID3v2, Vorbis comments, MP4
//! ilst, APE…). Files are untrusted: errors only mean "no tags".

use std::borrow::Cow;
use std::path::{Path, PathBuf};

use lofty::config::WriteOptions;
use lofty::prelude::*;
use lofty::tag::items::Timestamp;
use lofty::tag::{ItemKey, Tag};
use storage::MediaTags;

/// Extensions whose tags Miarina writes back into the file. Video
/// containers keep their tags in the library only.
const WRITABLE: &[&str] = &["mp3", "flac", "m4a", "ogg", "opus", "wav", "aiff", "aif"];

pub fn can_write(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .is_some_and(|e| WRITABLE.contains(&e.to_ascii_lowercase().as_str()))
}

fn text(value: Option<Cow<'_, str>>) -> Option<String> {
    value.map(|v| v.into_owned())
}

/// Tags of `path`, or `None` when the file has none or cannot be parsed.
pub fn read(path: &Path) -> Option<MediaTags> {
    let tagged = lofty::read_from_path(path).ok()?;
    let tag = tagged.primary_tag().or_else(|| tagged.first_tag())?;
    let year = tag.date().map(|d| i32::from(d.year)).or_else(|| {
        tag.get_string(ItemKey::Year)
            .and_then(|y| y.get(..4)?.parse().ok())
    });
    let tags = MediaTags {
        title: text(tag.title()),
        artist: text(tag.artist()),
        album: text(tag.album()),
        album_artist: tag.get_string(ItemKey::AlbumArtist).map(str::to_owned),
        year,
        genre: text(tag.genre()),
        track_no: tag.track(),
        disc_no: tag.disk(),
        comment: text(tag.comment()),
        lyrics: tag
            .get_string(ItemKey::UnsyncLyrics)
            .or_else(|| tag.get_string(ItemKey::Lyrics))
            .map(str::to_owned),
    }
    .normalized();
    (tags != MediaTags::default()).then_some(tags)
}

/// Tempo of `path` from its tags (ID3 TBPM, Vorbis BPM, MP4 tmpo), when
/// plausible (30 to 300 beats a minute). Drives the seek bar's wave on the
/// beat (vinyl handoff, 2026-11-25).
pub fn read_bpm(path: &Path) -> Option<f64> {
    let tagged = lofty::read_from_path(path).ok()?;
    for tag in tagged.tags() {
        for key in [ItemKey::Bpm, ItemKey::IntegerBpm] {
            let Some(value) = tag.get_string(key) else {
                continue;
            };
            if let Ok(bpm) = value.trim().replace(',', ".").parse::<f64>()
                && (30.0..=300.0).contains(&bpm)
            {
                return Some(bpm);
            }
        }
    }
    None
}

#[derive(Debug, thiserror::Error)]
pub enum TagWriteError {
    #[error("Tags cannot be written to this file type.")]
    Unsupported,
    #[error("The file could not be read: {0}")]
    Read(String),
    #[error("The tags could not be written: {0}")]
    Write(String),
}

fn set(tag: &mut Tag, key: ItemKey, value: &Option<String>) {
    match value {
        Some(v) => {
            tag.insert_text(key, v.clone());
        }
        None => tag.remove_key(key),
    }
}

/// Writes `tags` into `path`. The tags go into a copy next to the file,
/// which then replaces it: an interrupted write never leaves a half-written
/// original.
pub fn write(path: &Path, tags: &MediaTags) -> Result<(), TagWriteError> {
    if !can_write(path) {
        return Err(TagWriteError::Unsupported);
    }
    let tags = tags.normalized();
    let mut tagged = lofty::read_from_path(path).map_err(|e| TagWriteError::Read(e.to_string()))?;
    if tagged.primary_tag().is_none() {
        let tag_type = tagged.primary_tag_type();
        tagged.insert_tag(Tag::new(tag_type));
    }
    let tag = tagged.primary_tag_mut().ok_or(TagWriteError::Unsupported)?;
    set(tag, ItemKey::TrackTitle, &tags.title);
    set(tag, ItemKey::TrackArtist, &tags.artist);
    set(tag, ItemKey::AlbumTitle, &tags.album);
    set(tag, ItemKey::AlbumArtist, &tags.album_artist);
    set(tag, ItemKey::Genre, &tags.genre);
    set(tag, ItemKey::Comment, &tags.comment);
    set(tag, ItemKey::UnsyncLyrics, &tags.lyrics);
    // The recording date is the field every format maps (TDRC, DATE, ©day).
    tag.remove_key(ItemKey::Year);
    match tags.year.and_then(|y| u16::try_from(y).ok()) {
        Some(year) => tag.set_date(Timestamp {
            year,
            ..Timestamp::default()
        }),
        None => tag.remove_key(ItemKey::RecordingDate),
    }
    set(
        tag,
        ItemKey::TrackNumber,
        &tags.track_no.map(|n| n.to_string()),
    );
    set(
        tag,
        ItemKey::DiscNumber,
        &tags.disc_no.map(|n| n.to_string()),
    );

    let copy = temp_copy_path(path);
    let result = std::fs::copy(path, &copy)
        .map_err(|e| TagWriteError::Write(e.to_string()))
        .and_then(|_| {
            tagged
                .save_to_path(&copy, WriteOptions::default())
                .map_err(|e| TagWriteError::Write(e.to_string()))
        })
        .and_then(|()| {
            std::fs::rename(&copy, path).map_err(|e| TagWriteError::Write(e.to_string()))
        });
    if result.is_err() {
        let _ = std::fs::remove_file(&copy);
    }
    result
}

fn temp_copy_path(path: &Path) -> PathBuf {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    path.with_file_name(format!(".{name}.miarina-tags.tmp"))
}

#[cfg(test)]
mod bpm_tests {
    use super::*;
    use lofty::tag::TagType;

    /// A short silent WAV file (8 kHz, 16 bits, mono).
    fn wav(path: &Path) {
        let samples = 800u32;
        let data = samples * 2;
        let mut b = Vec::new();
        b.extend_from_slice(b"RIFF");
        b.extend_from_slice(&(36 + data).to_le_bytes());
        b.extend_from_slice(b"WAVEfmt ");
        b.extend_from_slice(&16u32.to_le_bytes());
        b.extend_from_slice(&1u16.to_le_bytes());
        b.extend_from_slice(&1u16.to_le_bytes());
        b.extend_from_slice(&8000u32.to_le_bytes());
        b.extend_from_slice(&16000u32.to_le_bytes());
        b.extend_from_slice(&2u16.to_le_bytes());
        b.extend_from_slice(&16u16.to_le_bytes());
        b.extend_from_slice(b"data");
        b.extend_from_slice(&data.to_le_bytes());
        b.resize(b.len() + data as usize, 0);
        std::fs::write(path, b).unwrap();
    }

    #[test]
    fn tempo_from_tags_and_implausible_values_ignored() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("beat.wav");
        wav(&path);
        assert_eq!(read_bpm(&path), None, "no tag yet");

        let mut tag = Tag::new(TagType::Id3v2);
        tag.insert_text(ItemKey::IntegerBpm, "128".into());
        tag.save_to_path(&path, WriteOptions::default()).unwrap();
        assert_eq!(read_bpm(&path), Some(128.0));

        let mut tag = Tag::new(TagType::Id3v2);
        tag.insert_text(ItemKey::IntegerBpm, "4000".into());
        tag.save_to_path(&path, WriteOptions::default()).unwrap();
        assert_eq!(read_bpm(&path), None, "not a tempo");
    }
}

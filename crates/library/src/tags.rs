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

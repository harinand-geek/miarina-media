//! Tag editor (COM-07, W-M1c « Modifier les tags »), ported from the
//! Tauri app (`TagEditor.tsx`, `library_tags` / `library_update_tags` /
//! cover commands) on the same core: tags are saved in the library and,
//! when asked and the format allows it, in the file itself (never
//! implicitly); the file can be renamed "Artist - Title"; covers are
//! applied at once. Errors are stable codes; the screen words them.

use std::path::Path;

use anyhow::{Result, anyhow};
use library::LibraryError;
use library::tags::TagWriteError;
use storage::{MediaTags, StorageError};

use crate::api::indexer::shared;
use crate::api::library::{LibraryItem, item};

/// Editable tags; `None` = no value.
pub struct TagFields {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub year: Option<i32>,
    pub genre: Option<String>,
    pub track_no: Option<u32>,
    pub disc_no: Option<u32>,
    pub comment: Option<String>,
    pub lyrics: Option<String>,
}

/// What the editor opens with.
pub struct TagSheet {
    pub fields: TagFields,
    /// The file's format takes tags (mp3, flac, m4a, ogg, opus, wav, aiff).
    pub writable: bool,
    /// The download's source offered a thumbnail.
    pub has_source_cover: bool,
}

fn fields(t: MediaTags) -> TagFields {
    TagFields {
        title: t.title,
        artist: t.artist,
        album: t.album,
        album_artist: t.album_artist,
        year: t.year,
        genre: t.genre,
        track_no: t.track_no,
        disc_no: t.disc_no,
        comment: t.comment,
        lyrics: t.lyrics,
    }
}

fn tags(f: TagFields) -> MediaTags {
    MediaTags {
        title: f.title,
        artist: f.artist,
        album: f.album,
        album_artist: f.album_artist,
        year: f.year,
        genre: f.genre,
        track_no: f.track_no,
        disc_no: f.disc_no,
        comment: f.comment,
        lyrics: f.lyrics,
    }
}

/// Stable codes, as in the Tauri app.
fn code(e: LibraryError) -> anyhow::Error {
    anyhow!(match e {
        LibraryError::Storage(StorageError::NotFound(_)) => "not_found",
        LibraryError::InvalidName => "invalid_name",
        LibraryError::Missing => "file_missing",
        LibraryError::Tags(TagWriteError::Unsupported) => "tags_unsupported",
        LibraryError::Tags(_) => "tags_write",
        LibraryError::Cover(_) => "cover_refused",
        _ => "library",
    })
}

pub fn tags_get(id: i64) -> Result<TagSheet> {
    let library = shared()?.library;
    let record = library.check(id).map_err(code)?;
    Ok(TagSheet {
        fields: fields(library.tags(id).map_err(code)?),
        writable: record.kind == storage::MediaKind::Audio
            && library::tags::can_write(Path::new(&record.path)),
        has_source_cover: library.has_source_thumbnail(id),
    })
}

/// Saves the tags (in the file too when `write_to_file`); `rename_to`
/// first renames the file ("Artist - Title"), so the tag title then
/// replaces the file-name title.
pub fn tags_save(
    id: i64,
    fields: TagFields,
    write_to_file: bool,
    rename_to: Option<String>,
) -> Result<LibraryItem> {
    let library = shared()?.library;
    if let Some(name) = rename_to
        .as_deref()
        .map(str::trim)
        .filter(|n| !n.is_empty())
    {
        library.rename(id, name).map_err(code)?;
    }
    let updated = library
        .update_tags(id, &tags(fields), write_to_file)
        .map_err(code)?;
    Ok(item(updated))
}

/// Cover: `from` = "image" (a picture file the user chose), "source" (the
/// download's thumbnail), "frame" (a video frame at `at_secs`) or "none".
pub fn tags_cover(
    id: i64,
    from: String,
    image: Option<String>,
    at_secs: Option<f64>,
) -> Result<LibraryItem> {
    let s = shared()?;
    let library = s.library;
    let record = match from.as_str() {
        "image" => {
            let image = image.ok_or_else(|| anyhow!("cover_refused"))?;
            s.runtime
                .block_on(library.cover_from_image(id, Path::new(&image)))
        }
        "source" => s.runtime.block_on(library.cover_from_source(id)),
        "frame" => s
            .runtime
            .block_on(library.cover_from_frame(id, at_secs.unwrap_or(0.0))),
        "none" => library.remove_cover(id),
        _ => return Err(anyhow!("cover_refused")),
    }
    .map_err(code)?;
    Ok(item(record))
}

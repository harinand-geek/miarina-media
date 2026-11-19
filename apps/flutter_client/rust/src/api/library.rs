use std::path::Path;
use std::sync::Mutex;

use anyhow::{Result, anyhow};
use storage::{MediaKind, MediaQuery, MediaRecord, MediaSort, NewMedia, Storage};

pub struct LibraryItem {
    pub id: i64,
    pub title: String,
    pub path: String,
    pub is_video: bool,
    pub duration_secs: Option<f64>,
    pub artist: Option<String>,
    pub album: Option<String>,
    /// Short technical label (codec or container), e.g. "FLAC".
    pub format: Option<String>,
    pub missing: bool,
    pub favorite: bool,
}

pub struct LibrarySummary {
    pub schema_version: i64,
    pub total: u64,
    pub audio_count: u64,
    pub video_count: u64,
    pub items: Vec<LibraryItem>,
}

pub struct LibraryPage {
    pub items: Vec<LibraryItem>,
    pub total: u64,
}

/// One open database at a time: opening runs the migration check, so the
/// connection is kept between calls for the same path.
static OPEN: Mutex<Option<(String, Storage)>> = Mutex::new(None);

fn with_db<R>(db_path: &str, f: impl FnOnce(&Storage) -> Result<R>) -> Result<R> {
    let mut guard = OPEN.lock().map_err(|_| anyhow!("library lock poisoned"))?;
    let reuse = matches!(guard.as_ref(), Some((path, _)) if path == db_path);
    if !reuse {
        *guard = None;
        let db = Storage::open(Path::new(db_path))?;
        *guard = Some((db_path.to_owned(), db));
    }
    let (_, db) = guard.as_ref().expect("opened above");
    f(db)
}

fn item(m: MediaRecord) -> LibraryItem {
    let format = m
        .audio_codec
        .as_deref()
        .filter(|_| m.kind == MediaKind::Audio)
        .or(m.container.as_deref())
        .map(|f| f.to_uppercase());
    LibraryItem {
        id: m.id,
        title: m.title,
        path: m.path,
        is_video: m.kind == MediaKind::Video,
        duration_secs: m.duration_secs,
        artist: m.artist,
        album: m.album,
        format,
        missing: m.missing,
        favorite: m.favorite,
    }
}

/// Opens the library database (running pending migrations, exactly like the
/// Tauri app) and returns its counters and the first `limit` entries.
pub fn library_summary(db_path: String, limit: u32) -> Result<LibrarySummary> {
    with_db(&db_path, |db| {
        let stats = db.media_stats()?;
        let page = db.query_media(&MediaQuery {
            limit: limit.min(200),
            ..MediaQuery::default()
        })?;
        Ok(LibrarySummary {
            schema_version: db.schema_version()?,
            total: stats.count,
            audio_count: stats.audio_count,
            video_count: stats.video_count,
            items: page.items.into_iter().map(item).collect(),
        })
    })
}

/// A page of audio tracks sorted by title; `search` uses the library's
/// full-text index (accent-insensitive), empty = everything.
pub fn library_tracks(
    db_path: String,
    search: String,
    favorites_only: bool,
    offset: u32,
    limit: u32,
) -> Result<LibraryPage> {
    with_db(&db_path, |db| {
        let page = db.query_media(&MediaQuery {
            search,
            kind: Some(MediaKind::Audio),
            favorites: favorites_only,
            sort: MediaSort::Title,
            offset,
            limit: limit.clamp(1, 500),
            ..MediaQuery::default()
        })?;
        Ok(LibraryPage {
            items: page.items.into_iter().map(item).collect(),
            total: page.total,
        })
    })
}

/// Marks or unmarks a library entry as a favorite.
pub fn library_set_favorite(db_path: String, media_id: i64, favorite: bool) -> Result<()> {
    with_db(&db_path, |db| Ok(db.set_favorite(media_id, favorite)?))
}

/// Adds one local file to the library and returns its id.
pub fn library_add_file(
    db_path: String,
    path: String,
    title: String,
    is_video: bool,
    size_bytes: u64,
) -> Result<i64> {
    with_db(&db_path, |db| {
        let record = db.upsert_media(&NewMedia {
            path,
            title,
            kind: if is_video {
                MediaKind::Video
            } else {
                MediaKind::Audio
            },
            source_host: None,
            source_url: None,
            task_id: None,
            size_bytes,
        })?;
        Ok(record.id)
    })
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

use std::path::Path;

use anyhow::Result;
use storage::{MediaKind, MediaQuery, NewMedia, Storage};

pub struct LibraryItem {
    pub id: i64,
    pub title: String,
    pub path: String,
    pub is_video: bool,
    pub duration_secs: Option<f64>,
    pub artist: Option<String>,
    pub album: Option<String>,
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

/// Opens the library database (running pending migrations, exactly like the
/// Tauri app) and returns its counters and the first `limit` entries.
pub fn library_summary(db_path: String, limit: u32) -> Result<LibrarySummary> {
    let db = Storage::open(Path::new(&db_path))?;
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
        items: page
            .items
            .into_iter()
            .map(|m| LibraryItem {
                id: m.id,
                title: m.title,
                path: m.path,
                is_video: m.kind == MediaKind::Video,
                duration_secs: m.duration_secs,
                artist: m.artist,
                album: m.album,
                missing: m.missing,
                favorite: m.favorite,
            })
            .collect(),
    })
}

/// Adds one local file to the library and returns its id.
pub fn library_add_file(
    db_path: String,
    path: String,
    title: String,
    is_video: bool,
    size_bytes: u64,
) -> Result<i64> {
    let db = Storage::open(Path::new(&db_path))?;
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
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

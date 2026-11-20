//! Library indexing (handoff W-O1): the core's `library` crate, as the
//! Tauri app runs it. Folders are scanned, then a background worker reads
//! tags (no external tool) and technical details (FFmpeg, when shipped
//! next to the app). Nothing is modified or moved in the user's folders.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use anyhow::{Result, anyhow};
use download_engine::components::Components;
use library::Library;
use storage::{GroupBy, Storage};

use super::library::with_db;

struct Indexer {
    db: String,
    /// Owns the worker threads: dropping it would stop the worker.
    #[allow(dead_code)]
    runtime: tokio::runtime::Runtime,
    library: Library,
    has_ffmpeg: bool,
}

static INDEXER: Mutex<Option<Indexer>> = Mutex::new(None);
/// Bumped whenever library rows change; screens poll it to refresh.
static GENERATION: AtomicU64 = AtomicU64::new(0);

pub struct ScanTotals {
    pub added: u32,
    pub missing: u32,
    pub restored: u32,
}

pub struct IndexStatus {
    pub total: u64,
    pub to_tag: u64,
    pub to_probe: u64,
    pub unreadable: u64,
    pub audio: u64,
    pub video: u64,
    pub albums: u64,
    /// FFmpeg found: durations and pictures are read too.
    pub has_ffmpeg: bool,
}

fn with_indexer<R>(f: impl FnOnce(&Indexer) -> Result<R>) -> Result<R> {
    let guard = INDEXER
        .lock()
        .map_err(|_| anyhow!("indexer lock poisoned"))?;
    let indexer = guard
        .as_ref()
        .ok_or_else(|| anyhow!("indexer not started"))?;
    f(indexer)
}

/// Starts indexing for `db_path` (again only if the database changed).
/// `tools_dir`: folder holding `ffmpeg/<version>/ffmpeg.exe` shipped with
/// the app; components installed by the user in `data_dir` count too.
pub fn indexer_start(db_path: String, data_dir: String, tools_dir: Option<String>) -> Result<()> {
    let mut guard = INDEXER
        .lock()
        .map_err(|_| anyhow!("indexer lock poisoned"))?;
    if guard.as_ref().is_some_and(|i| i.db == db_path) {
        return Ok(());
    }
    let data = PathBuf::from(&data_dir);
    let mut components = Components::new(data.join("components"))?;
    if let Some(tools) = tools_dir {
        components = components.with_bundled(PathBuf::from(tools));
    }
    let has_ffmpeg = components.ffmpeg_dir().is_some();
    let storage = Arc::new(Mutex::new(Storage::open(Path::new(&db_path))?));
    let library = Library::new(
        storage,
        components,
        data.join("thumbnails"),
        Arc::new(|| {
            GENERATION.fetch_add(1, Ordering::Relaxed);
        }),
    );
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .thread_name("miarina-indexer")
        .enable_all()
        .build()?;
    runtime.spawn(library.clone().run_worker());
    *guard = Some(Indexer {
        db: db_path,
        runtime,
        library,
        has_ffmpeg,
    });
    Ok(())
}

/// Indexes folders (new files added, vanished ones marked missing, back
/// ones restored); the worker then reads their details in the background.
pub fn indexer_scan(folders: Vec<String>) -> Result<ScanTotals> {
    let library = with_indexer(|i| Ok(i.library.clone()))?;
    let mut totals = ScanTotals {
        added: 0,
        missing: 0,
        restored: 0,
    };
    for folder in folders {
        let path = PathBuf::from(&folder);
        if !path.is_dir() {
            continue;
        }
        let report = library.scan(&path)?;
        totals.added += report.added as u32;
        totals.missing += report.missing as u32;
        totals.restored += report.restored as u32;
    }
    library.refresh();
    GENERATION.fetch_add(1, Ordering::Relaxed);
    Ok(totals)
}

/// Media files a folder holds (what a scan would find), for the import list.
pub fn indexer_count(folder: String) -> u32 {
    library::files::media_files(Path::new(&folder)).len() as u32
}

pub fn indexer_status(db_path: String) -> Result<IndexStatus> {
    let has_ffmpeg = with_indexer(|i| Ok(i.has_ffmpeg)).unwrap_or(false);
    with_db(&db_path, |db| {
        let p = db.index_progress()?;
        let albums = db.media_groups(GroupBy::Album)?.len() as u64;
        Ok(IndexStatus {
            total: p.total,
            to_tag: p.to_tag,
            to_probe: p.to_probe,
            unreadable: p.unreadable,
            audio: p.audio,
            video: p.video,
            albums,
            has_ffmpeg,
        })
    })
}

/// Changes counter: different from the last value read = reload the
/// library screens.
pub fn indexer_generation() -> u64 {
    GENERATION.load(Ordering::Relaxed)
}

/// Folders the user typed "Focus" (W-O1b): their files are courses unless
/// their genre or folder says podcast or audiobook.
pub fn indexer_set_focus_folders(folders: Vec<String>) {
    crate::focus::set_focus_roots(folders.into_iter().map(PathBuf::from).collect());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scans_a_folder_then_reads_tags_in_the_background() {
        let dir = std::env::temp_dir().join(format!("mm-indexer-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let music = dir.join("Musique").join("Album");
        std::fs::create_dir_all(&music).unwrap();
        // Not real audio: tags cannot be read, which still counts as done.
        std::fs::write(music.join("01 Titre.mp3"), b"not audio").unwrap();
        std::fs::write(music.join("cover.jpg"), b"x").unwrap();
        std::fs::write(dir.join("Musique").join("notes.txt"), b"x").unwrap();
        let db = dir.join("miarina.db").to_string_lossy().into_owned();
        let data = dir.to_string_lossy().into_owned();

        assert_eq!(
            indexer_count(dir.join("Musique").to_string_lossy().into_owned()),
            1
        );
        indexer_start(db.clone(), data, None).unwrap();
        let before = indexer_generation();
        let totals =
            indexer_scan(vec![dir.join("Musique").to_string_lossy().into_owned()]).unwrap();
        assert_eq!(totals.added, 1);
        assert!(indexer_generation() > before);

        let mut status = indexer_status(db.clone()).unwrap();
        for _ in 0..100 {
            if status.to_tag == 0 {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
            status = indexer_status(db.clone()).unwrap();
        }
        assert_eq!((status.total, status.audio, status.to_tag), (1, 1, 0));
        // Without FFmpeg, durations and pictures wait.
        assert!(!status.has_ffmpeg);
        assert_eq!(status.to_probe, 1);
    }
}

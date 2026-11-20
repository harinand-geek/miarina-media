//! Library health (handoff W-O2): files not found, grouped by probable
//! cause, and duplicates. Runs on the indexer's library; nothing is deleted
//! automatically.

use std::path::Path;

use anyhow::Result;
use library::health::MissingCause as Cause;

use super::indexer::running_library;
use super::library::{LibraryItem, item};

pub enum MissingCause {
    /// Drive or removable volume not connected.
    VolumeAbsent,
    /// Same name and size found elsewhere in the library.
    Moved,
    NotFound,
}

pub struct MissingFileInfo {
    pub id: i64,
    pub path: String,
    pub title: String,
    pub is_video: bool,
    /// Where the same file is now (cause `Moved`).
    pub found: Option<String>,
}

pub struct MissingGroupInfo {
    pub cause: MissingCause,
    pub key: String,
    pub folder: String,
    pub target: Option<String>,
    pub files: Vec<MissingFileInfo>,
}

pub struct DuplicateVersion {
    pub item: LibraryItem,
    pub size_bytes: u64,
    pub codec: Option<String>,
    pub lossless: bool,
    pub bitrate_kbps: Option<u32>,
    pub height: Option<u32>,
}

pub struct DuplicateSet {
    pub is_video: bool,
    pub title: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    /// Best quality first.
    pub versions: Vec<DuplicateVersion>,
}

pub struct HealthCounts {
    pub missing: u64,
    pub duplicates: u32,
}

pub struct RelocateResult {
    pub found: u32,
    pub left: u32,
}

/// Missing entries by cause; entries whose file is back are restored
/// first.
pub fn health_missing() -> Result<Vec<MissingGroupInfo>> {
    let groups = running_library()?.missing_report()?;
    Ok(groups
        .into_iter()
        .map(|g| MissingGroupInfo {
            cause: match g.cause {
                Cause::VolumeAbsent => MissingCause::VolumeAbsent,
                Cause::Moved => MissingCause::Moved,
                Cause::NotFound => MissingCause::NotFound,
            },
            key: g.key,
            folder: g.folder,
            target: g.target,
            files: g
                .files
                .into_iter()
                .map(|f| MissingFileInfo {
                    id: f.record.id,
                    is_video: f.record.kind == storage::MediaKind::Video,
                    path: f.record.path,
                    title: f.record.title,
                    found: f.found,
                })
                .collect(),
        })
        .collect())
}

/// The user located the file of entry `id`.
pub fn health_relocate(id: i64, file: String) -> Result<()> {
    running_library()?.relocate(id, Path::new(&file))?;
    Ok(())
}

/// Applies found locations (cause `Moved`): `ids[i]` now lives at
/// `files[i]`. Returns how many were updated.
pub fn health_relocate_found(ids: Vec<i64>, files: Vec<String>) -> Result<u32> {
    let library = running_library()?;
    let mut done = 0;
    for (id, file) in ids.into_iter().zip(files) {
        if library.relocate(id, Path::new(&file)).is_ok() {
            done += 1;
        }
    }
    Ok(done)
}

/// Searches `folder` for the files of `ids` (same name and size).
pub fn health_relocate_in(ids: Vec<i64>, folder: String) -> Result<RelocateResult> {
    let report = running_library()?.relocate_in(&ids, Path::new(&folder))?;
    Ok(RelocateResult {
        found: report.found,
        left: report.left,
    })
}

/// Removes entries from the library (files are not touched).
pub fn health_remove(ids: Vec<i64>) -> Result<()> {
    let library = running_library()?;
    for id in ids {
        library.remove(id)?;
    }
    Ok(())
}

pub fn health_duplicates() -> Result<Vec<DuplicateSet>> {
    let groups = running_library()?.duplicate_report()?;
    Ok(groups
        .into_iter()
        .map(|g| DuplicateSet {
            is_video: g.kind == storage::MediaKind::Video,
            title: g.title,
            artist: g.artist,
            album: g.album,
            versions: g
                .entries
                .into_iter()
                .map(|e| DuplicateVersion {
                    size_bytes: e.record.size_bytes,
                    height: e.record.height,
                    codec: e.codec,
                    lossless: e.lossless,
                    bitrate_kbps: e.bitrate_kbps,
                    item: item(e.record),
                })
                .collect(),
        })
        .collect())
}

/// Sets duplicate `drop_id` aside for `keep`: hidden from the library (file
/// kept), or sent to the Recycle Bin when `delete_file`.
pub fn health_set_aside(keep: i64, drop_id: i64, delete_file: bool) -> Result<()> {
    running_library()?.set_aside_duplicate(keep, drop_id, delete_file)?;
    Ok(())
}

/// Badges of the sidebar.
pub fn health_counts() -> Result<HealthCounts> {
    let library = running_library()?;
    let duplicates = library.duplicate_report()?.len() as u32;
    let missing = library.missing_count()?;
    Ok(HealthCounts {
        missing,
        duplicates,
    })
}

/// Whether the file of entry `id` is still there (checked before playing;
/// the entry is marked missing otherwise).
pub fn health_check(id: i64) -> Result<bool> {
    Ok(!running_library()?.check(id)?.missing)
}

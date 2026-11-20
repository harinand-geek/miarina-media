//! Library health (handoff W-O2): files that were not found, and
//! duplicates. Nothing is ever deleted automatically: missing entries stay
//! until the user relocates or removes them, and a duplicate is only hidden
//! (or sent to the Recycle Bin) on request.

use std::collections::HashMap;
use std::path::{Component, MAIN_SEPARATOR, Path, PathBuf};

use serde::Serialize;
use storage::{MediaKind, MediaRecord};

use crate::{Library, LibraryError, files, lock};

/// Why a file was not found, as far as the app can tell.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum MissingCause {
    /// Its drive (or removable volume) is not connected: the entries come
    /// back when it is.
    VolumeAbsent,
    /// A file with the same name and size is in the library elsewhere: the
    /// folder was probably renamed or moved.
    Moved,
    /// No clue: perhaps deleted.
    NotFound,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MissingFile {
    pub record: MediaRecord,
    /// Where the same file was found (cause `Moved`).
    pub found: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MissingGroup {
    pub cause: MissingCause,
    /// Stable identity of the group (the user may dismiss it).
    pub key: String,
    /// Absent volume, or the folder the files were in.
    pub folder: String,
    /// Folder where the moved files are now.
    pub target: Option<String>,
    pub files: Vec<MissingFile>,
}

/// Root of the volume holding `path` when it is one that can be unplugged
/// or unmounted: a Windows drive or share, an Android SD card, a mounted
/// disk. `None` for the system volume.
pub fn volume_root(path: &Path) -> Option<PathBuf> {
    let mut parts = path.components();
    match parts.next()? {
        Component::Prefix(prefix) => Some(PathBuf::from(format!(
            "{}{MAIN_SEPARATOR}",
            prefix.as_os_str().to_string_lossy()
        ))),
        Component::RootDir => {
            let names: Vec<String> = parts
                .take(5)
                .map_while(|c| match c {
                    Component::Normal(n) => Some(n.to_string_lossy().into_owned()),
                    _ => None,
                })
                .collect();
            let first = |i: usize| names.get(i).map(String::as_str);
            let take = match first(0)? {
                "storage" if !matches!(first(1), Some("emulated" | "self") | None) => 2,
                "media" => 3,
                "run" if first(1) == Some("media") => 4,
                "Volumes" | "mnt" => 2,
                _ => return None,
            };
            // The path must lie inside the volume, not be the volume.
            if names.len() <= take {
                return None;
            }
            // These volumes only exist on Unix-like systems: `/` throughout.
            Some(PathBuf::from(format!("/{}", names[..take].join("/"))))
        }
        _ => None,
    }
}

fn file_name_key(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|n| n.to_string_lossy().to_lowercase())
        .unwrap_or_default()
}

fn folder_of(path: &str) -> String {
    Path::new(path)
        .parent()
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_default()
}

/// Sorts missing entries by probable cause. `present`: files of the library
/// that are there, as (id, path, size); `volume_present` tells whether a
/// volume root is connected.
pub fn missing_groups(
    missing: Vec<MediaRecord>,
    present: &[(i64, String, u64)],
    volume_present: impl Fn(&Path) -> bool,
) -> Vec<MissingGroup> {
    let mut by_name_size: HashMap<(String, u64), Vec<&str>> = HashMap::new();
    for (_, path, size) in present {
        if *size > 0 {
            by_name_size
                .entry((file_name_key(path), *size))
                .or_default()
                .push(path);
        }
    }
    let mut volumes: Vec<MissingGroup> = Vec::new();
    let mut moved: Vec<MissingGroup> = Vec::new();
    let mut lost: Vec<MissingFile> = Vec::new();
    let mut checked: HashMap<PathBuf, bool> = HashMap::new();
    for record in missing {
        let path = PathBuf::from(&record.path);
        if let Some(root) = volume_root(&path) {
            let there = *checked
                .entry(root.clone())
                .or_insert_with(|| volume_present(&root));
            if !there {
                let key = format!("volume:{}", root.display());
                let file = MissingFile {
                    record,
                    found: None,
                };
                match volumes.iter_mut().find(|g| g.key == key) {
                    Some(g) => g.files.push(file),
                    None => volumes.push(MissingGroup {
                        cause: MissingCause::VolumeAbsent,
                        key,
                        folder: root.to_string_lossy().into_owned(),
                        target: None,
                        files: vec![file],
                    }),
                }
                continue;
            }
        }
        let found = (record.size_bytes > 0)
            .then(|| by_name_size.get(&(file_name_key(&record.path), record.size_bytes)))
            .flatten()
            .and_then(|paths| paths.iter().find(|p| **p != record.path))
            .map(|p| (*p).to_owned());
        match found {
            Some(found) => {
                let (from, to) = (folder_of(&record.path), folder_of(&found));
                let key = format!("moved:{from}>{to}");
                let file = MissingFile {
                    record,
                    found: Some(found),
                };
                match moved.iter_mut().find(|g| g.key == key) {
                    Some(g) => g.files.push(file),
                    None => moved.push(MissingGroup {
                        cause: MissingCause::Moved,
                        key,
                        folder: from,
                        target: Some(to),
                        files: vec![file],
                    }),
                }
            }
            None => lost.push(MissingFile {
                record,
                found: None,
            }),
        }
    }
    let mut groups = volumes;
    groups.extend(moved);
    if !lost.is_empty() {
        groups.push(MissingGroup {
            cause: MissingCause::NotFound,
            key: "lost".into(),
            folder: String::new(),
            target: None,
            files: lost,
        });
    }
    groups
}

/// Outcome of a search for missing files in a folder.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RelocateReport {
    pub found: u32,
    pub left: u32,
}

/// One version of a duplicated title.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DuplicateEntry {
    pub record: MediaRecord,
    /// Codec name, e.g. "flac", "mp3" (from FFmpeg, else the extension).
    pub codec: Option<String>,
    pub lossless: bool,
    pub bitrate_kbps: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DuplicateGroup {
    pub kind: MediaKind,
    pub title: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    /// Best quality first: the one proposed to keep.
    pub entries: Vec<DuplicateEntry>,
}

/// Same title and duration within this margin (seconds): the same
/// recording, whatever the file format.
pub const DUPLICATE_DURATION_MARGIN: f64 = 2.0;

const LOSSLESS: [&str; 7] = ["flac", "alac", "wav", "ape", "wavpack", "tta", "truehd"];

fn fold(text: &str) -> String {
    text.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

fn entry(record: MediaRecord) -> DuplicateEntry {
    let codec = match record.kind {
        MediaKind::Audio => record.audio_codec.clone(),
        MediaKind::Video => record.video_codec.clone(),
    }
    .or_else(|| files::extension(Path::new(&record.path)))
    .map(|c| c.to_lowercase());
    let lossless = record.kind == MediaKind::Audio
        && codec
            .as_deref()
            .is_some_and(|c| LOSSLESS.contains(&c) || c.starts_with("pcm_"));
    let bitrate_kbps = record
        .duration_secs
        .filter(|d| *d > 0.0 && record.size_bytes > 0)
        .map(|d| (record.size_bytes as f64 * 8.0 / d / 1000.0).round() as u32);
    DuplicateEntry {
        record,
        codec,
        lossless,
        bitrate_kbps,
    }
}

/// Better version first: lossless, then picture height (video), bit rate,
/// size.
fn quality_order(a: &DuplicateEntry, b: &DuplicateEntry) -> std::cmp::Ordering {
    let key = |e: &DuplicateEntry| {
        (
            e.lossless,
            e.record.height.unwrap_or(0),
            e.bitrate_kbps.unwrap_or(0),
            e.record.size_bytes,
        )
    };
    key(b).cmp(&key(a))
}

/// Groups versions of the same title: same kind, same title (case and
/// spaces ignored), durations within [`DUPLICATE_DURATION_MARGIN`], and no
/// two different artists. Entries without a duration are left out.
pub fn duplicate_groups(records: Vec<MediaRecord>) -> Vec<DuplicateGroup> {
    let mut buckets: HashMap<(bool, String), Vec<MediaRecord>> = HashMap::new();
    for r in records.into_iter().filter(|r| r.duration_secs.is_some()) {
        buckets
            .entry((r.kind == MediaKind::Video, fold(&r.title)))
            .or_default()
            .push(r);
    }
    let mut groups = Vec::new();
    for (_, mut bucket) in buckets {
        bucket.sort_by(|a, b| a.duration_secs.partial_cmp(&b.duration_secs).unwrap());
        let mut clusters: Vec<(f64, Option<String>, Vec<MediaRecord>)> = Vec::new();
        for r in bucket {
            let duration = r.duration_secs.unwrap_or(0.0);
            let artist = r.artist.as_deref().map(fold);
            let fits = clusters.iter_mut().find(|(d, a, _)| {
                (duration - *d).abs() <= DUPLICATE_DURATION_MARGIN
                    && match (a.as_deref(), artist.as_deref()) {
                        (Some(x), Some(y)) => x == y,
                        _ => true,
                    }
            });
            match fits {
                Some((_, a, members)) => {
                    if a.is_none() {
                        *a = artist;
                    }
                    members.push(r);
                }
                None => clusters.push((duration, artist, vec![r])),
            }
        }
        for (_, _, members) in clusters.into_iter().filter(|c| c.2.len() > 1) {
            let mut entries: Vec<DuplicateEntry> = members.into_iter().map(entry).collect();
            entries.sort_by(quality_order);
            let pick = |f: fn(&MediaRecord) -> Option<&String>| {
                entries.iter().find_map(|e| f(&e.record).cloned())
            };
            groups.push(DuplicateGroup {
                kind: entries[0].record.kind,
                title: entries[0].record.title.clone(),
                artist: pick(|r| r.artist.as_ref()),
                album: pick(|r| r.album.as_ref()),
                entries,
            });
        }
    }
    groups.sort_by(|a, b| {
        a.title
            .to_lowercase()
            .cmp(&b.title.to_lowercase())
            .then(a.entries[0].record.id.cmp(&b.entries[0].record.id))
    });
    groups
}

impl Library {
    /// Entries whose file is back (a drive plugged in again) are shown
    /// again. Returns how many.
    pub fn recheck_missing(&self) -> Result<usize, LibraryError> {
        let missing = lock(&self.inner.storage).missing_media()?;
        let back: Vec<i64> = missing
            .iter()
            .filter(|r| Path::new(&r.path).is_file())
            .map(|r| r.id)
            .collect();
        if back.is_empty() {
            return Ok(0);
        }
        lock(&self.inner.storage).with_batch(|s| {
            for id in &back {
                s.set_media_missing(*id, false)?;
            }
            Ok(())
        })?;
        (self.inner.on_change)();
        self.inner.wake.notify_one();
        Ok(back.len())
    }

    pub fn missing_count(&self) -> Result<u64, LibraryError> {
        Ok(lock(&self.inner.storage).missing_count()?)
    }

    /// Missing entries grouped by probable cause (after a recheck).
    pub fn missing_report(&self) -> Result<Vec<MissingGroup>, LibraryError> {
        self.recheck_missing()?;
        let storage = lock(&self.inner.storage);
        let missing = storage.missing_media()?;
        let present = storage.present_files()?;
        drop(storage);
        Ok(missing_groups(missing, &present, |root| root.exists()))
    }

    /// Points entry `id` at `file` (the user located it, or it was found
    /// elsewhere). The entry keeps its history, playlists and tags; if
    /// `file` was indexed separately meanwhile, that newer entry is merged
    /// into it.
    pub fn relocate(&self, id: i64, file: &Path) -> Result<MediaRecord, LibraryError> {
        if !file.is_file() {
            return Err(LibraryError::Missing);
        }
        let key = file.to_string_lossy().into_owned();
        let storage = lock(&self.inner.storage);
        let record = storage.media(id)?;
        if files::kind_for(file).is_none() {
            return Err(LibraryError::InvalidName);
        }
        let other = storage.media_by_path(&key)?.filter(|o| o.id != id);
        storage.with_batch(|s| {
            if let Some(o) = &other {
                s.transfer_media_links(o.id, id)?;
                s.delete_media(o.id)?;
            }
            s.forget_removed(&key)?;
            s.rename_media(id, &key, &record.title)?;
            s.set_media_missing(id, false)
        })?;
        let updated = storage.media(id)?;
        drop(storage);
        if let Some(thumb) = other.and_then(|o| o.thumbnail) {
            self.forget_picture(Path::new(&thumb));
        }
        (self.inner.on_change)();
        self.inner.wake.notify_one();
        Ok(updated)
    }

    /// Looks for the files of entries `ids` under `folder` (same name and,
    /// when known, same size) and relocates the ones found.
    pub fn relocate_in(&self, ids: &[i64], folder: &Path) -> Result<RelocateReport, LibraryError> {
        let mut by_name: HashMap<String, Vec<(PathBuf, u64)>> = HashMap::new();
        for path in files::media_files(folder) {
            let size = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
            by_name
                .entry(file_name_key(&path.to_string_lossy()))
                .or_default()
                .push((path, size));
        }
        let mut report = RelocateReport::default();
        for id in ids {
            let Ok(record) = lock(&self.inner.storage).media(*id) else {
                continue;
            };
            let candidates = by_name
                .get(&file_name_key(&record.path))
                .map(Vec::as_slice)
                .unwrap_or_default();
            let found = if record.size_bytes > 0 {
                candidates.iter().find(|(_, s)| *s == record.size_bytes)
            } else if candidates.len() == 1 {
                candidates.first()
            } else {
                None
            };
            match found {
                Some((path, _)) if self.relocate(*id, path).is_ok() => report.found += 1,
                _ => report.left += 1,
            }
        }
        Ok(report)
    }

    /// Present titles found in several versions, best quality first.
    pub fn duplicate_report(&self) -> Result<Vec<DuplicateGroup>, LibraryError> {
        let candidates = lock(&self.inner.storage).duplicate_candidates()?;
        Ok(duplicate_groups(candidates))
    }

    /// Sets a duplicate aside in favour of `keep`: its playlist entries and
    /// favorite move to `keep`, then it is hidden from the library (the file
    /// stays, scans skip it) or, when `delete_file`, sent to the Recycle
    /// Bin.
    pub fn set_aside_duplicate(
        &self,
        keep: i64,
        drop_id: i64,
        delete_file: bool,
    ) -> Result<(), LibraryError> {
        if keep == drop_id {
            return Err(LibraryError::InvalidName);
        }
        {
            let storage = lock(&self.inner.storage);
            storage.media(keep)?;
            storage.transfer_media_links(drop_id, keep)?;
        }
        if delete_file {
            self.delete(drop_id)
        } else {
            self.remove(drop_id)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(id: i64, path: &str, title: &str, size: u64) -> MediaRecord {
        MediaRecord {
            id,
            path: path.into(),
            title: title.into(),
            kind: MediaKind::Audio,
            source_host: None,
            source_url: None,
            task_id: None,
            size_bytes: size,
            duration_secs: None,
            width: None,
            height: None,
            video_codec: None,
            audio_codec: None,
            container: None,
            thumbnail: None,
            probed: true,
            missing: false,
            added_at: 0,
            modified_at: 0,
            artist: None,
            album: None,
            album_artist: None,
            year: None,
            genre: None,
            track_no: None,
            disc_no: None,
            favorite: false,
            cover_custom: false,
        }
    }

    #[test]
    fn volumes_that_can_be_unplugged() {
        let root = |p: &str| volume_root(Path::new(p)).map(|r| r.to_string_lossy().into_owned());
        assert_eq!(root("/storage/1A2B-3C4D/Music/a.mp3").as_deref(), Some("/storage/1A2B-3C4D"));
        assert_eq!(root("/storage/emulated/0/Music/a.mp3"), None);
        assert_eq!(root("/media/hery/Disque/a.mkv").as_deref(), Some("/media/hery/Disque"));
        assert_eq!(root("/Volumes/USB/a.mkv").as_deref(), Some("/Volumes/USB"));
        assert_eq!(root("/home/hery/a.mp3"), None);
        assert_eq!(root("/Volumes/USB"), None);
        #[cfg(windows)]
        {
            assert_eq!(root(r"E:\Films\a.mkv").as_deref(), Some(r"E:\"));
            assert_eq!(root(r"\\nas\share\a.mkv").as_deref(), Some(r"\\nas\share\"));
        }
    }

    #[test]
    fn missing_files_are_grouped_by_cause() {
        let missing = vec![
            record(1, "/Volumes/E/Films/Ferry.mkv", "Ferry", 10),
            record(2, "/Volumes/E/Films/Rova.mp4", "Rova", 20),
            record(3, "/home/h/Musique/Nafy/05 Seuil.flac", "Seuil", 900),
            record(4, "/home/h/Musique/Nafy/06 Fin.flac", "Fin", 800),
            record(5, "/home/h/Music/Vieux/Mena.mp3", "Mena", 5),
        ];
        let present = vec![
            (10, "/home/h/Musique/Nafy (2024)/05 Seuil.flac".to_owned(), 900),
            (11, "/home/h/Musique/Nafy (2024)/06 fin.FLAC".to_owned(), 800),
            // Same name, other size: not the same file.
            (12, "/home/h/Autre/Mena.mp3".to_owned(), 6),
        ];
        let groups = missing_groups(missing, &present, |root| root != Path::new("/Volumes/E"));
        let summary: Vec<_> = groups
            .iter()
            .map(|g| (g.cause, g.files.iter().map(|f| f.record.id).collect::<Vec<_>>()))
            .collect();
        assert_eq!(
            summary,
            [
                (MissingCause::VolumeAbsent, vec![1, 2]),
                (MissingCause::Moved, vec![3, 4]),
                (MissingCause::NotFound, vec![5]),
            ]
        );
        assert_eq!(groups[0].folder, "/Volumes/E");
        assert_eq!(groups[1].target.as_deref(), Some("/home/h/Musique/Nafy (2024)"));
        assert_eq!(
            groups[1].files[1].found.as_deref(),
            Some("/home/h/Musique/Nafy (2024)/06 fin.FLAC")
        );
    }

    #[test]
    fn duplicates_keep_the_best_version_first() {
        let mut flac = record(1, "D:/Nafy/02 Marée haute.flac", "Marée haute", 58_000_000);
        flac.audio_codec = Some("flac".into());
        flac.artist = Some("Nafy Rakoto".into());
        flac.duration_secs = Some(240.0);
        let mut mp3 = record(2, "C:/Dl/Marée haute.mp3", "marée  haute", 5_760_000);
        mp3.duration_secs = Some(241.5);
        let mut live = record(3, "D:/Live/Marée haute.mp3", "Marée haute", 9_000_000);
        live.duration_secs = Some(300.0);
        let mut cover = record(4, "D:/Toky/Marée haute.mp3", "Marée haute", 5_000_000);
        cover.artist = Some("Toky".into());
        cover.duration_secs = Some(240.5);
        let unprobed = record(5, "D:/x/Marée haute.ogg", "Marée haute", 1);

        let groups = duplicate_groups(vec![mp3, live, flac, cover, unprobed]);
        assert_eq!(groups.len(), 1);
        let g = &groups[0];
        assert_eq!(g.artist.as_deref(), Some("Nafy Rakoto"));
        let ids: Vec<_> = g.entries.iter().map(|e| e.record.id).collect();
        assert_eq!(ids, [1, 2]);
        assert!(g.entries[0].lossless);
        assert_eq!(g.entries[1].codec.as_deref(), Some("mp3"));
        assert_eq!(g.entries[1].bitrate_kbps, Some(191));
    }
}

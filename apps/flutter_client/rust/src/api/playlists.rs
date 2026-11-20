//! Playlists (handoff W-M5, A-02c): the core's playlist tables, shared with
//! the Tauri app, plus M3U import / export. Removing an entry from a
//! playlist never touches the file.

use std::path::Path;

use anyhow::{Result, anyhow};
use storage::{PlaylistSummary, Storage};

use super::library::{LibraryItem, item, with_db};
use crate::m3u;

pub struct PlaylistInfo {
    pub id: i64,
    pub name: String,
    pub count: u32,
    pub duration_secs: f64,
    /// Up to four covers for the mosaic.
    pub covers: Vec<String>,
    /// Milliseconds since the epoch.
    pub updated_at: i64,
}

pub struct PlaylistDetail {
    pub info: PlaylistInfo,
    /// In playlist order; the same file may appear twice.
    pub items: Vec<LibraryItem>,
}

pub struct ImportReport {
    pub playlist: PlaylistInfo,
    pub added: u32,
    /// Entries not found in the library, and web addresses (never fetched).
    pub skipped: u32,
}

fn info(s: PlaylistSummary) -> PlaylistInfo {
    PlaylistInfo {
        id: s.id,
        name: s.name,
        count: s.count,
        duration_secs: s.duration_secs,
        covers: s.covers,
        updated_at: s.updated_at,
    }
}

pub fn playlists_list(db_path: String) -> Result<Vec<PlaylistInfo>> {
    with_db(&db_path, |db| {
        Ok(db.playlists()?.into_iter().map(info).collect())
    })
}

/// One playlist with its entries; None when it was deleted.
pub fn playlist_get(db_path: String, id: i64) -> Result<Option<PlaylistDetail>> {
    with_db(&db_path, |db| {
        let summary = match db.playlist_summary(id) {
            Ok(s) => s,
            Err(storage::StorageError::NotFound(_)) => return Ok(None),
            Err(e) => return Err(e.into()),
        };
        let playlist = db.playlist(id)?;
        Ok(Some(PlaylistDetail {
            info: info(summary),
            items: playlist.items.into_iter().map(item).collect(),
        }))
    })
}

pub fn playlist_create(db_path: String, name: String, media_ids: Vec<i64>) -> Result<PlaylistInfo> {
    with_db(&db_path, |db| {
        Ok(info(db.create_playlist(&name, &media_ids)?))
    })
}

pub fn playlist_rename(db_path: String, id: i64, name: String) -> Result<()> {
    with_db(&db_path, |db| Ok(db.rename_playlist(id, &name)?))
}

pub fn playlist_delete(db_path: String, id: i64) -> Result<()> {
    with_db(&db_path, |db| Ok(db.delete_playlist(id)?))
}

pub fn playlist_add(db_path: String, id: i64, media_ids: Vec<i64>) -> Result<()> {
    with_db(&db_path, |db| Ok(db.add_to_playlist(id, &media_ids)?))
}

/// Removes the entry at `index` (the file stays in the library).
pub fn playlist_remove(db_path: String, id: i64, index: u32) -> Result<()> {
    with_db(&db_path, |db| {
        Ok(db.remove_from_playlist(id, index as usize)?)
    })
}

pub fn playlist_move(db_path: String, id: i64, from: u32, to: u32) -> Result<()> {
    with_db(&db_path, |db| {
        Ok(db.move_in_playlist(id, from as usize, to as usize)?)
    })
}

fn find_id(db: &Storage, path: &Path) -> Result<Option<i64>> {
    let text = path.to_string_lossy();
    // The library stores the platform separators; try both spellings.
    Ok(db
        .media_id_by_path(&text)?
        .or(db.media_id_by_path(&text.replace('/', "\\"))?)
        .or(db.media_id_by_path(&text.replace('\\', "/"))?))
}

/// Creates a playlist from an `.m3u` / `.m3u8` file: entries found in the
/// library are added, the others counted.
pub fn playlist_import_m3u(db_path: String, path: String) -> Result<ImportReport> {
    let path = Path::new(&path);
    let meta = std::fs::metadata(path)?;
    if meta.len() > m3u::M3U_MAX_BYTES {
        return Err(anyhow!("playlist file too large"));
    }
    let bytes = std::fs::read(path)?;
    let text = String::from_utf8_lossy(&bytes);
    let parsed = m3u::parse(&text, path.parent().unwrap_or(Path::new("")));
    let name = path
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "Playlist".into());
    with_db(&db_path, |db| {
        let mut ids = Vec::new();
        let mut skipped = parsed.skipped;
        for entry in &parsed.paths {
            match find_id(db, entry)? {
                Some(id) => ids.push(id),
                None => skipped += 1,
            }
        }
        let added = ids.len().min(storage::PLAYLIST_ITEMS_MAX);
        skipped += ids.len() - added;
        ids.truncate(added);
        let playlist = info(db.create_playlist(&name, &ids)?);
        Ok(ImportReport {
            playlist,
            added: added as u32,
            skipped: skipped as u32,
        })
    })
}

/// Writes the playlist as extended `.m3u8` to `path`: written next to it,
/// then moved, so a failure leaves no half file.
pub fn playlist_export_m3u(db_path: String, id: i64, path: String) -> Result<()> {
    let playlist = with_db(&db_path, |db| Ok(db.playlist(id)?))?;
    let text = m3u::export(&playlist.name, &playlist.items);
    let target = Path::new(&path);
    let partial = target.with_extension("m3u8.part");
    std::fs::write(&partial, text.as_bytes())
        .and_then(|_| std::fs::rename(&partial, target))
        .map_err(|e| {
            let _ = std::fs::remove_file(&partial);
            anyhow!(e)
        })
}

#[cfg(test)]
mod tests {
    use super::*;
    use storage::{MediaKind, NewMedia};

    #[test]
    fn create_edit_and_round_trip_through_m3u() {
        let dir = std::env::temp_dir().join(format!("mm-playlists-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let db_path = dir.join("miarina.db").to_string_lossy().into_owned();
        let ids: Vec<i64> = with_db(&db_path, |db| {
            Ok(["a", "b", "c"]
                .iter()
                .map(|n| {
                    db.upsert_media(&NewMedia {
                        path: format!("D:/Musique/{n}.flac"),
                        title: n.to_string(),
                        kind: MediaKind::Audio,
                        source_host: None,
                        source_url: None,
                        task_id: None,
                        size_bytes: 1,
                    })
                    .unwrap()
                    .id
                })
                .collect())
        })
        .unwrap();

        let p = playlist_create(db_path.clone(), "Soirées calmes".into(), ids.clone()).unwrap();
        assert_eq!(p.count, 3);
        playlist_move(db_path.clone(), p.id, 2, 0).unwrap();
        playlist_remove(db_path.clone(), p.id, 1).unwrap();
        let d = playlist_get(db_path.clone(), p.id).unwrap().unwrap();
        let order: Vec<_> = d.items.iter().map(|i| i.title.as_str()).collect();
        assert_eq!(order, ["c", "b"]);

        let file = dir.join("export.m3u8");
        playlist_export_m3u(db_path.clone(), p.id, file.to_string_lossy().into_owned()).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        assert!(text.starts_with("#EXTM3U\n#PLAYLIST:Soirées calmes\n"));
        // An entry the library does not know, and a web address.
        std::fs::write(
            &file,
            format!("{text}D:/ailleurs/x.mp3\nhttps://example.org/s.mp3\n"),
        )
        .unwrap();
        let r = playlist_import_m3u(db_path.clone(), file.to_string_lossy().into_owned()).unwrap();
        assert_eq!((r.added, r.skipped), (2, 2));
        assert_eq!(r.playlist.name, "export");

        playlist_rename(db_path.clone(), p.id, "Calme".into()).unwrap();
        assert_eq!(playlists_list(db_path.clone()).unwrap().len(), 2);
        playlist_delete(db_path.clone(), p.id).unwrap();
        assert!(playlist_get(db_path.clone(), p.id).unwrap().is_none());
        // Files stay in the library.
        let kept = super::super::library::library_item(db_path, ids[0]).unwrap();
        assert!(kept.is_some());
        let _ = std::fs::remove_dir_all(&dir);
    }
}

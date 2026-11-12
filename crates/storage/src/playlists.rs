//! Favorites and playlists (CDC COM-06, COM-11). A playlist is an ordered
//! list of library entries; an entry removed from the library leaves every
//! playlist on its own (foreign key cascade).

use rusqlite::{OptionalExtension, params};
use serde::Serialize;

use crate::media::{COLUMNS, row_to_media};
use crate::{MediaRecord, Result, Storage, StorageError, ensure_found, now_ms};

/// Longest playlist name accepted.
pub const PLAYLIST_NAME_MAX: usize = 120;
/// Entries per playlist (a large M3U is cut there).
pub const PLAYLIST_ITEMS_MAX: usize = 5_000;
/// Playlists kept at most.
pub const PLAYLISTS_MAX: usize = 1_000;

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistSummary {
    pub id: i64,
    pub name: String,
    pub count: u32,
    pub duration_secs: f64,
    /// Up to four thumbnails for the cover mosaic.
    pub covers: Vec<String>,
    pub updated_at: i64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Playlist {
    pub id: i64,
    pub name: String,
    /// In playlist order; missing files are included (shown as missing).
    pub items: Vec<MediaRecord>,
}

fn clean_name(name: &str) -> Result<String> {
    let name: String = name
        .chars()
        .filter(|c| !c.is_control())
        .collect::<String>()
        .trim()
        .to_owned();
    if name.is_empty() {
        return Err(StorageError::Invalid("a playlist needs a name".into()));
    }
    Ok(name.chars().take(PLAYLIST_NAME_MAX).collect())
}

impl Storage {
    pub fn set_favorite(&self, media_id: i64, favorite: bool) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE media SET favorite = ?2 WHERE id = ?1",
            params![media_id, favorite],
        )?;
        ensure_found(changed, &media_id.to_string())
    }

    pub fn playlists(&self) -> Result<Vec<PlaylistSummary>> {
        let mut stmt = self.conn.prepare(
            "SELECT p.id, p.name, p.updated_at, count(i.id), coalesce(sum(m.duration_secs), 0) \
             FROM playlists p \
             LEFT JOIN playlist_items i ON i.playlist_id = p.id \
             LEFT JOIN media m ON m.id = i.media_id \
             GROUP BY p.id ORDER BY p.updated_at DESC, p.id DESC",
        )?;
        let rows = stmt
            .query_map([], |r| {
                Ok((
                    r.get::<_, i64>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, i64>(2)?,
                    r.get::<_, i64>(3)?,
                    r.get::<_, f64>(4)?,
                ))
            })?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        let mut covers = self.conn.prepare(
            "SELECT m.thumbnail FROM playlist_items i JOIN media m ON m.id = i.media_id \
             WHERE i.playlist_id = ?1 AND m.thumbnail IS NOT NULL \
             ORDER BY i.position, i.id LIMIT 4",
        )?;
        rows.into_iter()
            .map(|(id, name, updated_at, count, duration)| {
                Ok(PlaylistSummary {
                    covers: covers
                        .query_map([id], |r| r.get(0))?
                        .collect::<rusqlite::Result<_>>()?,
                    id,
                    name,
                    count: count.max(0) as u32,
                    duration_secs: duration,
                    updated_at,
                })
            })
            .collect()
    }

    pub fn playlist_summary(&self, id: i64) -> Result<PlaylistSummary> {
        self.playlists()?
            .into_iter()
            .find(|p| p.id == id)
            .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    pub fn playlist(&self, id: i64) -> Result<Playlist> {
        let name: String = self
            .conn
            .query_row("SELECT name FROM playlists WHERE id = ?1", [id], |r| {
                r.get(0)
            })
            .optional()?
            .ok_or_else(|| StorageError::NotFound(id.to_string()))?;
        let columns = COLUMNS
            .split(", ")
            .map(|c| format!("m.{c}"))
            .collect::<Vec<_>>()
            .join(", ");
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {columns} FROM playlist_items i JOIN media m ON m.id = i.media_id \
             WHERE i.playlist_id = ?1 ORDER BY i.position, i.id"
        ))?;
        let items = stmt
            .query_map([id], row_to_media)?
            .map(|r| r?)
            .collect::<Result<Vec<_>>>()?;
        Ok(Playlist { id, name, items })
    }

    fn playlist_ids(&self, id: i64) -> Result<Vec<i64>> {
        let mut stmt = self.conn.prepare(
            "SELECT media_id FROM playlist_items WHERE playlist_id = ?1 ORDER BY position, id",
        )?;
        stmt.query_map([id], |r| r.get(0))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
    }

    /// Replaces the entries of a playlist, in order. Unknown media ids are
    /// skipped; the list is cut at [`PLAYLIST_ITEMS_MAX`].
    fn write_items(&self, id: i64, media_ids: &[i64]) -> Result<()> {
        let tx = self.conn.unchecked_transaction()?;
        tx.execute("DELETE FROM playlist_items WHERE playlist_id = ?1", [id])?;
        let mut position = 0i64;
        for media_id in media_ids.iter().take(PLAYLIST_ITEMS_MAX) {
            position += tx.execute(
                "INSERT INTO playlist_items (playlist_id, media_id, position) \
                 SELECT ?1, id, ?3 FROM media WHERE id = ?2",
                params![id, media_id, position],
            )? as i64;
        }
        let changed = tx.execute(
            "UPDATE playlists SET updated_at = ?2 WHERE id = ?1",
            params![id, now_ms()],
        )?;
        ensure_found(changed, &id.to_string())?;
        tx.commit()?;
        Ok(())
    }

    pub fn create_playlist(&self, name: &str, media_ids: &[i64]) -> Result<PlaylistSummary> {
        let name = clean_name(name)?;
        let count: i64 = self
            .conn
            .query_row("SELECT count(*) FROM playlists", [], |r| r.get(0))?;
        if count as usize >= PLAYLISTS_MAX {
            return Err(StorageError::Invalid("too many playlists".into()));
        }
        let now = now_ms();
        self.conn.execute(
            "INSERT INTO playlists (name, created_at, updated_at) VALUES (?1, ?2, ?2)",
            params![name, now],
        )?;
        let id = self.conn.last_insert_rowid();
        self.write_items(id, media_ids)?;
        self.playlist_summary(id)
    }

    pub fn rename_playlist(&self, id: i64, name: &str) -> Result<()> {
        let name = clean_name(name)?;
        let changed = self.conn.execute(
            "UPDATE playlists SET name = ?2, updated_at = ?3 WHERE id = ?1",
            params![id, name, now_ms()],
        )?;
        ensure_found(changed, &id.to_string())
    }

    pub fn delete_playlist(&self, id: i64) -> Result<()> {
        let changed = self
            .conn
            .execute("DELETE FROM playlists WHERE id = ?1", [id])?;
        ensure_found(changed, &id.to_string())
    }

    /// Appends entries (a media may appear more than once, as in M3U).
    pub fn add_to_playlist(&self, id: i64, media_ids: &[i64]) -> Result<()> {
        let mut ids = self.playlist_ids(id)?;
        ids.extend_from_slice(media_ids);
        self.write_items(id, &ids)
    }

    /// Removes the entry at `index` (playlist order).
    pub fn remove_from_playlist(&self, id: i64, index: usize) -> Result<()> {
        let mut ids = self.playlist_ids(id)?;
        if index >= ids.len() {
            return Err(StorageError::Invalid("no entry at this place".into()));
        }
        ids.remove(index);
        self.write_items(id, &ids)
    }

    pub fn move_in_playlist(&self, id: i64, from: usize, to: usize) -> Result<()> {
        let mut ids = self.playlist_ids(id)?;
        if from >= ids.len() || to >= ids.len() {
            return Err(StorageError::Invalid("no entry at this place".into()));
        }
        let item = ids.remove(from);
        ids.insert(to, item);
        self.write_items(id, &ids)
    }

    /// Library entry stored at `path` (case-insensitive, for M3U import).
    pub fn media_id_by_path(&self, path: &str) -> Result<Option<i64>> {
        Ok(self
            .conn
            .query_row(
                "SELECT id FROM media WHERE path = ?1 COLLATE NOCASE ORDER BY missing, id LIMIT 1",
                [path],
                |r| r.get(0),
            )
            .optional()?)
    }
}

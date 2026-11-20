//! Media library repository (schema v2).

use rusqlite::{OptionalExtension, Row, params, params_from_iter, types::Value};
use serde::{Deserialize, Serialize};

use crate::{MediaKind, Result, Storage, StorageError, now_ms};

/// A file entering the library (download, scan).
#[derive(Debug, Clone)]
pub struct NewMedia {
    pub path: String,
    pub title: String,
    pub kind: MediaKind,
    pub source_host: Option<String>,
    pub source_url: Option<String>,
    pub task_id: Option<String>,
    pub size_bytes: u64,
}

/// Technical metadata read with ffprobe.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaProbe {
    pub duration_secs: Option<f64>,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub video_codec: Option<String>,
    pub audio_codec: Option<String>,
    pub container: Option<String>,
    /// `false` when no video stream exists (audio file).
    pub has_video: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaRecord {
    pub id: i64,
    pub path: String,
    pub title: String,
    pub kind: MediaKind,
    pub source_host: Option<String>,
    pub source_url: Option<String>,
    pub task_id: Option<String>,
    pub size_bytes: u64,
    pub duration_secs: Option<f64>,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub video_codec: Option<String>,
    pub audio_codec: Option<String>,
    pub container: Option<String>,
    pub thumbnail: Option<String>,
    pub probed: bool,
    pub missing: bool,
    pub added_at: i64,
    pub modified_at: i64,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub year: Option<i32>,
    pub genre: Option<String>,
    pub track_no: Option<u32>,
    pub disc_no: Option<u32>,
    /// Marked as a favorite (COM-06).
    pub favorite: bool,
    /// The picture was chosen by the user (or removed on purpose): the
    /// library never replaces it.
    pub cover_custom: bool,
}

/// Editable tags of a library entry (COM-07). `None` = no value.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct MediaTags {
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

/// Longest stored value of a short tag / of lyrics (characters).
pub const TAG_TEXT_MAX: usize = 500;
pub const TAG_LYRICS_MAX: usize = 20_000;

fn bounded(value: &Option<String>, max: usize) -> Option<String> {
    let text = value.as_deref()?.trim();
    (!text.is_empty()).then(|| text.chars().take(max).collect())
}

impl MediaTags {
    /// Trimmed, length-bounded copy; empty strings become `None`, numbers
    /// out of range are dropped.
    pub fn normalized(&self) -> Self {
        Self {
            title: bounded(&self.title, TAG_TEXT_MAX),
            artist: bounded(&self.artist, TAG_TEXT_MAX),
            album: bounded(&self.album, TAG_TEXT_MAX),
            album_artist: bounded(&self.album_artist, TAG_TEXT_MAX),
            year: self.year.filter(|y| (1..=9999).contains(y)),
            genre: bounded(&self.genre, TAG_TEXT_MAX),
            track_no: self.track_no.filter(|n| (1..=9999).contains(n)),
            disc_no: self.disc_no.filter(|n| (1..=999).contains(n)),
            comment: bounded(&self.comment, TAG_TEXT_MAX * 4),
            lyrics: bounded(&self.lyrics, TAG_LYRICS_MAX),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GroupBy {
    Album,
    Artist,
    Folder,
}

/// One album, artist or folder of the music library.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaGroup {
    pub name: String,
    /// Album artist (albums) or number of albums (artists).
    pub detail: Option<String>,
    pub count: u64,
    pub duration_secs: f64,
    pub year: Option<i32>,
    pub thumbnail: Option<String>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MediaSort {
    #[default]
    Added,
    Title,
    Size,
    Duration,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct MediaQuery {
    pub search: String,
    pub kind: Option<MediaKind>,
    /// Tracks of one album / artist / folder (sub-folders included).
    pub album: Option<String>,
    pub artist: Option<String>,
    pub folder: Option<String>,
    /// Favorites only (COM-06).
    pub favorites: bool,
    pub sort: MediaSort,
    pub offset: u32,
    pub limit: u32,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaPage {
    pub items: Vec<MediaRecord>,
    pub total: u64,
}

/// Background indexing work left (first import, W-O1c).
#[derive(Debug, Clone, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IndexProgress {
    /// Entries whose file is present.
    pub total: u64,
    /// Tags not read yet.
    pub to_tag: u64,
    /// Technical details (duration, picture) not read yet.
    pub to_probe: u64,
    /// Read but without a duration: the file could not be decoded.
    pub unreadable: u64,
    pub audio: u64,
    pub video: u64,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaStats {
    pub count: u64,
    pub total_bytes: u64,
    pub video_count: u64,
    pub video_bytes: u64,
    pub audio_count: u64,
    pub audio_bytes: u64,
}

/// Largest page returned by one query.
pub const MEDIA_PAGE_MAX: u32 = 10_000;
const MAX_SEARCH_TOKENS: usize = 8;

pub(crate) const COLUMNS: &str = "id, path, title, kind, source_host, source_url, task_id, size_bytes, \
     duration_secs, width, height, video_codec, audio_codec, container, thumbnail, probed, \
     missing, added_at, modified_at, artist, album, album_artist, year, genre, track_no, disc_no, favorite, cover_custom";

impl<'de> Deserialize<'de> for MediaKind {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> std::result::Result<Self, D::Error> {
        match String::deserialize(d)?.as_str() {
            "video" => Ok(Self::Video),
            "audio" => Ok(Self::Audio),
            other => Err(serde::de::Error::unknown_variant(
                other,
                &["video", "audio"],
            )),
        }
    }
}

/// Turns user input into a safe FTS5 query: every word becomes a quoted
/// prefix term (`"tear"* "ste"*`), so operators and quotes typed by the user
/// are never interpreted.
pub fn fts_query(input: &str) -> Option<String> {
    let terms: Vec<String> = input
        .split(|c: char| !c.is_alphanumeric())
        .filter(|t| !t.is_empty())
        .take(MAX_SEARCH_TOKENS)
        .map(|t| format!("\"{t}\"*"))
        .collect();
    (!terms.is_empty()).then(|| terms.join(" "))
}

impl Storage {
    /// Adds a file, or refreshes size/source if the path is already known.
    /// Adding a path explicitly (e.g. a new download) cancels an earlier
    /// removal from the library.
    pub fn upsert_media(&self, media: &NewMedia) -> Result<MediaRecord> {
        let now = now_ms();
        self.conn
            .execute("DELETE FROM media_removed WHERE path = ?1", [&media.path])?;
        self.conn.execute(
            "INSERT INTO media (path, title, kind, source_host, source_url, task_id, size_bytes, \
             added_at, modified_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8) \
             ON CONFLICT(path) DO UPDATE SET size_bytes = excluded.size_bytes, missing = 0, \
             source_host = coalesce(excluded.source_host, source_host), \
             source_url = coalesce(excluded.source_url, source_url), \
             task_id = coalesce(excluded.task_id, task_id), modified_at = excluded.modified_at",
            params![
                media.path,
                media.title,
                media.kind.as_str(),
                media.source_host,
                media.source_url,
                media.task_id,
                media.size_bytes as i64,
                now,
            ],
        )?;
        self.media_by_path(&media.path)?
            .ok_or_else(|| StorageError::NotFound(media.path.clone()))
    }

    pub fn media(&self, id: i64) -> Result<MediaRecord> {
        self.conn
            .query_row(
                &format!("SELECT {COLUMNS} FROM media WHERE id = ?1"),
                [id],
                row_to_media,
            )
            .optional()?
            .ok_or_else(|| StorageError::NotFound(id.to_string()))?
    }

    pub fn media_by_path(&self, path: &str) -> Result<Option<MediaRecord>> {
        self.conn
            .query_row(
                &format!("SELECT {COLUMNS} FROM media WHERE path = ?1"),
                [path],
                row_to_media,
            )
            .optional()?
            .transpose()
    }

    /// Searches the library (missing files excluded).
    pub fn query_media(&self, query: &MediaQuery) -> Result<MediaPage> {
        let mut conditions = vec!["m.missing = 0".to_owned()];
        let mut values: Vec<Value> = Vec::new();
        let fts = fts_query(&query.search);
        if let Some(fts) = &fts {
            conditions.push("m.id IN (SELECT rowid FROM media_fts WHERE media_fts MATCH ?)".into());
            values.push(Value::Text(fts.clone()));
        }
        if let Some(kind) = query.kind {
            conditions.push("m.kind = ?".into());
            values.push(Value::Text(kind.as_str().into()));
        }
        if let Some(album) = &query.album {
            conditions.push("m.album = ? COLLATE NOCASE".into());
            values.push(Value::Text(album.clone()));
        }
        if let Some(artist) = &query.artist {
            conditions
                .push("(m.artist = ? COLLATE NOCASE OR m.album_artist = ? COLLATE NOCASE)".into());
            values.push(Value::Text(artist.clone()));
            values.push(Value::Text(artist.clone()));
        }
        if query.favorites {
            conditions.push("m.favorite = 1".into());
        }
        if let Some(folder) = &query.folder {
            conditions.push("(m.path LIKE ? ESCAPE '!' OR m.path LIKE ? ESCAPE '!')".into());
            let escaped = folder
                .trim_end_matches(['/', '\\'])
                .replace('!', "!!")
                .replace('%', "!%")
                .replace('_', "!_");
            values.push(Value::Text(format!("{escaped}\\%")));
            values.push(Value::Text(format!("{escaped}/%")));
        }
        let filter = conditions.join(" AND ");
        let order = match query.sort {
            // Within an album, disc and track order wins.
            _ if query.album.is_some() => {
                "coalesce(m.disc_no, 1), coalesce(m.track_no, 9999), m.title COLLATE NOCASE, m.id"
            }
            MediaSort::Added => "m.added_at DESC, m.id DESC",
            MediaSort::Title => "m.title COLLATE NOCASE ASC, m.id",
            MediaSort::Size => "m.size_bytes DESC, m.id DESC",
            MediaSort::Duration => "coalesce(m.duration_secs, -1) DESC, m.id DESC",
        };
        let total: i64 = self.conn.query_row(
            &format!("SELECT count(*) FROM media m WHERE {filter}"),
            params_from_iter(values.iter()),
            |r| r.get(0),
        )?;
        let limit = if query.limit == 0 {
            MEDIA_PAGE_MAX
        } else {
            query.limit.min(MEDIA_PAGE_MAX)
        };
        let mut paged = values.clone();
        paged.push(Value::Integer(limit as i64));
        paged.push(Value::Integer(query.offset as i64));
        let columns = COLUMNS
            .split(", ")
            .map(|c| format!("m.{c}"))
            .collect::<Vec<_>>()
            .join(", ");
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {columns} FROM media m WHERE {filter} ORDER BY {order} LIMIT ? OFFSET ?"
        ))?;
        let items = stmt
            .query_map(params_from_iter(paged.iter()), row_to_media)?
            .map(|r| r?)
            .collect::<Result<Vec<_>>>()?;
        Ok(MediaPage {
            items,
            total: total.max(0) as u64,
        })
    }

    /// How much indexing is left, for progress screens.
    pub fn index_progress(&self) -> Result<IndexProgress> {
        Ok(self.conn.query_row(
            "SELECT count(*),              count(*) FILTER (WHERE tags_read = 0),              count(*) FILTER (WHERE probed = 0),              count(*) FILTER (WHERE probed = 1 AND duration_secs IS NULL),              count(*) FILTER (WHERE kind = 'audio'),              count(*) FILTER (WHERE kind = 'video')              FROM media WHERE missing = 0",
            [],
            |r| {
                let n = |i: usize| r.get::<_, i64>(i).map(|v| v.max(0) as u64);
                Ok(IndexProgress {
                    total: n(0)?,
                    to_tag: n(1)?,
                    to_probe: n(2)?,
                    unreadable: n(3)?,
                    audio: n(4)?,
                    video: n(5)?,
                })
            },
        )?)
    }

    pub fn media_stats(&self) -> Result<MediaStats> {
        Ok(self.conn.query_row(
            "SELECT count(*), coalesce(sum(size_bytes), 0), \
             count(*) FILTER (WHERE kind = 'video'), \
             coalesce(sum(size_bytes) FILTER (WHERE kind = 'video'), 0), \
             count(*) FILTER (WHERE kind = 'audio'), \
             coalesce(sum(size_bytes) FILTER (WHERE kind = 'audio'), 0) \
             FROM media WHERE missing = 0",
            [],
            |r| {
                let n = |i: usize| r.get::<_, i64>(i).map(|v| v.max(0) as u64);
                Ok(MediaStats {
                    count: n(0)?,
                    total_bytes: n(1)?,
                    video_count: n(2)?,
                    video_bytes: n(3)?,
                    audio_count: n(4)?,
                    audio_bytes: n(5)?,
                })
            },
        )?)
    }

    /// Present files that still need ffprobe / a thumbnail.
    pub fn media_to_probe(&self, limit: u32) -> Result<Vec<MediaRecord>> {
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {COLUMNS} FROM media WHERE probed = 0 AND missing = 0 \
             ORDER BY added_at DESC LIMIT ?1"
        ))?;
        stmt.query_map([limit], row_to_media)?.map(|r| r?).collect()
    }

    /// Stores probe results; the kind follows the streams actually found.
    pub fn set_media_probe(
        &self,
        id: i64,
        probe: &MediaProbe,
        thumbnail: Option<&str>,
    ) -> Result<()> {
        let kind = if probe.has_video {
            MediaKind::Video
        } else {
            MediaKind::Audio
        };
        let changed = self.conn.execute(
            "UPDATE media SET duration_secs = ?2, width = ?3, height = ?4, video_codec = ?5, \
             audio_codec = ?6, container = ?7, kind = ?8, \
             thumbnail = CASE WHEN cover_custom = 1 THEN thumbnail ELSE coalesce(?9, thumbnail) END, \
             probed = 1 WHERE id = ?1",
            params![
                id,
                probe.duration_secs,
                probe.width,
                probe.height,
                probe.video_codec,
                probe.audio_codec,
                probe.container,
                kind.as_str(),
                thumbnail,
            ],
        )?;
        crate::ensure_found(changed, &id.to_string())
    }

    /// Sets the picture of an entry (e.g. the source thumbnail of a download).
    pub fn set_media_thumbnail(&self, id: i64, thumbnail: &str) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE media SET thumbnail = ?2 WHERE id = ?1",
            params![id, thumbnail],
        )?;
        crate::ensure_found(changed, &id.to_string())
    }

    /// Sets a picture chosen by the user, or `None` for no picture at all;
    /// either way the library no longer builds one (COM-07 covers).
    pub fn set_media_cover(&self, id: i64, cover: Option<&str>) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE media SET thumbnail = ?2, cover_custom = 1 WHERE id = ?1",
            params![id, cover],
        )?;
        crate::ensure_found(changed, &id.to_string())
    }

    /// Marks a file as unreadable so it is not probed again on every start.
    pub fn mark_media_unprobeable(&self, id: i64) -> Result<()> {
        let changed = self
            .conn
            .execute("UPDATE media SET probed = 1 WHERE id = ?1", [id])?;
        crate::ensure_found(changed, &id.to_string())
    }

    pub fn set_media_missing(&self, id: i64, missing: bool) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE media SET missing = ?2 WHERE id = ?1",
            params![id, missing],
        )?;
        crate::ensure_found(changed, &id.to_string())
    }

    pub fn rename_media(&self, id: i64, path: &str, title: &str) -> Result<MediaRecord> {
        let changed = self.conn.execute(
            "UPDATE media SET path = ?2, title = ?3, modified_at = ?4 WHERE id = ?1",
            params![id, path, title, now_ms()],
        )?;
        crate::ensure_found(changed, &id.to_string())?;
        self.media(id)
    }

    /// Entries whose tags were never read (present files only).
    pub fn media_to_tag(&self, limit: u32) -> Result<Vec<(i64, String)>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, path FROM media WHERE tags_read = 0 AND missing = 0 \
             ORDER BY added_at DESC LIMIT ?1",
        )?;
        stmt.query_map([limit], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
    }

    /// Stores tags read from the file (`None`: nothing readable). A tag
    /// title replaces the file-name title only on this first read.
    pub fn set_media_tags_read(&self, id: i64, tags: Option<&MediaTags>) -> Result<()> {
        let Some(tags) = tags.map(MediaTags::normalized) else {
            self.conn
                .execute("UPDATE media SET tags_read = 1 WHERE id = ?1", [id])?;
            return Ok(());
        };
        self.conn.execute(
            "UPDATE media SET title = coalesce(?2, title), artist = ?3, album = ?4, \
             album_artist = ?5, year = ?6, genre = ?7, track_no = ?8, disc_no = ?9, \
             comment = ?10, lyrics = ?11, tags_read = 1 WHERE id = ?1 AND tags_read = 0",
            params![
                id,
                tags.title,
                tags.artist,
                tags.album,
                tags.album_artist,
                tags.year,
                tags.genre,
                tags.track_no,
                tags.disc_no,
                tags.comment,
                tags.lyrics,
            ],
        )?;
        Ok(())
    }

    /// Tags edited by the user (the title is kept when none is given).
    pub fn update_media_tags(&self, id: i64, tags: &MediaTags) -> Result<MediaRecord> {
        let tags = tags.normalized();
        let changed = self.conn.execute(
            "UPDATE media SET title = coalesce(?2, title), artist = ?3, album = ?4, \
             album_artist = ?5, year = ?6, genre = ?7, track_no = ?8, disc_no = ?9, \
             comment = ?10, lyrics = ?11, tags_read = 1, modified_at = ?12 WHERE id = ?1",
            params![
                id,
                tags.title,
                tags.artist,
                tags.album,
                tags.album_artist,
                tags.year,
                tags.genre,
                tags.track_no,
                tags.disc_no,
                tags.comment,
                tags.lyrics,
                now_ms(),
            ],
        )?;
        crate::ensure_found(changed, &id.to_string())?;
        self.media(id)
    }

    /// Every tag of an entry, lyrics and comment included (editor).
    pub fn media_tags(&self, id: i64) -> Result<MediaTags> {
        self.conn
            .query_row(
                "SELECT title, artist, album, album_artist, year, genre, track_no, disc_no, \
                 comment, lyrics FROM media WHERE id = ?1",
                [id],
                |r| {
                    Ok(MediaTags {
                        title: r.get(0)?,
                        artist: r.get(1)?,
                        album: r.get(2)?,
                        album_artist: r.get(3)?,
                        year: r.get(4)?,
                        genre: r.get(5)?,
                        track_no: r.get(6)?,
                        disc_no: r.get(7)?,
                        comment: r.get(8)?,
                        lyrics: r.get(9)?,
                    })
                },
            )
            .optional()?
            .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    /// Albums, artists or folders of the present audio files.
    pub fn media_groups(&self, by: GroupBy) -> Result<Vec<MediaGroup>> {
        let sql = match by {
            GroupBy::Album => {
                "SELECT min(album), max(coalesce(album_artist, artist)), count(*), \
                 coalesce(sum(duration_secs), 0.0), max(year), max(thumbnail) FROM media \
                 WHERE kind = 'audio' AND missing = 0 AND album IS NOT NULL \
                 GROUP BY album COLLATE NOCASE ORDER BY album COLLATE NOCASE"
            }
            GroupBy::Artist => {
                "SELECT min(artist), CAST(count(DISTINCT album COLLATE NOCASE) AS TEXT), count(*), \
                 coalesce(sum(duration_secs), 0.0), max(year), max(thumbnail) FROM media \
                 WHERE kind = 'audio' AND missing = 0 AND artist IS NOT NULL \
                 GROUP BY artist COLLATE NOCASE ORDER BY artist COLLATE NOCASE"
            }
            GroupBy::Folder => return self.media_folders(),
        };
        let mut stmt = self.conn.prepare(sql)?;
        stmt.query_map([], |r| {
            Ok(MediaGroup {
                name: r.get(0)?,
                detail: r.get(1)?,
                count: r.get::<_, i64>(2)?.max(0) as u64,
                duration_secs: r.get(3)?,
                year: r.get(4)?,
                thumbnail: r.get(5)?,
            })
        })?
        .collect::<rusqlite::Result<_>>()
        .map_err(Into::into)
    }

    fn media_folders(&self) -> Result<Vec<MediaGroup>> {
        let mut stmt = self.conn.prepare(
            "SELECT path, coalesce(duration_secs, 0.0), thumbnail FROM media \
             WHERE kind = 'audio' AND missing = 0",
        )?;
        let rows = stmt.query_map([], |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, f64>(1)?,
                r.get::<_, Option<String>>(2)?,
            ))
        })?;
        let mut folders = std::collections::BTreeMap::<String, MediaGroup>::new();
        for row in rows {
            let (path, secs, thumbnail) = row?;
            let Some(parent) = parent_folder(&path) else {
                continue;
            };
            let group = folders.entry(parent.clone()).or_insert(MediaGroup {
                name: parent,
                detail: None,
                count: 0,
                duration_secs: 0.0,
                year: None,
                thumbnail: None,
            });
            group.count += 1;
            group.duration_secs += secs;
            if group.thumbnail.is_none() {
                group.thumbnail = thumbnail;
            }
        }
        Ok(folders.into_values().collect())
    }

    pub fn delete_media(&self, id: i64) -> Result<()> {
        let changed = self.conn.execute("DELETE FROM media WHERE id = ?1", [id])?;
        self.conn.execute(
            "DELETE FROM playback_state WHERE key = ?1",
            [crate::position_key(id)],
        )?;
        crate::ensure_found(changed, &id.to_string())
    }

    /// Removes an entry from the library and remembers its path so folder
    /// scans skip it; the file itself is not touched.
    pub fn remove_media(&self, id: i64) -> Result<()> {
        let tx = self.conn.unchecked_transaction()?;
        let path: Option<String> = tx
            .query_row("SELECT path FROM media WHERE id = ?1", [id], |r| r.get(0))
            .optional()?;
        let Some(path) = path else {
            return crate::ensure_found(0, &id.to_string());
        };
        tx.execute(
            "INSERT INTO media_removed (path, removed_at) VALUES (?1, ?2)              ON CONFLICT(path) DO UPDATE SET removed_at = excluded.removed_at",
            params![path, now_ms()],
        )?;
        tx.execute("DELETE FROM media WHERE id = ?1", [id])?;
        // Its resume position is meaningless now.
        tx.execute(
            "DELETE FROM playback_state WHERE key = ?1",
            [crate::position_key(id)],
        )?;
        tx.commit()?;
        Ok(())
    }

    /// The user opened this file again on purpose: scans no longer skip it.
    pub fn forget_removed(&self, path: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM media_removed WHERE path = ?1", [path])?;
        Ok(())
    }

    /// Paths removed from the library by the user (skipped by scans).
    pub fn removed_media_paths(&self) -> Result<std::collections::HashSet<String>> {
        let mut stmt = self.conn.prepare("SELECT path FROM media_removed")?;
        stmt.query_map([], |r| r.get(0))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
    }

    /// Every known path (for folder scans).
    pub fn media_paths(&self) -> Result<Vec<(i64, String, bool)>> {
        let mut stmt = self.conn.prepare("SELECT id, path, missing FROM media")?;
        stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
    }

    /// Entries whose file was not found at the last check (W-O2), by path.
    pub fn missing_media(&self) -> Result<Vec<MediaRecord>> {
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {COLUMNS} FROM media WHERE missing = 1 ORDER BY path"
        ))?;
        stmt.query_map([], row_to_media)?.map(|r| r?).collect()
    }

    pub fn missing_count(&self) -> Result<u64> {
        Ok(self.conn.query_row(
            "SELECT count(*) FROM media WHERE missing = 1",
            [],
            |r| r.get::<_, i64>(0),
        )? as u64)
    }

    /// Present files as (id, path, size): a missing entry whose name and
    /// size match one of them was probably moved.
    pub fn present_files(&self) -> Result<Vec<(i64, String, u64)>> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, path, size_bytes FROM media WHERE missing = 0")?;
        stmt.query_map([], |r| {
            Ok((r.get(0)?, r.get(1)?, r.get::<_, i64>(2)?.max(0) as u64))
        })?
        .collect::<rusqlite::Result<_>>()
        .map_err(Into::into)
    }

    /// Present entries with a known duration whose kind and title (ASCII
    /// case ignored) are shared with another one: possible duplicates,
    /// sorted out by the caller.
    pub fn duplicate_candidates(&self) -> Result<Vec<MediaRecord>> {
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {COLUMNS} FROM media \
             WHERE missing = 0 AND duration_secs IS NOT NULL \
             AND (kind, lower(trim(title))) IN ( \
               SELECT kind, lower(trim(title)) FROM media \
               WHERE missing = 0 AND duration_secs IS NOT NULL \
               GROUP BY 1, 2 HAVING count(*) > 1) \
             ORDER BY id"
        ))?;
        stmt.query_map([], row_to_media)?.map(|r| r?).collect()
    }

    /// Moves what the user attached to `from` (playlist entries, favorite)
    /// onto `to`, before `from` leaves the library.
    pub fn transfer_media_links(&self, from: i64, to: i64) -> Result<()> {
        self.conn.execute(
            "UPDATE playlist_items SET media_id = ?2 WHERE media_id = ?1",
            params![from, to],
        )?;
        self.conn.execute(
            "UPDATE media SET favorite = 1 WHERE id = ?2 \
             AND EXISTS (SELECT 1 FROM media WHERE id = ?1 AND favorite = 1)",
            params![from, to],
        )?;
        Ok(())
    }

    /// Thumbnail files referenced by the library.
    pub fn thumbnail_paths(&self) -> Result<Vec<String>> {
        let mut stmt = self
            .conn
            .prepare("SELECT thumbnail FROM media WHERE thumbnail IS NOT NULL")?;
        stmt.query_map([], |r| r.get(0))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
    }

    /// Forgets thumbnails (after the cache was cleared) so they are rebuilt.
    pub fn reset_thumbnails(&self) -> Result<usize> {
        Ok(self.conn.execute(
            "UPDATE media SET thumbnail = NULL, probed = 0 \
             WHERE thumbnail IS NOT NULL AND cover_custom = 0",
            [],
        )?)
    }
}

pub(crate) fn row_to_media(row: &Row<'_>) -> rusqlite::Result<Result<MediaRecord>> {
    let kind: String = row.get(3)?;
    let Some(kind) = MediaKind::parse(&kind) else {
        return Ok(Err(StorageError::Corrupted("media.kind")));
    };
    let opt_u32 = |i: usize| {
        row.get::<_, Option<i64>>(i)
            .map(|v| v.map(|v| v.max(0) as u32))
    };
    Ok(Ok(MediaRecord {
        id: row.get(0)?,
        path: row.get(1)?,
        title: row.get(2)?,
        kind,
        source_host: row.get(4)?,
        source_url: row.get(5)?,
        task_id: row.get(6)?,
        size_bytes: row.get::<_, i64>(7)?.max(0) as u64,
        duration_secs: row.get(8)?,
        width: opt_u32(9)?,
        height: opt_u32(10)?,
        video_codec: row.get(11)?,
        audio_codec: row.get(12)?,
        container: row.get(13)?,
        thumbnail: row.get(14)?,
        probed: row.get(15)?,
        missing: row.get(16)?,
        added_at: row.get(17)?,
        modified_at: row.get(18)?,
        artist: row.get(19)?,
        album: row.get(20)?,
        album_artist: row.get(21)?,
        year: row.get(22)?,
        genre: row.get(23)?,
        track_no: opt_u32(24)?,
        disc_no: opt_u32(25)?,
        favorite: row.get(26)?,
        cover_custom: row.get(27)?,
    }))
}

/// Folder part of a stored path, for both `\` and `/` separators (paths
/// may come from Windows or Android).
fn parent_folder(path: &str) -> Option<String> {
    let cut = path.rfind(['/', '\\'])?;
    (cut > 0).then(|| path[..cut].to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn new(path: &str, title: &str, kind: MediaKind, size: u64) -> NewMedia {
        NewMedia {
            path: path.into(),
            title: title.into(),
            kind,
            source_host: Some("blender.org".into()),
            source_url: None,
            task_id: None,
            size_bytes: size,
        }
    }

    fn library() -> Storage {
        let s = Storage::open_in_memory().unwrap();
        s.upsert_media(&new(
            "C:/V/tears.mp4",
            "Tears of Steel",
            MediaKind::Video,
            300,
        ))
        .unwrap();
        s.upsert_media(&new("C:/V/sintel.webm", "Sintel", MediaKind::Video, 600))
            .unwrap();
        s.upsert_media(&new(
            "C:/V/gymnopedie.flac",
            "Gymnopédie No. 1 — Satie",
            MediaKind::Audio,
            30,
        ))
        .unwrap();
        s
    }

    fn titles(page: &MediaPage) -> Vec<&str> {
        page.items.iter().map(|m| m.title.as_str()).collect()
    }

    #[test]
    fn latest_schema_is_applied() {
        assert_eq!(
            Storage::open_in_memory().unwrap().schema_version().unwrap(),
            9
        );
    }

    fn tags(artist: &str, album: &str, track: u32) -> MediaTags {
        MediaTags {
            artist: Some(artist.into()),
            album: Some(album.into()),
            track_no: Some(track),
            ..Default::default()
        }
    }

    #[test]
    fn tags_read_once_then_user_edits_win() {
        let s = Storage::open_in_memory().unwrap();
        let m = s
            .upsert_media(&new("C:/M/01 hira.mp3", "01 hira", MediaKind::Audio, 1))
            .unwrap();
        assert_eq!(s.media_to_tag(10).unwrap(), vec![(m.id, m.path.clone())]);
        let read = MediaTags {
            title: Some("  Hira vaovao ".into()),
            year: Some(0),
            ..tags("Ankorabe Sound", "Tany Maitso", 1)
        };
        s.set_media_tags_read(m.id, Some(&read)).unwrap();
        let r = s.media(m.id).unwrap();
        assert_eq!(r.title, "Hira vaovao");
        assert_eq!(r.artist.as_deref(), Some("Ankorabe Sound"));
        assert_eq!(r.year, None, "out of range year dropped");
        assert!(s.media_to_tag(10).unwrap().is_empty());

        // A second read never overrides the stored values.
        s.set_media_tags_read(m.id, Some(&tags("Other", "Other", 2)))
            .unwrap();
        assert_eq!(s.media(m.id).unwrap().album.as_deref(), Some("Tany Maitso"));

        let edited = s
            .update_media_tags(
                m.id,
                &MediaTags {
                    title: Some(String::new()),
                    lyrics: Some("Tononkira".into()),
                    ..tags("Ankorabe", "Live", 3)
                },
            )
            .unwrap();
        assert_eq!(edited.title, "Hira vaovao", "empty title keeps the old one");
        assert_eq!(edited.track_no, Some(3));
        assert_eq!(
            s.media_tags(m.id).unwrap().lyrics.as_deref(),
            Some("Tononkira")
        );
    }

    #[test]
    fn albums_artists_and_folders_group_audio_only() {
        let s = Storage::open_in_memory().unwrap();
        for (path, artist, album, track) in [
            ("C:\\Music\\A\\1.mp3", "Tsiory", "Andro vaovao", 2),
            ("C:\\Music\\A\\2.mp3", "Tsiory", "andro VAOVAO", 1),
            ("C:\\Music\\B\\3.flac", "Voahangy R.", "Lalana", 1),
        ] {
            let m = s
                .upsert_media(&new(path, path, MediaKind::Audio, 1))
                .unwrap();
            s.set_media_tags_read(m.id, Some(&tags(artist, album, track)))
                .unwrap();
        }
        s.upsert_media(&new("C:\\Videos\\v.mp4", "v", MediaKind::Video, 1))
            .unwrap();

        let albums = s.media_groups(GroupBy::Album).unwrap();
        assert_eq!(
            albums
                .iter()
                .map(|g| (g.name.as_str(), g.count))
                .collect::<Vec<_>>(),
            [("Andro vaovao", 2), ("Lalana", 1)]
        );
        assert_eq!(albums[0].detail.as_deref(), Some("Tsiory"));
        let artists = s.media_groups(GroupBy::Artist).unwrap();
        assert_eq!(artists[0].detail.as_deref(), Some("1"), "one album");
        let folders = s.media_groups(GroupBy::Folder).unwrap();
        assert_eq!(
            folders.iter().map(|g| g.name.as_str()).collect::<Vec<_>>(),
            ["C:\\Music\\A", "C:\\Music\\B"]
        );

        let album = s
            .query_media(&MediaQuery {
                album: Some("ANDRO VAOVAO".into()),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(
            album.items.iter().map(|m| m.track_no).collect::<Vec<_>>(),
            [Some(1), Some(2)],
            "track order"
        );
        let folder = s
            .query_media(&MediaQuery {
                folder: Some("C:\\Music\\B".into()),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(folder.total, 1);
        let by_artist = s
            .query_media(&MediaQuery {
                search: "voahangy".into(),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(by_artist.total, 1, "search covers artists");
    }

    #[test]
    fn folder_filter_escapes_like_wildcards() {
        let s = Storage::open_in_memory().unwrap();
        s.upsert_media(&new("C:/M/a_b/1.mp3", "1", MediaKind::Audio, 1))
            .unwrap();
        s.upsert_media(&new("C:/M/axb/2.mp3", "2", MediaKind::Audio, 1))
            .unwrap();
        let page = s
            .query_media(&MediaQuery {
                folder: Some("C:/M/a_b".into()),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(page.total, 1);
    }

    #[test]
    fn upsert_is_idempotent_per_path() {
        let s = library();
        let again = s
            .upsert_media(&new("C:/V/tears.mp4", "ignored", MediaKind::Video, 999))
            .unwrap();
        assert_eq!(again.title, "Tears of Steel", "title kept");
        assert_eq!(again.size_bytes, 999);
        assert_eq!(s.query_media(&MediaQuery::default()).unwrap().total, 3);
    }

    #[test]
    fn full_text_search_with_prefixes_and_diacritics() {
        let s = library();
        let q = |text: &str| MediaQuery {
            search: text.into(),
            ..Default::default()
        };
        assert_eq!(
            titles(&s.query_media(&q("tear")).unwrap()),
            ["Tears of Steel"]
        );
        assert_eq!(
            titles(&s.query_media(&q("gymnopedie")).unwrap()),
            ["Gymnopédie No. 1 — Satie"]
        );
        assert_eq!(
            s.query_media(&q("blender")).unwrap().total,
            3,
            "source host is indexed"
        );
        assert_eq!(
            s.query_media(&q("steel sintel")).unwrap().total,
            0,
            "terms are AND-ed"
        );
        // FTS syntax typed by the user is searched as plain words, never
        // interpreted (no error, no "OR", no column filter).
        assert_eq!(s.query_media(&q("\" OR * NEAR(")).unwrap().total, 0);
        assert_eq!(s.query_media(&q("tears\" OR title:x")).unwrap().total, 0);
        assert_eq!(s.query_media(&q("steel\"")).unwrap().total, 1);
    }

    #[test]
    fn filters_sorting_and_paging() {
        let s = library();
        let audio = s
            .query_media(&MediaQuery {
                kind: Some(MediaKind::Audio),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(audio.total, 1);
        let by_size = s
            .query_media(&MediaQuery {
                sort: MediaSort::Size,
                ..Default::default()
            })
            .unwrap();
        assert_eq!(titles(&by_size)[0], "Sintel");
        let by_title = s
            .query_media(&MediaQuery {
                sort: MediaSort::Title,
                limit: 2,
                offset: 1,
                ..Default::default()
            })
            .unwrap();
        assert_eq!(titles(&by_title), ["Sintel", "Tears of Steel"]);
        assert_eq!(by_title.total, 3);
    }

    #[test]
    fn probe_results_update_kind_and_metadata() {
        let s = library();
        let id = s.media_by_path("C:/V/sintel.webm").unwrap().unwrap().id;
        assert_eq!(s.media_to_probe(10).unwrap().len(), 3);
        let probe = MediaProbe {
            duration_secs: Some(888.0),
            has_video: false,
            audio_codec: Some("opus".into()),
            ..Default::default()
        };
        s.set_media_probe(id, &probe, Some("thumbs/2.jpg")).unwrap();
        let m = s.media(id).unwrap();
        assert_eq!(m.kind, MediaKind::Audio, "no video stream found");
        assert_eq!(
            (m.duration_secs, m.thumbnail.as_deref(), m.probed),
            (Some(888.0), Some("thumbs/2.jpg"), true)
        );
        assert_eq!(s.media_to_probe(10).unwrap().len(), 2);
        assert_eq!(s.reset_thumbnails().unwrap(), 1);
        assert_eq!(s.media_to_probe(10).unwrap().len(), 3);
    }

    #[test]
    fn chosen_covers_survive_probes_and_cache_reset() {
        let s = library();
        let id = s.media_by_path("C:/V/sintel.webm").unwrap().unwrap().id;
        s.set_media_cover(id, Some("covers/1.jpg")).unwrap();
        let probe = MediaProbe {
            has_video: true,
            ..Default::default()
        };
        s.set_media_probe(id, &probe, Some("thumbs/new.jpg"))
            .unwrap();
        let m = s.media(id).unwrap();
        assert_eq!(
            (m.thumbnail.as_deref(), m.cover_custom),
            (Some("covers/1.jpg"), true)
        );
        assert_eq!(
            s.reset_thumbnails().unwrap(),
            0,
            "chosen covers are not cache"
        );
        assert_eq!(
            s.media(id).unwrap().thumbnail.as_deref(),
            Some("covers/1.jpg")
        );

        // Removed on purpose: the library does not put a frame back.
        s.set_media_cover(id, None).unwrap();
        s.set_media_probe(id, &probe, Some("thumbs/new.jpg"))
            .unwrap();
        let m = s.media(id).unwrap();
        assert_eq!((m.thumbnail, m.cover_custom), (None, true));
        assert!(matches!(
            s.set_media_cover(9999, None),
            Err(StorageError::NotFound(_))
        ));
    }

    #[test]
    fn missing_files_leave_results_and_stats() {
        let s = library();
        let id = s.media_by_path("C:/V/tears.mp4").unwrap().unwrap().id;
        s.set_media_missing(id, true).unwrap();
        assert_eq!(s.query_media(&MediaQuery::default()).unwrap().total, 2);
        let stats = s.media_stats().unwrap();
        assert_eq!((stats.count, stats.total_bytes), (2, 630));
        assert_eq!(
            (stats.video_count, stats.audio_count, stats.audio_bytes),
            (1, 1, 30)
        );
    }

    #[test]
    fn rename_and_delete_keep_search_in_sync() {
        let s = library();
        let id = s.media_by_path("C:/V/tears.mp4").unwrap().unwrap().id;
        s.rename_media(id, "C:/V/steel.mp4", "Steel Story").unwrap();
        let q = |text: &str| MediaQuery {
            search: text.into(),
            ..Default::default()
        };
        assert_eq!(s.query_media(&q("tears")).unwrap().total, 0);
        assert_eq!(s.query_media(&q("story")).unwrap().total, 1);
        s.delete_media(id).unwrap();
        assert_eq!(s.query_media(&q("story")).unwrap().total, 0);
        assert!(matches!(s.media(id), Err(StorageError::NotFound(_))));
    }

    #[test]
    fn fts_query_building() {
        assert_eq!(fts_query("Tears of"), Some("\"Tears\"* \"of\"*".into()));
        assert_eq!(fts_query("  --  "), None);
        assert_eq!(
            fts_query("a b c d e f g h i j")
                .unwrap()
                .matches('*')
                .count(),
            MAX_SEARCH_TOKENS
        );
    }

    #[test]
    fn a_large_library_stays_fast() {
        let s = Storage::open_in_memory().unwrap();
        s.conn.execute_batch("BEGIN").unwrap();
        for i in 0..5_000 {
            s.upsert_media(&new(
                &format!("C:/V/{i}.mp4"),
                &format!("Clip number {i} sunset"),
                MediaKind::Video,
                i,
            ))
            .unwrap();
        }
        s.conn.execute_batch("COMMIT").unwrap();
        let started = std::time::Instant::now();
        let page = s
            .query_media(&MediaQuery {
                search: "number 42".into(),
                ..Default::default()
            })
            .unwrap();
        let elapsed = started.elapsed();
        assert!(page.total >= 1);
        // Generous bound (debug build); real figures go to docs/performance.md.
        assert!(elapsed.as_millis() < 500, "search took {elapsed:?}");
    }
}

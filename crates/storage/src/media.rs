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

const COLUMNS: &str = "id, path, title, kind, source_host, source_url, task_id, size_bytes, \
     duration_secs, width, height, video_codec, audio_codec, container, thumbnail, probed, \
     missing, added_at, modified_at";

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
    pub fn upsert_media(&self, media: &NewMedia) -> Result<MediaRecord> {
        let now = now_ms();
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
        let filter = conditions.join(" AND ");
        let order = match query.sort {
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
             audio_codec = ?6, container = ?7, kind = ?8, thumbnail = coalesce(?9, thumbnail), \
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

    pub fn delete_media(&self, id: i64) -> Result<()> {
        let changed = self.conn.execute("DELETE FROM media WHERE id = ?1", [id])?;
        crate::ensure_found(changed, &id.to_string())
    }

    /// Every known path (for folder scans).
    pub fn media_paths(&self) -> Result<Vec<(i64, String, bool)>> {
        let mut stmt = self.conn.prepare("SELECT id, path, missing FROM media")?;
        stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
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
            "UPDATE media SET thumbnail = NULL, probed = 0 WHERE thumbnail IS NOT NULL",
            [],
        )?)
    }
}

fn row_to_media(row: &Row<'_>) -> rusqlite::Result<Result<MediaRecord>> {
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
    }))
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
            3
        );
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

//! Durable playback state (CDC L02, COM-03/04/13): queues, resume positions
//! and play history, kept as small JSON values under fixed keys. The
//! interface keeps a synchronous copy in WebView storage; this table is
//! the copy that survives a lost or damaged WebView profile.

use rusqlite::{OptionalExtension, params};

use crate::{Result, Storage, StorageError, now_ms};

/// Set once the WebView's older local copy has been imported.
pub const PLAYBACK_IMPORTED: &str = "meta:imported";
/// Largest accepted value (a queue is bounded to 500 small records).
pub const PLAYBACK_VALUE_MAX: usize = 1024 * 1024;
/// Rows kept at most (one per resume position plus a few fixed keys).
pub const PLAYBACK_ROWS_MAX: usize = 50_000;

const FIXED_KEYS: &[&str] = &[
    "mm:player:v1",
    "mm:mobile:session:v1",
    "mm:playHistory:v1",
    "mm:lang",
    "mm:theme",
    "mm:resume",
    "mm:mobile:rate",
    "mm:eq:v1",
    "mm:gestures",
    PLAYBACK_IMPORTED,
];

/// Only known keys are stored: `mm:position:<library id>` and fixed keys.
pub fn is_playback_key(key: &str) -> bool {
    FIXED_KEYS.contains(&key)
        || key.strip_prefix("mm:position:").is_some_and(|id| {
            !id.is_empty() && id.len() <= 19 && id.bytes().all(|b| b.is_ascii_digit())
        })
}

/// Key of a media's resume position.
pub fn position_key(media_id: i64) -> String {
    format!("mm:position:{media_id}")
}

impl Storage {
    /// Every stored playback value.
    pub fn playback_entries(&self) -> Result<Vec<(String, String)>> {
        let mut stmt = self
            .conn
            .prepare("SELECT key, value FROM playback_state ORDER BY key")?;
        stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<_>>()
            .map_err(Into::into)
    }

    pub fn playback_value(&self, key: &str) -> Result<Option<String>> {
        Ok(self
            .conn
            .query_row(
                "SELECT value FROM playback_state WHERE key = ?1",
                [key],
                |r| r.get(0),
            )
            .optional()?)
    }

    /// Applies writes (`Some`) and removals (`None`) in one transaction;
    /// nothing is written if one change is refused.
    pub fn write_playback(&self, changes: &[(String, Option<String>)]) -> Result<()> {
        for (key, value) in changes {
            if !is_playback_key(key) {
                return Err(StorageError::Invalid(format!(
                    "unknown playback key: {key}"
                )));
            }
            if value.as_ref().is_some_and(|v| v.len() > PLAYBACK_VALUE_MAX) {
                return Err(StorageError::Invalid(format!(
                    "playback value too large: {key}"
                )));
            }
        }
        let tx = self.conn.unchecked_transaction()?;
        let now = now_ms();
        for (key, value) in changes {
            match value {
                Some(value) => {
                    tx.execute(
                        "INSERT INTO playback_state (key, value, updated_at) VALUES (?1, ?2, ?3) \
                         ON CONFLICT(key) DO UPDATE SET value = excluded.value, \
                         updated_at = excluded.updated_at",
                        params![key, value, now],
                    )?;
                }
                None => {
                    tx.execute("DELETE FROM playback_state WHERE key = ?1", [key])?;
                }
            }
        }
        let rows: i64 = tx.query_row("SELECT count(*) FROM playback_state", [], |r| r.get(0))?;
        if rows as usize > PLAYBACK_ROWS_MAX {
            // Dropped without committing: the earlier state stays intact.
            return Err(StorageError::Invalid("too many playback entries".into()));
        }
        tx.commit()?;
        Ok(())
    }
}

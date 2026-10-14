//! SQLite persistence for Miarina Media.
//!
//! Only metadata lives here: media bytes always stay on disk. Every state
//! change is validated by [`media_core::TaskState`] before it is written.

mod migrations;

use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use media_core::{TaskState, TransitionError};
use rusqlite::{Connection, OptionalExtension, Row, params};
use serde::{Serialize, de::DeserializeOwned};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StorageError {
    #[error("database error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("migration error: {0}")]
    Migration(#[from] rusqlite_migration::Error),
    #[error("task {0} not found")]
    NotFound(String),
    #[error(transparent)]
    Transition(#[from] TransitionError),
    #[error("corrupted value in column {0}")]
    Corrupted(&'static str),
    #[error("invalid settings value: {0}")]
    Settings(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, StorageError>;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum MediaKind {
    Video,
    Audio,
}

impl MediaKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::Video => "video",
            Self::Audio => "audio",
        }
    }

    fn parse(value: &str) -> Option<Self> {
        match value {
            "video" => Some(Self::Video),
            "audio" => Some(Self::Audio),
            _ => None,
        }
    }
}

/// Values required to create a task.
#[derive(Debug, Clone)]
pub struct NewTask {
    pub id: String,
    pub url: String,
    pub source_host: String,
    pub title: String,
    pub kind: MediaKind,
    pub engine: String,
    pub format_id: Option<String>,
    pub format_label: String,
    pub dest_dir: String,
    pub file_name: String,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskRecord {
    pub id: String,
    pub url: String,
    pub source_host: String,
    pub title: String,
    pub kind: MediaKind,
    pub engine: String,
    pub format_id: Option<String>,
    pub format_label: String,
    pub state: TaskState,
    pub position: i64,
    pub dest_dir: String,
    pub file_name: String,
    pub part_path: Option<String>,
    pub final_path: Option<String>,
    pub total_bytes: Option<u64>,
    pub downloaded_bytes: u64,
    pub supports_resume: bool,
    pub attempts: u32,
    pub error_code: Option<String>,
    pub error_message: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
    pub completed_at: Option<i64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HistoryStatus {
    Completed,
    Failed,
    Canceled,
}

impl HistoryStatus {
    fn as_str(self) -> &'static str {
        match self {
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Canceled => "canceled",
        }
    }

    fn parse(value: &str) -> Option<Self> {
        match value {
            "completed" => Some(Self::Completed),
            "failed" => Some(Self::Failed),
            "canceled" => Some(Self::Canceled),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryEntry {
    pub id: i64,
    pub task_id: String,
    pub url: String,
    pub title: String,
    pub source_host: String,
    pub format_label: String,
    pub total_bytes: Option<u64>,
    pub done_bytes: u64,
    pub status: HistoryStatus,
    pub reason: Option<String>,
    pub final_path: Option<String>,
    pub finished_at: i64,
}

/// Maximum number of history rows returned in one page.
pub const HISTORY_PAGE_MAX: u32 = 500;

pub struct Storage {
    conn: Connection,
}

pub fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or_default()
}

const TASK_COLUMNS: &str = "id, url, source_host, title, kind, engine, format_id, format_label, \
     state, position, dest_dir, file_name, part_path, final_path, total_bytes, downloaded_bytes, \
     supports_resume, attempts, error_code, error_message, created_at, updated_at, completed_at";

impl Storage {
    pub fn open(path: &Path) -> Result<Self> {
        Self::init(Connection::open(path)?)
    }

    pub fn open_in_memory() -> Result<Self> {
        Self::init(Connection::open_in_memory()?)
    }

    fn init(mut conn: Connection) -> Result<Self> {
        // WAL keeps readers non-blocking; NORMAL sync is safe with WAL and
        // avoids an fsync per progress checkpoint.
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.busy_timeout(std::time::Duration::from_secs(5))?;
        migrations::migrations().to_latest(&mut conn)?;
        Ok(Self { conn })
    }

    /// Current schema version (number of applied migrations).
    pub fn schema_version(&self) -> Result<i64> {
        Ok(self
            .conn
            .pragma_query_value(None, "user_version", |r| r.get(0))?)
    }

    // ---------------------------------------------------------------- tasks

    pub fn insert_task(&self, task: &NewTask) -> Result<TaskRecord> {
        let now = now_ms();
        let position: i64 = self.conn.query_row(
            "SELECT COALESCE(MAX(position), 0) + 1 FROM tasks",
            [],
            |r| r.get(0),
        )?;
        self.conn.execute(
            "INSERT INTO tasks (id, url, source_host, title, kind, engine, format_id, format_label, \
             state, position, dest_dir, file_name, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?13)",
            params![
                task.id,
                task.url,
                task.source_host,
                task.title,
                task.kind.as_str(),
                task.engine,
                task.format_id,
                task.format_label,
                TaskState::Queued.as_str(),
                position,
                task.dest_dir,
                task.file_name,
                now,
            ],
        )?;
        self.task(&task.id)
    }

    pub fn task(&self, id: &str) -> Result<TaskRecord> {
        self.conn
            .query_row(
                &format!("SELECT {TASK_COLUMNS} FROM tasks WHERE id = ?1"),
                [id],
                row_to_task,
            )
            .optional()?
            .ok_or_else(|| StorageError::NotFound(id.to_owned()))?
    }

    /// Tasks that are not terminal, in queue order.
    pub fn open_tasks(&self) -> Result<Vec<TaskRecord>> {
        self.tasks_where("state NOT IN ('completed', 'canceled') ORDER BY position")
    }

    /// Next tasks ready for a download slot, in queue order.
    pub fn waiting_tasks(&self, limit: u32) -> Result<Vec<TaskRecord>> {
        self.tasks_where(&format!(
            "state IN ('queued', 'waiting') ORDER BY position LIMIT {limit}"
        ))
    }

    fn tasks_where(&self, clause: &str) -> Result<Vec<TaskRecord>> {
        let mut stmt = self
            .conn
            .prepare(&format!("SELECT {TASK_COLUMNS} FROM tasks WHERE {clause}"))?;
        let rows = stmt.query_map([], row_to_task)?;
        rows.map(|r| r?).collect()
    }

    /// Applies a validated state transition and returns the updated task.
    pub fn transition(&self, id: &str, to: TaskState) -> Result<TaskRecord> {
        let current = self.task(id)?;
        current.state.transition(to)?;
        let now = now_ms();
        let completed_at = (to == TaskState::Completed).then_some(now);
        self.conn.execute(
            "UPDATE tasks SET state = ?2, updated_at = ?3, completed_at = COALESCE(?4, completed_at) \
             WHERE id = ?1",
            params![id, to.as_str(), now, completed_at],
        )?;
        self.task(id)
    }

    /// Progress checkpoint. Callers throttle it (it is not written per chunk).
    pub fn record_progress(&self, id: &str, downloaded: u64, total: Option<u64>) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE tasks SET downloaded_bytes = ?2, total_bytes = COALESCE(?3, total_bytes), \
             updated_at = ?4 WHERE id = ?1",
            params![id, downloaded as i64, total.map(|t| t as i64), now_ms()],
        )?;
        ensure_found(changed, id)
    }

    pub fn set_paths(
        &self,
        id: &str,
        part_path: Option<&str>,
        final_path: Option<&str>,
    ) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE tasks SET part_path = ?2, final_path = ?3, updated_at = ?4 WHERE id = ?1",
            params![id, part_path, final_path, now_ms()],
        )?;
        ensure_found(changed, id)
    }

    pub fn set_resume_support(&self, id: &str, supported: bool) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE tasks SET supports_resume = ?2 WHERE id = ?1",
            params![id, supported],
        )?;
        ensure_found(changed, id)
    }

    pub fn set_error(&self, id: &str, code: Option<&str>, message: Option<&str>) -> Result<()> {
        let changed = self.conn.execute(
            "UPDATE tasks SET error_code = ?2, error_message = ?3, updated_at = ?4 WHERE id = ?1",
            params![id, code, message, now_ms()],
        )?;
        ensure_found(changed, id)
    }

    pub fn increment_attempts(&self, id: &str) -> Result<u32> {
        self.conn.execute(
            "UPDATE tasks SET attempts = attempts + 1 WHERE id = ?1",
            [id],
        )?;
        Ok(self.task(id)?.attempts)
    }

    pub fn reset_attempts(&self, id: &str) -> Result<()> {
        let changed = self
            .conn
            .execute("UPDATE tasks SET attempts = 0 WHERE id = ?1", [id])?;
        ensure_found(changed, id)
    }

    /// Moves a task to `index` among open tasks (0 = first), renumbering
    /// positions in a single transaction.
    pub fn move_task(&mut self, id: &str, index: usize) -> Result<()> {
        let mut ids: Vec<String> = self.open_tasks()?.into_iter().map(|t| t.id).collect();
        let from = ids
            .iter()
            .position(|t| t == id)
            .ok_or_else(|| StorageError::NotFound(id.to_owned()))?;
        let moved = ids.remove(from);
        ids.insert(index.min(ids.len()), moved);
        let tx = self.conn.transaction()?;
        for (i, task_id) in ids.iter().enumerate() {
            tx.execute(
                "UPDATE tasks SET position = ?2 WHERE id = ?1",
                params![task_id, i as i64 + 1],
            )?;
        }
        tx.commit()?;
        Ok(())
    }

    pub fn delete_task(&self, id: &str) -> Result<()> {
        let changed = self.conn.execute("DELETE FROM tasks WHERE id = ?1", [id])?;
        ensure_found(changed, id)
    }

    /// Puts tasks interrupted by a crash or forced shutdown back into a safe
    /// state (see [`TaskState::recover_after_restart`]). This is the only
    /// write that bypasses the transition table, by design. Returns the
    /// number of tasks changed.
    pub fn recover_after_restart(&mut self) -> Result<usize> {
        let interrupted =
            self.tasks_where("state IN ('analyzing', 'downloading', 'processing')")?;
        let tx = self.conn.transaction()?;
        for task in &interrupted {
            let next = task.state.recover_after_restart(task.supports_resume);
            // Non-resumable partial data is useless: restart from zero.
            let downloaded = if task.supports_resume {
                task.downloaded_bytes as i64
            } else {
                0
            };
            tx.execute(
                "UPDATE tasks SET state = ?2, downloaded_bytes = ?3, updated_at = ?4 WHERE id = ?1",
                params![task.id, next.as_str(), downloaded, now_ms()],
            )?;
        }
        tx.commit()?;
        Ok(interrupted.len())
    }

    // -------------------------------------------------------------- history

    pub fn append_history(
        &self,
        task: &TaskRecord,
        status: HistoryStatus,
        reason: Option<&str>,
    ) -> Result<HistoryEntry> {
        self.conn.execute(
            "INSERT INTO history (task_id, title, source_host, format_label, total_bytes, \
             done_bytes, status, reason, final_path, finished_at, url) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
            params![
                task.id,
                task.title,
                task.source_host,
                task.format_label,
                task.total_bytes.map(|b| b as i64),
                task.downloaded_bytes as i64,
                status.as_str(),
                reason,
                task.final_path,
                now_ms(),
                task.url,
            ],
        )?;
        let id = self.conn.last_insert_rowid();
        self.conn.query_row(
            "SELECT id, task_id, title, source_host, format_label, total_bytes, done_bytes, status, \
             reason, final_path, finished_at, url FROM history WHERE id = ?1",
            [id],
            row_to_history,
        )?
    }

    /// Most recent first.
    pub fn history(&self, limit: u32) -> Result<Vec<HistoryEntry>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, task_id, title, source_host, format_label, total_bytes, done_bytes, status, \
             reason, final_path, finished_at, url FROM history ORDER BY finished_at DESC, id DESC LIMIT ?1",
        )?;
        let rows = stmt.query_map([limit.min(HISTORY_PAGE_MAX)], row_to_history)?;
        rows.map(|r| r?).collect()
    }

    /// Removes the list of past downloads; files on disk are untouched.
    pub fn clear_history(&self) -> Result<usize> {
        Ok(self.conn.execute("DELETE FROM history", [])?)
    }

    // ------------------------------------------------------------- settings

    pub fn setting<T: DeserializeOwned>(&self, key: &str) -> Result<Option<T>> {
        let raw: Option<String> = self
            .conn
            .query_row("SELECT value FROM settings WHERE key = ?1", [key], |r| {
                r.get(0)
            })
            .optional()?;
        raw.map(|v| serde_json::from_str(&v).map_err(StorageError::from))
            .transpose()
    }

    pub fn set_setting<T: Serialize>(&self, key: &str, value: &T) -> Result<()> {
        self.conn.execute(
            "INSERT INTO settings (key, value) VALUES (?1, ?2) \
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            params![key, serde_json::to_string(value)?],
        )?;
        Ok(())
    }
}

fn ensure_found(changed: usize, id: &str) -> Result<()> {
    if changed == 0 {
        Err(StorageError::NotFound(id.to_owned()))
    } else {
        Ok(())
    }
}

fn opt_u64(value: Option<i64>) -> Option<u64> {
    value.map(|v| v.max(0) as u64)
}

fn row_to_task(row: &Row<'_>) -> rusqlite::Result<Result<TaskRecord>> {
    let kind: String = row.get(4)?;
    let state: String = row.get(8)?;
    let Some(kind) = MediaKind::parse(&kind) else {
        return Ok(Err(StorageError::Corrupted("tasks.kind")));
    };
    let Some(state) = TaskState::parse(&state) else {
        return Ok(Err(StorageError::Corrupted("tasks.state")));
    };
    Ok(Ok(TaskRecord {
        id: row.get(0)?,
        url: row.get(1)?,
        source_host: row.get(2)?,
        title: row.get(3)?,
        kind,
        engine: row.get(5)?,
        format_id: row.get(6)?,
        format_label: row.get(7)?,
        state,
        position: row.get(9)?,
        dest_dir: row.get(10)?,
        file_name: row.get(11)?,
        part_path: row.get(12)?,
        final_path: row.get(13)?,
        total_bytes: opt_u64(row.get(14)?),
        downloaded_bytes: row.get::<_, i64>(15)?.max(0) as u64,
        supports_resume: row.get(16)?,
        attempts: row.get::<_, i64>(17)?.max(0) as u32,
        error_code: row.get(18)?,
        error_message: row.get(19)?,
        created_at: row.get(20)?,
        updated_at: row.get(21)?,
        completed_at: row.get(22)?,
    }))
}

fn row_to_history(row: &Row<'_>) -> rusqlite::Result<Result<HistoryEntry>> {
    let status: String = row.get(7)?;
    let Some(status) = HistoryStatus::parse(&status) else {
        return Ok(Err(StorageError::Corrupted("history.status")));
    };
    Ok(Ok(HistoryEntry {
        id: row.get(0)?,
        task_id: row.get(1)?,
        title: row.get(2)?,
        source_host: row.get(3)?,
        format_label: row.get(4)?,
        total_bytes: opt_u64(row.get(5)?),
        done_bytes: row.get::<_, i64>(6)?.max(0) as u64,
        status,
        reason: row.get(8)?,
        final_path: row.get(9)?,
        finished_at: row.get(10)?,
        url: row.get(11)?,
    }))
}

#[cfg(test)]
mod tests;

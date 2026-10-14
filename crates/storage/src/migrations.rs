//! Versioned schema. Migrations are append-only: never edit a shipped one.

use rusqlite_migration::{M, Migrations};

pub fn migrations() -> Migrations<'static> {
    Migrations::new(vec![M::up(
        r#"
        CREATE TABLE tasks (
            id               TEXT PRIMARY KEY,
            url              TEXT NOT NULL,
            source_host      TEXT NOT NULL,
            title            TEXT NOT NULL,
            kind             TEXT NOT NULL CHECK (kind IN ('video', 'audio')),
            engine           TEXT NOT NULL,
            format_id        TEXT,
            format_label     TEXT NOT NULL,
            state            TEXT NOT NULL,
            position         INTEGER NOT NULL,
            dest_dir         TEXT NOT NULL,
            file_name        TEXT NOT NULL,
            part_path        TEXT,
            final_path       TEXT,
            total_bytes      INTEGER,
            downloaded_bytes INTEGER NOT NULL DEFAULT 0,
            supports_resume  INTEGER NOT NULL DEFAULT 0,
            attempts         INTEGER NOT NULL DEFAULT 0,
            error_code       TEXT,
            error_message    TEXT,
            created_at       INTEGER NOT NULL,
            updated_at       INTEGER NOT NULL,
            completed_at     INTEGER
        );
        CREATE INDEX tasks_state_position ON tasks (state, position);

        CREATE TABLE history (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id      TEXT NOT NULL,
            title        TEXT NOT NULL,
            source_host  TEXT NOT NULL,
            format_label TEXT NOT NULL,
            total_bytes  INTEGER,
            done_bytes   INTEGER NOT NULL DEFAULT 0,
            status       TEXT NOT NULL CHECK (status IN ('completed', 'failed', 'canceled')),
            reason       TEXT,
            final_path   TEXT,
            finished_at  INTEGER NOT NULL,
            url          TEXT NOT NULL
        );
        CREATE INDEX history_finished_at ON history (finished_at DESC);

        CREATE TABLE settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        "#,
    )])
}

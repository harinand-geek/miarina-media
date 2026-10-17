//! Versioned schema. Migrations are append-only: never edit a shipped one.

use rusqlite_migration::{M, Migrations};

pub fn migrations() -> Migrations<'static> {
    Migrations::new(vec![
        // v1 — tasks, history, settings (Phase 2).
        M::up(
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
        ),
        // v2 — media library (Phase 3). Only metadata: files stay on disk.
        M::up(
            r#"
        CREATE TABLE media (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            path          TEXT NOT NULL UNIQUE,
            title         TEXT NOT NULL,
            kind          TEXT NOT NULL CHECK (kind IN ('video', 'audio')),
            source_host   TEXT,
            source_url    TEXT,
            task_id       TEXT,
            size_bytes    INTEGER NOT NULL DEFAULT 0,
            duration_secs REAL,
            width         INTEGER,
            height        INTEGER,
            video_codec   TEXT,
            audio_codec   TEXT,
            container     TEXT,
            thumbnail     TEXT,
            probed        INTEGER NOT NULL DEFAULT 0,
            missing       INTEGER NOT NULL DEFAULT 0,
            added_at      INTEGER NOT NULL,
            modified_at   INTEGER NOT NULL
        );
        CREATE INDEX media_added ON media (added_at DESC);
        CREATE INDEX media_probe ON media (probed, missing);

        -- Full-text search on titles and sources, kept in sync by triggers.
        CREATE VIRTUAL TABLE media_fts USING fts5(
            title, source_host, content='media', content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );
        CREATE TRIGGER media_ai AFTER INSERT ON media BEGIN
            INSERT INTO media_fts(rowid, title, source_host)
            VALUES (new.id, new.title, coalesce(new.source_host, ''));
        END;
        CREATE TRIGGER media_ad AFTER DELETE ON media BEGIN
            INSERT INTO media_fts(media_fts, rowid, title, source_host)
            VALUES ('delete', old.id, old.title, coalesce(old.source_host, ''));
        END;
        CREATE TRIGGER media_au AFTER UPDATE OF title, source_host ON media BEGIN
            INSERT INTO media_fts(media_fts, rowid, title, source_host)
            VALUES ('delete', old.id, old.title, coalesce(old.source_host, ''));
            INSERT INTO media_fts(rowid, title, source_host)
            VALUES (new.id, new.title, coalesce(new.source_host, ''));
        END;
        "#,
        ),
        // v3 — picture shown while a task downloads: the source's thumbnail,
        // cached locally at analysis time (path inside the thumbnail folder).
        M::up("ALTER TABLE tasks ADD COLUMN thumbnail TEXT;"),
    ])
}

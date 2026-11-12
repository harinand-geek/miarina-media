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
        // v4 — files removed from the library but kept on disk (COM-10):
        // folder scans must not add them back.
        M::up(
            r#"
        CREATE TABLE media_removed (
            path       TEXT PRIMARY KEY,
            removed_at INTEGER NOT NULL
        );
        "#,
        ),
        // v5 — music tags (L06, COM-07): read from files, editable; search
        // also covers artist and album.
        M::up(
            r#"
        ALTER TABLE media ADD COLUMN artist TEXT;
        ALTER TABLE media ADD COLUMN album TEXT;
        ALTER TABLE media ADD COLUMN album_artist TEXT;
        ALTER TABLE media ADD COLUMN year INTEGER;
        ALTER TABLE media ADD COLUMN genre TEXT;
        ALTER TABLE media ADD COLUMN track_no INTEGER;
        ALTER TABLE media ADD COLUMN disc_no INTEGER;
        ALTER TABLE media ADD COLUMN comment TEXT;
        ALTER TABLE media ADD COLUMN lyrics TEXT;
        ALTER TABLE media ADD COLUMN tags_read INTEGER NOT NULL DEFAULT 0;
        CREATE INDEX media_tags_pending ON media (tags_read, missing);
        CREATE INDEX media_album ON media (album COLLATE NOCASE) WHERE album IS NOT NULL;
        CREATE INDEX media_artist ON media (artist COLLATE NOCASE) WHERE artist IS NOT NULL;

        DROP TRIGGER media_ai;
        DROP TRIGGER media_ad;
        DROP TRIGGER media_au;
        DROP TABLE media_fts;
        CREATE VIRTUAL TABLE media_fts USING fts5(
            title, source_host, artist, album, content='media', content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );
        CREATE TRIGGER media_ai AFTER INSERT ON media BEGIN
            INSERT INTO media_fts(rowid, title, source_host, artist, album)
            VALUES (new.id, new.title, coalesce(new.source_host, ''),
                    coalesce(new.artist, ''), coalesce(new.album, ''));
        END;
        CREATE TRIGGER media_ad AFTER DELETE ON media BEGIN
            INSERT INTO media_fts(media_fts, rowid, title, source_host, artist, album)
            VALUES ('delete', old.id, old.title, coalesce(old.source_host, ''),
                    coalesce(old.artist, ''), coalesce(old.album, ''));
        END;
        CREATE TRIGGER media_au AFTER UPDATE OF title, source_host, artist, album ON media BEGIN
            INSERT INTO media_fts(media_fts, rowid, title, source_host, artist, album)
            VALUES ('delete', old.id, old.title, coalesce(old.source_host, ''),
                    coalesce(old.artist, ''), coalesce(old.album, ''));
            INSERT INTO media_fts(rowid, title, source_host, artist, album)
            VALUES (new.id, new.title, coalesce(new.source_host, ''),
                    coalesce(new.artist, ''), coalesce(new.album, ''));
        END;
        INSERT INTO media_fts(media_fts) VALUES ('rebuild');
        "#,
        ),
        // v6 — durable playback state (L02, COM-03/04/13): queues, resume
        // positions and play history survive a lost WebView profile.
        M::up(
            r#"
        CREATE TABLE playback_state (
            key        TEXT PRIMARY KEY,
            value      TEXT NOT NULL,
            updated_at INTEGER NOT NULL
        );
        "#,
        ),
        // v7 — favorites and playlists (COM-06, COM-11). Playlist items
        // follow their media: removed from the library, gone from playlists.
        M::up(
            r#"
        ALTER TABLE media ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;
        CREATE INDEX media_favorite ON media (favorite) WHERE favorite = 1;
        CREATE TABLE playlists (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        CREATE TABLE playlist_items (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id INTEGER NOT NULL REFERENCES playlists (id) ON DELETE CASCADE,
            media_id    INTEGER NOT NULL REFERENCES media (id) ON DELETE CASCADE,
            position    INTEGER NOT NULL
        );
        CREATE INDEX playlist_items_order ON playlist_items (playlist_id, position);
        CREATE INDEX playlist_items_media ON playlist_items (media_id);
        "#,
        ),
        // v8 — covers chosen by the user (COM-07): kept by scans, probes
        // and "Clear thumbnail cache".
        M::up("ALTER TABLE media ADD COLUMN cover_custom INTEGER NOT NULL DEFAULT 0;"),
        // v9 — built-in browser history (NAV-03), local only.
        M::up(
            r#"
        CREATE TABLE browser_history (
            id         INTEGER PRIMARY KEY,
            url        TEXT NOT NULL,
            title      TEXT NOT NULL DEFAULT '',
            visited_at INTEGER NOT NULL
        );
        CREATE INDEX browser_history_time ON browser_history (visited_at);
        CREATE INDEX browser_history_url ON browser_history (url);
        "#,
        ),
    ])
}

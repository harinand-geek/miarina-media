//! Closing the app, as the Tauri app does on exit: the torrent session
//! stops (no more sharing), then running downloads flush their partial
//! files so they resume at the next launch.

use anyhow::Result;

/// Called once when the window is closing; never fails the closing.
pub fn app_shutdown() -> Result<()> {
    let torrents = crate::torrent_engine::disable().is_ok();
    crate::api::get::shutdown_downloads();
    // One line, no names or paths: the closing went through.
    eprintln!("miarina: closed cleanly (torrent session stopped: {torrents})");
    Ok(())
}

/// How opening the app database went (UPD-10, as the Tauri app).
pub struct DatabaseOpen {
    /// Empty when the database is ready; else "too_new" (written by a newer
    /// version), "upgrade_failed" (rolled back), "backup" (no copy could be
    /// made, nothing changed) or "open" (cannot be opened).
    pub issue: String,
    pub db_path: String,
    /// Schema before and after opening.
    pub from: i64,
    pub to: i64,
    /// Schema found in a too new database, and the newest this build knows.
    pub found: i64,
    pub supported: i64,
    /// Copy taken before migrating.
    pub backup: Option<String>,
    pub detail: Option<String>,
}

/// Opens `<data_dir>/miarina.db` once at launch, before anything else
/// reads it: an existing database is copied to `<data_dir>/backups` before
/// its schema changes, migrations run in one transaction, and a database
/// from a newer version is left untouched.
pub fn app_open_database(data_dir: String) -> DatabaseOpen {
    let dir = std::path::PathBuf::from(&data_dir);
    let db = dir.join("miarina.db");
    let mut out = DatabaseOpen {
        issue: String::new(),
        db_path: db.to_string_lossy().into_owned(),
        from: 0,
        to: 0,
        found: 0,
        supported: 0,
        backup: None,
        detail: None,
    };
    if let Err(e) = std::fs::create_dir_all(&dir) {
        out.issue = "open".into();
        out.detail = Some(e.to_string());
        return out;
    }
    let path = |p: &std::path::Path| p.to_string_lossy().into_owned();
    match storage::Storage::open_upgrading(&db, &dir.join("backups")) {
        Ok((_, upgrade)) => {
            out.from = upgrade.from;
            out.to = upgrade.to;
            out.backup = upgrade.backup.as_deref().map(path);
        }
        Err(storage::StorageError::TooNew { found, supported }) => {
            out.issue = "too_new".into();
            out.found = found;
            out.supported = supported;
        }
        Err(storage::StorageError::UpgradeFailed {
            from,
            to,
            backup,
            reason,
        }) => {
            out.issue = "upgrade_failed".into();
            out.from = from;
            out.to = to;
            out.backup = backup.as_deref().map(path);
            out.detail = Some(reason);
        }
        Err(storage::StorageError::Backup(reason)) => {
            out.issue = "backup".into();
            out.detail = Some(reason);
        }
        Err(e) => {
            out.issue = "open".into();
            out.detail = Some(e.to_string());
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opens_with_a_copy_first_and_refuses_a_newer_schema() {
        let dir = std::env::temp_dir().join(format!("mm-open-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let data = dir.to_string_lossy().into_owned();

        // New database: created at the latest schema, nothing to copy.
        let fresh = app_open_database(data.clone());
        assert_eq!(fresh.issue, "");
        assert_eq!((fresh.from, fresh.backup.is_none()), (0, true));
        let latest = fresh.to;

        // A database from an older version (schema 9, as 0.1.11).
        let db = dir.join("miarina.db");
        {
            let conn = rusqlite::Connection::open(&db).unwrap();
            conn.pragma_update(None, "user_version", 9).unwrap();
        }
        let _ = std::fs::remove_dir_all(dir.join("backups"));
        // Schema 9 recorded on a schema-10 file: migration 10 fails on its
        // existing columns, is rolled back, and the copy stays.
        let failed = app_open_database(data.clone());
        assert_eq!(failed.issue, "upgrade_failed");
        assert!(
            failed
                .backup
                .as_deref()
                .is_some_and(|b| std::path::Path::new(b).is_file())
        );

        // A database written by a newer version is not opened.
        {
            let conn = rusqlite::Connection::open(&db).unwrap();
            conn.pragma_update(None, "user_version", latest + 1)
                .unwrap();
        }
        let newer = app_open_database(data);
        assert_eq!(
            (newer.issue.as_str(), newer.found, newer.supported),
            ("too_new", latest + 1, latest)
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}

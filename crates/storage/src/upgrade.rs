//! Opening the app database across updates (UPD-10): an older build never
//! touches a schema it does not know, and an existing database is copied
//! before its schema changes.
use std::path::{Path, PathBuf};
use std::time::Duration;

use rusqlite::Connection;

use crate::{Result, Storage, StorageError, migrations, now_ms};

/// Copies kept in the backup folder; older ones are deleted.
pub const BACKUPS_KEPT: usize = 3;

/// What opening the database did to it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Upgrade {
    /// Schema found on disk (0 for a new database).
    pub from: i64,
    /// Schema after opening: the latest this build knows.
    pub to: i64,
    /// Copy taken before migrating an existing database.
    pub backup: Option<PathBuf>,
}

/// Latest schema version this build knows.
pub fn latest_schema() -> i64 {
    let conn = Connection::open_in_memory().expect("in-memory database");
    i64::from(
        migrations::migrations()
            .pending_migrations(&conn)
            .expect("migration list"),
    )
}

impl Storage {
    /// Opens the app database for an installed build.
    ///
    /// - A schema newer than this build (an older version reinstalled over
    ///   a newer one) is refused before anything is written.
    /// - An existing database with pending migrations is first copied into
    ///   `backups` (`VACUUM INTO`, consistent with the WAL); without that
    ///   copy the migration does not run.
    /// - Migrations run in one transaction: if one fails, the file keeps its
    ///   previous schema and the copy stays available.
    pub fn open_upgrading(path: &Path, backups: &Path) -> Result<(Self, Upgrade)> {
        let conn = Connection::open(path)?;
        conn.busy_timeout(Duration::from_secs(5))?;
        let found: i64 = conn.pragma_query_value(None, "user_version", |r| r.get(0))?;
        let pending = i64::from(migrations::migrations().pending_migrations(&conn)?);
        let latest = found + pending;
        if pending < 0 {
            return Err(StorageError::TooNew {
                found,
                supported: latest,
            });
        }
        let backup = if found > 0 && pending > 0 {
            Some(
                back_up(&conn, path, backups, found)
                    .map_err(|e| StorageError::Backup(e.to_string()))?,
            )
        } else {
            None
        };
        match Self::init(conn) {
            Ok(storage) => Ok((
                storage,
                Upgrade {
                    from: found,
                    to: latest,
                    backup,
                },
            )),
            Err(e) if found > 0 && pending > 0 => Err(StorageError::UpgradeFailed {
                from: found,
                to: latest,
                backup,
                reason: e.to_string(),
            }),
            Err(e) => Err(e),
        }
    }
}

fn back_up(conn: &Connection, db: &Path, dir: &Path, schema: i64) -> Result<PathBuf> {
    std::fs::create_dir_all(dir).map_err(|e| StorageError::Backup(e.to_string()))?;
    let stem = db
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("database");
    let target = dir.join(format!("{stem}-schema{schema}-{}.db", now_ms()));
    let target_str = target
        .to_str()
        .ok_or_else(|| StorageError::Backup("backup path is not valid UTF-8".into()))?;
    conn.execute("VACUUM INTO ?1", [target_str])?;
    prune(dir, stem);
    Ok(target)
}

/// Keeps the newest `BACKUPS_KEPT` copies of `stem` (names carry the time).
fn prune(dir: &Path, stem: &str) {
    let prefix = format!("{stem}-schema");
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    let mut copies: Vec<(i64, PathBuf)> = entries
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().into_string().ok()?;
            let rest = name.strip_prefix(&prefix)?.strip_suffix(".db")?;
            let (_, time) = rest.split_once('-')?;
            Some((time.parse().ok()?, e.path()))
        })
        .collect();
    copies.sort_by_key(|c| std::cmp::Reverse(c.0));
    for (_, old) in copies.into_iter().skip(BACKUPS_KEPT) {
        let _ = std::fs::remove_file(old);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at_version(path: &Path, version: usize) -> Connection {
        let mut conn = Connection::open(path).unwrap();
        migrations::migrations()
            .to_version(&mut conn, version)
            .unwrap();
        conn
    }

    fn user_version(path: &Path) -> i64 {
        Connection::open(path)
            .unwrap()
            .pragma_query_value(None, "user_version", |r| r.get(0))
            .unwrap()
    }

    fn backups(dir: &Path) -> Vec<PathBuf> {
        match std::fs::read_dir(dir) {
            Ok(entries) => entries.map(|e| e.unwrap().path()).collect(),
            Err(_) => Vec::new(),
        }
    }

    #[test]
    fn a_new_database_needs_no_backup() {
        let dir = tempfile::tempdir().unwrap();
        let (storage, up) =
            Storage::open_upgrading(&dir.path().join("miarina.db"), &dir.path().join("backups"))
                .unwrap();
        assert_eq!(
            up,
            Upgrade {
                from: 0,
                to: latest_schema(),
                backup: None
            }
        );
        assert_eq!(storage.schema_version().unwrap(), latest_schema());
        assert!(backups(&dir.path().join("backups")).is_empty());
    }

    #[test]
    fn an_older_schema_is_copied_then_upgraded_with_its_data() {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("miarina.db");
        let conn = at_version(&db, 5);
        conn.execute(
            "INSERT INTO settings (key, value) VALUES ('lang', '\"fr\"')",
            [],
        )
        .unwrap();
        drop(conn);

        let (storage, up) = Storage::open_upgrading(&db, &dir.path().join("backups")).unwrap();
        assert_eq!((up.from, up.to), (5, latest_schema()));
        let copy = up.backup.expect("backup taken");
        assert_eq!(user_version(&copy), 5, "the copy keeps the old schema");
        let kept: String = Connection::open(&copy)
            .unwrap()
            .query_row("SELECT value FROM settings WHERE key = 'lang'", [], |r| {
                r.get(0)
            })
            .unwrap();
        assert_eq!(kept, "\"fr\"");
        assert_eq!(storage.schema_version().unwrap(), latest_schema());
        assert_eq!(
            storage.setting::<String>("lang").unwrap().as_deref(),
            Some("fr")
        );
        drop(storage);

        // Already up to date: no new copy.
        let (_, again) = Storage::open_upgrading(&db, &dir.path().join("backups")).unwrap();
        assert_eq!(again.backup, None);
        assert_eq!(backups(&dir.path().join("backups")).len(), 1);
    }

    #[test]
    fn a_newer_schema_is_refused_without_writing() {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("miarina.db");
        let conn = at_version(&db, latest_schema() as usize);
        conn.pragma_update(None, "user_version", latest_schema() + 1)
            .unwrap();
        conn.pragma_update(None, "journal_mode", "DELETE").unwrap();
        drop(conn);
        let before = std::fs::read(&db).unwrap();

        let err = Storage::open_upgrading(&db, &dir.path().join("backups"))
            .err()
            .expect("refused");
        assert!(matches!(
            err,
            StorageError::TooNew { found, supported } if found == latest_schema() + 1 && supported == latest_schema()
        ));
        assert_eq!(std::fs::read(&db).unwrap(), before, "file untouched");
        assert!(backups(&dir.path().join("backups")).is_empty());
    }

    #[test]
    fn a_failed_migration_keeps_the_previous_schema_and_the_copy() {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("miarina.db");
        let last = latest_schema() as usize;
        let conn = at_version(&db, last - 1);
        // An object that makes the last migration fail half-way.
        conn.execute_batch(
            "CREATE TABLE browser_history (x); INSERT INTO settings (key, value) VALUES ('k', '1');",
        )
        .unwrap();
        drop(conn);

        let err = Storage::open_upgrading(&db, &dir.path().join("backups"))
            .err()
            .expect("migration fails");
        let StorageError::UpgradeFailed { from, backup, .. } = err else {
            panic!("unexpected error {err}");
        };
        assert_eq!(from, last as i64 - 1);
        assert!(backup.expect("copy taken").exists());
        assert_eq!(user_version(&db), last as i64 - 1, "rolled back");
        let kept: String = Connection::open(&db)
            .unwrap()
            .query_row("SELECT value FROM settings WHERE key = 'k'", [], |r| {
                r.get(0)
            })
            .unwrap();
        assert_eq!(kept, "1");
    }

    #[test]
    fn only_the_newest_copies_are_kept() {
        let dir = tempfile::tempdir().unwrap();
        for time in [10, 40, 20, 30, 50] {
            std::fs::write(dir.path().join(format!("miarina-schema3-{time}.db")), b"x").unwrap();
        }
        std::fs::write(dir.path().join("other.db"), b"x").unwrap();
        prune(dir.path(), "miarina");
        let mut left: Vec<String> = backups(dir.path())
            .iter()
            .map(|p| p.file_name().unwrap().to_string_lossy().into_owned())
            .collect();
        left.sort();
        assert_eq!(
            left,
            [
                "miarina-schema3-30.db",
                "miarina-schema3-40.db",
                "miarina-schema3-50.db",
                "other.db"
            ]
        );
    }
}

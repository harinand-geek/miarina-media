use super::*;

fn new_task(id: &str) -> NewTask {
    NewTask {
        id: id.to_owned(),
        url: format!("https://example.org/{id}.mp4"),
        source_host: "example.org".to_owned(),
        title: format!("Title {id}"),
        kind: MediaKind::Video,
        engine: "http".to_owned(),
        format_id: None,
        format_label: "MP4".to_owned(),
        dest_dir: "C:/Videos/Miarina".to_owned(),
        file_name: format!("{id}.mp4"),
        thumbnail: None,
    }
}

fn storage_with(ids: &[&str]) -> Storage {
    let storage = Storage::open_in_memory().unwrap();
    for id in ids {
        storage.insert_task(&new_task(id)).unwrap();
    }
    storage
}

#[test]
fn migrations_apply_and_are_idempotent() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let storage = Storage::open(&path).unwrap();
        assert!(storage.schema_version().unwrap() >= 3);
        storage.insert_task(&new_task("a")).unwrap();
    }
    // Reopening runs migrations again without touching existing data.
    let storage = Storage::open(&path).unwrap();
    assert!(storage.schema_version().unwrap() >= 3);
    assert_eq!(storage.task("a").unwrap().title, "Title a");
}

#[test]
fn migration_definitions_are_valid() {
    migrations::migrations().validate().unwrap();
}

#[test]
fn new_tasks_are_queued_in_insertion_order() {
    let storage = storage_with(&["a", "b", "c"]);
    let open: Vec<_> = storage
        .open_tasks()
        .unwrap()
        .into_iter()
        .map(|t| t.id)
        .collect();
    assert_eq!(open, ["a", "b", "c"]);
    assert!(
        storage
            .open_tasks()
            .unwrap()
            .iter()
            .all(|t| t.state == TaskState::Queued)
    );
}

#[test]
fn transitions_are_validated() {
    let storage = storage_with(&["a"]);
    let err = storage.transition("a", TaskState::Completed).unwrap_err();
    assert!(matches!(err, StorageError::Transition(_)));
    assert_eq!(storage.task("a").unwrap().state, TaskState::Queued);

    for state in [
        TaskState::Waiting,
        TaskState::Downloading,
        TaskState::Completed,
    ] {
        storage.transition("a", state).unwrap();
    }
    let done = storage.task("a").unwrap();
    assert_eq!(done.state, TaskState::Completed);
    assert!(done.completed_at.is_some());
    assert!(storage.open_tasks().unwrap().is_empty());
}

#[test]
fn unknown_task_is_reported() {
    let storage = storage_with(&[]);
    assert!(matches!(
        storage.task("nope"),
        Err(StorageError::NotFound(_))
    ));
    assert!(matches!(
        storage.record_progress("nope", 1, None),
        Err(StorageError::NotFound(_))
    ));
}

#[test]
fn progress_and_paths_are_persisted() {
    let storage = storage_with(&["a"]);
    storage.record_progress("a", 500, Some(1000)).unwrap();
    storage.record_progress("a", 700, None).unwrap();
    storage.set_paths("a", Some("a.mp4.part"), None).unwrap();
    storage.set_resume_support("a", true).unwrap();
    let task = storage.task("a").unwrap();
    assert_eq!((task.downloaded_bytes, task.total_bytes), (700, Some(1000)));
    assert_eq!(task.part_path.as_deref(), Some("a.mp4.part"));
    assert!(task.supports_resume);
}

#[test]
fn attempts_count_and_reset() {
    let storage = storage_with(&["a"]);
    assert_eq!(storage.increment_attempts("a").unwrap(), 1);
    assert_eq!(storage.increment_attempts("a").unwrap(), 2);
    storage.reset_attempts("a").unwrap();
    assert_eq!(storage.task("a").unwrap().attempts, 0);
}

#[test]
fn queue_can_be_reordered() {
    let mut storage = storage_with(&["a", "b", "c"]);
    storage.move_task("c", 0).unwrap();
    let order: Vec<_> = storage
        .open_tasks()
        .unwrap()
        .into_iter()
        .map(|t| t.id)
        .collect();
    assert_eq!(order, ["c", "a", "b"]);
    storage.move_task("c", 99).unwrap();
    let order: Vec<_> = storage
        .open_tasks()
        .unwrap()
        .into_iter()
        .map(|t| t.id)
        .collect();
    assert_eq!(order, ["a", "b", "c"]);
    let waiting: Vec<_> = storage
        .waiting_tasks(2)
        .unwrap()
        .into_iter()
        .map(|t| t.id)
        .collect();
    assert_eq!(waiting, ["a", "b"]);
}

#[test]
fn restart_recovery_parks_interrupted_work() {
    let mut storage = storage_with(&["resumable", "restart", "analyzing", "paused"]);
    for id in ["resumable", "restart"] {
        storage.transition(id, TaskState::Waiting).unwrap();
        storage.transition(id, TaskState::Downloading).unwrap();
        storage.record_progress(id, 400, Some(1000)).unwrap();
    }
    storage.set_resume_support("resumable", true).unwrap();
    storage
        .transition("analyzing", TaskState::Analyzing)
        .unwrap();
    storage.transition("paused", TaskState::Waiting).unwrap();
    storage.transition("paused", TaskState::Paused).unwrap();

    assert_eq!(storage.recover_after_restart().unwrap(), 3);

    let resumable = storage.task("resumable").unwrap();
    assert_eq!(
        (resumable.state, resumable.downloaded_bytes),
        (TaskState::Paused, 400)
    );
    let restart = storage.task("restart").unwrap();
    assert_eq!(
        (restart.state, restart.downloaded_bytes),
        (TaskState::Queued, 0)
    );
    assert_eq!(storage.task("analyzing").unwrap().state, TaskState::Queued);
    assert_eq!(storage.task("paused").unwrap().state, TaskState::Paused);
    assert_eq!(
        storage.recover_after_restart().unwrap(),
        0,
        "recovery is idempotent"
    );
}

#[test]
fn history_is_newest_first_and_clearable() {
    let storage = storage_with(&["a", "b"]);
    let a = storage.task("a").unwrap();
    let b = storage.task("b").unwrap();
    storage
        .append_history(&a, HistoryStatus::Completed, None)
        .unwrap();
    let entry = storage
        .append_history(
            &b,
            HistoryStatus::Failed,
            Some("Live streams are not supported"),
        )
        .unwrap();
    assert_eq!(entry.status, HistoryStatus::Failed);

    let history = storage.history(10).unwrap();
    assert_eq!(history.len(), 2);
    assert_eq!(history[0].task_id, "b");
    assert_eq!(storage.history(1).unwrap().len(), 1);

    assert_eq!(storage.clear_history().unwrap(), 2);
    assert!(storage.history(10).unwrap().is_empty());
    // Clearing history never deletes tasks (or files).
    assert!(storage.task("a").is_ok());
}

#[test]
fn settings_round_trip_as_json() {
    let storage = storage_with(&[]);
    assert_eq!(storage.setting::<u32>("concurrency").unwrap(), None);
    storage.set_setting("concurrency", &3u32).unwrap();
    storage.set_setting("concurrency", &4u32).unwrap();
    assert_eq!(storage.setting::<u32>("concurrency").unwrap(), Some(4));
    storage.set_setting("theme", &"light").unwrap();
    assert_eq!(
        storage.setting::<String>("theme").unwrap().as_deref(),
        Some("light")
    );
}

#[test]
fn corrupted_rows_are_reported_not_panicked() {
    let storage = storage_with(&["a"]);
    storage
        .conn
        .execute("UPDATE tasks SET state = 'exploded' WHERE id = 'a'", [])
        .unwrap();
    assert!(matches!(
        storage.task("a"),
        Err(StorageError::Corrupted("tasks.state"))
    ));
}

#[test]
fn upgrading_a_v1_database_keeps_existing_data() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("v1.db");
    {
        let mut conn = rusqlite::Connection::open(&path).unwrap();
        migrations::migrations().to_version(&mut conn, 1).unwrap();
        conn.execute(
            "INSERT INTO settings (key, value) VALUES ('concurrency', '5')",
            [],
        )
        .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert!(storage.schema_version().unwrap() >= 3);
    assert_eq!(storage.setting::<u32>("concurrency").unwrap(), Some(5));
    assert_eq!(storage.media_stats().unwrap().count, 0);
}

#[test]
fn v3_keeps_existing_tasks_and_stores_thumbnails() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let mut conn = rusqlite::Connection::open(&path).unwrap();
        migrations::migrations().to_version(&mut conn, 2).unwrap();
        conn.execute(
            "INSERT INTO tasks (id, url, source_host, title, kind, engine, format_label, state, \
             position, dest_dir, file_name, created_at, updated_at) \
             VALUES ('old', 'https://example.org/a.mp4', 'example.org', 'Old', 'video', 'http', \
             'MP4', 'queued', 1, 'C:/V', 'a.mp4', 1, 1)",
            [],
        )
        .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert!(storage.schema_version().unwrap() >= 3);
    assert_eq!(storage.task("old").unwrap().thumbnail, None);

    let task = storage
        .insert_task(&NewTask {
            thumbnail: Some("C:/data/thumbnails/sources/ab.jpg".into()),
            ..new_task("new")
        })
        .unwrap();
    assert_eq!(
        task.thumbnail.as_deref(),
        Some("C:/data/thumbnails/sources/ab.jpg")
    );
}

#[test]
fn removed_media_is_remembered_until_added_again() {
    let storage = Storage::open_in_memory().unwrap();
    let media = |path: &str| NewMedia {
        path: path.into(),
        title: "Hira".into(),
        kind: MediaKind::Audio,
        source_host: None,
        source_url: None,
        task_id: None,
        size_bytes: 3,
    };
    let kept = storage.upsert_media(&media("C:/Music/hira.mp3")).unwrap();
    storage.remove_media(kept.id).unwrap();
    assert_eq!(storage.media_stats().unwrap().count, 0);
    assert!(
        storage
            .removed_media_paths()
            .unwrap()
            .contains("C:/Music/hira.mp3")
    );
    assert!(matches!(
        storage.remove_media(kept.id),
        Err(StorageError::NotFound(_))
    ));

    storage.upsert_media(&media("C:/Music/hira.mp3")).unwrap();
    assert!(storage.removed_media_paths().unwrap().is_empty());
    assert_eq!(storage.media_stats().unwrap().count, 1);
}

#[test]
fn v4_keeps_the_library_of_a_v3_database() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let mut conn = rusqlite::Connection::open(&path).unwrap();
        migrations::migrations().to_version(&mut conn, 3).unwrap();
        conn.execute(
            "INSERT INTO media (path, title, kind, size_bytes, added_at, modified_at)              VALUES ('C:/V/a.mp4', 'A', 'video', 1, 1, 1)",
            [],
        )
        .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert!(storage.schema_version().unwrap() >= 4);
    assert_eq!(storage.media_stats().unwrap().count, 1);
    assert!(storage.removed_media_paths().unwrap().is_empty());
}

#[test]
fn v5_adds_tags_and_keeps_search_of_a_v4_database() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let mut conn = rusqlite::Connection::open(&path).unwrap();
        migrations::migrations().to_version(&mut conn, 4).unwrap();
        conn.execute(
            "INSERT INTO media (path, title, kind, source_host, size_bytes, added_at, modified_at) \
             VALUES ('C:/M/a.mp3', 'Rivotra', 'audio', 'example.org', 1, 1, 1)",
            [],
        )
        .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert_eq!(storage.schema_version().unwrap(), 5);
    let found = storage
        .query_media(&MediaQuery {
            search: "rivo".into(),
            ..Default::default()
        })
        .unwrap();
    assert_eq!(found.total, 1, "existing entries are re-indexed");
    assert_eq!(found.items[0].artist, None);
    assert_eq!(
        storage.media_to_tag(10).unwrap().len(),
        1,
        "tags read later"
    );
}

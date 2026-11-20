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
    assert!(storage.schema_version().unwrap() >= 5);
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

#[test]
fn v6_keeps_a_v5_database_and_starts_empty() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let mut conn = rusqlite::Connection::open(&path).unwrap();
        migrations::migrations().to_version(&mut conn, 5).unwrap();
        conn.execute(
            "INSERT INTO media (path, title, kind, size_bytes, added_at, modified_at) \
             VALUES ('C:/M/a.mp3', 'A', 'audio', 1, 1, 1)",
            [],
        )
        .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert!(storage.schema_version().unwrap() >= 6);
    assert_eq!(storage.media_stats().unwrap().count, 1);
    assert!(storage.playback_entries().unwrap().is_empty());
}

#[test]
fn playback_state_is_written_atomically_and_survives_reopening() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let storage = Storage::open(&path).unwrap();
        storage
            .write_playback(&[
                ("mm:position:7".into(), Some("75".into())),
                ("mm:player:v1".into(), Some("{\"queue\":[]}".into())),
            ])
            .unwrap();
        // One refused key: nothing from this batch is written.
        assert!(
            storage
                .write_playback(&[
                    ("mm:position:8".into(), Some("12".into())),
                    ("mm:sidebar".into(), Some("open".into())),
                ])
                .is_err()
        );
        storage
            .write_playback(&[("mm:player:v1".into(), None)])
            .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert_eq!(
        storage.playback_entries().unwrap(),
        vec![("mm:position:7".to_string(), "75".to_string())]
    );
}

#[test]
fn playback_keys_and_sizes_are_bounded() {
    assert!(is_playback_key("mm:position:42"));
    assert!(is_playback_key(PLAYBACK_IMPORTED));
    assert!(is_playback_key("mm:lang"));
    assert!(is_playback_key("mm:focus:v1"));
    assert!(!is_playback_key("mm:sidebar"));
    assert!(!is_playback_key("mm:position:"));
    assert!(!is_playback_key("mm:position:4a"));
    assert!(!is_playback_key("../etc"));
    let storage = Storage::open_in_memory().unwrap();
    let big = "x".repeat(PLAYBACK_VALUE_MAX + 1);
    assert!(
        storage
            .write_playback(&[("mm:player:v1".into(), Some(big))])
            .is_err()
    );
}

#[test]
fn removing_a_media_forgets_its_resume_position() {
    let storage = Storage::open_in_memory().unwrap();
    let id = storage
        .upsert_media(&NewMedia {
            path: "C:/M/b.mp3".into(),
            title: "B".into(),
            kind: MediaKind::Audio,
            source_host: None,
            source_url: None,
            task_id: None,
            size_bytes: 3,
        })
        .unwrap()
        .id;
    storage
        .write_playback(&[(position_key(id), Some("30".into()))])
        .unwrap();
    storage.remove_media(id).unwrap();
    assert!(storage.playback_value(&position_key(id)).unwrap().is_none());
}

fn audio(storage: &Storage, path: &str, title: &str) -> MediaRecord {
    storage
        .upsert_media(&NewMedia {
            path: path.into(),
            title: title.into(),
            kind: MediaKind::Audio,
            source_host: None,
            source_url: None,
            task_id: None,
            size_bytes: 3,
        })
        .unwrap()
}

#[test]
fn v7_adds_favorites_and_playlists_to_a_v6_database() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("miarina.db");
    {
        let mut conn = rusqlite::Connection::open(&path).unwrap();
        migrations::migrations().to_version(&mut conn, 6).unwrap();
        conn.execute(
            "INSERT INTO media (path, title, kind, size_bytes, added_at, modified_at) \
             VALUES ('C:/M/a.mp3', 'A', 'audio', 1, 1, 1)",
            [],
        )
        .unwrap();
    }
    let storage = Storage::open(&path).unwrap();
    assert_eq!(storage.schema_version().unwrap(), 9);
    let page = storage.query_media(&MediaQuery::default()).unwrap();
    assert!(!page.items[0].favorite);
    assert!(
        !page.items[0].cover_custom,
        "v8: existing pictures stay cache"
    );
    assert!(storage.playlists().unwrap().is_empty());
}

#[test]
fn favorites_are_marked_and_filtered() {
    let storage = Storage::open_in_memory().unwrap();
    let a = audio(&storage, "C:/M/a.mp3", "A");
    audio(&storage, "C:/M/b.mp3", "B");
    storage.set_favorite(a.id, true).unwrap();
    let favorites = storage
        .query_media(&MediaQuery {
            favorites: true,
            ..Default::default()
        })
        .unwrap();
    assert_eq!(favorites.total, 1);
    assert!(favorites.items[0].favorite);
    assert!(storage.set_favorite(9999, true).is_err());
}

#[test]
fn playlists_keep_order_and_follow_the_library() {
    let storage = Storage::open_in_memory().unwrap();
    let a = audio(&storage, "C:/M/a.mp3", "A");
    let b = audio(&storage, "C:/M/b.mp3", "B");
    let c = audio(&storage, "C:/M/c.mp3", "C");
    let list = storage
        .create_playlist("  Matin\n calme ", &[a.id, b.id, 4242, c.id, a.id])
        .unwrap();
    assert_eq!(list.name, "Matin calme");
    assert_eq!(list.count, 4, "unknown ids are skipped, repeats kept");

    storage.move_in_playlist(list.id, 3, 0).unwrap();
    storage.remove_from_playlist(list.id, 1).unwrap();
    let titles = |s: &Storage| {
        s.playlist(list.id)
            .unwrap()
            .items
            .iter()
            .map(|m| m.title.clone())
            .collect::<Vec<_>>()
    };
    assert_eq!(titles(&storage), ["A", "B", "C"]);

    storage.add_to_playlist(list.id, &[b.id]).unwrap();
    storage.remove_media(b.id).unwrap();
    assert_eq!(
        titles(&storage),
        ["A", "C"],
        "removed media leave playlists"
    );

    storage.rename_playlist(list.id, "Soir").unwrap();
    assert!(storage.rename_playlist(list.id, "   ").is_err());
    assert_eq!(storage.playlists().unwrap()[0].name, "Soir");
    storage.delete_playlist(list.id).unwrap();
    assert!(storage.playlist(list.id).is_err());
    assert_eq!(
        storage.media_stats().unwrap().count,
        2,
        "files stay in the library"
    );
}

#[test]
fn media_is_found_by_path_ignoring_case() {
    let storage = Storage::open_in_memory().unwrap();
    let a = audio(&storage, "C:/Music/Hira.mp3", "Hira");
    assert_eq!(
        storage.media_id_by_path("c:/music/hira.MP3").unwrap(),
        Some(a.id)
    );
    assert_eq!(
        storage.media_id_by_path("C:/Music/other.mp3").unwrap(),
        None
    );
}

#[test]
fn index_progress_counts_the_work_left() {
    let storage = Storage::open_in_memory().unwrap();
    let add = |path: &str, kind| {
        storage
            .upsert_media(&NewMedia {
                path: path.into(),
                title: path.into(),
                kind,
                source_host: None,
                source_url: None,
                task_id: None,
                size_bytes: 1,
            })
            .unwrap()
            .id
    };
    let a = add("D:/a.flac", MediaKind::Audio);
    let b = add("D:/b.mkv", MediaKind::Video);
    let c = add("D:/c.mp3", MediaKind::Audio);
    let p = storage.index_progress().unwrap();
    assert_eq!((p.total, p.to_tag, p.to_probe, p.audio, p.video), (3, 3, 3, 2, 1));

    storage.set_media_tags_read(a, None).unwrap();
    let probe = MediaProbe {
        duration_secs: Some(200.0),
        has_video: false,
        ..MediaProbe::default()
    };
    storage.set_media_probe(a, &probe, None).unwrap();
    storage.mark_media_unprobeable(b).unwrap();
    storage.set_media_missing(c, true).unwrap();
    let p = storage.index_progress().unwrap();
    assert_eq!((p.total, p.to_tag, p.to_probe, p.unreadable), (2, 1, 0, 1));
}

mod support;

use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use download_engine::{HttpEngine, Manager, ManagerError, ManagerEvent, RetryPolicy};
use media_core::TaskState;
use resource_manager::{Platform, ResourceMode, limits};
use storage::{HistoryStatus, MediaKind, NewTask, Storage};
use support::{Behavior, TestServer, body, serve};
use tokio::sync::mpsc;

const FAST_RETRY: RetryPolicy = RetryPolicy {
    max_retries: 3,
    base: Duration::from_millis(10),
    max_delay: Duration::from_millis(40),
};

struct Harness {
    manager: Manager,
    storage: Arc<Mutex<Storage>>,
    events: mpsc::Receiver<ManagerEvent>,
}

fn harness(db: &Path, max_downloads: usize) -> Harness {
    let storage = Arc::new(Mutex::new(Storage::open(db).unwrap()));
    let (tx, rx) = mpsc::channel(4096);
    let mut l = limits(
        ResourceMode::Performance,
        Platform::Windows,
        max_downloads,
        4,
    );
    l.progress_interval = Duration::from_millis(0);
    let manager = Manager::new(
        storage.clone(),
        vec![Arc::new(HttpEngine::new().unwrap())],
        l,
        FAST_RETRY,
        tx,
    );
    Harness {
        manager,
        storage,
        events: rx,
    }
}

fn task(id: &str, url: String, dest: &Path) -> NewTask {
    NewTask {
        id: id.into(),
        url,
        source_host: "127.0.0.1".into(),
        title: format!("Movie {id}"),
        kind: MediaKind::Video,
        engine: "http".into(),
        format_id: None,
        format_label: "MP4".into(),
        dest_dir: dest.to_string_lossy().into_owned(),
        file_name: format!("{id}.mp4"),
        thumbnail: None,
    }
}

async fn wait_for(h: &Harness, id: &str, state: TaskState) {
    for _ in 0..500 {
        if h.storage.lock().unwrap().task(id).unwrap().state == state {
            return;
        }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }
    let actual = h.storage.lock().unwrap().task(id).unwrap();
    panic!("task {id} never reached {state:?}: {actual:?}");
}

async fn slow_server(len: usize) -> TestServer {
    serve(
        body(len),
        Behavior {
            support_ranges: true,
            chunk_delay: Duration::from_millis(15),
            ..Default::default()
        },
    )
    .await
}

#[tokio::test]
async fn respects_the_concurrency_limit_and_completes_the_queue() {
    let server = serve(
        body(200_000),
        Behavior {
            support_ranges: true,
            chunk_delay: Duration::from_millis(5),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 1);
    h.manager.start().unwrap();
    for id in ["a", "b", "c"] {
        h.manager
            .enqueue(task(id, server.url(&format!("/{id}.mp4")), dir.path()))
            .unwrap();
    }
    for id in ["a", "b", "c"] {
        wait_for(&h, id, TaskState::Completed).await;
        assert_eq!(
            std::fs::read(dir.path().join(format!("{id}.mp4"))).unwrap(),
            *server.body
        );
    }
    assert_eq!(server.max_active.load(Ordering::SeqCst), 1);
    let history = h.storage.lock().unwrap().history(10).unwrap();
    assert_eq!(history.len(), 3);
    assert!(history.iter().all(|e| e.status == HistoryStatus::Completed));
}

#[tokio::test]
async fn transient_errors_are_retried_with_backoff() {
    let server = serve(
        body(10_000),
        Behavior {
            fail_first: 2.into(),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let mut h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Completed).await;
    assert_eq!(h.storage.lock().unwrap().task("a").unwrap().attempts, 2);

    let mut retries = 0;
    while let Ok(event) = h.events.try_recv() {
        if matches!(event, ManagerEvent::Retrying(_)) {
            retries += 1;
        }
    }
    assert_eq!(retries, 2);
}

#[tokio::test]
async fn exhausted_retries_fail_with_a_reason() {
    let server = serve(
        body(10),
        Behavior {
            fail_first: 100.into(),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Failed).await;
    let failed = h.storage.lock().unwrap().task("a").unwrap();
    assert_eq!(failed.error_code.as_deref(), Some("http"));
    assert_eq!(failed.attempts, FAST_RETRY.max_retries + 1);
    let history = h.storage.lock().unwrap().history(1).unwrap();
    assert_eq!(history[0].status, HistoryStatus::Failed);
    assert!(history[0].reason.as_deref().unwrap().contains("503"));

    // A user retry requeues it.
    h.manager.retry("a").unwrap();
    assert_eq!(h.storage.lock().unwrap().task("a").unwrap().attempts, 0);
}

#[tokio::test]
async fn permanent_errors_are_not_retried() {
    let server = serve(
        body(10),
        Behavior {
            status: Some(404),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Failed).await;
    assert_eq!(h.storage.lock().unwrap().task("a").unwrap().attempts, 0);
    assert_eq!(server.ranges().len(), 1);
}

#[tokio::test]
async fn cancel_stops_the_transfer_and_deletes_the_partial_file() {
    let server = slow_server(2_000_000).await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Downloading).await;
    tokio::time::sleep(Duration::from_millis(100)).await;

    h.manager.cancel("a").unwrap();
    wait_for(&h, "a", TaskState::Canceled).await;
    let leftovers: Vec<_> = std::fs::read_dir(dir.path())
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().ends_with(".part"))
        .collect();
    assert!(leftovers.is_empty(), "partial file removed");
    assert_eq!(
        h.storage.lock().unwrap().history(1).unwrap()[0].status,
        HistoryStatus::Canceled
    );
    assert!(matches!(
        h.manager.cancel("a"),
        Err(ManagerError::InvalidAction(TaskState::Canceled))
    ));
}

#[tokio::test]
async fn pause_keeps_resumable_data_and_resume_continues_with_a_range() {
    let server = slow_server(1_000_000).await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Downloading).await;
    tokio::time::sleep(Duration::from_millis(150)).await;

    h.manager.pause("a").unwrap();
    wait_for(&h, "a", TaskState::Paused).await;
    let paused = h.storage.lock().unwrap().task("a").unwrap();
    assert!(paused.supports_resume);
    assert!(paused.downloaded_bytes > 0);

    h.manager.resume("a").unwrap();
    wait_for(&h, "a", TaskState::Completed).await;
    assert_eq!(
        std::fs::read(dir.path().join("a.mp4")).unwrap(),
        *server.body
    );
    let ranges = server.ranges();
    assert_eq!(ranges[0], None);
    assert_eq!(
        ranges[1],
        Some(format!("bytes={}-", paused.downloaded_bytes))
    );
}

#[tokio::test]
async fn interrupted_session_is_recovered_and_resumed() {
    let server = slow_server(1_000_000).await;
    let dir = tempfile::tempdir().unwrap();
    let db = dir.path().join("db.sqlite");
    {
        let h = harness(&db, 2);
        h.manager
            .enqueue(task("a", server.url("/a.mp4"), dir.path()))
            .unwrap();
        wait_for(&h, "a", TaskState::Downloading).await;
        tokio::time::sleep(Duration::from_millis(150)).await;
        h.manager.shutdown().await; // simulates the app closing mid-download
        assert_eq!(
            h.storage.lock().unwrap().task("a").unwrap().state,
            TaskState::Downloading
        );
    }

    let h = harness(&db, 2);
    assert_eq!(h.manager.start().unwrap(), 1);
    let recovered = h.storage.lock().unwrap().task("a").unwrap();
    assert_eq!(recovered.state, TaskState::Paused, "never resumes silently");
    h.manager.resume("a").unwrap();
    wait_for(&h, "a", TaskState::Completed).await;
    assert_eq!(
        std::fs::read(dir.path().join("a.mp4")).unwrap(),
        *server.body
    );
    assert!(
        server.ranges().last().unwrap().is_some(),
        "resumed with a Range request"
    );
}

#[tokio::test]
async fn raising_the_limit_starts_waiting_tasks() {
    let server = slow_server(400_000).await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 1);
    for id in ["a", "b", "c"] {
        h.manager
            .enqueue(task(id, server.url(&format!("/{id}.mp4")), dir.path()))
            .unwrap();
    }
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert_eq!(h.manager.running_count(), 1);
    let mut more = h.manager.limits();
    more.max_downloads = 3;
    h.manager.set_limits(more);
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert_eq!(h.manager.running_count(), 3);
}

#[tokio::test]
async fn rejects_unknown_engines() {
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 1);
    let mut t = task("a", "https://example.org/a.mp4".into(), dir.path());
    t.engine = "nope".into();
    assert!(matches!(
        h.manager.enqueue(t),
        Err(ManagerError::UnknownEngine(_))
    ));
}

#[tokio::test]
async fn temporary_files_can_live_outside_the_destination() {
    let server = serve(body(150_000), Behavior::default()).await;
    let dir = tempfile::tempdir().unwrap();
    let dest = dir.path().join("Movies").join("Miarina");
    let staging = dir.path().join("partial");
    let h = harness(&dir.path().join("db.sqlite"), 1);
    h.manager.set_staging_dir(staging.clone());
    h.manager.start().unwrap();
    h.manager
        .enqueue(task("s", server.url("/s.mp4"), &dest))
        .unwrap();
    wait_for(&h, "s", TaskState::Completed).await;

    assert_eq!(std::fs::read(dest.join("s.mp4")).unwrap(), *server.body);
    // Only the finished media file ever lands in the destination.
    let names: Vec<_> = std::fs::read_dir(&dest)
        .unwrap()
        .map(|e| e.unwrap().file_name().into_string().unwrap())
        .collect();
    assert_eq!(names, ["s.mp4"]);
    assert_eq!(std::fs::read_dir(&staging).unwrap().count(), 0);
    let record = h.storage.lock().unwrap().task("s").unwrap();
    assert_eq!(record.final_path.as_deref(), dest.join("s.mp4").to_str());
}

#[tokio::test]
async fn without_network_a_task_waits_without_spending_retries() {
    let data = body(300_000);
    let behavior = Behavior {
        support_ranges: true,
        ..Default::default()
    };
    *behavior.cut_after.lock().unwrap() = Some(60_000);
    let server = serve(data.clone(), behavior).await;
    let dir = tempfile::tempdir().unwrap();
    let mut h = harness(&dir.path().join("db.sqlite"), 2);
    let online = Arc::new(AtomicBool::new(false));
    let probe = online.clone();
    h.manager
        .set_connectivity(Arc::new(move || Some(probe.load(Ordering::SeqCst))));
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();

    // Cut while "offline": far longer than the whole retry budget.
    wait_for(&h, "a", TaskState::Waiting).await;
    tokio::time::sleep(Duration::from_millis(600)).await;
    let waiting = h.storage.lock().unwrap().task("a").unwrap();
    assert_eq!((waiting.state, waiting.attempts), (TaskState::Waiting, 0));
    assert_eq!(server.ranges().len(), 1, "no request while offline");

    online.store(true, Ordering::SeqCst);
    wait_for(&h, "a", TaskState::Completed).await;
    assert_eq!(std::fs::read(dir.path().join("a.mp4")).unwrap(), data);
    let ranges = server.ranges();
    assert!(
        ranges[1]
            .as_deref()
            .is_some_and(|r| r.starts_with("bytes=")),
        "{ranges:?}"
    );
    assert_eq!(h.storage.lock().unwrap().task("a").unwrap().attempts, 0);
    let mut offline_notices = 0;
    while let Ok(event) = h.events.try_recv() {
        if let ManagerEvent::Retrying(n) = event {
            assert!(n.offline);
            offline_notices += 1;
        }
    }
    assert_eq!(offline_notices, 1);
}

#[tokio::test]
async fn restart_drops_the_partial_data_and_starts_over() {
    let server = slow_server(600_000).await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Downloading).await;
    tokio::time::sleep(Duration::from_millis(150)).await;
    h.manager.pause("a").unwrap();
    wait_for(&h, "a", TaskState::Paused).await;
    let part = h
        .storage
        .lock()
        .unwrap()
        .task("a")
        .unwrap()
        .part_path
        .unwrap();
    assert!(Path::new(&part).exists());

    h.manager.restart("a").unwrap();
    wait_for(&h, "a", TaskState::Completed).await;
    assert_eq!(
        server.ranges().last().unwrap(),
        &None,
        "no Range: from zero"
    );
    assert_eq!(
        std::fs::read(dir.path().join("a.mp4")).unwrap(),
        *server.body
    );
    assert!(matches!(
        h.manager.restart("a"),
        Err(ManagerError::InvalidAction(TaskState::Completed))
    ));
}

#[cfg(windows)]
#[tokio::test]
async fn a_retry_without_enough_space_fails_before_downloading() {
    let server = serve(
        body(10),
        Behavior {
            status: Some(404),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let h = harness(&dir.path().join("db.sqlite"), 2);
    h.manager
        .enqueue(task("a", server.url("/a.mp4"), dir.path()))
        .unwrap();
    wait_for(&h, "a", TaskState::Failed).await;
    // As if the first attempt had learnt a size the disk cannot hold.
    h.storage
        .lock()
        .unwrap()
        .record_progress("a", 0, Some(u64::MAX / 4))
        .unwrap();
    h.manager.retry("a").unwrap();
    wait_for(&h, "a", TaskState::Failed).await;
    let failed = h.storage.lock().unwrap().task("a").unwrap();
    assert_eq!(failed.error_code.as_deref(), Some("insufficient_space"));
    assert_eq!(server.ranges().len(), 1, "nothing downloaded again");
}

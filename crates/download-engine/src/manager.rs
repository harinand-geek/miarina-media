//! Persistent, bounded download scheduler.
//!
//! The manager owns the task lifecycle: it validates every transition
//! through `storage`, runs at most `Limits::max_downloads` transfers, retries
//! transient failures with backoff and emits throttled events for the UI.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::{Duration, Instant};

use media_core::{TaskState, ValidatedUrl, validate_media_url};
use resource_manager::{Limits, MAX_QUEUE_LEN};
use serde::Serialize;
use storage::{HistoryEntry, HistoryStatus, NewTask, Storage, StorageError, TaskRecord};
use thiserror::Error;
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use crate::engine::{DownloadJob, Engine};
use crate::{EngineError, Progress, RetryPolicy};

/// Minimum delay between two progress checkpoints written to SQLite.
const CHECKPOINT_EVERY: Duration = Duration::from_secs(2);

#[derive(Debug, Error)]
pub enum ManagerError {
    #[error(transparent)]
    Storage(#[from] StorageError),
    #[error("the queue is full ({MAX_QUEUE_LEN} tasks)")]
    QueueFull,
    #[error("no engine named {0}")]
    UnknownEngine(String),
    #[error("this action is not possible while the task is {0:?}")]
    InvalidAction(TaskState),
}

impl Serialize for ManagerError {
    fn serialize<S: serde::Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_string())
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProgressEvent {
    pub id: String,
    #[serde(flatten)]
    pub progress: Progress,
    pub eta_secs: Option<u64>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RetryNotice {
    pub id: String,
    pub retry: u32,
    pub in_secs: u64,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum ManagerEvent {
    /// Lossy: dropped if the UI is not keeping up.
    Progress(ProgressEvent),
    /// A task changed state (or was created / deleted).
    Task(TaskRecord),
    Removed {
        id: String,
    },
    Retrying(RetryNotice),
    History(HistoryEntry),
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Intent {
    Pause,
    Cancel,
    Shutdown,
}

struct Running {
    cancel: CancellationToken,
    intent: Arc<Mutex<Option<Intent>>>,
}

struct Inner {
    storage: Arc<Mutex<Storage>>,
    engines: HashMap<&'static str, Arc<dyn Engine>>,
    limits: Mutex<Limits>,
    retry: RetryPolicy,
    running: Mutex<HashMap<String, Running>>,
    events: mpsc::Sender<ManagerEvent>,
}

#[derive(Clone)]
pub struct Manager {
    inner: Arc<Inner>,
}

fn lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    // A panic while holding the lock must not take the whole manager down.
    m.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Temporary file of a task: next to the destination so the final move is
/// a rename on the same volume.
pub fn part_path(dest_dir: &Path, file_name: &str, task_id: &str) -> PathBuf {
    let short: String = task_id
        .chars()
        .filter(char::is_ascii_alphanumeric)
        .take(12)
        .collect();
    dest_dir.join(format!("{file_name}.{short}.part"))
}

impl Manager {
    pub fn new(
        storage: Arc<Mutex<Storage>>,
        engines: Vec<Arc<dyn Engine>>,
        limits: Limits,
        retry: RetryPolicy,
        events: mpsc::Sender<ManagerEvent>,
    ) -> Self {
        let engines = engines.into_iter().map(|e| (e.id(), e)).collect();
        Self {
            inner: Arc::new(Inner {
                storage,
                engines,
                limits: Mutex::new(limits),
                retry,
                running: Mutex::new(HashMap::new()),
                events,
            }),
        }
    }

    /// Recovers tasks interrupted by the previous session, then starts the
    /// queue. Returns the number of recovered tasks.
    pub fn start(&self) -> Result<usize, ManagerError> {
        let recovered = lock(&self.inner.storage).recover_after_restart()?;
        self.schedule();
        Ok(recovered)
    }

    pub fn set_limits(&self, limits: Limits) {
        *lock(&self.inner.limits) = limits;
        self.schedule();
    }

    pub fn limits(&self) -> Limits {
        *lock(&self.inner.limits)
    }

    pub fn tasks(&self) -> Result<Vec<TaskRecord>, ManagerError> {
        Ok(lock(&self.inner.storage).open_tasks()?)
    }

    pub fn enqueue(&self, task: NewTask) -> Result<TaskRecord, ManagerError> {
        if !self.inner.engines.contains_key(task.engine.as_str()) {
            return Err(ManagerError::UnknownEngine(task.engine));
        }
        let record = {
            let storage = lock(&self.inner.storage);
            if storage.open_tasks()?.len() >= MAX_QUEUE_LEN {
                return Err(ManagerError::QueueFull);
            }
            storage.insert_task(&task)?
        };
        self.emit_task(&record);
        self.schedule();
        Ok(record)
    }

    /// Starts a task immediately, even above the concurrency limit
    /// (design: "Start now").
    pub fn start_now(&self, id: &str) -> Result<(), ManagerError> {
        let task = lock(&self.inner.storage).task(id)?;
        match task.state {
            TaskState::Queued | TaskState::Waiting => {}
            TaskState::Paused => {
                self.transition(id, TaskState::Waiting)?;
            }
            other => return Err(ManagerError::InvalidAction(other)),
        }
        self.spawn_worker(lock(&self.inner.storage).task(id)?);
        Ok(())
    }

    pub fn pause(&self, id: &str) -> Result<(), ManagerError> {
        if self.signal(id, Intent::Pause) {
            return Ok(());
        }
        let state = lock(&self.inner.storage).task(id)?.state;
        match state {
            TaskState::Queued => {
                self.transition(id, TaskState::Waiting)?;
                self.transition(id, TaskState::Paused)?;
            }
            TaskState::Waiting => {
                self.transition(id, TaskState::Paused)?;
            }
            TaskState::Paused => {}
            other => return Err(ManagerError::InvalidAction(other)),
        }
        Ok(())
    }

    pub fn resume(&self, id: &str) -> Result<(), ManagerError> {
        let state = lock(&self.inner.storage).task(id)?.state;
        match state {
            TaskState::Paused => {
                self.transition(id, TaskState::Waiting)?;
                self.schedule();
                Ok(())
            }
            TaskState::Queued | TaskState::Waiting | TaskState::Downloading => Ok(()),
            other => Err(ManagerError::InvalidAction(other)),
        }
    }

    pub fn pause_all(&self) {
        let ids: Vec<String> = lock(&self.inner.running).keys().cloned().collect();
        for id in ids {
            self.signal(&id, Intent::Pause);
        }
        if let Ok(tasks) = self.tasks() {
            for t in tasks
                .iter()
                .filter(|t| matches!(t.state, TaskState::Queued | TaskState::Waiting))
            {
                let _ = self.pause(&t.id);
            }
        }
    }

    pub fn resume_all(&self) {
        if let Ok(tasks) = self.tasks() {
            for t in tasks.iter().filter(|t| t.state == TaskState::Paused) {
                let _ = self.resume(&t.id);
            }
        }
    }

    /// Cancels a task and deletes its partial file.
    pub fn cancel(&self, id: &str) -> Result<(), ManagerError> {
        if self.signal(id, Intent::Cancel) {
            return Ok(());
        }
        let task = lock(&self.inner.storage).task(id)?;
        if task.state.is_terminal() {
            return Err(ManagerError::InvalidAction(task.state));
        }
        self.finish_canceled(&task)?;
        Ok(())
    }

    /// Requeues a failed task (user retry).
    pub fn retry(&self, id: &str) -> Result<(), ManagerError> {
        let storage = lock(&self.inner.storage);
        let task = storage.task(id)?;
        if task.state != TaskState::Failed {
            return Err(ManagerError::InvalidAction(task.state));
        }
        storage.reset_attempts(id)?;
        storage.set_error(id, None, None)?;
        drop(storage);
        self.transition(id, TaskState::Queued)?;
        self.schedule();
        Ok(())
    }

    pub fn move_task(&self, id: &str, index: usize) -> Result<(), ManagerError> {
        lock(&self.inner.storage).move_task(id, index)?;
        Ok(())
    }

    /// Stops running transfers, keeping them recoverable on next start.
    pub async fn shutdown(&self) {
        let ids: Vec<String> = lock(&self.inner.running).keys().cloned().collect();
        for id in &ids {
            self.signal(id, Intent::Shutdown);
        }
        // Give workers a moment to flush their partial files.
        for _ in 0..50 {
            if lock(&self.inner.running).is_empty() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    }

    pub fn running_count(&self) -> usize {
        lock(&self.inner.running).len()
    }

    // ------------------------------------------------------------ internals

    fn signal(&self, id: &str, intent: Intent) -> bool {
        let running = lock(&self.inner.running);
        match running.get(id) {
            Some(r) => {
                *lock(&r.intent) = Some(intent);
                r.cancel.cancel();
                true
            }
            None => false,
        }
    }

    fn schedule(&self) {
        let free = {
            let running = lock(&self.inner.running);
            lock(&self.inner.limits)
                .max_downloads
                .saturating_sub(running.len())
        };
        if free == 0 {
            return;
        }
        let candidates = match lock(&self.inner.storage).waiting_tasks((free + 8) as u32) {
            Ok(tasks) => tasks,
            Err(_) => return,
        };
        let mut started = 0;
        for task in candidates {
            if started == free {
                break;
            }
            if lock(&self.inner.running).contains_key(&task.id) {
                continue;
            }
            self.spawn_worker(task);
            started += 1;
        }
    }

    fn spawn_worker(&self, task: TaskRecord) {
        let running = Running {
            cancel: CancellationToken::new(),
            intent: Arc::new(Mutex::new(None)),
        };
        let cancel = running.cancel.clone();
        let intent = running.intent.clone();
        {
            let mut map = lock(&self.inner.running);
            if map.contains_key(&task.id) {
                return;
            }
            map.insert(task.id.clone(), running);
        }
        let manager = self.clone();
        tokio::spawn(async move {
            let id = task.id.clone();
            manager.run_task(task, cancel, intent).await;
            lock(&manager.inner.running).remove(&id);
            manager.schedule();
        });
    }

    async fn run_task(
        &self,
        task: TaskRecord,
        cancel: CancellationToken,
        intent: Arc<Mutex<Option<Intent>>>,
    ) {
        let id = task.id.clone();
        let Some(engine) = self.inner.engines.get(task.engine.as_str()).cloned() else {
            self.fail(
                &id,
                &EngineError::Unsupported {
                    reason: format!("engine {}", task.engine),
                },
            );
            return;
        };
        let url = match validate_media_url(&task.url) {
            Ok(url) => url,
            Err(e) => {
                self.fail(
                    &id,
                    &EngineError::Unsupported {
                        reason: e.to_string(),
                    },
                );
                return;
            }
        };
        if task.state == TaskState::Queued && self.transition(&id, TaskState::Waiting).is_err() {
            return;
        }

        let dest_dir = PathBuf::from(&task.dest_dir);
        if let Err(err) = tokio::fs::create_dir_all(&dest_dir).await {
            self.fail(&id, &EngineError::from_io(err));
            return;
        }
        let part = part_path(&dest_dir, &task.file_name, &id);
        let _ = lock(&self.inner.storage).set_paths(&id, part.to_str(), None);

        loop {
            if self.transition(&id, TaskState::Downloading).is_err() {
                return;
            }
            let result = self
                .attempt(&engine, &url, &task, &dest_dir, &part, &cancel)
                .await;
            match result {
                Ok(outcome) => {
                    let storage = lock(&self.inner.storage);
                    let _ = storage.record_progress(&id, outcome.bytes, Some(outcome.bytes));
                    let _ = storage.set_paths(&id, None, outcome.final_path.to_str());
                    drop(storage);
                    if let Ok(done) = self.transition(&id, TaskState::Completed) {
                        self.history(&done, HistoryStatus::Completed, None);
                    }
                    return;
                }
                Err(EngineError::Canceled) => {
                    self.on_interrupted(&id, *lock(&intent));
                    return;
                }
                Err(err) if err.is_retryable() => {
                    let retries = lock(&self.inner.storage)
                        .increment_attempts(&id)
                        .unwrap_or(u32::MAX);
                    if retries > self.inner.retry.max_retries {
                        self.fail(&id, &err);
                        return;
                    }
                    if self.transition(&id, TaskState::Waiting).is_err() {
                        return;
                    }
                    let delay = self.inner.retry.delay(retries, seed(&id, retries));
                    self.emit(ManagerEvent::Retrying(RetryNotice {
                        id: id.clone(),
                        retry: retries,
                        in_secs: delay.as_secs().max(1),
                        reason: err.to_string(),
                    }));
                    tokio::select! {
                        _ = cancel.cancelled() => {
                            self.on_interrupted(&id, *lock(&intent));
                            return;
                        }
                        _ = tokio::time::sleep(delay) => {}
                    }
                }
                Err(err) => {
                    self.fail(&id, &err);
                    return;
                }
            }
        }
    }

    async fn attempt(
        &self,
        engine: &Arc<dyn Engine>,
        url: &ValidatedUrl,
        task: &TaskRecord,
        dest_dir: &Path,
        part: &Path,
        cancel: &CancellationToken,
    ) -> Result<crate::Outcome, EngineError> {
        let job = DownloadJob {
            url: url.clone(),
            part_path: part.to_path_buf(),
            dest_dir: dest_dir.to_path_buf(),
            file_name: task.file_name.clone(),
            progress_interval: lock(&self.inner.limits).progress_interval,
            format_id: task.format_id.clone(),
        };
        let checkpoint = Mutex::new((Instant::now(), None::<bool>));
        let on_progress = |p: Progress| {
            let mut cp = lock(&checkpoint);
            let resume_changed = cp.1 != Some(p.supports_resume);
            if resume_changed || cp.0.elapsed() >= CHECKPOINT_EVERY {
                let storage = lock(&self.inner.storage);
                let _ = storage.record_progress(&task.id, p.downloaded, p.total);
                if resume_changed {
                    let _ = storage.set_resume_support(&task.id, p.supports_resume);
                }
                *cp = (Instant::now(), Some(p.supports_resume));
            }
            drop(cp);
            self.emit(ManagerEvent::Progress(ProgressEvent {
                id: task.id.clone(),
                progress: p,
                eta_secs: p.eta().map(|d| d.as_secs()),
            }));
        };
        let result = engine.download(&job, &on_progress, cancel.clone()).await;
        // Persist the last position so a pause or crash resumes from it.
        if result.is_err()
            && let Ok(meta) = tokio::fs::metadata(part).await
        {
            let _ = lock(&self.inner.storage).record_progress(&task.id, meta.len(), None);
        }
        result
    }

    fn on_interrupted(&self, id: &str, intent: Option<Intent>) {
        match intent {
            Some(Intent::Cancel) => {
                // Bind first: a guard in an `if let` scrutinee lives for the
                // whole block, and finish_canceled locks storage again.
                let task = lock(&self.inner.storage).task(id);
                if let Ok(task) = task {
                    let _ = self.finish_canceled(&task);
                }
            }
            Some(Intent::Pause) => {
                let task = lock(&self.inner.storage).task(id);
                if let Ok(task) = task {
                    // Partial data is useless if the source cannot resume.
                    if !task.supports_resume {
                        remove_part(&task);
                        let _ = lock(&self.inner.storage).record_progress(id, 0, None);
                    }
                }
                let _ = self.transition(id, TaskState::Paused);
            }
            // Leave the state as is: recover_after_restart handles it.
            Some(Intent::Shutdown) | None => {}
        }
    }

    fn finish_canceled(&self, task: &TaskRecord) -> Result<(), ManagerError> {
        remove_part(task);
        let done = self.transition(&task.id, TaskState::Canceled)?;
        self.history(&done, HistoryStatus::Canceled, None);
        Ok(())
    }

    fn fail(&self, id: &str, err: &EngineError) {
        let _ = lock(&self.inner.storage).set_error(id, Some(err.code()), Some(&err.to_string()));
        // Keep resumable partial data for a user retry; drop the rest.
        let task = lock(&self.inner.storage).task(id);
        if let Ok(task) = task
            && !task.supports_resume
        {
            remove_part(&task);
        }
        if let Ok(task) = self.transition(id, TaskState::Failed) {
            self.history(&task, HistoryStatus::Failed, Some(&err.to_string()));
        }
    }

    fn transition(&self, id: &str, to: TaskState) -> Result<TaskRecord, ManagerError> {
        let task = lock(&self.inner.storage).transition(id, to)?;
        self.emit_task(&task);
        Ok(task)
    }

    fn history(&self, task: &TaskRecord, status: HistoryStatus, reason: Option<&str>) {
        if let Ok(entry) = lock(&self.inner.storage).append_history(task, status, reason) {
            self.emit(ManagerEvent::History(entry));
        }
    }

    fn emit_task(&self, task: &TaskRecord) {
        self.emit(ManagerEvent::Task(task.clone()));
    }

    fn emit(&self, event: ManagerEvent) {
        // Progress is lossy by design; state changes must not be lost, but
        // try_send never blocks a worker. The channel is sized for bursts.
        let _ = self.inner.events.try_send(event);
    }
}

fn remove_part(task: &TaskRecord) {
    if let Some(part) = &task.part_path {
        let _ = std::fs::remove_file(part);
    }
}

fn seed(id: &str, retry: u32) -> u64 {
    id.bytes().fold(retry as u64, |acc, b| {
        acc.wrapping_mul(31).wrapping_add(b as u64)
    })
}

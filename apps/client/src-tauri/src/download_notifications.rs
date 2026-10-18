//! Android download notifications (design "B · Notification concepts").
//! `Board` turns download manager events into what the notification shows;
//! on Android a 1 s loop sends it to `DownloadsPlugin.kt`, which runs the
//! foreground service, and applies the buttons pressed in the notification.

#![cfg_attr(not(target_os = "android"), allow(dead_code))]

use std::collections::HashMap;

use download_engine::ManagerEvent;
use media_core::TaskState;
use serde::{Deserialize, Serialize};

use crate::commands::human_size;

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ActiveDownload {
    pub id: String,
    pub title: String,
    pub text: String,
    /// 0–100, -1 when unknown (indeterminate bar).
    pub percent: i32,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FinishedDownload {
    pub id: String,
    pub title: String,
    pub text: String,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct Update {
    pub active: Vec<ActiveDownload>,
    pub finished: Vec<FinishedDownload>,
}

/// A button pressed in the notification.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Action {
    pub action: String,
    pub id: String,
}

#[derive(Debug, Clone)]
struct Item {
    title: String,
    state: TaskState,
    position: i64,
    downloaded: u64,
    total: Option<u64>,
    speed: f64,
    eta: Option<u64>,
}

/// Work that keeps the service (and its notification) running.
fn is_active(state: TaskState) -> bool {
    matches!(
        state,
        TaskState::Queued
            | TaskState::Analyzing
            | TaskState::Waiting
            | TaskState::Downloading
            | TaskState::Processing
    )
}

#[derive(Debug, Default)]
pub struct Board {
    items: HashMap<String, Item>,
    finished: Vec<FinishedDownload>,
    dirty: bool,
}

impl Board {
    pub fn on_event(&mut self, event: &ManagerEvent) {
        match event {
            ManagerEvent::Progress(p) => {
                if let Some(item) = self.items.get_mut(&p.id) {
                    item.downloaded = p.progress.downloaded;
                    item.total = p.progress.total.or(item.total);
                    item.speed = p.progress.bytes_per_sec;
                    item.eta = p.eta_secs;
                    self.dirty = true;
                }
            }
            ManagerEvent::Task(task) => {
                let was_active = self.items.contains_key(&task.id);
                if is_active(task.state) {
                    let item = self.items.entry(task.id.clone()).or_insert_with(|| Item {
                        title: task.title.clone(),
                        state: task.state,
                        position: task.position,
                        downloaded: task.downloaded_bytes,
                        total: task.total_bytes,
                        speed: 0.0,
                        eta: None,
                    });
                    item.title.clone_from(&task.title);
                    item.state = task.state;
                    item.position = task.position;
                    item.total = task.total_bytes.or(item.total);
                    if task.state != TaskState::Downloading {
                        item.speed = 0.0;
                        item.eta = None;
                    }
                } else {
                    self.items.remove(&task.id);
                    // Only downloads followed in this session are announced.
                    if was_active && task.state == TaskState::Completed {
                        let size = task.total_bytes.unwrap_or(task.downloaded_bytes);
                        self.finished.push(FinishedDownload {
                            id: task.id.clone(),
                            title: task.title.clone(),
                            text: format!("{} · tap to play", human_size(size)),
                        });
                    }
                }
                self.dirty = true;
            }
            ManagerEvent::Removed { id } => {
                self.dirty |= self.items.remove(id).is_some();
            }
            ManagerEvent::Retrying(_) | ManagerEvent::History(_) => {}
        }
    }

    pub fn has_active(&self) -> bool {
        !self.items.is_empty()
    }

    /// What to show now: when something changed, or every time while
    /// downloads run (each send also collects the notification's buttons).
    /// `None` when idle and unchanged.
    pub fn take(&mut self) -> Option<Update> {
        if !self.dirty && self.items.is_empty() {
            return None;
        }
        self.dirty = false;
        let mut items: Vec<(&String, &Item)> = self.items.iter().collect();
        // Running first, then queue order.
        items.sort_by_key(|(_, i)| (i.state != TaskState::Downloading, i.position));
        Some(Update {
            active: items
                .into_iter()
                .map(|(id, item)| ActiveDownload {
                    id: id.clone(),
                    title: item.title.clone(),
                    text: describe(item),
                    percent: percent(item),
                })
                .collect(),
            finished: std::mem::take(&mut self.finished),
        })
    }
}

fn percent(item: &Item) -> i32 {
    match (item.state, item.total) {
        (TaskState::Processing, _) | (_, None) | (_, Some(0)) => -1,
        (_, Some(total)) => ((item.downloaded.min(total) * 100) / total) as i32,
    }
}

/// "712 MB of 1.12 GB · 6.4 MB/s · 1 min left" (design).
fn describe(item: &Item) -> String {
    match item.state {
        TaskState::Queued | TaskState::Waiting => "Waiting for a free slot".into(),
        TaskState::Analyzing => "Reading the formats…".into(),
        TaskState::Processing => "Preparing the file…".into(),
        _ => {
            let mut parts = vec![match item.total {
                Some(total) => format!("{} of {}", human_size(item.downloaded), human_size(total)),
                None => human_size(item.downloaded),
            }];
            if item.speed > 0.0 {
                parts.push(format!("{:.1} MB/s", item.speed / (1024.0 * 1024.0)));
            }
            if let Some(eta) = item.eta {
                parts.push(time_left(eta));
            }
            parts.join(" · ")
        }
    }
}

fn time_left(secs: u64) -> String {
    match secs {
        0..60 => "less than a minute left".into(),
        60..3600 => format!("{} min left", secs.div_ceil(60)),
        _ => format!("{} h {} min left", secs / 3600, (secs % 3600) / 60),
    }
}

#[cfg(target_os = "android")]
pub use android::{init, spawn};

#[cfg(target_os = "android")]
mod android {
    use std::sync::{Arc, Mutex};
    use std::time::Duration;

    use download_engine::Manager;
    use serde::Deserialize;
    use tauri::plugin::{Builder, PluginHandle, TauriPlugin};
    use tauri::{Manager as _, Wry};

    use super::{Action, Board};

    pub struct DownloadsNotifier(PluginHandle<Wry>);

    pub fn init() -> TauriPlugin<Wry> {
        Builder::new("downloads-notify")
            .setup(|app, api| {
                let handle = api.register_android_plugin("org.miarina.media", "DownloadsPlugin")?;
                app.manage(DownloadsNotifier(handle));
                Ok(())
            })
            .build()
    }

    #[derive(Deserialize)]
    struct Reply {
        #[serde(default)]
        actions: Vec<Action>,
    }

    /// Once a second: sends the board when it changed (or while downloads
    /// run, to collect button presses) and applies the pressed buttons.
    pub fn spawn(app: &tauri::AppHandle, board: Arc<Mutex<Board>>, manager: Manager) {
        let Some(notifier) = app.try_state::<DownloadsNotifier>() else {
            return;
        };
        let handle = notifier.0.clone();
        tauri::async_runtime::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(1)).await;
                let update = board.lock().unwrap_or_else(|p| p.into_inner()).take();
                let Some(update) = update else { continue };
                let Ok(reply) = handle
                    .run_mobile_plugin_async::<Reply>("update", update)
                    .await
                else {
                    continue;
                };
                for action in reply.actions {
                    match action.action.as_str() {
                        "pause" => drop(manager.pause(&action.id)),
                        "cancel" => drop(manager.cancel(&action.id)),
                        "pause_all" => manager.pause_all(),
                        _ => {}
                    }
                }
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use download_engine::{Progress, ProgressEvent, Stage};
    use storage::{MediaKind, TaskRecord};

    fn task(id: &str, state: TaskState, position: i64) -> TaskRecord {
        TaskRecord {
            id: id.into(),
            url: format!("https://example.org/{id}.mp4"),
            source_host: "example.org".into(),
            title: format!("Movie {id}"),
            kind: MediaKind::Video,
            engine: "http".into(),
            format_id: None,
            format_label: "MP4".into(),
            state,
            position,
            dest_dir: "/x".into(),
            file_name: format!("{id}.mp4"),
            part_path: None,
            final_path: None,
            total_bytes: Some(1_200 * 1024 * 1024),
            downloaded_bytes: 0,
            supports_resume: true,
            attempts: 0,
            error_code: None,
            error_message: None,
            created_at: 0,
            updated_at: 0,
            completed_at: None,
            thumbnail: None,
        }
    }

    fn progress(id: &str, downloaded: u64) -> ManagerEvent {
        ManagerEvent::Progress(ProgressEvent {
            id: id.into(),
            progress: Progress {
                downloaded,
                total: Some(1_200 * 1024 * 1024),
                bytes_per_sec: 6.4 * 1024.0 * 1024.0,
                supports_resume: true,
                stage: Stage::Downloading,
            },
            eta_secs: Some(70),
        })
    }

    #[test]
    fn the_notification_follows_the_design() {
        let mut board = Board::default();
        board.on_event(&ManagerEvent::Task(task("a", TaskState::Downloading, 1)));
        board.on_event(&ManagerEvent::Task(task("b", TaskState::Queued, 2)));
        board.on_event(&progress("a", 712 * 1024 * 1024));
        let update = board.take().unwrap();
        assert_eq!(update.active.len(), 2);
        assert_eq!(update.active[0].title, "Movie a");
        assert_eq!(update.active[0].percent, 59);
        assert_eq!(
            update.active[0].text,
            "712 MB of 1.17 GB · 6.4 MB/s · 2 min left"
        );
        assert_eq!(update.active[1].text, "Waiting for a free slot");
        // While downloads run, the full list is sent again (never empty).
        assert_eq!(board.take().unwrap().active.len(), 2);

        board.on_event(&ManagerEvent::Task(task("a", TaskState::Completed, 1)));
        let update = board.take().unwrap();
        assert_eq!(update.active.len(), 1);
        assert_eq!(update.finished[0].title, "Movie a");
        assert_eq!(update.finished[0].text, "1.17 GB · tap to play");
    }

    #[test]
    fn paused_and_old_tasks_stop_the_service() {
        let mut board = Board::default();
        // Completed without having been followed: not announced.
        board.on_event(&ManagerEvent::Task(task("old", TaskState::Completed, 1)));
        assert!(board.take().unwrap().finished.is_empty());
        board.on_event(&ManagerEvent::Task(task("a", TaskState::Downloading, 1)));
        assert!(board.has_active());
        board.on_event(&ManagerEvent::Task(task("a", TaskState::Paused, 1)));
        assert!(!board.has_active());
        let update = board.take().unwrap();
        assert!(update.active.is_empty() && update.finished.is_empty());
        assert!(board.take().is_none(), "idle and unchanged");
    }

    #[test]
    fn processing_and_unknown_sizes_are_indeterminate() {
        let mut board = Board::default();
        let mut unknown = task("u", TaskState::Downloading, 1);
        unknown.total_bytes = None;
        board.on_event(&ManagerEvent::Task(unknown));
        board.on_event(&ManagerEvent::Task(task("p", TaskState::Processing, 2)));
        let update = board.take().unwrap();
        assert!(update.active.iter().all(|a| a.percent == -1));
        assert!(
            update
                .active
                .iter()
                .any(|a| a.text == "Preparing the file…")
        );
    }
}

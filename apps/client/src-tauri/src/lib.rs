mod commands;
mod state;

use std::sync::{Arc, Mutex};

use download_engine::components::Components;
use download_engine::{HttpEngine, Manager, ManagerEvent, RetryPolicy, YtDlpEngine};
use storage::Storage;
use tauri::{Emitter, Manager as _, RunEvent};
use tokio::sync::mpsc;

use state::AppState;

/// Event carrying every download manager notification to the UI.
pub const DOWNLOAD_EVENT: &str = "downloads://event";
/// Sized for bursts; progress is throttled upstream (≤ 1 Hz per task).
const EVENT_BUFFER: usize = 1024;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let data_dir = app.path().app_data_dir()?;
            std::fs::create_dir_all(&data_dir)?;
            let storage = Arc::new(Mutex::new(Storage::open(&data_dir.join("miarina.db"))?));
            let default_download_dir = app
                .path()
                .video_dir()
                .or_else(|_| app.path().download_dir())?
                .join("Miarina");

            let http = HttpEngine::new()?;
            // yt-dlp and FFmpeg are downloaded on first use into app data.
            let ytdlp = YtDlpEngine::new(Components::new(data_dir.join("components"))?);
            let (tx, mut rx) = mpsc::channel::<ManagerEvent>(EVENT_BUFFER);
            let manager = Manager::new(
                storage.clone(),
                vec![Arc::new(http.clone()), Arc::new(ytdlp.clone())],
                resource_manager::limits(
                    Default::default(),
                    state::PLATFORM,
                    state::DEFAULT_CONCURRENCY,
                    state::cpu_count(),
                ),
                RetryPolicy::default(),
                tx,
            );
            let state = AppState {
                storage,
                manager: manager.clone(),
                http,
                ytdlp,
                default_download_dir,
                install_lock: tokio::sync::Mutex::new(()),
            };
            // Apply the persisted settings before anything is scheduled.
            state.apply_limits();
            app.manage(state);

            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                while let Some(event) = rx.recv().await {
                    let _ = handle.emit(DOWNLOAD_EVENT, event);
                }
            });
            tauri::async_runtime::spawn(async move {
                if let Err(err) = manager.start() {
                    eprintln!("download manager failed to start: {err}");
                }
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::validate_media_url,
            commands::analyze_link,
            commands::downloads_list,
            commands::downloads_start,
            commands::downloads_pause,
            commands::downloads_resume,
            commands::downloads_cancel,
            commands::downloads_retry,
            commands::downloads_start_now,
            commands::downloads_move,
            commands::downloads_pause_all,
            commands::downloads_resume_all,
            commands::downloads_reveal,
            commands::history_list,
            commands::history_clear,
            commands::history_reveal,
            commands::settings_get,
            commands::settings_set_concurrency,
            commands::settings_set_resource_mode,
            commands::settings_pick_download_dir,
            commands::components_status,
            commands::components_install,
        ])
        .build(tauri::generate_context!())
        .expect("error while building Miarina Media");

    app.run(|handle, event| {
        if let RunEvent::Exit = event {
            // Flush partial files so interrupted downloads stay resumable.
            let manager = handle.state::<AppState>().manager.clone();
            tauri::async_runtime::block_on(manager.shutdown());
        }
    });
}

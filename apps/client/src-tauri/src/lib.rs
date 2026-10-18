#[cfg(target_os = "android")]
mod android_tls;
mod browser;
mod commands;
#[cfg(target_os = "android")]
mod media_tools;
mod player;
mod shared_storage;
mod shell;
mod state;

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use download_engine::components::Components;
use download_engine::{HttpEngine, Manager, ManagerEvent, RetryPolicy, YtDlpEngine};
use library::Library;
use media_core::TaskState;
use storage::Storage;
use tauri::{AppHandle, Emitter, Manager as _, RunEvent};
use tokio::sync::mpsc;

use state::AppState;

/// Event carrying every download manager notification to the UI.
pub const DOWNLOAD_EVENT: &str = "downloads://event";
/// Emitted when library rows changed (added, probed, renamed, removed).
pub const LIBRARY_EVENT: &str = "library://changed";
/// Sized for bursts; progress is throttled upstream (≤ 1 Hz per task).
const EVENT_BUFFER: usize = 1024;

/// Lets the WebView stream files of `dir` through the asset protocol
/// (HTTP range requests, nothing loaded in memory). Only library and
/// thumbnail folders are ever allowed.
pub fn allow_media_dir(app: &AppHandle, dir: &Path) {
    if let Err(err) = app.asset_protocol_scope().allow_directory(dir, true) {
        eprintln!("could not allow {}: {err}", dir.display());
    }
}

/// Indexes the library folder without blocking the async runtime.
pub fn scan_library(library: &Library, dir: PathBuf) {
    let library = library.clone();
    tauri::async_runtime::spawn_blocking(move || {
        if let Err(err) = library.scan(&dir) {
            eprintln!("library scan failed: {err}");
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init());
    #[cfg(target_os = "android")]
    let builder = builder
        .plugin(player::init())
        .plugin(shell::init())
        .plugin(media_tools::init());
    let app = builder
        .setup(|app| {
            #[cfg(target_os = "android")]
            android_tls::init()?;
            let data_dir = app.path().app_data_dir()?;
            std::fs::create_dir_all(&data_dir)?;
            let storage = Arc::new(Mutex::new(Storage::open(&data_dir.join("miarina.db"))?));
            let app_download_dir = app
                .path()
                .video_dir()
                .or_else(|_| app.path().download_dir())?
                .join("Miarina");
            // Android 11+: shared Movies/Miarina and Music/Miarina (gallery,
            // kept after uninstall). Elsewhere: the folder above.
            #[cfg(target_os = "android")]
            let shared =
                shared_storage::shared_dirs(&app_download_dir, shared_storage::sdk_level());
            #[cfg(not(target_os = "android"))]
            let shared: Option<shared_storage::SharedDirs> = None;
            let default_download_dir = shared
                .as_ref()
                .map_or_else(|| app_download_dir.clone(), |d| d.video.clone());
            let audio_download_dir = shared.as_ref().map(|d| d.audio.clone());
            // Shared folders only accept media files: temporary files stay
            // in the app's own folder on the same storage (`files/partial`).
            let staging_dir = shared.as_ref().and(
                app_download_dir
                    .parent()
                    .and_then(Path::parent)
                    .map(|files| files.join("partial")),
            );

            let http = HttpEngine::new()?;
            // yt-dlp and FFmpeg ship with the Windows installer (`tools/`);
            // if they are missing they are downloaded on first use into app data.
            #[allow(unused_mut)]
            let mut components = Components::new(data_dir.join("components"))?;
            #[cfg(windows)]
            if let Ok(resources) = app.path().resource_dir() {
                components = components.with_bundled(resources.join("tools"));
            }
            let ytdlp = YtDlpEngine::new(components.clone());
            let handle = app.handle().clone();
            let library = Library::new(
                storage.clone(),
                components,
                data_dir.join("thumbnails"),
                Arc::new(move || {
                    let _ = handle.emit(LIBRARY_EVENT, ());
                }),
            );

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
            if let Some(dir) = &staging_dir {
                manager.set_staging_dir(dir.clone());
            }
            let state = AppState {
                storage: storage.clone(),
                manager: manager.clone(),
                http,
                ytdlp,
                library: library.clone(),
                default_download_dir,
                audio_download_dir: audio_download_dir.clone(),
                staging_dir: staging_dir.clone(),
                install_lock: tokio::sync::Mutex::new(()),
            };
            // Apply the persisted settings before anything is scheduled.
            let settings = state.apply_limits();
            app.manage(state);
            app.manage(browser::BrowserState::default());

            // Media playback and thumbnails go through the asset protocol.
            let download_dir = PathBuf::from(&settings.download_dir);
            allow_media_dir(app.handle(), &download_dir);
            allow_media_dir(app.handle(), library.thumbnails_dir());
            let known_dirs: Vec<PathBuf> = storage
                .lock()
                .map(|s| s.media_paths().unwrap_or_default())
                .unwrap_or_default()
                .into_iter()
                .filter_map(|(_, path, _)| Path::new(&path).parent().map(Path::to_path_buf))
                .collect();
            for dir in known_dirs {
                allow_media_dir(app.handle(), &dir);
            }

            // Android: metadata and thumbnails through platform APIs.
            #[cfg(target_os = "android")]
            if let Some(tools) = app.try_state::<media_tools::MediaTools>() {
                library.set_prober(tools.prober());
            }
            tauri::async_runtime::spawn(library.clone().run_worker());
            // Shared folders, plus the app folder used before Android 11
            // storage support (earlier downloads stay in the library).
            for dir in [
                Some(download_dir.clone()),
                audio_download_dir,
                Some(app_download_dir),
            ]
            .into_iter()
            .flatten()
            .filter(|d| *d == download_dir || d.is_dir())
            {
                scan_library(&library, dir);
            }

            // Android: finished downloads in shared folders are published to
            // the system media index (gallery, music apps).
            #[cfg(target_os = "android")]
            let publisher = shared.clone().zip(
                app.try_state::<media_tools::MediaTools>()
                    .map(|t| t.publisher()),
            );
            let handle = app.handle().clone();
            let completed_library = library.clone();
            tauri::async_runtime::spawn(async move {
                while let Some(event) = rx.recv().await {
                    // A finished download joins the library right away.
                    if let ManagerEvent::Task(task) = &event
                        && task.state == TaskState::Completed
                        && let Some(path) = &task.final_path
                    {
                        #[cfg(target_os = "android")]
                        if let Some((dirs, publisher)) = &publisher {
                            let file = PathBuf::from(path);
                            if file.starts_with(&dirs.video) || file.starts_with(&dirs.audio) {
                                let publisher = publisher.clone();
                                tauri::async_runtime::spawn(async move {
                                    if !publisher.publish(&file).await {
                                        eprintln!("could not publish a download to the gallery");
                                    }
                                });
                            }
                        }
                        let _ = completed_library.add_download(
                            Path::new(path),
                            &task.source_host,
                            &task.url,
                            &task.id,
                            task.thumbnail.as_deref().map(Path::new),
                        );
                    }
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
            commands::library_query,
            commands::library_overview,
            commands::library_get,
            commands::library_rename,
            commands::library_delete,
            commands::library_reveal,
            commands::library_rescan,
            commands::library_open_external,
            commands::downloads_open_folder,
            commands::storage_usage,
            commands::storage_clear_thumbnails,
            commands::storage_clean_temp,
            browser::browser_open,
            browser::browser_navigate,
            browser::browser_nav,
            browser::browser_state,
            browser::browser_sheet,
            browser::browser_fab_size,
            browser::browser_show_in_app,
            player::player_open,
            player::player_status,
            player::player_play,
            player::player_pause,
            player::player_seek,
            player::player_rate,
            player::player_surface,
            player::player_close,
            shell::app_ready,
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

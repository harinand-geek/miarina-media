#[cfg(target_os = "android")]
mod android_extractor;
#[cfg(target_os = "android")]
mod android_tls;
mod browser;
#[cfg(windows)]
mod browser_bridge;
mod commands;
mod data_guard;
mod device_media;
mod download_notifications;
mod m3u;
#[cfg(target_os = "android")]
mod media_tools;
mod native_player;
mod open_media;
mod playback_state;
mod player;
mod playlists;
mod shared_storage;
mod shell;
mod state;
#[cfg(windows)]
mod torrents;
mod updates;

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use download_engine::components::Components;
use download_engine::{HttpEngine, Manager, ManagerEvent, RetryPolicy, YtDlpEngine};
use library::Library;
use media_core::TaskState;
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

/// Checks for a newer yt-dlp a few minutes after start, then hourly, and
/// installs it when the last check is more than a day old. Failures (e.g.
/// offline) are retried on the next round; nothing is shown to the user.
#[cfg(windows)]
fn spawn_ytdlp_updates(app: AppHandle) {
    use std::time::Duration;
    tauri::async_runtime::spawn(async move {
        tokio::time::sleep(Duration::from_secs(120)).await;
        loop {
            let state = app.state::<AppState>();
            let last: i64 = state
                .storage()
                .setting(commands::KEY_YTDLP_CHECKED_AT)
                .ok()
                .flatten()
                .unwrap_or(0);
            if storage::now_ms() - last >= commands::YTDLP_CHECK_INTERVAL_MS {
                // Settings reads the active version when opened.
                if let Err(err) = commands::check_ytdlp_update(&state).await {
                    eprintln!("yt-dlp update check failed: {}", err.message);
                }
            }
            tokio::time::sleep(Duration::from_secs(3600)).await;
        }
    });
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
    let context = tauri::generate_context!();
    // UPD-10: before any window exists (see `data_guard`).
    #[cfg(windows)]
    let early = data_guard::open_early(
        &context.config().identifier,
        &context.package_info().version.to_string(),
    );
    #[cfg(not(windows))]
    let early: Option<data_guard::Opened> = None;
    let builder = tauri::Builder::default()
        .manage(updates::Updates::default())
        .plugin(tauri_plugin_dialog::init())
        // Its click script would run in every webview, browser pages
        // included, and swallow their target=_blank links (the frontend has
        // no opener permission anyway): Rust opens URLs itself.
        .plugin(
            tauri_plugin_opener::Builder::new()
                .open_js_links_on_click(false)
                .build(),
        );
    #[cfg(target_os = "android")]
    let builder = builder
        .plugin(player::init())
        .plugin(shell::init())
        .plugin(media_tools::init())
        .plugin(device_media::init())
        .plugin(download_notifications::init())
        .plugin(android_extractor::init())
        .plugin(browser::init());
    let app = builder
        .setup(move |app| {
            #[cfg(target_os = "android")]
            android_tls::init()?;
            let data_dir = app.path().app_data_dir()?;
            #[cfg(windows)]
            app.manage(torrents::TorrentState::default());
            std::fs::create_dir_all(&data_dir)?;
            // UPD-10: copy before migrating, never open a newer schema.
            let (storage, _upgrade) = match early {
                Some(opened) if opened.dir == data_dir => (opened.storage, opened.upgrade),
                _ => data_guard::open(&data_dir, &app.package_info().version.to_string())?,
            };
            let storage = Arc::new(Mutex::new(storage));
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
            // Video engine of the Windows player (decision 0005), started on
            // first use; without it the WebView2 player is used.
            app.manage(native_player::NativePlayer::new(components.libvlc_dir()));
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
            #[cfg(all(windows, feature = "mdm-http"))]
            let transfer_http: Arc<dyn download_engine::Engine> =
                Arc::new(miarina_mdm_adapter::MdmEngine::new(http.clone()));
            #[cfg(not(all(windows, feature = "mdm-http")))]
            let transfer_http: Arc<dyn download_engine::Engine> = Arc::new(http.clone());
            let manager = Manager::new(
                storage.clone(),
                vec![transfer_http, Arc::new(ytdlp.clone())],
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
            // UPD-03: a finished update download stays ready; leftovers of
            // an installed or abandoned one are removed.
            updates::restore(app.handle());

            // Media playback and thumbnails go through the asset protocol.
            let download_dir = PathBuf::from(&settings.download_dir);
            allow_media_dir(app.handle(), &download_dir);
            allow_media_dir(app.handle(), library.thumbnails_dir());
            allow_media_dir(app.handle(), &library.covers_dir());
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
            // Android: music and videos already on the phone, when access
            // was granted before (AND-06). Never asks at startup.
            #[cfg(target_os = "android")]
            {
                let handle = app.handle().clone();
                let library = library.clone();
                tauri::async_runtime::spawn(async move {
                    if let Err(err) = device_media::sync(&handle, library).await {
                        eprintln!("phone media index failed: {}", err.message);
                    }
                });
            }

            // Android: finished downloads in shared folders are published to
            // the system media index (gallery, music apps).
            #[cfg(target_os = "android")]
            let publisher = shared.clone().zip(
                app.try_state::<media_tools::MediaTools>()
                    .map(|t| t.publisher()),
            );
            // Android: download notifications follow the manager's events.
            let board = Arc::new(Mutex::new(download_notifications::Board::default()));
            #[cfg(target_os = "android")]
            download_notifications::spawn(app.handle(), board.clone(), manager.clone());
            let handle = app.handle().clone();
            let completed_library = library.clone();
            tauri::async_runtime::spawn(async move {
                while let Some(event) = rx.recv().await {
                    if cfg!(target_os = "android") {
                        board
                            .lock()
                            .unwrap_or_else(|p| p.into_inner())
                            .on_event(&event);
                    }
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
            // Windows: keep yt-dlp current (verified updates, at most daily).
            #[cfg(windows)]
            spawn_ytdlp_updates(app.handle().clone());
            #[cfg(target_os = "android")]
            let extractor_app = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                #[cfg(target_os = "android")]
                if android_extractor::prepare(&extractor_app).await.is_err() {
                    eprintln!("Android media tools could not be prepared");
                }
                if let Err(err) = manager.start() {
                    eprintln!("download manager failed to start: {err}");
                }
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            updates::app_update_progress,
            updates::app_update_check,
            updates::app_update_download,
            updates::app_update_install,
            updates::app_update_status,
            updates::app_update_cancel,
            updates::app_update_prefs,
            updates::app_update_set_prefs,
            updates::app_update_auto_allowed,
            #[cfg(windows)]
            browser_bridge::browser_inbox,
            #[cfg(windows)]
            browser_bridge::browser_inbox_dismiss,
            #[cfg(windows)]
            browser_bridge::browser_bridge_register,
            #[cfg(windows)]
            browser_bridge::browser_extension_folder,
            #[cfg(windows)]
            torrents::torrents_enable,
            #[cfg(windows)]
            torrents::torrents_disable,
            #[cfg(windows)]
            torrents::torrents_list,
            #[cfg(windows)]
            torrents::torrents_preview,
            #[cfg(windows)]
            torrents::torrents_start,
            #[cfg(windows)]
            torrents::torrents_action,
            #[cfg(windows)]
            torrents::torrents_limits,
            commands::validate_media_url,
            commands::analyze_link,
            commands::downloads_list,
            commands::downloads_start,
            commands::downloads_pause,
            commands::downloads_resume,
            commands::downloads_cancel,
            commands::downloads_retry,
            commands::downloads_restart,
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
            commands::components_update_ytdlp,
            commands::library_query,
            commands::library_overview,
            commands::library_get,
            commands::library_rename,
            commands::library_tags,
            commands::library_update_tags,
            commands::library_groups,
            commands::library_remove,
            playback_state::playback_load,
            playlists::library_set_favorite,
            open_media::library_open_files,
            open_media::library_import_folder,
            native_player::native_player_status,
            native_player::native_player_open,
            native_player::native_player_control,
            native_player::native_player_volume,
            native_player::native_player_equalizer,
            native_player::native_player_add_subtitle,
            native_player::native_player_frame,
            commands::library_cover_pick,
            commands::library_cover_source,
            commands::library_cover_frame,
            commands::library_cover_remove,
            commands::library_has_source_cover,
            playlists::playlists_list,
            playlists::playlist_get,
            playlists::playlist_create,
            playlists::playlist_rename,
            playlists::playlist_delete,
            playlists::playlist_add,
            playlists::playlist_remove,
            playlists::playlist_move,
            playlists::playlist_import,
            playlists::playlist_export,
            playback_state::playback_write,
            commands::library_delete,
            commands::library_reveal,
            commands::library_rescan,
            device_media::device_media_access,
            device_media::device_media_request,
            device_media::device_media_sync,
            device_media::device_media_settings,
            commands::library_open_external,
            commands::library_share,
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
            browser::browser_frame,
            browser::browser_favorites,
            browser::browser_favorite_toggle,
            browser::browser_tab_new,
            browser::browser_tab_close,
            browser::browser_tab_select,
            browser::browser_history,
            browser::browser_history_delete,
            browser::browser_history_clear,
            player::player_open,
            player::player_queue,
            player::player_skip,
            player::player_repeat,
            player::player_status,
            player::player_play,
            player::player_pause,
            player::player_seek,
            player::player_rate,
            player::player_surface,
            player::player_close,
            player::player_fullscreen,
            player::player_tracks,
            player::player_select_track,
            player::player_pick_subtitle,
            player::player_level,
            player::player_equalizer,
            player::player_pip,
            shell::app_ready,
            shell::app_take_launch,
            shell::app_read_clipboard,
        ])
        .build(context)
        .expect("error while building Miarina Media");

    app.run(|handle, event| {
        // WIN-04: files and folders dropped on the app (not on a page of
        // the built-in browser).
        #[cfg(desktop)]
        if let RunEvent::WebviewEvent {
            label,
            event: tauri::WebviewEvent::DragDrop(tauri::DragDropEvent::Drop { paths, .. }),
            ..
        } = &event
            && label == "main"
        {
            let library = handle.state::<AppState>().library.clone();
            tauri::async_runtime::spawn(open_media::dropped(
                handle.clone(),
                library,
                paths.clone(),
            ));
        }
        if let RunEvent::Exit = event {
            #[cfg(windows)]
            tauri::async_runtime::block_on(handle.state::<torrents::TorrentState>().shutdown());
            // Flush partial files so interrupted downloads stay resumable.
            let manager = handle.state::<AppState>().manager.clone();
            tauri::async_runtime::block_on(manager.shutdown());
        }
    });
}

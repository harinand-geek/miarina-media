//! Native preparation only; Rust owns subprocesses, progress and cancellation.
use crate::{commands::CommandError, state::AppState};
use download_engine::ytdlp::runtime::AndroidRuntime;
use tauri::{AppHandle, Manager};

struct Extractor(tauri::plugin::PluginHandle<tauri::Wry>);

pub fn init() -> tauri::plugin::TauriPlugin<tauri::Wry> {
    tauri::plugin::Builder::new("media-extractor")
        .setup(|app, api| {
            app.manage(Extractor(
                api.register_android_plugin("org.miarina.media", "ExtractorPlugin")?,
            ));
            Ok(())
        })
        .build()
}

pub async fn prepare(app: &AppHandle) -> Result<(), CommandError> {
    let state = app.state::<AppState>();
    let _guard = state.install_lock.lock().await;
    if state.ytdlp.available() {
        return Ok(());
    }
    let runtime: AndroidRuntime = app
        .state::<Extractor>()
        .0
        .run_mobile_plugin_async("prepare", ())
        .await
        .map_err(|_| {
            CommandError::new(
                "extractor_init",
                "The media tools could not be prepared. Restart the app or reinstall the APK.",
            )
        })?;
    state.ytdlp.set_android_runtime(runtime).map_err(|_| {
        CommandError::new(
            "extractor_init",
            "The APK media tools are incomplete. Reinstall the APK.",
        )
    })
}

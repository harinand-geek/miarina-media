//! App shell signals. Android: `AppShellPlugin.kt` ends the launch screen
//! once the interface has rendered. Desktop has no launch screen.

use tauri::AppHandle;

use crate::commands::CommandError;

#[cfg(target_os = "android")]
pub struct AppShell(tauri::plugin::PluginHandle<tauri::Wry>);

#[cfg(target_os = "android")]
pub fn init() -> tauri::plugin::TauriPlugin<tauri::Wry> {
    use tauri::Manager;
    tauri::plugin::Builder::new("app-shell")
        .setup(|app, api| {
            let handle = api.register_android_plugin("org.miarina.media", "AppShellPlugin")?;
            app.manage(AppShell(handle));
            Ok(())
        })
        .build()
}

/// The interface has rendered its first screen.
#[tauri::command]
pub async fn app_ready(app: AppHandle) -> Result<(), CommandError> {
    #[cfg(target_os = "android")]
    {
        use tauri::Manager;
        if let Some(shell) = app.try_state::<AppShell>() {
            shell
                .0
                .run_mobile_plugin_async::<serde_json::Value>("ready", ())
                .await
                .map_err(|e| CommandError::new("app_shell", e.to_string()))?;
        }
    }
    #[cfg(not(target_os = "android"))]
    let _ = app;
    Ok(())
}

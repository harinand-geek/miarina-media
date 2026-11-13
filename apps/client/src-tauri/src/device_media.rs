//! Music and videos already on the phone (AND-06). Android:
//! `DeviceMediaPlugin.kt` asks for read access and lists the files of the
//! system media index; the library indexes them like its own folders
//! (`Library::sync_listed`). Read only. Desktop has nothing to do here: its
//! library imports folders and files instead (WIN-04).

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, State};

use crate::commands::{CmdResult, CommandError};
use crate::state::AppState;

/// Read access to the phone's media: `granted`, `denied` (refused for
/// good: only the system settings can change it), `prompt`
/// (or `prompt-with-rationale`), or `unsupported` on desktop.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DeviceAccess {
    pub audio: String,
    pub video: String,
}

impl DeviceAccess {
    #[cfg_attr(target_os = "android", allow(dead_code))]
    fn unsupported() -> Self {
        Self {
            audio: "unsupported".into(),
            video: "unsupported".into(),
        }
    }

    #[cfg_attr(not(target_os = "android"), allow(dead_code))]
    pub fn any_granted(&self) -> bool {
        self.audio == "granted" || self.video == "granted"
    }
}

#[cfg(target_os = "android")]
pub struct DeviceMedia(tauri::plugin::PluginHandle<tauri::Wry>);

#[cfg(target_os = "android")]
pub fn init() -> tauri::plugin::TauriPlugin<tauri::Wry> {
    use tauri::Manager;
    tauri::plugin::Builder::new("device-media")
        .setup(|app, api| {
            let handle = api.register_android_plugin("org.miarina.media", "DeviceMediaPlugin")?;
            app.manage(DeviceMedia(handle));
            Ok(())
        })
        .build()
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
fn plugin_error(e: impl std::fmt::Display) -> CommandError {
    CommandError::new("device_media", e.to_string())
}

#[cfg(target_os = "android")]
async fn run<T: serde::de::DeserializeOwned>(app: &AppHandle, command: &str) -> CmdResult<T> {
    use tauri::Manager;
    let plugin = app
        .try_state::<DeviceMedia>()
        .ok_or_else(|| plugin_error("device media unavailable"))?;
    plugin
        .0
        .run_mobile_plugin_async(command, ())
        .await
        .map_err(plugin_error)
}

/// Lists the phone's media the granted access allows and indexes them.
/// Returns the access state; nothing is indexed without access.
pub async fn sync(app: &AppHandle, library: library::Library) -> CmdResult<DeviceAccess> {
    #[cfg(target_os = "android")]
    {
        #[derive(Deserialize)]
        struct Listed {
            #[serde(flatten)]
            access: DeviceAccess,
            #[serde(default)]
            paths: Vec<String>,
        }
        let listed: Listed = run(app, "list").await?;
        if !listed.access.any_granted() {
            return Ok(listed.access);
        }
        let paths: Vec<std::path::PathBuf> =
            listed.paths.iter().map(std::path::PathBuf::from).collect();
        let mut dirs: Vec<std::path::PathBuf> = paths
            .iter()
            .filter_map(|p| p.parent().map(std::path::Path::to_path_buf))
            .collect();
        dirs.sort();
        dirs.dedup();
        for dir in &dirs {
            crate::allow_media_dir(app, dir);
        }
        tauri::async_runtime::spawn_blocking(move || library.sync_listed(&paths))
            .await
            .map_err(plugin_error)?
            .map_err(|e| CommandError::new("library", e.to_string()))?;
        Ok(listed.access)
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = (app, library);
        Ok(DeviceAccess::unsupported())
    }
}

/// Current access, without asking.
#[tauri::command]
pub async fn device_media_access(app: AppHandle) -> CmdResult<DeviceAccess> {
    #[cfg(target_os = "android")]
    return run(&app, "access").await;
    #[cfg(not(target_os = "android"))]
    {
        let _ = app;
        Ok(DeviceAccess::unsupported())
    }
}

/// Shows the system permission dialogs, then indexes what became
/// readable. Only ever started by a tap in Music.
#[tauri::command]
pub async fn device_media_request(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<DeviceAccess> {
    #[cfg(target_os = "android")]
    {
        let access: DeviceAccess = run(&app, "request").await?;
        if !access.any_granted() {
            return Ok(access);
        }
        sync(&app, state.library.clone()).await
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = (app, state);
        Ok(DeviceAccess::unsupported())
    }
}

/// Indexes the phone's media again (pull to refresh, return to the app).
#[tauri::command]
pub async fn device_media_sync(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<DeviceAccess> {
    sync(&app, state.library.clone()).await
}

/// Opens the app's page in the system settings, where a refusal is undone.
#[tauri::command]
pub async fn device_media_settings(app: AppHandle) -> CmdResult<()> {
    #[cfg(target_os = "android")]
    {
        let _: serde_json::Value = run(&app, "openSettings").await?;
        Ok(())
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = app;
        Err(CommandError::new(
            "unsupported_platform",
            "System settings are opened on Android only.",
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn access_reads_the_plugin_reply() {
        let a: DeviceAccess =
            serde_json::from_str(r#"{"audio":"granted","video":"denied"}"#).unwrap();
        assert!(a.any_granted());
        let b: DeviceAccess =
            serde_json::from_str(r#"{"audio":"prompt","video":"denied"}"#).unwrap();
        assert!(!b.any_granted());
        assert!(!DeviceAccess::unsupported().any_granted());
    }
}

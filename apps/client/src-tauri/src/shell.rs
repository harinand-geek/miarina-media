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

/// First http(s) link in text shared by another app ("Title https://youtu.be/x"),
/// validated like a pasted link. `None` when there is none.
#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub fn extract_shared_link(text: &str) -> Option<String> {
    let start = text.find("https://").or_else(|| text.find("http://"))?;
    let candidate: String = text[start..]
        .chars()
        .take_while(|c| !c.is_whitespace())
        .collect();
    let candidate = candidate.trim_end_matches(['.', ',', ';', ')', ']', '"', '\'', '»']);
    media_core::validate_media_url(candidate)
        .ok()
        .map(|url| url.as_str().to_owned())
}

/// What Android asked the app to open since the last call, taken once:
/// a link shared from another app, or the task of a tapped "Download
/// complete" notification. Always empty on desktop.
#[derive(Debug, Default, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchRequest {
    pub link: Option<String>,
    pub play_task: Option<String>,
}

/// Task ids are short alphanumeric strings (`commands::new_task_id`).
#[cfg_attr(not(target_os = "android"), allow(dead_code))]
fn valid_task_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 32 && id.bytes().all(|b| b.is_ascii_alphanumeric())
}

#[tauri::command]
pub async fn app_take_launch(app: AppHandle) -> Result<LaunchRequest, CommandError> {
    #[cfg(target_os = "android")]
    {
        use tauri::Manager;
        #[derive(serde::Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct Taken {
            text: Option<String>,
            play_task: Option<String>,
        }
        let Some(shell) = app.try_state::<AppShell>() else {
            return Ok(LaunchRequest::default());
        };
        let taken: Taken = shell
            .0
            .run_mobile_plugin_async("takeShared", ())
            .await
            .map_err(|e| CommandError::new("app_shell", e.to_string()))?;
        Ok(LaunchRequest {
            link: taken.text.as_deref().and_then(extract_shared_link),
            play_task: taken.play_task.filter(|id| valid_task_id(id)),
        })
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = app;
        Ok(LaunchRequest::default())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_link_is_found_in_shared_text() {
        assert_eq!(
            extract_shared_link("SIMONDA - LOVE https://youtu.be/jkRyWwKqVs4?si=abc").as_deref(),
            Some("https://youtu.be/jkRyWwKqVs4?si=abc")
        );
        assert_eq!(
            extract_shared_link("Look (https://example.org/a.mp4).").as_deref(),
            Some("https://example.org/a.mp4")
        );
        assert_eq!(extract_shared_link("no link here"), None);
        assert_eq!(extract_shared_link("ftp://example.org/a.mp4"), None);
        assert_eq!(extract_shared_link("https://user:pw@example.org/a"), None);
    }

    #[test]
    fn notification_task_ids_are_checked() {
        assert!(valid_task_id("1a14db099960002"));
        assert!(!valid_task_id(""));
        assert!(!valid_task_id("../x"));
        assert!(!valid_task_id(&"a".repeat(40)));
    }
}

use crate::commands::CommandError;
use miarina_browser_bridge::{Entry, HOST};
use std::path::PathBuf;
use tauri::{AppHandle, Manager};
use tauri_plugin_opener::OpenerExt;

type Result<T> = std::result::Result<T, CommandError>;
fn err(_: impl std::fmt::Display) -> CommandError {
    CommandError::new(
        "browser_bridge",
        "Browser connection could not be updated. Check the extension ID and that the bridge is installed.",
    )
}
fn inbox(app: &AppHandle) -> Result<PathBuf> {
    Ok(app
        .path()
        .app_data_dir()
        .map_err(err)?
        .join("browser-inbox"))
}

#[tauri::command]
pub fn browser_inbox(app: AppHandle) -> Result<Vec<Entry>> {
    miarina_browser_bridge::inbox(&inbox(&app)?).map_err(err)
}
#[tauri::command]
pub fn browser_inbox_dismiss(app: AppHandle, id: String) -> Result<()> {
    miarina_browser_bridge::dismiss(&inbox(&app)?, &id).map_err(err)
}

fn registration(browser: &str, id: &str) -> Result<(String, serde_json::Value)> {
    let (vendor, access) = match browser {
        "chrome" | "edge" if id.len() == 32 && id.bytes().all(|b| (b'a'..=b'p').contains(&b)) => (
            if browser == "chrome" {
                "Google\\Chrome"
            } else {
                "Microsoft\\Edge"
            },
            serde_json::json!({"allowed_origins": [format!("chrome-extension://{id}/")]}),
        ),
        "firefox" => (
            "Mozilla",
            serde_json::json!({"allowed_extensions": ["miarina-media@miarina.org"]}),
        ),
        _ => return Err(err("invalid browser or ID")),
    };
    Ok((
        format!("HKCU\\Software\\{vendor}\\NativeMessagingHosts\\{HOST}"),
        access,
    ))
}

#[tauri::command]
pub async fn browser_bridge_register(
    app: AppHandle,
    browser: String,
    extension_id: String,
    enabled: bool,
) -> Result<()> {
    let (key, access) = registration(&browser, &extension_id)?;
    let dir = app
        .path()
        .app_data_dir()
        .map_err(err)?
        .join("browser-bridge");
    std::fs::create_dir_all(&dir).map_err(err)?;
    let manifest = dir.join(format!("{browser}.json"));
    if enabled {
        let bundled = app
            .path()
            .resource_dir()
            .map_err(err)?
            .join("tools/bridge/miarina-browser-bridge.exe");
        let sibling = std::env::current_exe()
            .map_err(err)?
            .with_file_name("miarina-browser-bridge.exe");
        let host = if bundled.is_file() { bundled } else { sibling };
        if !host.is_file() {
            return Err(CommandError::new(
                "bridge_missing",
                "The browser bridge is missing. Install a build that includes the browser extension.",
            ));
        }
        let mut doc = serde_json::json!({"name":HOST, "description":"Miarina Media browser connection", "path":host, "type":"stdio"});
        for (k, v) in access.as_object().unwrap() {
            doc[k] = v.clone();
        }
        std::fs::write(&manifest, serde_json::to_vec_pretty(&doc).map_err(err)?).map_err(err)?;
    }
    let status = tauri::async_runtime::spawn_blocking(move || {
        use std::os::windows::process::CommandExt;
        let exe =
            PathBuf::from(std::env::var_os("SystemRoot").unwrap_or_else(|| "C:\\Windows".into()))
                .join("System32/reg.exe");
        let mut command = std::process::Command::new(exe);
        if enabled {
            command
                .args(["ADD", &key, "/ve", "/t", "REG_SZ", "/d"])
                .arg(manifest)
                .arg("/f");
        } else {
            command.args(["DELETE", &key, "/f"]);
        }
        command.creation_flags(0x08000000).output()
    })
    .await
    .map_err(err)?
    .map_err(err)?;
    if !status.status.success() {
        return Err(err("registry failed"));
    }
    Ok(())
}

#[tauri::command]
pub fn browser_extension_folder(app: AppHandle) -> Result<()> {
    let bundled = app
        .path()
        .resource_dir()
        .map_err(err)?
        .join("browser-extension");
    let folder = if bundled.is_dir() {
        bundled
    } else {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../browser-extension")
    };
    if !folder.is_dir() {
        return Err(err("extension missing"));
    }
    app.opener()
        .open_path(folder.to_string_lossy(), None::<&str>)
        .map_err(err)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn registration_restricts_origins_and_registry_paths() {
        assert!(registration("chrome", "invalid").is_err());
        assert!(registration("..\\other", &"a".repeat(32)).is_err());
        let (key, access) = registration("chrome", &"a".repeat(32)).unwrap();
        assert!(key.starts_with("HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\"));
        assert_eq!(
            access["allowed_origins"][0],
            format!("chrome-extension://{}/", "a".repeat(32))
        );
    }
}

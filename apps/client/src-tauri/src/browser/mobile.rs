//! Mobile placeholder: the desktop browser window does not exist on
//! Android/iOS. Commands keep their names so one handler list serves every
//! platform.

use tauri::AppHandle;

use crate::commands::CommandError;

#[derive(Default)]
pub struct BrowserState;

fn unavailable() -> CommandError {
    CommandError::new(
        "browser_unavailable",
        "The built-in browser is not available on this platform yet",
    )
}

#[tauri::command]
pub async fn browser_open(_app: AppHandle, _url: Option<String>) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn browser_navigate(_app: AppHandle, _address: String) -> Result<String, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn browser_nav(_app: AppHandle, _action: String) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub fn browser_state() -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn browser_sheet(_app: AppHandle, _open: bool) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub fn browser_fab_size(_width: f64, _height: f64) {}

#[tauri::command]
pub fn browser_show_in_app(_screen: String) -> Result<(), CommandError> {
    Err(unavailable())
}

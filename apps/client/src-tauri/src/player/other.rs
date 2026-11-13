//! Desktop: playback runs in the WebView (asset protocol). Same command
//! names as Android so one handler list serves every platform.

use crate::commands::CommandError;

use super::{PlayerStatus, SurfaceRect};

fn unavailable() -> CommandError {
    CommandError::new(
        "unsupported_platform",
        "The native player is only used on Android",
    )
}

#[tauri::command]
pub async fn player_open(
    _ids: Vec<i64>,
    _index: usize,
    _position_secs: f64,
) -> Result<bool, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_queue(_ids: Vec<i64>, _current_index: usize) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_skip(_index: usize) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_repeat(_mode: String) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_status() -> Result<PlayerStatus, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_play() -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_pause() -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_seek(_position_secs: f64) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_rate(_rate: f64) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_surface(_rect: SurfaceRect) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_close() -> Result<PlayerStatus, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_fullscreen(_on: bool, _landscape: bool) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_tracks() -> Result<serde_json::Value, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_select_track(kind: String, id: Option<String>) -> Result<(), CommandError> {
    super::check_track(&kind, id)?;
    Err(unavailable())
}

#[tauri::command]
pub async fn player_pick_subtitle() -> Result<serde_json::Value, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn player_level(kind: String, value: Option<f64>) -> Result<f64, CommandError> {
    super::check_level(&kind, value)?;
    Err(unavailable())
}

#[tauri::command]
pub async fn player_pip(_enter: bool) -> Result<bool, CommandError> {
    Err(unavailable())
}

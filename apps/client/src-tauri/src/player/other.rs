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
pub async fn player_open(_id: i64, _position_secs: f64) -> Result<bool, CommandError> {
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

//! Android: forwards to `NativePlayerPlugin.kt` (Media3). The file to play
//! is resolved here from the library id; the page never passes a path.

use serde::Serialize;
use serde::de::DeserializeOwned;
use tauri::plugin::{Builder, PluginHandle, TauriPlugin};
use tauri::{Manager, State, Wry};

use crate::commands::CommandError;
use crate::state::AppState;

use super::{PlayerStatus, SurfaceRect, check_rate, check_rect, to_ms};

pub struct NativePlayer(PluginHandle<Wry>);

pub fn init() -> TauriPlugin<Wry> {
    Builder::new("native-player")
        .setup(|app, api| {
            let handle = api.register_android_plugin("org.miarina.media", "NativePlayerPlugin")?;
            app.manage(NativePlayer(handle));
            Ok(())
        })
        .build()
}

impl NativePlayer {
    async fn call<T: DeserializeOwned>(
        &self,
        command: &str,
        payload: impl Serialize,
    ) -> Result<T, CommandError> {
        self.0
            .run_mobile_plugin_async(command, payload)
            .await
            .map_err(|e| CommandError::new("player", e.to_string()))
    }

    async fn run(&self, command: &str, payload: impl Serialize) -> Result<(), CommandError> {
        self.call::<serde_json::Value>(command, payload)
            .await
            .map(drop)
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct OpenArgs {
    path: String,
    position_ms: i64,
    video: bool,
}

/// Opens a library entry. Returns `true` for video (a surface is needed).
#[tauri::command]
pub async fn player_open(
    state: State<'_, AppState>,
    player: State<'_, NativePlayer>,
    id: i64,
    position_secs: f64,
) -> Result<bool, CommandError> {
    let record = state
        .library
        .check(id)
        .map_err(|_| CommandError::new("not_found", "This item is no longer in the library."))?;
    if record.missing {
        return Err(CommandError::new(
            "not_found",
            "This file is no longer on the device.",
        ));
    }
    let video = record.kind == storage::MediaKind::Video;
    let args = OpenArgs {
        path: record.path,
        position_ms: to_ms(position_secs)?,
        video,
    };
    player.run("open", args).await?;
    Ok(video)
}

#[tauri::command]
pub async fn player_status(player: State<'_, NativePlayer>) -> Result<PlayerStatus, CommandError> {
    player.call("status", ()).await
}

#[tauri::command]
pub async fn player_play(player: State<'_, NativePlayer>) -> Result<(), CommandError> {
    player.run("play", ()).await
}

#[tauri::command]
pub async fn player_pause(player: State<'_, NativePlayer>) -> Result<(), CommandError> {
    player.run("pause", ()).await
}

#[tauri::command]
pub async fn player_seek(
    player: State<'_, NativePlayer>,
    position_secs: f64,
) -> Result<(), CommandError> {
    let position_ms = to_ms(position_secs)?;
    player
        .run("seek", serde_json::json!({ "positionMs": position_ms }))
        .await
}

#[tauri::command]
pub async fn player_rate(player: State<'_, NativePlayer>, rate: f64) -> Result<(), CommandError> {
    let rate = check_rate(rate)?;
    player
        .run("setRate", serde_json::json!({ "rate": rate }))
        .await
}

#[tauri::command]
pub async fn player_surface(
    player: State<'_, NativePlayer>,
    rect: SurfaceRect,
) -> Result<(), CommandError> {
    player.run("setSurface", check_rect(rect)?).await
}

/// Stops playback; returns the last position so the UI can resume later.
#[tauri::command]
pub async fn player_close(player: State<'_, NativePlayer>) -> Result<PlayerStatus, CommandError> {
    let mut status: PlayerStatus = player.call("close", ()).await?;
    status.open = false;
    Ok(status)
}

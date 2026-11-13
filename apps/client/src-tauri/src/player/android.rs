//! Android: forwards to `NativePlayerPlugin.kt` (Media3). The file to play
//! is resolved here from the library id; the page never passes a path.

use serde::Serialize;
use serde::de::DeserializeOwned;
use tauri::plugin::{Builder, PluginHandle, TauriPlugin};
use tauri::{Manager, State, Wry};

use crate::commands::CommandError;
use crate::state::AppState;

use super::{PlayerStatus, SurfaceRect, check_queue, check_rate, check_rect, check_repeat, to_ms};

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

/// A queue entry for the native player: path and metadata come from the
/// library, so the notification and lock screen show the real tags.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct QueueItem {
    id: i64,
    path: String,
    title: String,
    artist: Option<String>,
    album: Option<String>,
    artwork: Option<String>,
    video: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct OpenArgs {
    items: Vec<QueueItem>,
    start_index: usize,
    position_ms: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct QueueArgs {
    items: Vec<QueueItem>,
    current_index: usize,
}

/// Resolves `ids` from the library, dropping entries whose file is gone;
/// returns the items and the new position of `ids[index]`.
fn resolve(
    state: &AppState,
    ids: &[i64],
    index: usize,
) -> Result<(Vec<QueueItem>, usize), CommandError> {
    check_queue(ids, index)?;
    let wanted = ids[index];
    let mut items = Vec::with_capacity(ids.len());
    let mut at = None;
    for &id in ids {
        let Ok(record) = state.library.check(id) else {
            continue;
        };
        if record.missing {
            continue;
        }
        if id == wanted && at.is_none() {
            at = Some(items.len());
        }
        items.push(QueueItem {
            id,
            video: record.kind == storage::MediaKind::Video,
            path: record.path,
            title: record.title,
            artist: record.artist,
            album: record.album,
            artwork: record.thumbnail,
        });
    }
    let at =
        at.ok_or_else(|| CommandError::new("not_found", "This file is no longer on the device."))?;
    Ok((items, at))
}

/// Opens a play queue at `index`. Returns `true` when that item is a video
/// (a surface is needed).
#[tauri::command]
pub async fn player_open(
    state: State<'_, AppState>,
    player: State<'_, NativePlayer>,
    ids: Vec<i64>,
    index: usize,
    position_secs: f64,
) -> Result<bool, CommandError> {
    let (items, start_index) = resolve(&state, &ids, index)?;
    let video = items[start_index].video;
    let args = OpenArgs {
        items,
        start_index,
        position_ms: to_ms(position_secs)?,
    };
    player.run("open", args).await?;
    Ok(video)
}

/// Reorders the queue around the current item without interrupting it.
#[tauri::command]
pub async fn player_queue(
    state: State<'_, AppState>,
    player: State<'_, NativePlayer>,
    ids: Vec<i64>,
    current_index: usize,
) -> Result<(), CommandError> {
    let (items, current_index) = resolve(&state, &ids, current_index)?;
    player
        .run(
            "setQueue",
            QueueArgs {
                items,
                current_index,
            },
        )
        .await
}

#[tauri::command]
pub async fn player_skip(
    player: State<'_, NativePlayer>,
    index: usize,
) -> Result<(), CommandError> {
    if index >= super::MAX_QUEUE {
        return Err(CommandError::new(
            "invalid_request",
            "invalid queue position",
        ));
    }
    player
        .run("skip", serde_json::json!({ "index": index }))
        .await
}

#[tauri::command]
pub async fn player_repeat(
    player: State<'_, NativePlayer>,
    mode: String,
) -> Result<(), CommandError> {
    let mode = check_repeat(&mode)?;
    player
        .run("setRepeat", serde_json::json!({ "mode": mode }))
        .await
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

/// AND-07: immersive fullscreen, landscape or portrait.
#[tauri::command]
pub async fn player_fullscreen(
    player: State<'_, NativePlayer>,
    on: bool,
    landscape: bool,
) -> Result<(), CommandError> {
    player
        .run(
            "setFullscreen",
            serde_json::json!({ "on": on, "landscape": landscape }),
        )
        .await
}

/// AND-13: audio and subtitle tracks of the current file.
#[tauri::command]
pub async fn player_tracks(
    player: State<'_, NativePlayer>,
) -> Result<serde_json::Value, CommandError> {
    player.call("tracks", ()).await
}

#[tauri::command]
pub async fn player_select_track(
    player: State<'_, NativePlayer>,
    kind: String,
    id: Option<String>,
) -> Result<(), CommandError> {
    let (kind, id) = super::check_track(&kind, id)?;
    player
        .run("selectTrack", serde_json::json!({ "kind": kind, "id": id }))
        .await
}

/// AND-13: lets the user pick a SRT / WebVTT file (system picker).
#[tauri::command]
pub async fn player_pick_subtitle(
    player: State<'_, NativePlayer>,
) -> Result<serde_json::Value, CommandError> {
    player.call("pickSubtitle", ()).await
}

/// AND-14: screen brightness or media volume, 0..1 (`None` reads it).
#[tauri::command]
pub async fn player_level(
    player: State<'_, NativePlayer>,
    kind: String,
    value: Option<f64>,
) -> Result<f64, CommandError> {
    let (kind, value) = super::check_level(&kind, value)?;
    let out: serde_json::Value = player
        .call("level", serde_json::json!({ "kind": kind, "value": value }))
        .await?;
    Ok(out["value"].as_f64().unwrap_or(0.0))
}

/// AND-08: picture-in-picture; `false` when the device cannot.
#[tauri::command]
pub async fn player_pip(
    player: State<'_, NativePlayer>,
    enter: bool,
) -> Result<bool, CommandError> {
    let out: serde_json::Value = player
        .call(if enter { "enterPip" } else { "pipSupported" }, ())
        .await?;
    Ok(out[if enter { "entered" } else { "supported" }]
        .as_bool()
        .unwrap_or(false))
}

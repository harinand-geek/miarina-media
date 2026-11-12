//! Durable playback state (CDC L02): the interface mirrors its queues,
//! resume positions and play history here, so they survive a lost or
//! damaged WebView profile (seen on Android after a forced stop).

use serde::{Deserialize, Serialize};
use storage::{PLAYBACK_IMPORTED, StorageError};
use tauri::State;

use crate::commands::{CmdResult, CommandError};
use crate::state::AppState;

/// Writes accepted in one call (the interface batches them every second).
const MAX_CHANGES: usize = 2_000;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackSnapshot {
    /// False until the WebView's older local copy has been imported once.
    pub imported: bool,
    pub entries: Vec<(String, String)>,
}

#[derive(Debug, Deserialize)]
pub struct PlaybackChange {
    pub key: String,
    /// `None` removes the key.
    pub value: Option<String>,
}

fn refused(err: StorageError) -> CommandError {
    match err {
        StorageError::Invalid(message) => CommandError::new("invalid_playback_state", message),
        other => other.into(),
    }
}

#[tauri::command]
pub async fn playback_load(state: State<'_, AppState>) -> CmdResult<PlaybackSnapshot> {
    let storage = state.storage();
    let mut entries = storage.playback_entries()?;
    let imported = entries.iter().any(|(k, _)| k == PLAYBACK_IMPORTED);
    entries.retain(|(k, _)| k != PLAYBACK_IMPORTED);
    Ok(PlaybackSnapshot { imported, entries })
}

/// Applies a batch of writes atomically; unknown keys or oversized values
/// refuse the whole batch.
#[tauri::command]
pub async fn playback_write(
    state: State<'_, AppState>,
    changes: Vec<PlaybackChange>,
) -> CmdResult<()> {
    if changes.len() > MAX_CHANGES {
        return Err(CommandError::new(
            "invalid_playback_state",
            "too many changes in one call",
        ));
    }
    let changes: Vec<(String, Option<String>)> =
        changes.into_iter().map(|c| (c.key, c.value)).collect();
    state.storage().write_playback(&changes).map_err(refused)
}

//! Favorites and playlists commands (CDC COM-06, COM-11). Playlists only
//! reference library entries; M3U files are read and written through the
//! system file dialogs, never from a path given by the page.

use serde::Serialize;
use storage::{MediaRecord, Playlist, PlaylistSummary, StorageError};
use tauri::{AppHandle, State};

use crate::commands::{CmdResult, CommandError};
use crate::m3u;
use crate::state::AppState;

/// Ids accepted in one call.
const MAX_IDS: usize = storage::PLAYLIST_ITEMS_MAX;

fn refused(err: StorageError) -> CommandError {
    match err {
        StorageError::Invalid(message) => CommandError::new("invalid_playlist", message),
        other => other.into(),
    }
}

fn check_ids(ids: &[i64]) -> CmdResult<()> {
    if ids.len() > MAX_IDS {
        return Err(CommandError::new("invalid_playlist", "too many entries"));
    }
    Ok(())
}

#[tauri::command]
pub async fn library_set_favorite(
    state: State<'_, AppState>,
    id: i64,
    favorite: bool,
) -> CmdResult<MediaRecord> {
    let storage = state.storage();
    storage.set_favorite(id, favorite)?;
    Ok(storage.media(id)?)
}

#[tauri::command]
pub async fn playlists_list(state: State<'_, AppState>) -> CmdResult<Vec<PlaylistSummary>> {
    Ok(state.storage().playlists()?)
}

#[tauri::command]
pub async fn playlist_get(state: State<'_, AppState>, id: i64) -> CmdResult<Playlist> {
    Ok(state.storage().playlist(id)?)
}

#[tauri::command]
pub async fn playlist_create(
    state: State<'_, AppState>,
    name: String,
    ids: Vec<i64>,
) -> CmdResult<PlaylistSummary> {
    check_ids(&ids)?;
    state
        .storage()
        .create_playlist(&name, &ids)
        .map_err(refused)
}

#[tauri::command]
pub async fn playlist_rename(state: State<'_, AppState>, id: i64, name: String) -> CmdResult<()> {
    state.storage().rename_playlist(id, &name).map_err(refused)
}

#[tauri::command]
pub async fn playlist_delete(state: State<'_, AppState>, id: i64) -> CmdResult<()> {
    Ok(state.storage().delete_playlist(id)?)
}

#[tauri::command]
pub async fn playlist_add(state: State<'_, AppState>, id: i64, ids: Vec<i64>) -> CmdResult<()> {
    check_ids(&ids)?;
    state.storage().add_to_playlist(id, &ids).map_err(refused)
}

#[tauri::command]
pub async fn playlist_remove(state: State<'_, AppState>, id: i64, index: usize) -> CmdResult<()> {
    state
        .storage()
        .remove_from_playlist(id, index)
        .map_err(refused)
}

#[tauri::command]
pub async fn playlist_move(
    state: State<'_, AppState>,
    id: i64,
    from: usize,
    to: usize,
) -> CmdResult<()> {
    state
        .storage()
        .move_in_playlist(id, from, to)
        .map_err(refused)
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportReport {
    pub playlist: PlaylistSummary,
    pub added: usize,
    /// Entries not found in the library, or web addresses.
    pub skipped: usize,
}

/// Picks an `.m3u` / `.m3u8` file and creates a playlist from the entries
/// found in the library. `None` if the user cancels.
#[tauri::command]
pub async fn playlist_import(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<Option<ImportReport>> {
    let Some(path) = dialog::pick_m3u(app).await? else {
        return Ok(None);
    };
    let meta =
        std::fs::metadata(&path).map_err(|e| CommandError::new("read_failed", e.to_string()))?;
    if meta.len() > m3u::M3U_MAX_BYTES {
        return Err(CommandError::new(
            "invalid_playlist",
            "This playlist file is too large.",
        ));
    }
    let bytes =
        std::fs::read(&path).map_err(|e| CommandError::new("read_failed", e.to_string()))?;
    let text = String::from_utf8_lossy(&bytes);
    let base = path.parent().unwrap_or(std::path::Path::new(""));
    let parsed = m3u::parse(&text, base);
    let name = path
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "Playlist".into());
    let storage = state.storage();
    let mut ids = Vec::new();
    let mut skipped = parsed.skipped;
    for entry in &parsed.paths {
        let text = entry.to_string_lossy();
        // The library stores the platform's separators; try both spellings.
        let found = storage
            .media_id_by_path(&text)?
            .or(storage.media_id_by_path(&text.replace('/', "\\"))?)
            .or(storage.media_id_by_path(&text.replace('\\', "/"))?);
        match found {
            Some(id) => ids.push(id),
            None => skipped += 1,
        }
    }
    let added = ids.len().min(storage::PLAYLIST_ITEMS_MAX);
    skipped += ids.len() - added;
    let playlist = storage.create_playlist(&name, &ids).map_err(refused)?;
    Ok(Some(ImportReport {
        playlist,
        added,
        skipped,
    }))
}

/// Saves a playlist as `.m3u8` where the user chooses. Returns the path,
/// or `None` if the user cancels.
#[tauri::command]
pub async fn playlist_export(
    app: AppHandle,
    state: State<'_, AppState>,
    id: i64,
) -> CmdResult<Option<String>> {
    let playlist = state.storage().playlist(id)?;
    let Some(path) = dialog::save_m3u(app, &playlist.name).await? else {
        return Ok(None);
    };
    let text = m3u::export(&playlist.name, &playlist.items);
    // Written next to the target, then moved: a failure leaves no half file.
    let partial = path.with_extension("m3u8.part");
    std::fs::write(&partial, text.as_bytes())
        .and_then(|_| std::fs::rename(&partial, &path))
        .map_err(|e| {
            let _ = std::fs::remove_file(&partial);
            CommandError::new("write_failed", e.to_string())
        })?;
    Ok(Some(path.to_string_lossy().into_owned()))
}

#[cfg(desktop)]
mod dialog {
    use std::path::PathBuf;

    use tauri::AppHandle;
    use tauri_plugin_dialog::DialogExt;

    use crate::commands::{CmdResult, CommandError};

    fn into_path(file: tauri_plugin_dialog::FilePath) -> CmdResult<PathBuf> {
        file.into_path()
            .map_err(|e| CommandError::new("invalid_file", e.to_string()))
    }

    pub async fn pick_m3u(app: AppHandle) -> CmdResult<Option<PathBuf>> {
        let picked = tauri::async_runtime::spawn_blocking(move || {
            app.dialog()
                .file()
                .add_filter("M3U", &["m3u", "m3u8"])
                .blocking_pick_file()
        })
        .await
        .map_err(|e| CommandError::new("dialog_failed", e.to_string()))?;
        picked.map(into_path).transpose()
    }

    pub async fn save_m3u(app: AppHandle, name: &str) -> CmdResult<Option<PathBuf>> {
        let file_name = format!(
            "{}.m3u8",
            media_core::sanitize_filename(name, "m3u8")
                .map(|n| n.trim_end_matches(".m3u8").to_owned())
                .unwrap_or_else(|_| "playlist".into())
        );
        let picked = tauri::async_runtime::spawn_blocking(move || {
            app.dialog()
                .file()
                .add_filter("M3U8", &["m3u8"])
                .set_file_name(file_name)
                .blocking_save_file()
        })
        .await
        .map_err(|e| CommandError::new("dialog_failed", e.to_string()))?;
        picked.map(into_path).transpose()
    }
}

/// Android: playlist files go through the platform picker (Phase 4).
#[cfg(mobile)]
mod dialog {
    use std::path::PathBuf;

    use tauri::AppHandle;

    use crate::commands::{CmdResult, CommandError};

    fn unsupported() -> CommandError {
        CommandError::new(
            "unsupported_platform",
            "Playlist files are not available on this platform yet",
        )
    }

    pub async fn pick_m3u(_app: AppHandle) -> CmdResult<Option<PathBuf>> {
        Err(unsupported())
    }

    pub async fn save_m3u(_app: AppHandle, _name: &str) -> CmdResult<Option<PathBuf>> {
        Err(unsupported())
    }
}

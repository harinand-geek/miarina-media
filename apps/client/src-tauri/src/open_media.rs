//! Opening media from outside the library (WIN-04): files picked in the
//! system dialog, a folder to import, or files and folders dropped on the
//! window. Paths only ever come from the system (dialog, drop), never from
//! the page.

use std::path::{Path, PathBuf};

use library::{Library, files};
use serde::Serialize;
use storage::MediaRecord;
use tauri::{AppHandle, Emitter, State};

use crate::commands::{CmdResult, CommandError};
use crate::state::AppState;

/// Sent to the main window after a drop.
pub const OPENED_EVENT: &str = "app://opened";

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FolderImport {
    /// Media files found in the folder (up to the scan bounds).
    pub found: usize,
    pub added: usize,
    pub restored: usize,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Opened {
    /// Files to play, in the order given.
    pub media: Vec<MediaRecord>,
    /// Dropped folders, imported into the library.
    pub folders: Vec<FolderImport>,
}

fn library_error(e: library::LibraryError) -> CommandError {
    CommandError::new("library", e.to_string())
}

/// Makes the files' folders playable (asset protocol) and adds them.
async fn add_files(
    app: &AppHandle,
    library: Library,
    paths: Vec<PathBuf>,
) -> CmdResult<Vec<MediaRecord>> {
    for dir in paths.iter().filter_map(|p| p.parent()) {
        crate::allow_media_dir(app, dir);
    }
    tauri::async_runtime::spawn_blocking(move || library.add_opened(&paths))
        .await
        .map_err(|e| CommandError::new("library", e.to_string()))?
        .map_err(library_error)
}

async fn import_folder(app: &AppHandle, library: Library, dir: PathBuf) -> CmdResult<FolderImport> {
    crate::allow_media_dir(app, &dir);
    tauri::async_runtime::spawn_blocking(move || {
        let found = files::media_files(&dir).len();
        library.scan(&dir).map(|r| FolderImport {
            found,
            added: r.added,
            restored: r.restored,
        })
    })
    .await
    .map_err(|e| CommandError::new("library", e.to_string()))?
    .map_err(library_error)
}

/// Picks media files and adds them to the library; the page plays them.
#[tauri::command]
pub async fn library_open_files(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<Vec<MediaRecord>> {
    let picked = dialog::pick_media(app.clone()).await?;
    if picked.is_empty() {
        return Ok(Vec::new());
    }
    add_files(&app, state.library.clone(), picked).await
}

/// "Import a folder" (Windows v2 library): indexes a picked folder.
#[tauri::command]
pub async fn library_import_folder(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<Option<FolderImport>> {
    let Some(dir) = dialog::pick_folder(app.clone()).await? else {
        return Ok(None);
    };
    import_folder(&app, state.library.clone(), dir)
        .await
        .map(Some)
}

/// Files and folders dropped on the main window: files are added and
/// played, folders imported.
pub async fn dropped(app: AppHandle, library: Library, paths: Vec<PathBuf>) {
    let (dirs, files): (Vec<PathBuf>, Vec<PathBuf>) = paths.into_iter().partition(|p| p.is_dir());
    let mut opened = Opened {
        media: Vec::new(),
        folders: Vec::new(),
    };
    if !files.is_empty()
        && let Ok(media) = add_files(&app, library.clone(), files).await
    {
        opened.media = media;
    }
    for dir in dirs.into_iter().take(16) {
        if let Ok(import) = import_folder(&app, library.clone(), dir).await {
            opened.folders.push(import);
        }
    }
    let _ = app.emit_to("main", OPENED_EVENT, opened);
}

fn is_media(path: &Path) -> bool {
    files::kind_for(path).is_some()
}

#[cfg(desktop)]
mod dialog {
    use std::path::PathBuf;

    use tauri::AppHandle;
    use tauri_plugin_dialog::DialogExt;

    use crate::commands::{CmdResult, CommandError};

    pub async fn pick_media(app: AppHandle) -> CmdResult<Vec<PathBuf>> {
        let extensions: Vec<&str> = library::files::VIDEO_EXTENSIONS
            .iter()
            .chain(library::files::AUDIO_EXTENSIONS.iter())
            .copied()
            .collect();
        let picked = tauri::async_runtime::spawn_blocking(move || {
            app.dialog()
                .file()
                .add_filter("Media", &extensions)
                .blocking_pick_files()
        })
        .await
        .map_err(|e| CommandError::new("dialog_failed", e.to_string()))?;
        Ok(picked
            .unwrap_or_default()
            .into_iter()
            .filter_map(|f| f.into_path().ok())
            .filter(|p| super::is_media(p))
            .collect())
    }

    pub async fn pick_folder(app: AppHandle) -> CmdResult<Option<PathBuf>> {
        let picked = tauri::async_runtime::spawn_blocking(move || {
            app.dialog().file().blocking_pick_folder()
        })
        .await
        .map_err(|e| CommandError::new("dialog_failed", e.to_string()))?;
        picked
            .map(|f| {
                f.into_path()
                    .map_err(|e| CommandError::new("invalid_folder", e.to_string()))
            })
            .transpose()
    }
}

/// Android picks media through the platform (COM-08, phase 2).
#[cfg(mobile)]
mod dialog {
    use std::path::PathBuf;

    use tauri::AppHandle;

    use crate::commands::{CmdResult, CommandError};

    fn unsupported() -> CommandError {
        CommandError::new(
            "unsupported_platform",
            "Opening files is not available on this platform yet",
        )
    }

    pub async fn pick_media(_app: AppHandle) -> CmdResult<Vec<PathBuf>> {
        Err(unsupported())
    }

    pub async fn pick_folder(_app: AppHandle) -> CmdResult<Option<PathBuf>> {
        Err(unsupported())
    }
}

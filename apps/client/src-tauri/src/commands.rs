//! Narrow, validated commands exposed to the frontend. Every input is
//! treated as untrusted; file system effects stay in Rust.

use std::path::{Path, PathBuf};

use download_engine::{EngineError, ManagerError, media_extension};
use media_core::{UrlError, sanitize_filename, validate_media_url as validate};
use resource_manager::ResourceMode;
use serde::{Deserialize, Serialize};
use storage::{HistoryEntry, MediaKind, NewTask, StorageError, TaskRecord, now_ms};
use tauri::{AppHandle, State};
use tauri_plugin_dialog::DialogExt;
use tauri_plugin_opener::OpenerExt;

use crate::state::{AppState, KEY_CONCURRENCY, KEY_DOWNLOAD_DIR, KEY_RESOURCE_MODE, SettingsDto};

/// Error returned to the UI: a stable code plus a readable message.
#[derive(Debug, Serialize)]
pub struct CommandError {
    pub code: &'static str,
    pub message: String,
}

impl CommandError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl From<ManagerError> for CommandError {
    fn from(err: ManagerError) -> Self {
        let code = match &err {
            ManagerError::QueueFull => "queue_full",
            ManagerError::InvalidAction(_) => "invalid_action",
            ManagerError::UnknownEngine(_) => "unknown_engine",
            ManagerError::Storage(StorageError::NotFound(_)) => "not_found",
            ManagerError::Storage(_) => "storage",
        };
        Self::new(code, err.to_string())
    }
}

impl From<StorageError> for CommandError {
    fn from(err: StorageError) -> Self {
        Self::from(ManagerError::from(err))
    }
}

impl From<UrlError> for CommandError {
    fn from(err: UrlError) -> Self {
        Self::new("invalid_link", err.to_string())
    }
}

type CmdResult<T> = Result<T, CommandError>;

// ------------------------------------------------------------------- links

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ValidatedLink {
    pub url: String,
    pub host: String,
}

/// Validates a pasted link before analysis. Errors are returned as stable
/// codes so the UI can show the message defined by the design.
#[tauri::command]
pub fn validate_media_url(url: String) -> Result<ValidatedLink, UrlError> {
    let valid = validate(&url)?;
    Ok(ValidatedLink {
        url: valid.as_str().to_owned(),
        host: valid.host().to_owned(),
    })
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FormatDto {
    pub id: String,
    pub quality: String,
    pub detail: String,
    pub size: String,
    pub extension: String,
    pub size_bytes: Option<u64>,
}

#[derive(Debug, Default, Serialize)]
pub struct FormatGroups {
    pub video: Vec<FormatDto>,
    pub audio: Vec<FormatDto>,
    pub subtitles: Vec<FormatDto>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaInfoDto {
    pub url: String,
    pub host: String,
    pub engine: &'static str,
    pub title: String,
    pub subtitle: String,
    pub publisher: String,
    pub duration: Option<String>,
    pub formats: FormatGroups,
}

#[derive(Debug, Serialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum AnalysisDto {
    Ready { info: Box<MediaInfoDto> },
    NoMedia { reason: String },
}

/// Reads what a link points to. Phase 2 handles direct media files; pages
/// that need an extractor are reported as "no downloadable media" until the
/// yt-dlp engine is enabled.
#[tauri::command]
pub async fn analyze_link(state: State<'_, AppState>, url: String) -> CmdResult<AnalysisDto> {
    let url = validate(&url)?;
    let media = match state.http.probe(&url).await {
        Ok(media) => media,
        Err(EngineError::NotMedia) => {
            return Ok(AnalysisDto::NoMedia {
                reason: "not_media".into(),
            });
        }
        Err(err) => {
            return Ok(AnalysisDto::NoMedia {
                reason: err.code().into(),
            });
        }
    };
    let extension =
        media_extension(&media).unwrap_or_else(|| guess_extension(media.content_type.as_deref()));
    let is_audio = media
        .content_type
        .as_deref()
        .is_some_and(|c| c.starts_with("audio/"))
        || matches!(
            extension.as_str(),
            "mp3" | "m4a" | "flac" | "ogg" | "oga" | "opus" | "wav" | "aac"
        );
    let title = Path::new(&media.suggested_name)
        .file_stem()
        .and_then(|s| s.to_str())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(url.host())
        .to_owned();
    let format = FormatDto {
        id: "original".into(),
        quality: format!("{} · original file", extension.to_ascii_uppercase()),
        detail: media
            .content_type
            .clone()
            .unwrap_or_else(|| "Unknown type".into()),
        size: media
            .total_bytes
            .map(human_size)
            .unwrap_or_else(|| "Unknown size".into()),
        extension,
        size_bytes: media.total_bytes,
    };
    let mut formats = FormatGroups::default();
    if is_audio {
        formats.audio.push(format);
    } else {
        formats.video.push(format);
    }
    let resume = if media.supports_resume {
        "can resume if interrupted"
    } else {
        "cannot resume if interrupted"
    };
    Ok(AnalysisDto::Ready {
        info: Box::new(MediaInfoDto {
            url: url.as_str().to_owned(),
            host: url.host().to_owned(),
            engine: "http",
            title,
            subtitle: format!("Direct file · {resume}"),
            publisher: url.host().to_owned(),
            duration: None,
            formats,
        }),
    })
}

fn guess_extension(content_type: Option<&str>) -> String {
    match content_type
        .unwrap_or("")
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
    {
        "video/webm" => "webm",
        "video/x-matroska" => "mkv",
        "video/quicktime" => "mov",
        "audio/mpeg" => "mp3",
        "audio/mp4" => "m4a",
        "audio/flac" => "flac",
        "audio/ogg" => "ogg",
        "audio/wav" | "audio/x-wav" => "wav",
        _ => "mp4",
    }
    .to_owned()
}

pub fn human_size(bytes: u64) -> String {
    const KB: f64 = 1024.0;
    let b = bytes as f64;
    if b >= KB * KB * KB {
        format!("{:.2} GB", b / (KB * KB * KB))
    } else if b >= KB * KB {
        format!("{:.0} MB", b / (KB * KB))
    } else if b >= KB {
        format!("{:.0} KB", b / KB)
    } else {
        format!("{bytes} B")
    }
}

// --------------------------------------------------------------- downloads

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartRequest {
    pub url: String,
    pub title: String,
    pub kind: String,
    pub engine: String,
    pub format_id: Option<String>,
    pub format_label: String,
    pub extension: String,
    /// `true` = "Download" (start now), `false` = "Add to queue".
    pub start_now: bool,
}

fn new_task_id() -> String {
    use std::sync::atomic::{AtomicU32, Ordering};
    static SEQ: AtomicU32 = AtomicU32::new(0);
    format!(
        "{:x}{:04x}",
        now_ms(),
        SEQ.fetch_add(1, Ordering::Relaxed) & 0xffff
    )
}

#[tauri::command]
pub async fn downloads_start(
    state: State<'_, AppState>,
    request: StartRequest,
) -> CmdResult<TaskRecord> {
    let url = validate(&request.url)?;
    let kind = match request.kind.as_str() {
        "audio" => MediaKind::Audio,
        "video" => MediaKind::Video,
        _ => return Err(CommandError::new("invalid_request", "unknown media kind")),
    };
    let title: String = request.title.chars().take(300).collect();
    let file_name = sanitize_filename(&title, &request.extension)
        .map_err(|e| CommandError::new("invalid_request", e.to_string()))?;
    let task = NewTask {
        id: new_task_id(),
        url: url.as_str().to_owned(),
        source_host: url.host().to_owned(),
        title,
        kind,
        engine: request.engine,
        format_id: request.format_id,
        format_label: request.format_label.chars().take(80).collect(),
        dest_dir: state.settings().download_dir,
        file_name,
    };
    let record = state.manager.enqueue(task)?;
    if request.start_now {
        state.manager.start_now(&record.id)?;
    }
    Ok(state.storage().task(&record.id)?)
}

#[tauri::command]
pub async fn downloads_list(state: State<'_, AppState>) -> CmdResult<Vec<TaskRecord>> {
    Ok(state.manager.tasks()?)
}

#[tauri::command]
pub async fn downloads_pause(state: State<'_, AppState>, id: String) -> CmdResult<()> {
    Ok(state.manager.pause(&id)?)
}

#[tauri::command]
pub async fn downloads_resume(state: State<'_, AppState>, id: String) -> CmdResult<()> {
    Ok(state.manager.resume(&id)?)
}

#[tauri::command]
pub async fn downloads_cancel(state: State<'_, AppState>, id: String) -> CmdResult<()> {
    Ok(state.manager.cancel(&id)?)
}

#[tauri::command]
pub async fn downloads_retry(state: State<'_, AppState>, id: String) -> CmdResult<()> {
    Ok(state.manager.retry(&id)?)
}

#[tauri::command]
pub async fn downloads_start_now(state: State<'_, AppState>, id: String) -> CmdResult<()> {
    Ok(state.manager.start_now(&id)?)
}

#[tauri::command]
pub async fn downloads_move(state: State<'_, AppState>, id: String, index: usize) -> CmdResult<()> {
    Ok(state.manager.move_task(&id, index)?)
}

#[tauri::command]
pub async fn downloads_pause_all(state: State<'_, AppState>) -> CmdResult<()> {
    state.manager.pause_all();
    Ok(())
}

#[tauri::command]
pub async fn downloads_resume_all(state: State<'_, AppState>) -> CmdResult<()> {
    state.manager.resume_all();
    Ok(())
}

/// Shows a completed download in the file manager. Only paths recorded by
/// the app itself can be revealed.
#[tauri::command]
pub async fn downloads_reveal(
    app: AppHandle,
    state: State<'_, AppState>,
    id: String,
) -> CmdResult<()> {
    let path = state.storage().task(&id)?.final_path;
    reveal(&app, path)
}

#[tauri::command]
pub async fn history_reveal(app: AppHandle, state: State<'_, AppState>, id: i64) -> CmdResult<()> {
    let path = state
        .storage()
        .history(storage::HISTORY_PAGE_MAX)?
        .into_iter()
        .find(|e| e.id == id)
        .and_then(|e| e.final_path);
    reveal(&app, path)
}

fn reveal(app: &AppHandle, path: Option<String>) -> CmdResult<()> {
    let path = path
        .map(PathBuf::from)
        .filter(|p| p.is_file())
        .ok_or_else(|| CommandError::new("file_missing", "The file is no longer on disk."))?;
    app.opener()
        .reveal_item_in_dir(path)
        .map_err(|e| CommandError::new("reveal_failed", e.to_string()))
}

// ----------------------------------------------------------------- history

#[tauri::command]
pub async fn history_list(
    state: State<'_, AppState>,
    limit: Option<u32>,
) -> CmdResult<Vec<HistoryEntry>> {
    Ok(state.storage().history(limit.unwrap_or(200))?)
}

/// Clears the list of past downloads. Files on disk are not deleted.
#[tauri::command]
pub async fn history_clear(state: State<'_, AppState>) -> CmdResult<usize> {
    Ok(state.storage().clear_history()?)
}

// ---------------------------------------------------------------- settings

#[tauri::command]
pub async fn settings_get(state: State<'_, AppState>) -> CmdResult<SettingsDto> {
    Ok(state.settings())
}

#[tauri::command]
pub async fn settings_set_concurrency(
    state: State<'_, AppState>,
    value: usize,
) -> CmdResult<SettingsDto> {
    let value = value.clamp(1, resource_manager::MAX_USER_DOWNLOADS);
    state.storage().set_setting(KEY_CONCURRENCY, &value)?;
    Ok(state.apply_limits())
}

#[tauri::command]
pub async fn settings_set_resource_mode(
    state: State<'_, AppState>,
    mode: ResourceMode,
) -> CmdResult<SettingsDto> {
    state.storage().set_setting(KEY_RESOURCE_MODE, &mode)?;
    Ok(state.apply_limits())
}

/// Opens the native folder picker and stores the chosen destination after
/// checking that it is writable. Returns `None` if the user cancels.
#[tauri::command]
pub async fn settings_pick_download_dir(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<Option<SettingsDto>> {
    let picked =
        tauri::async_runtime::spawn_blocking(move || app.dialog().file().blocking_pick_folder())
            .await
            .map_err(|e| CommandError::new("dialog_failed", e.to_string()))?;
    let Some(picked) = picked else {
        return Ok(None);
    };
    let dir = picked
        .into_path()
        .map_err(|e| CommandError::new("invalid_folder", e.to_string()))?;
    ensure_writable(&dir)?;
    state
        .storage()
        .set_setting(KEY_DOWNLOAD_DIR, &dir.to_string_lossy().into_owned())?;
    Ok(Some(state.settings()))
}

fn ensure_writable(dir: &Path) -> CmdResult<()> {
    let probe = dir.join(".miarina-write-test");
    std::fs::create_dir_all(dir)
        .and_then(|_| std::fs::write(&probe, b"ok"))
        .and_then(|_| std::fs::remove_file(&probe))
        .map_err(|_| {
            CommandError::new(
                "folder_not_writable",
                "Miarina Media cannot write to this folder.",
            )
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sizes_are_human_readable() {
        assert_eq!(human_size(18 * 1024), "18 KB");
        assert_eq!(human_size(372 * 1024 * 1024), "372 MB");
        assert_eq!(human_size(1_202_590_843), "1.12 GB");
        assert_eq!(human_size(12), "12 B");
    }

    #[test]
    fn extensions_are_guessed_from_mime_types() {
        assert_eq!(guess_extension(Some("audio/mpeg")), "mp3");
        assert_eq!(guess_extension(Some("video/webm; codecs=vp9")), "webm");
        assert_eq!(guess_extension(None), "mp4");
    }

    #[test]
    fn task_ids_are_unique() {
        let a = new_task_id();
        let b = new_task_id();
        assert_ne!(a, b);
        assert!(a.chars().all(|c| c.is_ascii_hexdigit()));
    }
}

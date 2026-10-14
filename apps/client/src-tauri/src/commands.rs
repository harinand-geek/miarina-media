//! Narrow, validated commands exposed to the frontend. Every input is
//! treated as untrusted; file system effects stay in Rust.

use std::path::{Path, PathBuf};

use download_engine::components::{ComponentId, ComponentStatus};
use download_engine::ytdlp::FormatSpec;
use download_engine::{EngineError, ManagerError, media_extension};
use library::ScanReport;
use media_core::{UrlError, ValidatedUrl, sanitize_filename, validate_media_url as validate};
use resource_manager::ResourceMode;
use serde::{Deserialize, Serialize};
use storage::{
    HistoryEntry, MediaKind, MediaPage, MediaQuery, MediaRecord, MediaStats, NewTask, StorageError,
    TaskRecord, now_ms,
};
use tauri::{AppHandle, Emitter, State};
use tauri_plugin_dialog::DialogExt;
use tauri_plugin_opener::OpenerExt;
use tokio_util::sync::CancellationToken;

use crate::state::{AppState, KEY_CONCURRENCY, KEY_DOWNLOAD_DIR, KEY_RESOURCE_MODE, SettingsDto};

/// Error returned to the UI: a stable code plus a readable message.
#[derive(Debug, Serialize)]
pub struct CommandError {
    pub code: &'static str,
    pub message: String,
}

impl CommandError {
    pub(crate) fn new(code: &'static str, message: impl Into<String>) -> Self {
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

// --------------------------------------------------------- system opener

/// Android opens files through content URIs (FileProvider), which arrive
/// with the native media adapter (Phase 4); the desktop opener takes paths.
#[cfg(mobile)]
fn not_on_mobile() -> CommandError {
    CommandError::new(
        "unsupported_platform",
        "Opening files in another app is not available on Android yet.",
    )
}

/// Opens a file or folder with the system's default application.
fn open_local(app: &AppHandle, path: &str) -> CmdResult<()> {
    #[cfg(mobile)]
    {
        let _ = (app, path);
        Err(not_on_mobile())
    }
    #[cfg(desktop)]
    app.opener()
        .open_path(path, None::<&str>)
        .map_err(|e| CommandError::new("open_failed", e.to_string()))
}

/// Shows a file selected in the file manager.
fn reveal_local(app: &AppHandle, path: &Path) -> CmdResult<()> {
    #[cfg(mobile)]
    {
        let _ = (app, path);
        Err(not_on_mobile())
    }
    #[cfg(desktop)]
    app.opener()
        .reveal_item_in_dir(path)
        .map_err(|e| CommandError::new("reveal_failed", e.to_string()))
}

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
    pub tag: Option<&'static str>,
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
    pub released: Option<String>,
    pub license: Option<String>,
    /// Shown under the formats, e.g. when FFmpeg is missing.
    pub notice: Option<String>,
    pub formats: FormatGroups,
}

#[derive(Debug, Serialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum AnalysisDto {
    Ready {
        info: Box<MediaInfoDto>,
    },
    NoMedia {
        reason: String,
    },
    /// The page needs the extractor, which is not installed yet (D3).
    NeedsComponents {
        components: Vec<ComponentStatus>,
    },
}

/// Reads what a link points to: a direct media file is probed over HTTP,
/// anything else (a web page) goes to the yt-dlp extractor.
#[tauri::command]
pub async fn analyze_link(state: State<'_, AppState>, url: String) -> CmdResult<AnalysisDto> {
    let url = validate(&url)?;
    match state.http.probe(&url).await {
        Ok(media) => Ok(direct_analysis(&url, media)),
        Err(_) => extractor_analysis(&state, &url).await,
    }
}

async fn extractor_analysis(state: &AppState, url: &ValidatedUrl) -> CmdResult<AnalysisDto> {
    let components = state.ytdlp.components();
    if components.ytdlp().is_none() {
        return Ok(AnalysisDto::NeedsComponents {
            components: components.status(),
        });
    }
    let analysis = match state.ytdlp.analyze(url, &CancellationToken::new()).await {
        Ok(analysis) => analysis,
        Err(EngineError::Unsupported { reason }) => return Ok(AnalysisDto::NoMedia { reason }),
        // Technical details stay out of the UI (they may contain the URL).
        Err(EngineError::Network { .. }) => {
            return Ok(AnalysisDto::NoMedia {
                reason: "the website could not be reached — check the link and your connection"
                    .into(),
            });
        }
        Err(EngineError::Http { status }) => {
            return Ok(AnalysisDto::NoMedia {
                reason: format!("the website refused the request (HTTP {status})"),
            });
        }
        Err(err) => {
            return Ok(AnalysisDto::NoMedia {
                reason: err.to_string(),
            });
        }
    };
    let info = &analysis.info;
    let to_dto = |o: &download_engine::ytdlp::Offer| FormatDto {
        id: o.spec.encode(),
        quality: o.quality.clone(),
        detail: o.detail.clone(),
        size: o.size_bytes.map(human_size).unwrap_or_else(|| "—".into()),
        extension: o.extension.clone(),
        size_bytes: o.size_bytes,
        tag: o.tag,
    };
    let formats = FormatGroups {
        video: analysis.offers.video.iter().map(to_dto).collect(),
        audio: analysis.offers.audio.iter().map(to_dto).collect(),
        subtitles: Vec::new(),
    };
    let source = info
        .extractor_key
        .clone()
        .unwrap_or_else(|| "Web page".into());
    let notice = components.ffmpeg_dir().is_none().then(|| {
        "Install FFmpeg to get more qualities (merged video + audio) and MP3 conversion.".to_owned()
    });
    Ok(AnalysisDto::Ready {
        info: Box::new(MediaInfoDto {
            url: url.as_str().to_owned(),
            host: url.host().to_owned(),
            engine: "ytdlp",
            title: clean_text(info.title.as_deref()).unwrap_or_else(|| url.host().to_owned()),
            subtitle: format!(
                "{source} · {} video, {} audio formats offered",
                formats.video.len(),
                formats.audio.len()
            ),
            publisher: clean_text(info.uploader.as_deref().or(info.channel.as_deref()))
                .unwrap_or_else(|| url.host().to_owned()),
            duration: info.duration.map(format_duration),
            released: info
                .release_date
                .as_deref()
                .or(info.upload_date.as_deref())
                .and_then(format_date),
            license: clean_text(info.license.as_deref()),
            notice,
            formats,
        }),
    })
}

/// Untrusted metadata: single line, bounded length.
fn clean_text(value: Option<&str>) -> Option<String> {
    let text: String = value?
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .take(300)
        .collect();
    let text = text.trim().to_owned();
    (!text.is_empty()).then_some(text)
}

pub fn format_duration(secs: f64) -> String {
    let s = secs.max(0.0).round() as u64;
    let (h, m, s) = (s / 3600, (s % 3600) / 60, s % 60);
    if h > 0 {
        format!("{h}:{m:02}:{s:02}")
    } else {
        format!("{m}:{s:02}")
    }
}

/// `20120926` → `26 Sep 2012`.
pub fn format_date(yyyymmdd: &str) -> Option<String> {
    const MONTHS: [&str; 12] = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    if yyyymmdd.len() != 8 || !yyyymmdd.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let month: usize = yyyymmdd[4..6].parse().ok()?;
    let day: u32 = yyyymmdd[6..8].parse().ok()?;
    let name = MONTHS.get(month.checked_sub(1)?)?;
    Some(format!("{day} {name} {}", &yyyymmdd[..4]))
}

fn direct_analysis(url: &ValidatedUrl, media: download_engine::DirectMedia) -> AnalysisDto {
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
            .unwrap_or_else(|| "—".into()),
        extension,
        size_bytes: media.total_bytes,
        tag: None,
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
    AnalysisDto::Ready {
        info: Box::new(MediaInfoDto {
            url: url.as_str().to_owned(),
            host: url.host().to_owned(),
            engine: "http",
            title: clean_text(Some(&title)).unwrap_or_else(|| url.host().to_owned()),
            subtitle: format!("Direct file · {resume}"),
            publisher: url.host().to_owned(),
            duration: None,
            released: None,
            license: None,
            notice: None,
            formats,
        }),
    }
}

// -------------------------------------------------------------- components

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct InstallProgress {
    id: ComponentId,
    name: &'static str,
    downloaded: u64,
    total: u64,
}

pub const COMPONENTS_EVENT: &str = "components://progress";

#[tauri::command]
pub async fn components_status(state: State<'_, AppState>) -> CmdResult<Vec<ComponentStatus>> {
    Ok(state.ytdlp.components().status())
}

/// Downloads and installs the missing tools after the user agreed. Every
/// archive is checked against its pinned SHA-256 before use.
#[tauri::command]
pub async fn components_install(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<Vec<ComponentStatus>> {
    let _guard = state.install_lock.lock().await;
    let components = state.ytdlp.components();
    for spec in download_engine::components::ALL {
        if components.path(&spec).is_some() {
            continue;
        }
        let handle = app.clone();
        let report = move |downloaded: u64, total: u64| {
            let _ = handle.emit(
                COMPONENTS_EVENT,
                InstallProgress {
                    id: spec.id,
                    name: spec.name,
                    downloaded,
                    total,
                },
            );
        };
        components
            .install(&spec, &report, &CancellationToken::new())
            .await
            .map_err(|e| {
                CommandError::new("component_install_failed", format!("{}: {e}", spec.name))
            })?;
    }
    Ok(components.status())
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
    // The format comes back from the UI: only engine-validated specs pass.
    match request.engine.as_str() {
        "http" if request.format_id.is_none() => {}
        "ytdlp" => {
            FormatSpec::decode(request.format_id.as_deref().unwrap_or_default())
                .map_err(|e| CommandError::new("invalid_request", e))?;
        }
        _ => {
            return Err(CommandError::new(
                "invalid_request",
                "unknown engine or format",
            ));
        }
    }
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
    reveal_local(app, &path)
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

#[cfg(desktop)]
async fn pick_folder(app: AppHandle) -> CmdResult<Option<tauri_plugin_dialog::FilePath>> {
    tauri::async_runtime::spawn_blocking(move || app.dialog().file().blocking_pick_folder())
        .await
        .map_err(|e| CommandError::new("dialog_failed", e.to_string()))
}

/// Android storage goes through the platform adapter (scoped storage,
/// Phase 4); the desktop folder picker does not exist there.
#[cfg(mobile)]
async fn pick_folder(_app: AppHandle) -> CmdResult<Option<tauri_plugin_dialog::FilePath>> {
    Err(CommandError::new(
        "unsupported_platform",
        "Choosing a folder is not available on this platform yet",
    ))
}

/// Opens the native folder picker and stores the chosen destination after
/// checking that it is writable. Returns `None` if the user cancels.
#[tauri::command]
pub async fn settings_pick_download_dir(
    app: AppHandle,
    state: State<'_, AppState>,
) -> CmdResult<Option<SettingsDto>> {
    let picked = pick_folder(app.clone()).await?;
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
    // The new folder becomes playable and is indexed.
    crate::allow_media_dir(&app, &dir);
    crate::scan_library(&state.library, dir);
    Ok(Some(state.settings()))
}

// ----------------------------------------------------------------- library

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DiskSpace {
    pub free: u64,
    pub total: u64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryOverview {
    pub stats: MediaStats,
    pub disk: Option<DiskSpace>,
    pub download_dir: String,
}

fn disk_of(dir: &Path) -> Option<DiskSpace> {
    download_engine::fsops::disk_space(dir).map(|(free, total)| DiskSpace { free, total })
}

fn library_error(err: library::LibraryError) -> CommandError {
    match err {
        library::LibraryError::Storage(StorageError::NotFound(_)) => {
            CommandError::new("not_found", "This item is no longer in the library.")
        }
        library::LibraryError::InvalidName => {
            CommandError::new("invalid_name", "This name cannot be used.")
        }
        other => CommandError::new("library", other.to_string()),
    }
}

#[tauri::command]
pub async fn library_query(state: State<'_, AppState>, query: MediaQuery) -> CmdResult<MediaPage> {
    Ok(state.storage().query_media(&query)?)
}

#[tauri::command]
pub async fn library_overview(state: State<'_, AppState>) -> CmdResult<LibraryOverview> {
    let download_dir = state.settings().download_dir;
    Ok(LibraryOverview {
        stats: state.storage().media_stats()?,
        disk: disk_of(Path::new(&download_dir)),
        download_dir,
    })
}

/// One entry, after checking that its file still exists.
#[tauri::command]
pub async fn library_get(state: State<'_, AppState>, id: i64) -> CmdResult<MediaRecord> {
    state.library.check(id).map_err(library_error)
}

#[tauri::command]
pub async fn library_rename(
    state: State<'_, AppState>,
    id: i64,
    title: String,
) -> CmdResult<MediaRecord> {
    let title: String = title.chars().take(200).collect();
    state.library.rename(id, &title).map_err(library_error)
}

/// Deletes the file from disk (the UI asks for confirmation first).
#[tauri::command]
pub async fn library_delete(state: State<'_, AppState>, id: i64) -> CmdResult<()> {
    state.library.delete(id).map_err(library_error)
}

#[tauri::command]
pub async fn library_reveal(app: AppHandle, state: State<'_, AppState>, id: i64) -> CmdResult<()> {
    let path = state.storage().media(id)?.path;
    reveal(&app, Some(path))
}

/// Opens the download folder in the file manager (created if needed).
#[tauri::command]
pub async fn downloads_open_folder(app: AppHandle, state: State<'_, AppState>) -> CmdResult<()> {
    let dir = PathBuf::from(state.settings().download_dir);
    std::fs::create_dir_all(&dir)
        .map_err(|e| CommandError::new("folder_not_writable", e.to_string()))?;
    open_local(&app, &dir.to_string_lossy())
}

/// Opens a library file with the system's default player (for formats the
/// WebView cannot decode, e.g. HEVC or MKV).
#[tauri::command]
pub async fn library_open_external(
    app: AppHandle,
    state: State<'_, AppState>,
    id: i64,
) -> CmdResult<()> {
    let record = state.library.check(id).map_err(library_error)?;
    if record.missing {
        return Err(CommandError::new(
            "file_missing",
            "The file is no longer on disk.",
        ));
    }
    open_local(&app, &record.path)
}

#[tauri::command]
pub async fn library_rescan(state: State<'_, AppState>) -> CmdResult<ScanReport> {
    let dir = PathBuf::from(state.settings().download_dir);
    let library = state.library.clone();
    tauri::async_runtime::spawn_blocking(move || library.scan(&dir))
        .await
        .map_err(|e| CommandError::new("library", e.to_string()))?
        .map_err(library_error)
}

// ----------------------------------------------------------------- storage

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StorageUsage {
    pub download_dir: String,
    pub disk: Option<DiskSpace>,
    pub library_bytes: u64,
    pub thumbnail_bytes: u64,
    /// Partial files no download refers to any more.
    pub orphan_temp_bytes: u64,
    pub orphan_temp_count: usize,
}

/// `.part` files and `.part.d` folders of the download folder that belong
/// to no open task (leftovers of removed or crashed downloads).
fn orphan_temp_files(state: &AppState, dir: &Path) -> Vec<(PathBuf, u64)> {
    let in_use: Vec<PathBuf> = state
        .storage()
        .open_tasks()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|t| t.part_path)
        .map(PathBuf::from)
        .collect();
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Vec::new();
    };
    entries
        .flatten()
        .filter_map(|entry| {
            let path = entry.path();
            let name = entry.file_name().to_string_lossy().to_ascii_lowercase();
            let owner = if name.ends_with(".part") {
                path.clone()
            } else if name.ends_with(".part.d") {
                path.with_extension("")
            } else {
                return None;
            };
            if in_use.contains(&owner) {
                return None;
            }
            Some((path.clone(), dir_size(&path)))
        })
        .collect()
}

fn dir_size(path: &Path) -> u64 {
    match std::fs::metadata(path) {
        Ok(m) if m.is_file() => m.len(),
        Ok(_) => std::fs::read_dir(path)
            .map(|entries| entries.flatten().map(|e| dir_size(&e.path())).sum())
            .unwrap_or(0),
        Err(_) => 0,
    }
}

#[tauri::command]
pub async fn storage_usage(state: State<'_, AppState>) -> CmdResult<StorageUsage> {
    let download_dir = state.settings().download_dir;
    let dir = PathBuf::from(&download_dir);
    let orphans = orphan_temp_files(&state, &dir);
    Ok(StorageUsage {
        disk: disk_of(&dir),
        library_bytes: state.storage().media_stats()?.total_bytes,
        thumbnail_bytes: state.library.thumbnail_cache_bytes(),
        orphan_temp_bytes: orphans.iter().map(|(_, size)| size).sum(),
        orphan_temp_count: orphans.len(),
        download_dir,
    })
}

#[tauri::command]
pub async fn storage_clear_thumbnails(state: State<'_, AppState>) -> CmdResult<u64> {
    state.library.clear_thumbnails().map_err(library_error)
}

/// Deletes orphan partial files only; active and paused downloads keep theirs.
#[tauri::command]
pub async fn storage_clean_temp(state: State<'_, AppState>) -> CmdResult<u64> {
    let dir = PathBuf::from(state.settings().download_dir);
    let mut freed = 0;
    for (path, size) in orphan_temp_files(&state, &dir) {
        let removed = if path.is_dir() {
            std::fs::remove_dir_all(&path)
        } else {
            std::fs::remove_file(&path)
        };
        if removed.is_ok() {
            freed += size;
        }
    }
    Ok(freed)
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
    fn metadata_formatting() {
        assert_eq!(format_date("20120926").as_deref(), Some("26 Sep 2012"));
        assert_eq!(format_date("2012-09-26"), None);
        assert_eq!(format_date("20121326"), None);
        assert_eq!(format_duration(734.4), "12:14");
        assert_eq!(format_duration(5744.0), "1:35:44");
        assert_eq!(
            clean_text(Some(
                "  a
b  "
            ))
            .as_deref(),
            Some("a b")
        );
        assert_eq!(clean_text(Some("   ")), None);
    }

    #[test]
    fn task_ids_are_unique() {
        let a = new_task_id();
        let b = new_task_id();
        assert_ne!(a, b);
        assert!(a.chars().all(|c| c.is_ascii_hexdigit()));
    }
}

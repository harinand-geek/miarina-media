//! Obtenir (Get space), ported from the Tauri app (`apps/client/src-tauri/
//! src/commands.rs`): link checks, analysis, the download manager and its
//! events. Same crates, same rules: every input is untrusted, the format
//! chosen in the UI must be one the engine offered, file names are
//! sanitized, files are written by the manager (streamed to a temporary
//! file, then finalized). Texts are composed in Dart from codes.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use anyhow::{Result, anyhow};
use download_engine::components::ALL as ALL_COMPONENTS;
use download_engine::ytdlp::{FormatSpec, MAX_PLAYLIST_ITEMS};
use download_engine::{
    EngineError, HttpEngine, Manager, ManagerEvent, RetryPolicy, YtDlpEngine, media_extension,
};
use library::Library;
use media_core::{UrlError, ValidatedUrl, sanitize_dirname, sanitize_filename, validate_media_url};
use resource_manager::{MAX_QUEUE_LEN, Platform, ResourceMode, limits};
use storage::{HistoryEntry, HistoryStatus, MediaKind, NewTask, TaskRecord, now_ms};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use super::indexer::shared;
use crate::frb_generated::StreamSink;

const KEY_DOWNLOAD_DIR: &str = "download_dir";
const KEY_CONCURRENCY: &str = "concurrency";
const KEY_RESOURCE_MODE: &str = "resource_mode";
const KEY_DEFAULT_VIDEO: &str = "default_video_height";
const KEY_DEFAULT_AUDIO: &str = "default_audio";
const KEY_SPEED_LIMIT: &str = "speed_limit";
const KEY_SUBTITLES: &str = "download_subtitles";
/// Default video quality choices (height), the first the default.
const VIDEO_HEIGHTS: [u32; 6] = [1080, 2160, 1440, 720, 480, 360];
/// Default audio format choices, the first the default.
const AUDIO_CHOICES: [&str; 6] = ["mp3-320", "mp3-256", "mp3-192", "mp3-128", "m4a", "flac"];
/// Highest speed limit accepted (1 GiB/s); 0 = unlimited.
const MAX_SPEED_LIMIT: u64 = 1 << 30;
const DEFAULT_CONCURRENCY: usize = 3;
const EVENT_BUFFER: usize = 256;
/// Analysis never waits longer for the source's picture.
const THUMBNAIL_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(8);
/// A playlist's pictures are fetched this many at a time, and never delay
/// its downloads longer than this.
const PLAYLIST_THUMBNAILS_AT_ONCE: usize = 6;
const PLAYLIST_THUMBNAILS_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(20);
/// The direct-file check of a link never holds the analysis longer: a page
/// that stalls it (seen with Facebook on a phone) goes on to the extractor.
const PROBE_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(15);
/// Video sites whose links are pages, never files: straight to the
/// extractor, without the direct-file check (it may fail or stall where the
/// extractor's own requests work).
const PAGE_HOSTS: [&str; 12] = [
    "youtube.com",
    "youtu.be",
    "facebook.com",
    "fb.watch",
    "instagram.com",
    "tiktok.com",
    "x.com",
    "twitter.com",
    "vimeo.com",
    "dailymotion.com",
    "soundcloud.com",
    "twitch.tv",
];
/// Longest entry title kept in a playlist's file names (path length).
const PLAYLIST_TITLE_CHARS: usize = 100;

struct Getter {
    db: String,
    runtime: tokio::runtime::Handle,
    storage: Arc<Mutex<storage::Storage>>,
    manager: Manager,
    http: HttpEngine,
    ytdlp: YtDlpEngine,
    library: Library,
    default_dir: PathBuf,
    /// Android: audio downloads go to Music/Miarina (video: `default_dir`,
    /// Movies/Miarina), as in the Tauri app.
    audio_dir: Mutex<Option<PathBuf>>,
    install_lock: Arc<tokio::sync::Mutex<()>>,
}

static GETTER: Mutex<Option<Arc<Getter>>> = Mutex::new(None);
static SINK: Mutex<Option<StreamSink<GetEvent>>> = Mutex::new(None);

/// App closing (`api/app.rs`): running downloads flush their partial
/// files so they stay resumable. Nothing to do when Obtenir never started.
#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn shutdown_downloads() {
    if let Ok(g) = getter() {
        g.runtime.block_on(g.manager.shutdown());
    }
}

/// FFmpeg and FFprobe shipped with the app (Convertir).
#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn ffmpeg_tools() -> Option<(PathBuf, PathBuf)> {
    let dir = getter().ok()?.ytdlp.components().ffmpeg_dir()?;
    let exe = |name: &str| {
        dir.join(if cfg!(windows) {
            format!("{name}.exe")
        } else {
            name.to_owned()
        })
    };
    let tools = (exe("ffmpeg"), exe("ffprobe"));
    (tools.0.is_file() && tools.1.is_file()).then_some(tools)
}

/// A conversion is running (UPD-04: an update would interrupt it): a
/// download's, Convertir's, or a screen recording.
#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn converting() -> bool {
    crate::converter::running()
        || crate::recorder::active()
        || getter().is_ok_and(|g| {
            g.manager.tasks().is_ok_and(|t| {
                t.iter()
                    .any(|t| t.state == media_core::TaskState::Processing)
            })
        })
}

fn getter() -> Result<Arc<Getter>> {
    GETTER
        .lock()
        .map_err(|_| anyhow!("get lock poisoned"))?
        .clone()
        .ok_or_else(|| anyhow!("downloads not started"))
}

fn emit(event: GetEvent) {
    if let Ok(guard) = SINK.lock()
        && let Some(sink) = guard.as_ref()
    {
        let _ = sink.add(event);
    }
}

// ------------------------------------------------------------------ types

pub struct LinkCheck {
    /// Normalized link when valid.
    pub url: Option<String>,
    pub host: Option<String>,
    /// `empty`, `too_long`, `malformed`, `unsupported_scheme`,
    /// `missing_host`, `contains_credentials`.
    pub error: Option<String>,
}

pub struct FormatOffer {
    /// Engine format spec (`original` for a direct file).
    pub id: String,
    pub quality: String,
    pub detail: String,
    pub size_bytes: Option<u64>,
    pub extension: String,
    /// `Recommended` or `Best quality`.
    pub tag: Option<String>,
}

pub struct MediaInfo {
    pub url: String,
    pub host: String,
    /// `http` (direct file) or `ytdlp` (web page).
    pub engine: String,
    pub title: String,
    pub publisher: String,
    /// Site that published it (yt-dlp extractor), e.g. "Youtube".
    pub source: Option<String>,
    pub duration_secs: Option<f64>,
    /// `yyyymmdd`.
    pub released: Option<String>,
    pub license: Option<String>,
    /// Local copy of the source's picture.
    pub thumbnail: Option<String>,
    /// Direct file: the server accepts resuming.
    pub supports_resume: bool,
    /// FFmpeg missing: fewer qualities, no MP3 conversion.
    pub needs_ffmpeg: bool,
    pub video: Vec<FormatOffer>,
    pub audio: Vec<FormatOffer>,
    /// The source's subtitles, one file per language (Sous-titres tab).
    pub subtitles: Vec<FormatOffer>,
}

pub struct ToolStatus {
    /// yt_dlp, ffmpeg, quickjs, libvlc.
    pub id: String,
    pub name: String,
    pub version: String,
    pub license: String,
    pub download_bytes: u64,
    pub installed: bool,
    /// Shipped with the application rather than downloaded.
    pub bundled: bool,
}

pub enum AnalysisStatus {
    Ready,
    NoMedia,
    /// The page needs yt-dlp, not installed (consent before downloading it).
    NeedsTools,
    /// A playlist (`Analysis.playlist`): its entries are chosen, then each
    /// becomes a download.
    Playlist,
}

/// One entry of a playlist (DL-07).
pub struct WebPlaylistEntry {
    /// Position in the playlist, from 1.
    pub index: u32,
    /// `None`: private, deleted or not a single media; not downloadable.
    pub url: Option<String>,
    /// May be empty (the UI then names it by its position).
    pub title: String,
    pub duration_secs: Option<f64>,
    /// The site's picture, fetched only when the entry is downloaded.
    pub thumbnail_url: Option<String>,
}

pub struct WebPlaylist {
    pub url: String,
    pub host: String,
    pub title: String,
    pub publisher: String,
    pub source: Option<String>,
    /// Local copy of the first entry's picture.
    pub thumbnail: Option<String>,
    /// Entries in the whole playlist, when the source says.
    pub count: Option<u64>,
    /// Only the first `entries` are listed (`MAX_PLAYLIST_ITEMS`).
    pub truncated: bool,
    pub needs_ffmpeg: bool,
    pub entries: Vec<WebPlaylistEntry>,
    /// Qualities offered for every entry.
    pub video: Vec<FormatOffer>,
    pub audio: Vec<FormatOffer>,
}

/// An entry chosen for download.
pub struct WebPlaylistPick {
    pub index: u32,
    pub url: String,
    pub title: String,
    pub thumbnail_url: Option<String>,
}

pub struct WebPlaylistStart {
    pub playlist_title: String,
    pub is_audio: bool,
    /// One of the playlist's offers.
    pub format_id: String,
    pub format_label: String,
    pub extension: String,
    /// In a folder named after the playlist, inside the download folder.
    pub own_folder: bool,
    pub items: Vec<WebPlaylistPick>,
}

/// Plain structs and enums only: the bridge then needs no generated
/// sealed classes on the Dart side.
pub struct Analysis {
    pub status: AnalysisStatus,
    pub info: Option<MediaInfo>,
    /// No media: `unsupported`, `network`, `http:<status>`, `platform`,
    /// `other`.
    pub code: String,
    /// No media: the engine's reason (English, shown as is).
    pub detail: String,
    pub tools: Vec<ToolStatus>,
    pub playlist: Option<WebPlaylist>,
}

impl Analysis {
    fn ready(info: MediaInfo) -> Self {
        Self {
            status: AnalysisStatus::Ready,
            info: Some(info),
            code: String::new(),
            detail: String::new(),
            tools: Vec::new(),
            playlist: None,
        }
    }

    fn no_media(code: String, detail: String) -> Self {
        Self {
            status: AnalysisStatus::NoMedia,
            info: None,
            code,
            detail,
            tools: Vec::new(),
            playlist: None,
        }
    }
}

pub struct TaskInfo {
    pub id: String,
    pub url: String,
    pub source_host: String,
    pub title: String,
    pub is_audio: bool,
    pub engine: String,
    pub format_label: String,
    /// queued, waiting, analyzing, downloading, processing, paused,
    /// completed, failed, canceled.
    pub state: String,
    pub position: i64,
    pub dest_dir: String,
    pub file_name: String,
    pub final_path: Option<String>,
    pub total_bytes: Option<u64>,
    pub downloaded_bytes: u64,
    pub supports_resume: bool,
    pub error_code: Option<String>,
    pub error_message: Option<String>,
    pub thumbnail: Option<String>,
    pub created_at: i64,
}

pub struct HistoryInfo {
    pub id: i64,
    pub task_id: String,
    pub url: String,
    pub title: String,
    pub source_host: String,
    pub format_label: String,
    pub total_bytes: Option<u64>,
    pub done_bytes: u64,
    pub completed: bool,
    /// The user cancelled it (failed otherwise, when not completed).
    pub canceled: bool,
    pub reason: Option<String>,
    pub final_path: Option<String>,
    pub finished_at: i64,
}

pub enum GetEventKind {
    /// Throttled by the manager (resource limits).
    Progress,
    Task,
    Removed,
    Retrying,
    History,
    /// Media tools being downloaded after consent.
    ToolProgress,
}

/// One event of the download manager; the fields used depend on `kind`.
pub struct GetEvent {
    pub kind: GetEventKind,
    /// Task id (progress, removed, retrying) or tool name (tool progress).
    pub id: String,
    pub downloaded: u64,
    pub total: Option<u64>,
    pub bytes_per_sec: f64,
    pub eta_secs: Option<u64>,
    pub supports_resume: bool,
    pub retry_in_secs: u64,
    pub offline: bool,
    pub task: Option<TaskInfo>,
    pub history: Option<HistoryInfo>,
}

impl GetEvent {
    fn of(kind: GetEventKind, id: String) -> Self {
        Self {
            kind,
            id,
            downloaded: 0,
            total: None,
            bytes_per_sec: 0.0,
            eta_secs: None,
            supports_resume: false,
            retry_in_secs: 0,
            offline: false,
            task: None,
            history: None,
        }
    }
}

pub struct StartRequest {
    pub url: String,
    pub title: String,
    pub is_audio: bool,
    pub engine: String,
    pub format_id: Option<String>,
    pub format_label: String,
    pub extension: String,
    /// "Télécharger" (now) rather than "Ajouter à la file".
    pub start_now: bool,
    pub thumbnail: Option<String>,
}

pub struct GetSettings {
    pub download_dir: String,
    pub concurrency: u32,
    /// eco, balanced, performance.
    pub resource_mode: String,
    /// Limits the mode applies (downloads, conversions at once).
    pub max_downloads: u32,
    pub max_conversions: u32,
    /// Bounds of `concurrency`.
    pub max_concurrency: u32,
    /// Quality preselected for video (height; a lower one when missing).
    pub default_video_height: u32,
    /// Format preselected for audio: `mp3-320`…`mp3-128`, `m4a`, `flac`.
    pub default_audio: String,
    /// Total bytes per second for downloads; 0 = unlimited.
    pub speed_limit: u64,
    /// Language whose subtitles are embedded in videos (`fr`, `en`), or
    /// empty for none.
    pub subtitles: String,
}

fn task_info(r: TaskRecord) -> TaskInfo {
    TaskInfo {
        id: r.id,
        url: r.url,
        source_host: r.source_host,
        title: r.title,
        is_audio: r.kind == MediaKind::Audio,
        engine: r.engine,
        format_label: r.format_label,
        state: r.state.as_str().to_owned(),
        position: r.position,
        dest_dir: r.dest_dir,
        file_name: r.file_name,
        final_path: r.final_path,
        total_bytes: r.total_bytes,
        downloaded_bytes: r.downloaded_bytes,
        supports_resume: r.supports_resume,
        error_code: r.error_code,
        error_message: r.error_message,
        thumbnail: r.thumbnail,
        created_at: r.created_at,
    }
}

fn history_info(h: HistoryEntry) -> HistoryInfo {
    HistoryInfo {
        id: h.id,
        task_id: h.task_id,
        url: h.url,
        title: h.title,
        source_host: h.source_host,
        format_label: h.format_label,
        total_bytes: h.total_bytes,
        done_bytes: h.done_bytes,
        completed: h.status == HistoryStatus::Completed,
        canceled: h.status == HistoryStatus::Canceled,
        reason: h.reason,
        final_path: h.final_path,
        finished_at: h.finished_at,
    }
}

// ------------------------------------------------------------- lifecycle

fn settings_of(storage: &storage::Storage, default_dir: &Path) -> GetSettings {
    let download_dir = storage
        .setting::<String>(KEY_DOWNLOAD_DIR)
        .ok()
        .flatten()
        .unwrap_or_else(|| default_dir.to_string_lossy().into_owned());
    let concurrency = storage
        .setting::<usize>(KEY_CONCURRENCY)
        .ok()
        .flatten()
        .unwrap_or(DEFAULT_CONCURRENCY);
    let mode = storage
        .setting::<ResourceMode>(KEY_RESOURCE_MODE)
        .ok()
        .flatten()
        .unwrap_or_default();
    let applied = limits(mode, platform(), concurrency, cpu_count());
    GetSettings {
        download_dir,
        concurrency: concurrency as u32,
        resource_mode: match mode {
            ResourceMode::Eco => "eco",
            ResourceMode::Balanced => "balanced",
            ResourceMode::Performance => "performance",
        }
        .into(),
        max_downloads: applied.max_downloads as u32,
        max_conversions: applied.max_conversions as u32,
        max_concurrency: resource_manager::MAX_USER_DOWNLOADS as u32,
        default_video_height: storage
            .setting::<u32>(KEY_DEFAULT_VIDEO)
            .ok()
            .flatten()
            .filter(|h| VIDEO_HEIGHTS.contains(h))
            .unwrap_or(VIDEO_HEIGHTS[0]),
        default_audio: storage
            .setting::<String>(KEY_DEFAULT_AUDIO)
            .ok()
            .flatten()
            .filter(|a| AUDIO_CHOICES.contains(&a.as_str()))
            .unwrap_or_else(|| AUDIO_CHOICES[0].to_owned()),
        speed_limit: storage
            .setting::<u64>(KEY_SPEED_LIMIT)
            .ok()
            .flatten()
            .filter(|l| *l <= MAX_SPEED_LIMIT)
            .unwrap_or(0),
        subtitles: storage
            .setting::<String>(KEY_SUBTITLES)
            .ok()
            .flatten()
            .and_then(|l| subtitle_lang(&l).map(str::to_owned))
            .unwrap_or_default(),
    }
}

/// The subtitle languages the app offers (its own languages).
fn subtitle_lang(lang: &str) -> Option<&'static str> {
    match lang {
        "fr" => Some("fr"),
        "en" => Some("en"),
        _ => None,
    }
}

/// Speed limit and subtitles for the transfers that start next.
fn apply_options(g: &Getter) {
    let s = settings_of(&lock(&g.storage), &g.default_dir);
    g.manager.set_options(download_engine::JobOptions {
        speed_limit: (s.speed_limit > 0).then_some(s.speed_limit),
        subtitles: subtitle_lang(&s.subtitles),
    });
}

/// Réglages › Téléchargements: default qualities, speed limit, subtitles.
pub fn get_set_download_prefs(
    default_video_height: u32,
    default_audio: String,
    speed_limit: u64,
    subtitles: String,
) -> Result<GetSettings> {
    let g = getter()?;
    if !VIDEO_HEIGHTS.contains(&default_video_height)
        || !AUDIO_CHOICES.contains(&default_audio.as_str())
        || speed_limit > MAX_SPEED_LIMIT
        || !(subtitles.is_empty() || subtitle_lang(&subtitles).is_some())
    {
        return Err(anyhow!("invalid download preferences"));
    }
    {
        let storage = lock(&g.storage);
        storage.set_setting(KEY_DEFAULT_VIDEO, &default_video_height)?;
        storage.set_setting(KEY_DEFAULT_AUDIO, &default_audio)?;
        storage.set_setting(KEY_SPEED_LIMIT, &speed_limit)?;
        storage.set_setting(KEY_SUBTITLES, &subtitles)?;
    }
    apply_options(&g);
    Ok(settings_of(&lock(&g.storage), &g.default_dir))
}

fn current_limits(storage: &storage::Storage) -> resource_manager::Limits {
    let concurrency = storage
        .setting::<usize>(KEY_CONCURRENCY)
        .ok()
        .flatten()
        .unwrap_or(DEFAULT_CONCURRENCY);
    let mode = storage
        .setting::<ResourceMode>(KEY_RESOURCE_MODE)
        .ok()
        .flatten()
        .unwrap_or_default();
    limits(mode, platform(), concurrency, cpu_count())
}

/// Applies the stored settings to the running manager and library: Eco /
/// Balanced / Performance change real limits, not labels.
fn apply_limits(g: &Getter) -> GetSettings {
    let storage = lock(&g.storage);
    let applied = current_limits(&storage);
    g.manager.set_limits(applied);
    g.library.set_limits(library::WorkLimits {
        max_conversions: applied.max_conversions,
        thumbnail_px: applied.thumbnail_px,
        ffmpeg_threads: applied.ffmpeg_threads,
    });
    settings_of(&storage, &g.default_dir)
}

fn platform() -> Platform {
    if cfg!(target_os = "android") {
        Platform::Android
    } else {
        Platform::Windows
    }
}

fn cpu_count() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(2)
}

/// Starts the download manager on the indexing runtime (call after
/// `indexer_start`). `default_dir`: where files go until the user picks
/// another folder (Windows: Téléchargements\Miarina, as in the Tauri app).
pub fn get_start(default_dir: String) -> Result<()> {
    let parts = shared()?;
    let mut guard = GETTER.lock().map_err(|_| anyhow!("get lock poisoned"))?;
    if guard.as_ref().is_some_and(|g| g.db == parts.db) {
        return Ok(());
    }
    let http = HttpEngine::new()?;
    let ytdlp = YtDlpEngine::new(parts.components.clone());
    let default_dir = PathBuf::from(default_dir);
    let applied = current_limits(&lock(&parts.storage));
    let (tx, mut rx) = mpsc::channel::<ManagerEvent>(EVENT_BUFFER);
    let manager = Manager::new(
        parts.storage.clone(),
        vec![Arc::new(http.clone()), Arc::new(ytdlp.clone())],
        applied,
        RetryPolicy::default(),
        tx,
    );
    parts.library.set_limits(library::WorkLimits {
        max_conversions: applied.max_conversions,
        thumbnail_px: applied.thumbnail_px,
        ffmpeg_threads: applied.ffmpeg_threads,
    });
    let library = parts.library.clone();
    parts.runtime.spawn(async move {
        while let Some(event) = rx.recv().await {
            // A finished download joins the library right away.
            if let ManagerEvent::Task(task) = &event
                && task.state == media_core::TaskState::Completed
                && let Some(path) = &task.final_path
            {
                let _ = library.add_download(
                    Path::new(path),
                    &task.source_host,
                    &task.url,
                    &task.id,
                    task.thumbnail.as_deref().map(Path::new),
                );
            }
            emit(match event {
                ManagerEvent::Progress(p) => GetEvent {
                    downloaded: p.progress.downloaded,
                    total: p.progress.total,
                    bytes_per_sec: p.progress.bytes_per_sec,
                    eta_secs: p.eta_secs,
                    supports_resume: p.progress.supports_resume,
                    ..GetEvent::of(GetEventKind::Progress, p.id)
                },
                ManagerEvent::Task(t) => GetEvent {
                    task: Some(task_info(t)),
                    ..GetEvent::of(GetEventKind::Task, String::new())
                },
                ManagerEvent::Removed { id } => GetEvent::of(GetEventKind::Removed, id),
                ManagerEvent::Retrying(r) => GetEvent {
                    retry_in_secs: r.in_secs,
                    offline: r.offline,
                    ..GetEvent::of(GetEventKind::Retrying, r.id)
                },
                ManagerEvent::History(h) => GetEvent {
                    history: Some(history_info(h)),
                    ..GetEvent::of(GetEventKind::History, String::new())
                },
            });
        }
    });
    // The user's speed limit and subtitles, before interrupted downloads
    // resume.
    let prefs = settings_of(&lock(&parts.storage), &default_dir);
    manager.set_options(download_engine::JobOptions {
        speed_limit: (prefs.speed_limit > 0).then_some(prefs.speed_limit),
        subtitles: subtitle_lang(&prefs.subtitles),
    });
    {
        let _enter = parts.runtime.enter();
        manager.start()?;
    }
    // Windows: keep yt-dlp current (verified updates, at most daily).
    if cfg!(windows) {
        parts.runtime.spawn(daily_ytdlp_updates());
    }
    *guard = Some(Arc::new(Getter {
        db: parts.db,
        runtime: parts.runtime,
        storage: parts.storage,
        manager,
        http,
        ytdlp,
        library: parts.library,
        default_dir,
        audio_dir: Mutex::new(None),
        install_lock: Arc::new(tokio::sync::Mutex::new(())),
    }));
    Ok(())
}

fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|p| p.into_inner())
}

/// Download events for the UI (one listener: the latest replaces it).
pub fn get_events(sink: StreamSink<GetEvent>) -> Result<()> {
    *SINK.lock().map_err(|_| anyhow!("sink lock poisoned"))? = Some(sink);
    Ok(())
}

// ------------------------------------------------------------------ links

pub fn get_check_link(url: String) -> LinkCheck {
    match validate_media_url(&url) {
        Ok(valid) => LinkCheck {
            url: Some(valid.as_str().to_owned()),
            host: Some(valid.host().to_owned()),
            error: None,
        },
        Err(e) => LinkCheck {
            url: None,
            host: None,
            error: Some(
                match e {
                    UrlError::Empty => "empty",
                    UrlError::TooLong => "too_long",
                    UrlError::Malformed => "malformed",
                    UrlError::UnsupportedScheme => "unsupported_scheme",
                    UrlError::MissingHost => "missing_host",
                    UrlError::ContainsCredentials => "contains_credentials",
                }
                .into(),
            ),
        },
    }
}

/// Reads what a link points to: a direct media file is probed over HTTP,
/// anything else (a web page) goes to the yt-dlp extractor. Blocking:
/// runs the requests on the download runtime.
pub fn get_analyze(url: String) -> Result<Analysis> {
    analyze(url, false)
}

/// Obtenir › Playlist: the whole playlist a link belongs to, even a video
/// page inside one (`watch?v=…&list=…`). A link to a single media still
/// gives that media.
pub fn get_analyze_playlist(url: String) -> Result<Analysis> {
    analyze(url, true)
}

fn analyze(url: String, whole_playlist: bool) -> Result<Analysis> {
    let g = getter()?;
    let url = validate_media_url(&url).map_err(|e| anyhow!(e.to_string()))?;
    let runtime = g.runtime.clone();
    runtime.block_on(async move {
        // Known video pages go straight to their extractor: a generic HTTP
        // probe may fail where yt-dlp's own requests work. So does a
        // playlist (a page, never a file).
        if whole_playlist || page_host(url.host()) {
            return extractor_analysis(&g, &url, whole_playlist).await;
        }
        let probe = tokio::time::timeout(PROBE_TIMEOUT, g.http.probe(&url))
            .await
            .unwrap_or_else(|_| {
                Err(EngineError::Network {
                    message: "the link did not answer in time".into(),
                })
            });
        match probe {
            Ok(media) => Ok(direct_analysis(&url, media)),
            Err(error) if should_extract(&url, &error) => extractor_analysis(&g, &url, false).await,
            Err(error) => Ok(no_media(&error)),
        }
    })
}

fn no_media(error: &EngineError) -> Analysis {
    let code = match error {
        EngineError::Network { .. } => "network".to_owned(),
        EngineError::Http { status } => format!("http:{status}"),
        EngineError::Unsupported { .. } => "unsupported".to_owned(),
        _ => "other".to_owned(),
    };
    // Technical details stay out of the UI (they may contain the URL).
    let detail = match error {
        EngineError::Unsupported { reason } => reason.clone(),
        EngineError::Network { .. } | EngineError::Http { .. } => String::new(),
        other => other.to_string(),
    };
    Analysis::no_media(code, detail)
}

/// Path part of a link (no query or fragment), for its extension.
fn url_path(url: &ValidatedUrl) -> String {
    let s = url.as_str();
    let after_scheme = s.split_once("://").map_or(s, |(_, rest)| rest);
    let path = after_scheme.find('/').map_or("", |i| &after_scheme[i..]);
    path.split(['?', '#']).next().unwrap_or("").to_owned()
}

/// A known video site (the host or one of its subdomains).
fn page_host(host: &str) -> bool {
    PAGE_HOSTS
        .iter()
        .any(|d| host == *d || host.strip_suffix(d).is_some_and(|rest| rest.ends_with('.')))
}

// A page may reject generic requests, or stall them, yet work through its
// extractor. A direct media link keeps its real HTTP or network error.
fn should_extract(url: &ValidatedUrl, error: &EngineError) -> bool {
    matches!(error, EngineError::NotMedia)
        || (matches!(
            error,
            EngineError::Http { .. } | EngineError::Network { .. }
        ) && media_extension(&download_engine::DirectMedia {
            suggested_name: url_path(url),
            content_type: None,
            total_bytes: None,
            supports_resume: false,
        })
        .is_none())
}

fn tools_status(ytdlp: &YtDlpEngine) -> Vec<ToolStatus> {
    ytdlp
        .components()
        .status()
        .into_iter()
        .map(|c| ToolStatus {
            id: serde_json::to_value(c.id)
                .ok()
                .and_then(|v| v.as_str().map(str::to_owned))
                .unwrap_or_default(),
            bundled: c.bundled,
            name: c.name.to_owned(),
            version: c.version,
            license: c.license.to_owned(),
            download_bytes: c.download_bytes,
            installed: c.installed,
        })
        .collect()
}

async fn extractor_analysis(
    g: &Getter,
    url: &ValidatedUrl,
    whole_playlist: bool,
) -> Result<Analysis> {
    // Android: the extractor ships in the APK (get_set_android_tools); without
    // it (tools not unpacked) there is nothing to install from here.
    if !cfg!(windows) && !g.ytdlp.available() {
        return Ok(Analysis::no_media("platform".into(), String::new()));
    }
    if !g.ytdlp.available() {
        return Ok(Analysis {
            status: AnalysisStatus::NeedsTools,
            tools: tools_status(&g.ytdlp),
            ..Analysis::no_media(String::new(), String::new())
        });
    }
    let analysis = match g
        .ytdlp
        .analyze_with(url, whole_playlist, &CancellationToken::new())
        .await
    {
        Ok(analysis) => analysis,
        Err(error) => return Ok(no_media(&error)),
    };
    let info = &analysis.info;
    let offer = format_offer;
    if let Some(list) = &analysis.playlist {
        let first = list
            .items
            .iter()
            .filter(|i| i.url.is_some())
            .find_map(|i| i.thumbnail.as_deref());
        let thumbnail = source_thumbnail(g, first.or(info.thumbnail.as_deref())).await;
        return Ok(Analysis {
            status: AnalysisStatus::Playlist,
            playlist: Some(WebPlaylist {
                url: url.as_str().to_owned(),
                host: url.host().to_owned(),
                title: clean_text(info.title.as_deref()).unwrap_or_else(|| url.host().to_owned()),
                publisher: clean_text(info.uploader.as_deref().or(info.channel.as_deref()))
                    .unwrap_or_else(|| url.host().to_owned()),
                source: clean_text(info.extractor_key.as_deref()),
                thumbnail,
                count: list.count,
                truncated: list.truncated,
                needs_ffmpeg: !g.ytdlp.has_ffmpeg(),
                entries: list
                    .items
                    .iter()
                    .map(|i| WebPlaylistEntry {
                        index: i.index,
                        url: i.url.clone(),
                        title: clean_text(i.title.as_deref()).unwrap_or_default(),
                        duration_secs: i.duration,
                        thumbnail_url: i.thumbnail.clone(),
                    })
                    .collect(),
                video: analysis.offers.video.iter().map(offer).collect(),
                audio: analysis.offers.audio.iter().map(offer).collect(),
            }),
            ..Analysis::no_media(String::new(), String::new())
        });
    }
    let thumbnail = source_thumbnail(g, info.thumbnail.as_deref()).await;
    Ok(Analysis::ready(MediaInfo {
        url: url.as_str().to_owned(),
        host: url.host().to_owned(),
        engine: "ytdlp".into(),
        title: clean_text(info.title.as_deref()).unwrap_or_else(|| url.host().to_owned()),
        publisher: clean_text(info.uploader.as_deref().or(info.channel.as_deref()))
            .unwrap_or_else(|| url.host().to_owned()),
        source: clean_text(info.extractor_key.as_deref()),
        duration_secs: info.duration,
        released: info
            .release_date
            .clone()
            .or_else(|| info.upload_date.clone())
            .filter(|d| d.len() == 8 && d.chars().all(|c| c.is_ascii_digit())),
        license: clean_text(info.license.as_deref()),
        thumbnail,
        supports_resume: false,
        needs_ffmpeg: !g.ytdlp.has_ffmpeg(),
        video: analysis.offers.video.iter().map(offer).collect(),
        audio: analysis.offers.audio.iter().map(offer).collect(),
        subtitles: analysis.offers.subtitles.iter().map(offer).collect(),
    }))
}

fn format_offer(o: &download_engine::ytdlp::Offer) -> FormatOffer {
    FormatOffer {
        id: o.spec.encode(),
        quality: o.quality.clone(),
        detail: o.detail.clone(),
        size_bytes: o.size_bytes,
        extension: o.extension.clone(),
        tag: o.tag.map(str::to_owned),
    }
}

/// Qualities that apply to any page, resolved by the extractor for each
/// one (Obtenir › Plusieurs liens; the same as a playlist's).
pub struct PresetOffers {
    pub video: Vec<FormatOffer>,
    pub audio: Vec<FormatOffer>,
    pub needs_ffmpeg: bool,
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_preset_offers() -> Result<PresetOffers> {
    let g = getter()?;
    let ffmpeg = g.ytdlp.has_ffmpeg();
    let offers = download_engine::ytdlp::playlist_offers(ffmpeg);
    Ok(PresetOffers {
        video: offers.video.iter().map(format_offer).collect(),
        audio: offers.audio.iter().map(format_offer).collect(),
        needs_ffmpeg: !ffmpeg,
    })
}

/// Caches the site's picture locally; any failure just means no picture.
async fn source_thumbnail(g: &Getter, url: Option<&str>) -> Option<String> {
    let url = validate_media_url(url?).ok()?;
    let dir = g.library.source_thumbnails_dir();
    let path = tokio::time::timeout(THUMBNAIL_TIMEOUT, g.http.fetch_thumbnail(&url, &dir))
        .await
        .ok()?
        .ok()?;
    Some(path.to_string_lossy().into_owned())
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

fn direct_analysis(url: &ValidatedUrl, media: download_engine::DirectMedia) -> Analysis {
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
    let format = FormatOffer {
        id: "original".into(),
        quality: extension.to_ascii_uppercase(),
        detail: media.content_type.clone().unwrap_or_default(),
        size_bytes: media.total_bytes,
        extension,
        tag: None,
    };
    let (video, audio) = if is_audio {
        (Vec::new(), vec![format])
    } else {
        (vec![format], Vec::new())
    };
    Analysis::ready(MediaInfo {
        url: url.as_str().to_owned(),
        host: url.host().to_owned(),
        engine: "http".into(),
        title: clean_text(Some(&title)).unwrap_or_else(|| url.host().to_owned()),
        publisher: url.host().to_owned(),
        source: None,
        duration_secs: None,
        released: None,
        license: None,
        thumbnail: None,
        supports_resume: media.supports_resume,
        needs_ffmpeg: false,
        video,
        audio,
        subtitles: Vec::new(),
    })
}

/// Downloads the missing media tools after the user agreed; every archive
/// is checked against its pinned SHA-256 before use. Progress arrives as
/// `GetEvent::ToolProgress`.
pub fn get_install_tools() -> Result<()> {
    if !cfg!(windows) {
        return Err(anyhow!("unsupported_platform"));
    }
    let g = getter()?;
    let runtime = g.runtime.clone();
    runtime.block_on(async move {
        let _guard = g.install_lock.lock().await;
        let components = g.ytdlp.components();
        for spec in ALL_COMPONENTS {
            if components.path(&spec).is_some() {
                continue;
            }
            let name = spec.name.to_owned();
            let report = move |downloaded: u64, total: u64| {
                emit(GetEvent {
                    downloaded,
                    total: Some(total),
                    ..GetEvent::of(GetEventKind::ToolProgress, name.clone())
                });
            };
            components
                .install(&spec, &report, &CancellationToken::new())
                .await
                .map_err(|e| anyhow!("{}: {e}", spec.name))?;
        }
        // Entries waiting for FFmpeg get their details and pictures now.
        g.library.refresh();
        Ok(())
    })
}

// --------------------------------------------------------------- downloads

fn new_task_id() -> String {
    use std::sync::atomic::{AtomicU32, Ordering};
    static SEQ: AtomicU32 = AtomicU32::new(0);
    format!(
        "{:x}{:04x}",
        now_ms(),
        SEQ.fetch_add(1, Ordering::Relaxed) & 0xffff
    )
}

/// Android: the APK's extractor (Python, yt-dlp, FFmpeg, QuickJS unpacked by
/// `MediaToolsChannel.kt`), and the download folders.
pub struct AndroidTools {
    pub python: String,
    pub script: String,
    pub ffmpeg: String,
    pub quickjs: String,
    pub python_home: String,
    pub library_path: String,
    pub certificates: String,
    pub temp: String,
    pub bin: String,
    /// Music/Miarina (shared storage, Android 11+), `None` elsewhere.
    pub audio_dir: Option<String>,
    /// Temporary files: the app's own folder on the same storage, since the
    /// shared folders only accept media files.
    pub staging_dir: Option<String>,
}

/// Android: hands the extractor and the folders to Obtenir (after
/// `get_start`). Refused when a packaged tool is missing.
pub fn get_set_android_tools(tools: AndroidTools) -> Result<()> {
    let g = getter()?;
    g.ytdlp
        .set_android_runtime(download_engine::ytdlp::runtime::AndroidRuntime {
            python: PathBuf::from(tools.python),
            script: PathBuf::from(tools.script),
            ffmpeg: PathBuf::from(tools.ffmpeg),
            quickjs: PathBuf::from(tools.quickjs),
            python_home: PathBuf::from(tools.python_home),
            library_path: tools.library_path,
            certificates: PathBuf::from(tools.certificates),
            temp: PathBuf::from(tools.temp),
            bin: PathBuf::from(tools.bin),
        })
        .map_err(|e| anyhow!(e.to_string()))?;
    *lock(&g.audio_dir) = tools.audio_dir.map(PathBuf::from);
    if let Some(dir) = tools.staging_dir {
        std::fs::create_dir_all(&dir)?;
        g.manager.set_staging_dir(PathBuf::from(dir));
    }
    Ok(())
}

pub fn get_start_download(request: StartRequest) -> Result<TaskInfo> {
    let g = getter()?;
    let url = validate_media_url(&request.url).map_err(|e| anyhow!(e.to_string()))?;
    // The format comes back from the UI: only engine-validated specs pass.
    match request.engine.as_str() {
        "http" if request.format_id.is_none() => {}
        "ytdlp" => {
            FormatSpec::decode(request.format_id.as_deref().unwrap_or_default())
                .map_err(|e| anyhow!("invalid format: {e}"))?;
        }
        _ => return Err(anyhow!("unknown engine or format")),
    }
    let kind = if request.is_audio {
        MediaKind::Audio
    } else {
        MediaKind::Video
    };
    let title: String = request.title.chars().take(300).collect();
    let file_name = sanitize_filename(&title, &request.extension)?;
    let dest_dir = download_dir(&g, &kind);
    std::fs::create_dir_all(&dest_dir)?;
    let task = NewTask {
        id: new_task_id(),
        url: url.as_str().to_owned(),
        source_host: url.host().to_owned(),
        title,
        kind,
        engine: request.engine,
        format_id: request.format_id,
        format_label: request.format_label.chars().take(80).collect(),
        dest_dir,
        file_name,
        // Only a picture from the source thumbnail cache is accepted.
        thumbnail: request
            .thumbnail
            .filter(|t| g.library.is_source_thumbnail(Path::new(t))),
    };
    let _enter = g.runtime.enter();
    let record = g.manager.enqueue(task)?;
    if request.start_now {
        g.manager.start_now(&record.id)?;
    }
    Ok(task_info(lock(&g.storage).task(&record.id)?))
}

/// The download folder for a kind of media (Android: audio in Music/Miarina).
fn download_dir(g: &Getter, kind: &MediaKind) -> String {
    match (kind, lock(&g.audio_dir).as_ref()) {
        (MediaKind::Audio, Some(dir)) => dir.to_string_lossy().into_owned(),
        _ => settings_of(&lock(&g.storage), &g.default_dir).download_dir,
    }
}

/// Queues the chosen entries of a playlist, in the playlist's order, with
/// one quality for all (DL-07). Each becomes an ordinary task: the queue's
/// limits apply and a failure is retried on its own. All or nothing: a
/// queue without room for every entry refuses them (`queue_full`).
/// Returns how many were queued.
pub fn get_start_playlist(request: WebPlaylistStart) -> Result<u32> {
    let g = getter()?;
    FormatSpec::decode(&request.format_id).map_err(|e| anyhow!("invalid format: {e}"))?;
    if request.items.len() > MAX_PLAYLIST_ITEMS {
        return Err(anyhow!("too many entries"));
    }
    let picks = request
        .items
        .iter()
        .map(|item| {
            validate_media_url(&item.url)
                .map(|url| (item, url))
                .map_err(|e| anyhow!(e.to_string()))
        })
        .collect::<Result<Vec<_>>>()?;
    if picks.is_empty() {
        return Ok(0);
    }
    if g.manager.tasks()?.len() + picks.len() > MAX_QUEUE_LEN {
        return Err(anyhow!("queue_full"));
    }
    let kind = if request.is_audio {
        MediaKind::Audio
    } else {
        MediaKind::Video
    };
    let mut dest_dir = PathBuf::from(download_dir(&g, &kind));
    if request.own_folder {
        dest_dir.push(sanitize_dirname(&request.playlist_title));
    }
    std::fs::create_dir_all(&dest_dir)?;
    let dest_dir = dest_dir.to_string_lossy().into_owned();
    // File names keep the playlist's order: "01 - Title.mp4".
    let width = picks
        .iter()
        .map(|(item, _)| item.index.to_string().len())
        .max()
        .unwrap_or(1)
        .max(2);
    let mut tasks = Vec::with_capacity(picks.len());
    for (item, url) in &picks {
        let title: String = item
            .title
            .trim()
            .chars()
            .take(PLAYLIST_TITLE_CHARS)
            .collect();
        let title = if title.is_empty() {
            format!("{} {}", request.playlist_title.trim(), item.index)
        } else {
            title
        };
        let title: String = title.chars().take(300).collect();
        let file_name = sanitize_filename(
            &format!("{:0width$} - {title}", item.index),
            &request.extension,
        )?;
        tasks.push(NewTask {
            id: String::new(),
            url: url.as_str().to_owned(),
            source_host: url.host().to_owned(),
            title,
            kind,
            engine: "ytdlp".into(),
            format_id: Some(request.format_id.clone()),
            format_label: request.format_label.chars().take(80).collect(),
            dest_dir: dest_dir.clone(),
            file_name,
            thumbnail: None,
        });
    }
    let thumbnails = g.runtime.block_on(playlist_thumbnails(
        &g,
        picks
            .iter()
            .map(|(item, _)| item.thumbnail_url.clone())
            .collect(),
    ));
    let _enter = g.runtime.enter();
    let mut queued = 0;
    for (mut task, thumbnail) in tasks.into_iter().zip(thumbnails) {
        task.id = new_task_id();
        task.thumbnail = thumbnail;
        g.manager.enqueue(task)?;
        queued += 1;
    }
    Ok(queued)
}

/// The entries' pictures, a few at a time and within a time limit (a
/// missing picture only means the placeholder).
async fn playlist_thumbnails(g: &Arc<Getter>, urls: Vec<Option<String>>) -> Vec<Option<String>> {
    let mut found = vec![None; urls.len()];
    let permits = Arc::new(tokio::sync::Semaphore::new(PLAYLIST_THUMBNAILS_AT_ONCE));
    let mut set = tokio::task::JoinSet::new();
    for (i, url) in urls.into_iter().enumerate() {
        let Some(url) = url else { continue };
        let (g, permits) = (g.clone(), permits.clone());
        set.spawn(async move {
            let _permit = permits.acquire_owned().await.ok()?;
            Some((i, source_thumbnail(&g, Some(&url)).await?))
        });
    }
    let deadline = tokio::time::Instant::now() + PLAYLIST_THUMBNAILS_TIMEOUT;
    while let Ok(Some(done)) = tokio::time::timeout_at(deadline, set.join_next()).await {
        if let Ok(Some((i, path))) = done {
            found[i] = Some(path);
        }
    }
    // Pictures still on their way are dropped with the set.
    found
}

pub fn get_tasks() -> Result<Vec<TaskInfo>> {
    Ok(getter()?
        .manager
        .tasks()?
        .into_iter()
        .map(task_info)
        .collect())
}

pub fn get_history(limit: u32) -> Result<Vec<HistoryInfo>> {
    let g = getter()?;
    let entries = lock(&g.storage).history(limit.min(storage::HISTORY_PAGE_MAX))?;
    Ok(entries.into_iter().map(history_info).collect())
}

/// pause, resume, cancel, retry, restart, start_now.
pub fn get_task_action(id: String, action: String) -> Result<()> {
    let g = getter()?;
    let _enter = g.runtime.enter();
    let m = &g.manager;
    match action.as_str() {
        "pause" => m.pause(&id)?,
        "resume" => m.resume(&id)?,
        "cancel" => m.cancel(&id)?,
        "retry" => m.retry(&id)?,
        "restart" => m.restart(&id)?,
        "start_now" => m.start_now(&id)?,
        other => return Err(anyhow!("unknown action: {other}")),
    }
    Ok(())
}

pub fn get_move_task(id: String, index: u32) -> Result<()> {
    let g = getter()?;
    let _enter = g.runtime.enter();
    Ok(g.manager.move_task(&id, index as usize)?)
}

pub fn get_pause_all(pause: bool) -> Result<()> {
    let g = getter()?;
    let _enter = g.runtime.enter();
    if pause {
        g.manager.pause_all();
    } else {
        g.manager.resume_all();
    }
    Ok(())
}

/// Clears the list of past downloads; files are not deleted.
pub fn get_clear_history() -> Result<u32> {
    let g = getter()?;
    Ok(lock(&g.storage).clear_history()? as u32)
}

pub fn get_settings() -> Result<GetSettings> {
    let g = getter()?;
    Ok(settings_of(&lock(&g.storage), &g.default_dir))
}

/// Folder chosen by the user: must exist and accept files.
pub fn get_set_download_dir(path: String) -> Result<GetSettings> {
    let g = getter()?;
    let dir = PathBuf::from(&path);
    if !dir.is_absolute() || !dir.is_dir() {
        return Err(anyhow!("not_a_folder"));
    }
    let probe = dir.join(format!(".miarina-write-test-{}", std::process::id()));
    std::fs::write(&probe, b"").map_err(|_| anyhow!("not_writable"))?;
    let _ = std::fs::remove_file(&probe);
    let storage = lock(&g.storage);
    storage.set_setting(KEY_DOWNLOAD_DIR, &dir.to_string_lossy().into_owned())?;
    Ok(settings_of(&storage, &g.default_dir))
}

// ------------------------------------------------------- settings, tools

pub fn get_set_concurrency(value: u32) -> Result<GetSettings> {
    let g = getter()?;
    let value = (value as usize).clamp(1, resource_manager::MAX_USER_DOWNLOADS);
    lock(&g.storage).set_setting(KEY_CONCURRENCY, &value)?;
    let _enter = g.runtime.enter();
    Ok(apply_limits(&g))
}

/// eco, balanced or performance.
pub fn get_set_resource_mode(mode: String) -> Result<GetSettings> {
    let g = getter()?;
    let mode = match mode.as_str() {
        "eco" => ResourceMode::Eco,
        "balanced" => ResourceMode::Balanced,
        "performance" => ResourceMode::Performance,
        other => return Err(anyhow!("unknown mode: {other}")),
    };
    lock(&g.storage).set_setting(KEY_RESOURCE_MODE, &mode)?;
    let _enter = g.runtime.enter();
    Ok(apply_limits(&g))
}

/// yt-dlp, FFmpeg and the others: version, licence, installed or shipped.
pub fn get_tools() -> Result<Vec<ToolStatus>> {
    Ok(tools_status(&getter()?.ytdlp))
}

pub struct YtDlpUpdate {
    /// A newer version was installed (its signature verified).
    pub updated: bool,
    pub version: String,
}

/// When yt-dlp was last checked for updates (ms since the epoch).
const KEY_YTDLP_CHECKED_AT: &str = "ytdlp_checked_at";
/// At most one automatic check a day.
const YTDLP_CHECK_INTERVAL_MS: i64 = 24 * 60 * 60 * 1000;

async fn check_ytdlp_update(g: &Getter) -> Result<YtDlpUpdate> {
    let _guard = g.install_lock.lock().await;
    let outcome = g
        .ytdlp
        .components()
        .update_ytdlp(&CancellationToken::new())
        .await?;
    let _ = lock(&g.storage).set_setting(KEY_YTDLP_CHECKED_AT, &now_ms());
    Ok(match outcome {
        download_engine::ytdlp::update::UpdateOutcome::UpToDate { version } => YtDlpUpdate {
            updated: false,
            version,
        },
        download_engine::ytdlp::update::UpdateOutcome::Updated { version } => YtDlpUpdate {
            updated: true,
            version,
        },
    })
}

/// Settings › Téléchargements › "Rechercher une mise à jour" (Windows).
pub fn get_update_ytdlp() -> Result<YtDlpUpdate> {
    if !cfg!(windows) {
        return Err(anyhow!("unsupported_platform"));
    }
    let g = getter()?;
    let runtime = g.runtime.clone();
    runtime.block_on(async move { check_ytdlp_update(&g).await })
}

/// As the Tauri app: two minutes after start, then hourly, a check at most
/// once a day when yt-dlp is installed.
async fn daily_ytdlp_updates() {
    use std::time::Duration;
    tokio::time::sleep(Duration::from_secs(120)).await;
    loop {
        if let Ok(g) = getter()
            && g.ytdlp.available()
        {
            let last: i64 = lock(&g.storage)
                .setting(KEY_YTDLP_CHECKED_AT)
                .ok()
                .flatten()
                .unwrap_or(0);
            if now_ms() - last >= YTDLP_CHECK_INTERVAL_MS
                && let Err(err) = check_ytdlp_update(&g).await
            {
                eprintln!("yt-dlp update check failed: {err}");
            }
        }
        tokio::time::sleep(Duration::from_secs(3600)).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn links_are_checked_with_stable_codes() {
        let ok = get_check_link("https://example.org/v.mp4".into());
        assert_eq!(ok.host.as_deref(), Some("example.org"));
        assert!(ok.error.is_none());
        assert_eq!(get_check_link(" ".into()).error.as_deref(), Some("empty"));
        assert_eq!(
            get_check_link("ftp://example.org/a".into())
                .error
                .as_deref(),
            Some("unsupported_scheme")
        );
        assert_eq!(
            get_check_link("https://user:pw@example.org/a".into())
                .error
                .as_deref(),
            Some("contains_credentials")
        );
    }

    #[test]
    fn video_sites_go_straight_to_the_extractor() {
        for host in [
            "web.facebook.com",
            "facebook.com",
            "m.facebook.com",
            "www.youtube.com",
            "youtu.be",
            "www.instagram.com",
            "vm.tiktok.com",
            "x.com",
        ] {
            assert!(page_host(host), "{host}");
        }
        for host in [
            "notfacebook.com",
            "example.org",
            "box.com",
            "cdn.example.net",
        ] {
            assert!(!page_host(host), "{host}");
        }
    }

    #[test]
    fn a_page_that_fails_the_file_check_still_goes_to_the_extractor() {
        let page = validate_media_url("https://example.org/watch/123").unwrap();
        let file = validate_media_url("https://example.org/film.mp4").unwrap();
        let stalled = EngineError::Network {
            message: "the link did not answer in time".into(),
        };
        assert!(should_extract(&page, &stalled));
        assert!(should_extract(&page, &EngineError::Http { status: 403 }));
        assert!(should_extract(&page, &EngineError::NotMedia));
        // A media file keeps its real error.
        assert!(!should_extract(&file, &stalled));
        assert!(!should_extract(&file, &EngineError::Http { status: 404 }));
    }

    /// End to end on a real direct file (network): analysis, download,
    /// file on disk, history. Manual: `MM_GET_DB`, `MM_GET_DATA`,
    /// `MM_GET_DIR`, `MM_GET_URL`, then
    /// `cargo test -- --ignored downloads_a_direct_file`.
    #[test]
    #[ignore = "network and a scratch database"]
    fn downloads_a_direct_file() {
        let var = |k: &str| std::env::var(k).unwrap_or_else(|_| panic!("{k} not set"));
        crate::api::indexer::indexer_start(var("MM_GET_DB"), var("MM_GET_DATA"), None).unwrap();
        get_start(var("MM_GET_DIR")).unwrap();
        let url = var("MM_GET_URL");
        let analysis = get_analyze(url.clone()).unwrap();
        assert!(
            matches!(analysis.status, AnalysisStatus::Ready),
            "{}",
            analysis.code
        );
        let info = analysis.info.unwrap();
        assert_eq!(info.engine, "http");
        let format = info.audio.first().or(info.video.first()).unwrap();
        let task = get_start_download(StartRequest {
            url,
            title: info.title.clone(),
            is_audio: !info.audio.is_empty(),
            engine: info.engine.clone(),
            format_id: None,
            format_label: format.quality.clone(),
            extension: format.extension.clone(),
            start_now: true,
            thumbnail: None,
        })
        .unwrap();
        let mut done = None;
        for _ in 0..600 {
            if let Some(h) = get_history(20)
                .unwrap()
                .into_iter()
                .find(|h| h.task_id == task.id)
            {
                done = Some(h);
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        let entry = done.expect("finished within a minute");
        assert!(entry.completed, "{:?}", entry.reason);
        let path = entry.final_path.unwrap();
        assert!(Path::new(&path).is_file());
        println!("downloaded {path} ({} bytes)", entry.done_bytes);
    }

    #[test]
    fn a_page_without_media_extension_goes_to_the_extractor() {
        let page = validate_media_url("https://example.org/watch?v=1").unwrap();
        let file = validate_media_url("https://example.org/a/b.mp4?x=1").unwrap();
        assert_eq!(url_path(&file), "/a/b.mp4");
        let refused = EngineError::Http { status: 403 };
        assert!(should_extract(&page, &refused));
        assert!(!should_extract(&file, &refused));
        assert!(should_extract(&file, &EngineError::NotMedia));
    }
}

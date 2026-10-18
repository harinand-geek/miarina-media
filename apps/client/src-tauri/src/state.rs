//! Application state shared by commands: storage, download manager and the
//! persisted user settings that drive resource limits.

use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard};

use download_engine::{HttpEngine, Manager, YtDlpEngine};
use library::{Library, WorkLimits};
use resource_manager::{Limits, Platform, ResourceMode, limits};
use serde::Serialize;
use storage::Storage;

pub const KEY_DOWNLOAD_DIR: &str = "download_dir";
pub const KEY_CONCURRENCY: &str = "concurrency";
pub const KEY_RESOURCE_MODE: &str = "resource_mode";
pub const DEFAULT_CONCURRENCY: usize = 3;

pub struct AppState {
    pub storage: Arc<Mutex<Storage>>,
    pub manager: Manager,
    pub http: HttpEngine,
    pub ytdlp: YtDlpEngine,
    pub library: Library,
    pub default_download_dir: PathBuf,
    /// Android 11+: audio goes to shared `Music/Miarina`, video to the
    /// download folder (`Movies/Miarina`). `None`: one folder for both.
    pub audio_download_dir: Option<PathBuf>,
    /// Where temporary download files are written when not next to the
    /// destination (Android shared storage only accepts media files).
    pub staging_dir: Option<PathBuf>,
    /// Serializes component installs (one download of each tool at a time).
    pub install_lock: tokio::sync::Mutex<()>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SettingsDto {
    pub download_dir: String,
    /// Separate folder for audio (Android shared `Music/Miarina`).
    pub audio_download_dir: Option<String>,
    pub concurrency: usize,
    pub resource_mode: ResourceMode,
    pub limits: Limits,
}

pub const PLATFORM: Platform = if cfg!(target_os = "android") {
    Platform::Android
} else {
    Platform::Windows
};

pub fn cpu_count() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(2)
}

impl AppState {
    pub fn storage(&self) -> MutexGuard<'_, Storage> {
        self.storage
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    /// Folder holding temporary download files.
    pub fn temp_dir(&self) -> PathBuf {
        self.staging_dir
            .clone()
            .unwrap_or_else(|| PathBuf::from(self.settings().download_dir))
    }

    /// Folder a new download of `kind` is saved to.
    pub fn download_dir_for(&self, kind: storage::MediaKind) -> String {
        match (kind, &self.audio_download_dir) {
            (storage::MediaKind::Audio, Some(dir)) => dir.to_string_lossy().into_owned(),
            _ => self.settings().download_dir,
        }
    }

    pub fn settings(&self) -> SettingsDto {
        let storage = self.storage();
        let download_dir = storage
            .setting::<String>(KEY_DOWNLOAD_DIR)
            .ok()
            .flatten()
            .unwrap_or_else(|| self.default_download_dir.to_string_lossy().into_owned());
        let concurrency = storage
            .setting::<usize>(KEY_CONCURRENCY)
            .ok()
            .flatten()
            .unwrap_or(DEFAULT_CONCURRENCY);
        let resource_mode = storage
            .setting::<ResourceMode>(KEY_RESOURCE_MODE)
            .ok()
            .flatten()
            .unwrap_or_default();
        SettingsDto {
            download_dir,
            audio_download_dir: self
                .audio_download_dir
                .as_ref()
                .map(|d| d.to_string_lossy().into_owned()),
            concurrency,
            resource_mode,
            limits: limits(resource_mode, PLATFORM, concurrency, cpu_count()),
        }
    }

    /// Re-applies limits after a settings change.
    pub fn apply_limits(&self) -> SettingsDto {
        let settings = self.settings();
        self.manager.set_limits(settings.limits);
        self.library.set_limits(WorkLimits {
            max_conversions: settings.limits.max_conversions,
            thumbnail_px: settings.limits.thumbnail_px,
            ffmpeg_threads: settings.limits.ffmpeg_threads,
        });
        settings
    }
}

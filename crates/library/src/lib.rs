//! Local media library: indexes the download folder, reads metadata with
//! ffprobe, builds thumbnails with FFmpeg and performs file operations
//! (rename, delete) only on files the library knows.

pub mod files;
pub mod probe;

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard};

use download_engine::components::{Components, FFMPEG};
use download_engine::fsops::finalize_no_clobber;
use media_core::sanitize_filename;
use serde::Serialize;
use storage::{MediaProbe, MediaRecord, NewMedia, Storage, StorageError};
use thiserror::Error;
use tokio::sync::{Notify, Semaphore};
use tokio::task::JoinSet;

#[derive(Debug, Error)]
pub enum LibraryError {
    #[error(transparent)]
    Storage(#[from] StorageError),
    #[error("file system error: {0}")]
    Io(String),
    #[error("metadata could not be read: {0}")]
    Probe(String),
    #[error("thumbnail could not be created: {0}")]
    Thumbnail(String),
    #[error("invalid name")]
    InvalidName,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ScanReport {
    pub added: usize,
    pub missing: usize,
    pub restored: usize,
}

/// Notifies the UI that library rows changed.
pub type ChangeListener = Arc<dyn Fn() + Send + Sync>;

/// What a platform prober found: metadata, and whether it wrote a picture.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ProbeResult {
    pub probe: MediaProbe,
    pub thumbnail_written: bool,
}

pub type ProbeFuture<'a> = std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<ProbeResult, LibraryError>> + Send + 'a>,
>;

/// Reads metadata and builds thumbnails with platform APIs where FFmpeg
/// does not run (Android: MediaMetadataRetriever). When set, it replaces
/// ffprobe/FFmpeg for the library.
pub trait Prober: Send + Sync {
    /// `thumbnail`: where to write a JPEG (longest edge at most `max_px`),
    /// or `None` when the entry already has a picture.
    fn probe<'a>(
        &'a self,
        media: &'a Path,
        thumbnail: Option<&'a Path>,
        max_px: u32,
    ) -> ProbeFuture<'a>;
}

/// How the worker reads files.
#[derive(Clone)]
enum Tools {
    Ffmpeg { ffmpeg: PathBuf, ffprobe: PathBuf },
    Platform(Arc<dyn Prober>),
}

/// Settings applied to background work (from the resource mode).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WorkLimits {
    pub max_conversions: usize,
    pub thumbnail_px: u32,
    pub ffmpeg_threads: usize,
}

impl Default for WorkLimits {
    fn default() -> Self {
        Self {
            max_conversions: 1,
            thumbnail_px: 360,
            ffmpeg_threads: 1,
        }
    }
}

struct Inner {
    storage: Arc<Mutex<Storage>>,
    components: Components,
    thumbnails: PathBuf,
    limits: Mutex<WorkLimits>,
    prober: Mutex<Option<Arc<dyn Prober>>>,
    wake: Notify,
    on_change: ChangeListener,
}

#[derive(Clone)]
pub struct Library {
    inner: Arc<Inner>,
}

fn lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn io(err: std::io::Error) -> LibraryError {
    LibraryError::Io(err.to_string())
}

/// Items read with ffprobe per worker round.
const PROBE_BATCH: u32 = 32;
/// Subfolder of the thumbnail folder holding source thumbnails.
const SOURCES_DIR: &str = "sources";
const PICTURE_EXTENSIONS: [&str; 3] = ["jpg", "png", "webp"];

impl Library {
    pub fn new(
        storage: Arc<Mutex<Storage>>,
        components: Components,
        thumbnails: PathBuf,
        on_change: ChangeListener,
    ) -> Self {
        Self {
            inner: Arc::new(Inner {
                storage,
                components,
                thumbnails,
                limits: Mutex::new(WorkLimits::default()),
                prober: Mutex::new(None),
                wake: Notify::new(),
                on_change,
            }),
        }
    }

    pub fn thumbnails_dir(&self) -> &Path {
        &self.inner.thumbnails
    }

    /// Source thumbnails cached at analysis time (see
    /// `HttpEngine::fetch_thumbnail`), inside the thumbnail folder.
    pub fn source_thumbnails_dir(&self) -> PathBuf {
        self.inner.thumbnails.join(SOURCES_DIR)
    }

    /// `true` when `path` is a cached source thumbnail: the only pictures a
    /// download task may reference.
    pub fn is_source_thumbnail(&self, path: &Path) -> bool {
        let picture = path
            .extension()
            .and_then(|e| e.to_str())
            .is_some_and(|e| PICTURE_EXTENSIONS.contains(&e));
        let (Ok(file), Ok(dir)) = (
            path.canonicalize(),
            self.source_thumbnails_dir().canonicalize(),
        ) else {
            return false;
        };
        picture && file.is_file() && file.parent() == Some(dir.as_path())
    }

    /// Uses platform APIs instead of FFmpeg (Android) and wakes the worker.
    pub fn set_prober(&self, prober: Arc<dyn Prober>) {
        *lock(&self.inner.prober) = Some(prober);
        self.inner.wake.notify_one();
    }

    /// The platform prober when set, else FFmpeg/ffprobe when installed.
    fn tools(&self) -> Option<Tools> {
        if let Some(prober) = lock(&self.inner.prober).clone() {
            return Some(Tools::Platform(prober));
        }
        let ffmpeg = self.inner.components.path(&FFMPEG)?;
        let ffprobe = ffmpeg
            .parent()
            .map(|d| d.join("ffprobe.exe"))
            .filter(|p| p.is_file())?;
        Some(Tools::Ffmpeg { ffmpeg, ffprobe })
    }

    /// Wakes the background worker, e.g. once FFmpeg has been installed.
    pub fn refresh(&self) {
        self.inner.wake.notify_one();
    }

    pub fn set_limits(&self, limits: WorkLimits) {
        *lock(&self.inner.limits) = limits;
        self.inner.wake.notify_one();
    }

    /// Adds a finished download and schedules its metadata. The source
    /// thumbnail of the task, if any, becomes the entry's picture at once.
    pub fn add_download(
        &self,
        path: &Path,
        source_host: &str,
        source_url: &str,
        task_id: &str,
        thumbnail: Option<&Path>,
    ) -> Result<Option<MediaRecord>, LibraryError> {
        let Some(kind) = files::kind_for(path) else {
            return Ok(None);
        };
        let size = std::fs::metadata(path).map_err(io)?.len();
        let record = lock(&self.inner.storage).upsert_media(&NewMedia {
            path: path.to_string_lossy().into_owned(),
            title: files::title_for(path),
            kind,
            source_host: Some(source_host.to_owned()),
            source_url: Some(source_url.to_owned()),
            task_id: Some(task_id.to_owned()),
            size_bytes: size,
        })?;
        let record = match thumbnail.filter(|t| self.is_source_thumbnail(t)) {
            Some(source) => self.adopt_thumbnail(record, source),
            None => record,
        };
        (self.inner.on_change)();
        self.inner.wake.notify_one();
        Ok(Some(record))
    }

    /// Copies a source thumbnail as the entry's own picture, so deleting
    /// the entry never removes a file another task may still show.
    fn adopt_thumbnail(&self, record: MediaRecord, source: &Path) -> MediaRecord {
        let ext = source.extension().and_then(|e| e.to_str()).unwrap_or("jpg");
        let target = self.inner.thumbnails.join(format!("{}.{ext}", record.id));
        if std::fs::copy(source, &target).is_err() {
            return record;
        }
        let path = target.to_string_lossy();
        let storage = lock(&self.inner.storage);
        match storage.set_media_thumbnail(record.id, &path) {
            Ok(()) => storage.media(record.id).unwrap_or(record),
            Err(_) => record,
        }
    }

    /// Indexes `root`: new files are added, vanished ones marked missing,
    /// returning ones restored. Blocking file system work: call it from a
    /// blocking task.
    pub fn scan(&self, root: &Path) -> Result<ScanReport, LibraryError> {
        let found = files::media_files(root);
        let storage = lock(&self.inner.storage);
        let known = storage.media_paths()?;
        let mut report = ScanReport::default();
        for path in &found {
            let key = path.to_string_lossy();
            match known.iter().find(|(_, p, _)| *p == key) {
                Some((id, _, true)) => {
                    storage.set_media_missing(*id, false)?;
                    report.restored += 1;
                }
                Some(_) => {}
                None => {
                    let Some(kind) = files::kind_for(path) else {
                        continue;
                    };
                    storage.upsert_media(&NewMedia {
                        path: key.into_owned(),
                        title: files::title_for(path),
                        kind,
                        source_host: None,
                        source_url: None,
                        task_id: None,
                        size_bytes: std::fs::metadata(path).map(|m| m.len()).unwrap_or(0),
                    })?;
                    report.added += 1;
                }
            }
        }
        // Files of this folder the library knew but that are gone.
        for (id, path, missing) in &known {
            if !missing && Path::new(path).starts_with(root) && !Path::new(path).exists() {
                storage.set_media_missing(*id, true)?;
                report.missing += 1;
            }
        }
        drop(storage);
        if report != ScanReport::default() {
            (self.inner.on_change)();
            self.inner.wake.notify_one();
        }
        Ok(report)
    }

    /// Checks that a library file still exists (lazy existence check).
    pub fn check(&self, id: i64) -> Result<MediaRecord, LibraryError> {
        let storage = lock(&self.inner.storage);
        let record = storage.media(id)?;
        let exists = Path::new(&record.path).is_file();
        if exists == record.missing {
            storage.set_media_missing(id, !exists)?;
            drop(storage);
            (self.inner.on_change)();
            return Ok(lock(&self.inner.storage).media(id)?);
        }
        Ok(record)
    }

    /// Renames the file on disk (same folder, same extension, never
    /// overwriting) and the library entry.
    pub fn rename(&self, id: i64, new_title: &str) -> Result<MediaRecord, LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        let path = PathBuf::from(&record.path);
        let ext = files::extension(&path).ok_or(LibraryError::InvalidName)?;
        let name = sanitize_filename(new_title, &ext).map_err(|_| LibraryError::InvalidName)?;
        let dir = path.parent().ok_or(LibraryError::InvalidName)?;
        if path.file_name().and_then(|n| n.to_str()) == Some(name.as_str()) {
            return Ok(record);
        }
        let target =
            finalize_no_clobber(&path, dir, &name).map_err(|e| LibraryError::Io(e.to_string()))?;
        let updated = lock(&self.inner.storage).rename_media(
            id,
            &target.to_string_lossy(),
            &files::title_for(&target),
        )?;
        (self.inner.on_change)();
        Ok(updated)
    }

    /// Deletes the file and its thumbnail, then forgets the entry.
    pub fn delete(&self, id: i64) -> Result<(), LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        match std::fs::remove_file(&record.path) {
            Ok(()) => {}
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(io(e)),
        }
        if let Some(thumb) = &record.thumbnail {
            let _ = std::fs::remove_file(thumb);
        }
        lock(&self.inner.storage).delete_media(id)?;
        (self.inner.on_change)();
        Ok(())
    }

    /// Size of the thumbnail cache, in bytes.
    pub fn thumbnail_cache_bytes(&self) -> u64 {
        let size = |dir: &Path| -> u64 {
            std::fs::read_dir(dir)
                .map(|entries| {
                    entries
                        .flatten()
                        .filter_map(|e| e.metadata().ok())
                        .filter(|m| m.is_file())
                        .map(|m| m.len())
                        .sum()
                })
                .unwrap_or(0)
        };
        size(&self.inner.thumbnails) + size(&self.source_thumbnails_dir())
    }

    /// Deletes every thumbnail; they are rebuilt in the background.
    pub fn clear_thumbnails(&self) -> Result<u64, LibraryError> {
        let freed = self.thumbnail_cache_bytes();
        if self.inner.thumbnails.exists() {
            std::fs::remove_dir_all(&self.inner.thumbnails).map_err(io)?;
        }
        lock(&self.inner.storage).reset_thumbnails()?;
        (self.inner.on_change)();
        self.inner.wake.notify_one();
        Ok(freed)
    }

    /// Background worker: reads metadata and builds thumbnails for new
    /// entries, at most `max_conversions` FFmpeg jobs at a time. Waits for
    /// work instead of polling.
    pub async fn run_worker(self) {
        loop {
            self.process_pending().await;
            self.inner.wake.notified().await;
        }
    }

    /// Processes every pending entry, then returns (used by tests too).
    pub async fn process_pending(&self) {
        loop {
            let Some(tools) = self.tools() else {
                return;
            };
            let batch = match lock(&self.inner.storage).media_to_probe(PROBE_BATCH) {
                Ok(batch) if !batch.is_empty() => batch,
                _ => return,
            };
            let limits = *lock(&self.inner.limits);
            let permits = Arc::new(Semaphore::new(limits.max_conversions.max(1)));
            let mut jobs = JoinSet::new();
            for record in batch {
                let permit = permits
                    .clone()
                    .acquire_owned()
                    .await
                    .expect("semaphore open");
                let this = self.clone();
                let tools = tools.clone();
                jobs.spawn(async move {
                    this.describe(&record, &tools, limits).await;
                    drop(permit);
                });
            }
            while jobs.join_next().await.is_some() {}
            (self.inner.on_change)();
        }
    }

    async fn describe(&self, record: &MediaRecord, tools: &Tools, limits: WorkLimits) {
        let path = Path::new(&record.path);
        if !path.is_file() {
            let _ = lock(&self.inner.storage).set_media_missing(record.id, true);
            return;
        }
        // A source thumbnail (downloads) is kept: no frame is extracted.
        let has_picture = record
            .thumbnail
            .as_deref()
            .is_some_and(|t| Path::new(t).is_file());
        let (ffmpeg, ffprobe) = match tools {
            Tools::Ffmpeg { ffmpeg, ffprobe } => (ffmpeg, ffprobe),
            Tools::Platform(prober) => {
                let out = self.inner.thumbnails.join(format!("{}.jpg", record.id));
                let wanted =
                    !has_picture && std::fs::create_dir_all(&self.inner.thumbnails).is_ok();
                let target = wanted.then_some(out.as_path());
                match prober.probe(path, target, limits.thumbnail_px).await {
                    Ok(found) => {
                        let thumbnail = (found.thumbnail_written && out.is_file())
                            .then(|| out.to_string_lossy().into_owned());
                        let _ = lock(&self.inner.storage).set_media_probe(
                            record.id,
                            &found.probe,
                            thumbnail.as_deref(),
                        );
                    }
                    Err(_) => {
                        let _ = lock(&self.inner.storage).mark_media_unprobeable(record.id);
                    }
                }
                return;
            }
        };
        let Ok(meta) = probe::probe(ffprobe, path).await else {
            let _ = lock(&self.inner.storage).mark_media_unprobeable(record.id);
            return;
        };
        let mut thumbnail = None;
        if meta.has_video && !has_picture && std::fs::create_dir_all(&self.inner.thumbnails).is_ok()
        {
            let out = self.inner.thumbnails.join(format!("{}.jpg", record.id));
            if probe::thumbnail(
                ffmpeg,
                path,
                &out,
                meta.duration_secs,
                limits.thumbnail_px,
                limits.ffmpeg_threads,
            )
            .await
            .is_ok()
            {
                thumbnail = Some(out.to_string_lossy().into_owned());
            }
        }
        let _ = lock(&self.inner.storage).set_media_probe(record.id, &meta, thumbnail.as_deref());
    }
}

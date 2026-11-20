//! Local media library: indexes the download folder, reads metadata with
//! ffprobe, builds thumbnails with FFmpeg and performs file operations
//! (rename, delete) only on files the library knows.

pub mod files;
pub mod health;
pub mod probe;
pub mod tags;

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard};

use download_engine::components::{Components, FFMPEG};
use download_engine::fsops::finalize_no_clobber;
use media_core::sanitize_filename;
use serde::Serialize;
use storage::{
    GroupBy, MediaGroup, MediaProbe, MediaRecord, MediaTags, NewMedia, Storage, StorageError,
};
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
    #[error(transparent)]
    Tags(#[from] tags::TagWriteError),
    #[error("the file is no longer on disk")]
    Missing,
    /// The system refuses to delete the file (Android: media of another
    /// app or copied from a computer, AND-06).
    #[error("the system does not allow deleting this file")]
    NotAllowed,
    #[error("cover refused: {0}")]
    Cover(&'static str),
}

/// Covers are stored at most this large (longest edge).
/// Files taken from one open or drop.
pub const MAX_OPENED: usize = 500;
/// Bound on the files taken from a platform media list.
pub const MAX_LISTED: usize = 20_000;
const COVER_PX: u32 = 1000;
/// Largest picture accepted as a cover.
const COVER_SOURCE_MAX: u64 = 30 * 1024 * 1024;
const COVER_EXTENSIONS: [&str; 6] = ["jpg", "jpeg", "png", "webp", "bmp", "gif"];

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
    /// `false`: "Delete file" erases instead of using the Recycle Bin.
    use_trash: std::sync::atomic::AtomicBool,
}

#[derive(Clone)]
pub struct Library {
    inner: Arc<Inner>,
}

fn lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn discard(path: &Path, use_trash: bool) -> Result<(), LibraryError> {
    #[cfg(not(target_os = "android"))]
    if use_trash {
        return trash::delete(path).map_err(|e| LibraryError::Io(e.to_string()));
    }
    #[cfg(target_os = "android")]
    let _ = use_trash;
    match std::fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => Err(LibraryError::NotAllowed),
        Err(e) => Err(io(e)),
    }
}

fn io(err: std::io::Error) -> LibraryError {
    LibraryError::Io(err.to_string())
}

/// Items read with ffprobe per worker round.
const PROBE_BATCH: u32 = 32;
/// Tag reads per batch (pure Rust, no external tool).
const TAG_BATCH: u32 = 64;
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
                use_trash: std::sync::atomic::AtomicBool::new(cfg!(not(target_os = "android"))),
            }),
        }
    }

    /// Deletes files permanently instead of moving them to the Recycle Bin
    /// (tests, or systems without a trash).
    pub fn set_use_trash(&self, on: bool) {
        self.inner
            .use_trash
            .store(on, std::sync::atomic::Ordering::Relaxed);
    }

    pub fn thumbnails_dir(&self) -> &Path {
        &self.inner.thumbnails
    }

    /// Pictures chosen by the user (COM-07). Kept apart from the thumbnail
    /// cache, which the user may clear.
    pub fn covers_dir(&self) -> PathBuf {
        self.inner.thumbnails.with_file_name("covers")
    }

    /// Deletes a picture this library made (generated thumbnail or chosen
    /// cover); cached source pictures stay (tasks may still show them).
    fn forget_picture(&self, picture: &Path) {
        let own = (picture.starts_with(&self.inner.thumbnails)
            && !picture.starts_with(self.source_thumbnails_dir()))
            || picture.starts_with(self.covers_dir());
        if own {
            let _ = std::fs::remove_file(picture);
        }
    }

    /// Stores `cover` (or no picture) as chosen by the user and deletes the
    /// picture it replaces.
    fn replace_cover(
        &self,
        record: &MediaRecord,
        cover: Option<&Path>,
    ) -> Result<MediaRecord, LibraryError> {
        let storage = lock(&self.inner.storage);
        let cover = cover.map(|c| c.to_string_lossy().into_owned());
        if let Err(e) = storage.set_media_cover(record.id, cover.as_deref()) {
            drop(storage);
            if let Some(c) = &cover {
                let _ = std::fs::remove_file(c);
            }
            return Err(e.into());
        }
        let updated = storage.media(record.id)?;
        drop(storage);
        if let Some(old) = &record.thumbnail
            && cover.as_deref() != Some(old.as_str())
        {
            self.forget_picture(Path::new(old));
        }
        (self.inner.on_change)();
        Ok(updated)
    }

    /// Converts `source` (a picture, or the frame at `at` seconds of a video)
    /// into the entry's cover. Needs FFmpeg (desktop).
    async fn make_cover(
        &self,
        record: &MediaRecord,
        source: &Path,
        at: Option<f64>,
    ) -> Result<MediaRecord, LibraryError> {
        let Some(Tools::Ffmpeg { ffmpeg, .. }) = self.tools() else {
            return Err(LibraryError::Cover("FFmpeg is needed for covers"));
        };
        let dir = self.covers_dir();
        std::fs::create_dir_all(&dir).map_err(io)?;
        let out = dir.join(format!("{}-{}.jpg", record.id, storage::now_ms()));
        let threads = lock(&self.inner.limits).ffmpeg_threads;
        probe::jpeg(&ffmpeg, source, &out, at, COVER_PX, threads).await?;
        self.replace_cover(record, Some(&out))
    }

    /// Cover from a picture file chosen by the user.
    pub async fn cover_from_image(
        &self,
        id: i64,
        image: &Path,
    ) -> Result<MediaRecord, LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        let ext = image
            .extension()
            .and_then(|e| e.to_str())
            .map(str::to_ascii_lowercase)
            .unwrap_or_default();
        if !COVER_EXTENSIONS.contains(&ext.as_str()) {
            return Err(LibraryError::Cover("not a supported picture"));
        }
        let size = std::fs::metadata(image).map_err(io)?.len();
        if size == 0 || size > COVER_SOURCE_MAX {
            return Err(LibraryError::Cover("picture too large"));
        }
        self.make_cover(&record, image, None).await
    }

    /// Cover from the thumbnail the source offered at download time.
    pub async fn cover_from_source(&self, id: i64) -> Result<MediaRecord, LibraryError> {
        // Scoped so the lock is not held across the await below.
        let (record, source) = {
            let storage = lock(&self.inner.storage);
            let record = storage.media(id)?;
            let source = record
                .task_id
                .as_deref()
                .and_then(|task| storage.task(task).ok())
                .and_then(|task| task.thumbnail)
                .map(PathBuf::from);
            (record, source)
        };
        let source = source
            .filter(|s| self.is_source_thumbnail(s) && s.is_file())
            .ok_or(LibraryError::Cover("the source gave no thumbnail"))?;
        self.make_cover(&record, &source, None).await
    }

    /// Whether a source thumbnail is available for this entry.
    pub fn has_source_thumbnail(&self, id: i64) -> bool {
        let storage = lock(&self.inner.storage);
        storage
            .media(id)
            .ok()
            .and_then(|m| m.task_id)
            .and_then(|task| storage.task(&task).ok())
            .and_then(|task| task.thumbnail)
            .is_some_and(|t| {
                let t = PathBuf::from(t);
                self.is_source_thumbnail(&t) && t.is_file()
            })
    }

    /// Cover from the frame at `at` seconds of a video entry.
    pub async fn cover_from_frame(&self, id: i64, at: f64) -> Result<MediaRecord, LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        if record.kind != storage::MediaKind::Video {
            return Err(LibraryError::Cover("only videos have frames"));
        }
        let path = PathBuf::from(&record.path);
        if !path.is_file() {
            return Err(LibraryError::Missing);
        }
        let end = record.duration_secs.unwrap_or(f64::MAX);
        let at = if at.is_finite() {
            at.clamp(0.0, (end - 0.5).max(0.0))
        } else {
            0.0
        };
        self.make_cover(&record, &path, Some(at)).await
    }

    /// No picture at all, on purpose (the library will not build one).
    pub fn remove_cover(&self, id: i64) -> Result<MediaRecord, LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        self.replace_cover(&record, None)
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
        self.index(&found, |path| path.starts_with(root))
    }

    /// Indexes media files listed by the platform (Android media index,
    /// AND-06), at most `MAX_LISTED`. Entries the list no longer names are
    /// marked missing only when their file is gone: the app's own folders
    /// are scanned separately. Removed entries are not added back (COM-10).
    pub fn sync_listed(&self, listed: &[PathBuf]) -> Result<ScanReport, LibraryError> {
        let mut seen = std::collections::HashSet::new();
        let found: Vec<PathBuf> = listed
            .iter()
            .filter(|p| p.is_absolute() && files::kind_for(p).is_some() && seen.insert(p.as_path()))
            .filter(|p| p.is_file())
            .take(MAX_LISTED)
            .cloned()
            .collect();
        let named: std::collections::HashSet<&Path> = found.iter().map(PathBuf::as_path).collect();
        self.index(&found, |path| !named.contains(path))
    }

    /// Adds `found`, restores the ones marked missing, and marks missing the
    /// known entries that `may_be_gone` selects and whose file no longer
    /// exists. One transaction.
    fn index(
        &self,
        found: &[PathBuf],
        may_be_gone: impl Fn(&Path) -> bool,
    ) -> Result<ScanReport, LibraryError> {
        let storage = lock(&self.inner.storage);
        let known = storage.media_paths()?;
        let by_path: std::collections::HashMap<&str, (i64, bool)> = known
            .iter()
            .map(|(id, path, missing)| (path.as_str(), (*id, *missing)))
            .collect();
        let removed = storage.removed_media_paths()?;
        // One transaction: 10 000 new files took 30 s with one commit each
        // (L00 measurement).
        let report = storage.with_batch(|storage| {
            let mut report = ScanReport::default();
            for path in found {
                let key = path.to_string_lossy();
                if removed.contains(key.as_ref()) {
                    continue;
                }
                match by_path.get(key.as_ref()) {
                    Some((id, true)) => {
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
            // Files the library knew in this scope but that are gone.
            for (id, path, missing) in &known {
                let path = Path::new(path);
                if !missing && may_be_gone(path) && !path.exists() {
                    storage.set_media_missing(*id, true)?;
                    report.missing += 1;
                }
            }
            Ok(report)
        })?;
        drop(storage);
        if report != ScanReport::default() {
            (self.inner.on_change)();
            self.inner.wake.notify_one();
        }
        Ok(report)
    }

    /// Files the user opened on purpose (dialog, drag and drop), in the
    /// given order: indexed even if removed from the library before, found
    /// again if marked missing. Other files are ignored; at most
    /// `MAX_OPENED` are taken.
    pub fn add_opened(&self, paths: &[PathBuf]) -> Result<Vec<MediaRecord>, LibraryError> {
        let storage = lock(&self.inner.storage);
        let mut out = Vec::new();
        for path in paths.iter().filter(|p| p.is_file()).take(MAX_OPENED) {
            let Some(kind) = files::kind_for(path) else {
                continue;
            };
            let key = path.to_string_lossy().into_owned();
            storage.forget_removed(&key)?;
            let record = storage.upsert_media(&NewMedia {
                path: key,
                title: files::title_for(path),
                kind,
                source_host: None,
                source_url: None,
                task_id: None,
                size_bytes: std::fs::metadata(path).map(|m| m.len()).unwrap_or(0),
            })?;
            let record = if record.missing {
                storage.set_media_missing(record.id, false)?;
                storage.media(record.id)?
            } else {
                record
            };
            out.push(record);
        }
        drop(storage);
        if !out.is_empty() {
            (self.inner.on_change)();
            self.inner.wake.notify_one();
        }
        Ok(out)
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

    /// Removes the entry from the library but keeps the file on disk; later
    /// scans do not add it back (COM-10). A generated thumbnail goes with
    /// the entry; cached source pictures stay (tasks may still use them).
    pub fn remove(&self, id: i64) -> Result<(), LibraryError> {
        let storage = lock(&self.inner.storage);
        let record = storage.media(id)?;
        storage.remove_media(id)?;
        drop(storage);
        if let Some(thumb) = &record.thumbnail {
            self.forget_picture(Path::new(thumb));
        }
        (self.inner.on_change)();
        Ok(())
    }

    /// Moves the file to the Recycle Bin (desktop) or deletes it (Android),
    /// removes its thumbnail, then forgets the entry.
    pub fn delete(&self, id: i64) -> Result<(), LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        if Path::new(&record.path).exists() {
            let trash = self
                .inner
                .use_trash
                .load(std::sync::atomic::Ordering::Relaxed);
            discard(Path::new(&record.path), trash)?;
        }
        if let Some(thumb) = &record.thumbnail {
            self.forget_picture(Path::new(thumb));
        }
        lock(&self.inner.storage).delete_media(id)?;
        (self.inner.on_change)();
        Ok(())
    }

    /// Every tag of an entry (editor).
    pub fn tags(&self, id: i64) -> Result<MediaTags, LibraryError> {
        Ok(lock(&self.inner.storage).media_tags(id)?)
    }

    /// Saves edited tags in the library and, when asked and supported,
    /// in the file itself. Blocking file work: call from a blocking task.
    pub fn update_tags(
        &self,
        id: i64,
        tags: &MediaTags,
        write_to_file: bool,
    ) -> Result<MediaRecord, LibraryError> {
        let record = lock(&self.inner.storage).media(id)?;
        if write_to_file {
            let path = Path::new(&record.path);
            if !path.is_file() {
                return Err(LibraryError::Missing);
            }
            tags::write(path, tags)?;
        }
        let updated = lock(&self.inner.storage).update_media_tags(id, tags)?;
        (self.inner.on_change)();
        Ok(updated)
    }

    /// Albums, artists or folders of the music library.
    pub fn groups(&self, by: GroupBy) -> Result<Vec<MediaGroup>, LibraryError> {
        Ok(lock(&self.inner.storage).media_groups(by)?)
    }

    /// Reads the tags of entries that were never read. Runs without FFmpeg.
    pub async fn read_pending_tags(&self) {
        loop {
            let batch = match lock(&self.inner.storage).media_to_tag(TAG_BATCH) {
                Ok(batch) if !batch.is_empty() => batch,
                _ => return,
            };
            let read = tokio::task::spawn_blocking(move || {
                batch
                    .into_iter()
                    .map(|(id, path)| (id, tags::read(Path::new(&path))))
                    .collect::<Vec<_>>()
            })
            .await
            .unwrap_or_default();
            if read.is_empty() {
                return;
            }
            let storage = lock(&self.inner.storage);
            for (id, tags) in &read {
                let _ = storage.set_media_tags_read(*id, tags.as_ref());
            }
            drop(storage);
            (self.inner.on_change)();
        }
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
        self.read_pending_tags().await;
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

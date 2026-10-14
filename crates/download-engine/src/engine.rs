use std::path::PathBuf;
use std::time::Duration;

use futures_util::future::BoxFuture;
use media_core::ValidatedUrl;
use tokio_util::sync::CancellationToken;

use crate::{EngineError, Progress};

/// Everything an engine needs to run one transfer.
#[derive(Debug, Clone)]
pub struct DownloadJob {
    pub url: ValidatedUrl,
    /// Temporary file, in the destination directory so the final move is atomic.
    pub part_path: PathBuf,
    pub dest_dir: PathBuf,
    /// Sanitized file name; a free variant is chosen at finalization.
    pub file_name: String,
    /// Minimum delay between two progress callbacks.
    pub progress_interval: Duration,
    /// Engine-specific format selector (yt-dlp format id); ignored by HTTP.
    pub format_id: Option<String>,
    /// Resource limits for engines that spawn processes.
    pub process: ProcessLimits,
}

/// Subset of the resource-mode limits that applies to one transfer.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ProcessLimits {
    pub concurrent_fragments: usize,
    pub ffmpeg_threads: usize,
    pub low_priority: bool,
}

impl Default for ProcessLimits {
    fn default() -> Self {
        Self {
            concurrent_fragments: 1,
            ffmpeg_threads: 1,
            low_priority: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Outcome {
    pub final_path: PathBuf,
    pub bytes: u64,
    pub supports_resume: bool,
}

pub type ProgressFn<'a> = &'a (dyn Fn(Progress) + Send + Sync);

/// Platform-independent download interface. Analysis lives on each engine
/// because its result type differs (direct file vs. extractor formats).
pub trait Engine: Send + Sync {
    fn id(&self) -> &'static str;

    /// Streams the media to `job.part_path`, then moves it next to it under
    /// a free name. Must return [`EngineError::Canceled`] promptly once
    /// `cancel` fires and leave the partial file in place.
    fn download<'a>(
        &'a self,
        job: &'a DownloadJob,
        progress: ProgressFn<'a>,
        cancel: CancellationToken,
    ) -> BoxFuture<'a, Result<Outcome, EngineError>>;
}

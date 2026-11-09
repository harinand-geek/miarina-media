//! Miarina's task/lifecycle adapter for the pinned GPL MDM engine.
//! The upstream UI and services are not started by this adapter.

use download_engine::{
    DownloadJob, Engine, EngineError, HttpEngine, Outcome, Progress, ProgressFn, Stage,
};
use mdm_engine::download::State;
use mdm_engine::{Destination, Download, Options, Request};
use std::time::{Duration, Instant};
use tokio_util::sync::CancellationToken;

pub struct MdmEngine {
    legacy: HttpEngine,
}

impl MdmEngine {
    pub fn new(legacy: HttpEngine) -> Self {
        Self { legacy }
    }

    async fn run(
        &self,
        job: &DownloadJob,
        progress: ProgressFn<'_>,
        cancel: CancellationToken,
    ) -> Result<Outcome, EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Canceled);
        }
        // Existing sequential partial files must never be interpreted as sparse segments.
        if job.part_path.exists() {
            return self.legacy.download(job, progress, cancel).await;
        }
        // The manager already removes this per-task directory on explicit cancellation.
        let work = download_engine::ytdlp::work_dir(&job.part_path);
        tokio::fs::create_dir_all(&work).await.map_err(io_error)?;
        let target = work.join("transfer.bin");
        let state_path = mdm_engine::state::state_path(&target);
        let url =
            url::Url::parse(job.url.as_str()).map_err(|_| unsupported("Invalid download URL"))?;
        let opts = Options {
            max_connections: job.process.concurrent_fragments.clamp(1, 8) as u32,
            connect_timeout: Duration::from_secs(15),
            read_timeout: Duration::from_secs(30),
            max_retries: 2,
            user_agent: concat!("MiarinaMedia/", env!("CARGO_PKG_VERSION")).into(),
            ..Options::default()
        };
        let dl = if state_path.exists() {
            let saved = mdm_engine::state::ResumeState::load(&state_path)
                .map_err(|_| unsupported("Saved download state could not be read"))?;
            if saved.url != url || saved.dest != target {
                return Err(unsupported("Saved download state does not match this task"));
            }
            Download::resume(state_path, Default::default(), opts).map_err(map_error)?
        } else {
            // A completed staging file after a crash is left untouched; never guess its validity.
            if target.exists() {
                return Err(unsupported("A completed staging file needs recovery"));
            }
            Download::start(
                Request {
                    url,
                    headers: Default::default(),
                    dest: Destination::File(target),
                },
                opts,
            )
        };
        let started = Instant::now();
        let initial = dl.snapshot().downloaded;
        let mut resumable = false;
        loop {
            let s = dl.snapshot();
            resumable |= s.resumable == Some(true);
            progress(Progress {
                downloaded: s.downloaded,
                total: s.size,
                bytes_per_sec: s.downloaded.saturating_sub(initial) as f64
                    / started.elapsed().as_secs_f64().max(0.001),
                supports_resume: resumable,
                stage: if matches!(s.state, State::Verifying | State::Completing) {
                    Stage::Processing
                } else {
                    Stage::Downloading
                },
            });
            if matches!(s.state, State::Done | State::Failed | State::Cancelled) {
                break;
            }
            tokio::select! {
                _ = cancel.cancelled() => {
                    dl.cancel();
                    // Join the workers before the manager deletes partial files.
                    let _ = dl.wait().await;
                    return Err(EngineError::Canceled);
                }
                _ = tokio::time::sleep(job.progress_interval.max(Duration::from_millis(250))) => {}
            }
        }
        let done = dl.wait().await.map_err(map_error)?;
        let final_path =
            download_engine::fsops::finalize_no_clobber(&done.path, &job.dest_dir, &job.file_name)?;
        let _ = tokio::fs::remove_dir(&work).await;
        Ok(Outcome {
            final_path,
            bytes: done.size,
            supports_resume: resumable,
        })
    }
}

impl Engine for MdmEngine {
    fn id(&self) -> &'static str {
        "http"
    }
    fn download<'a>(
        &'a self,
        job: &'a DownloadJob,
        progress: ProgressFn<'a>,
        cancel: CancellationToken,
    ) -> std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<Outcome, EngineError>> + Send + 'a>,
    > {
        Box::pin(self.run(job, progress, cancel))
    }
}

fn unsupported(reason: &str) -> EngineError {
    EngineError::Unsupported {
        reason: reason.into(),
    }
}
fn io_error(e: std::io::Error) -> EngineError {
    if e.kind() == std::io::ErrorKind::StorageFull {
        EngineError::DiskFull
    } else {
        EngineError::Io {
            message: "Download storage could not be accessed".into(),
        }
    }
}
fn map_error(e: mdm_engine::Error) -> EngineError {
    use mdm_engine::Error as M;
    match e {
        M::Cancelled => EngineError::Canceled,
        M::DiskFull => EngineError::DiskFull,
        M::NoSpace { needed, free } => EngineError::InsufficientSpace {
            needed,
            available: free,
        },
        M::Status(s) | M::Throttled(s, _) => EngineError::Http { status: s.as_u16() },
        M::Http(_) | M::Net { .. } | M::ShortBody => EngineError::Network {
            message: "Connection interrupted".into(),
        },
        M::Io(_) | M::DriveGone | M::DestinationUnavailable(_) => EngineError::Io {
            message: "Download storage could not be accessed".into(),
        },
        // Do not persist upstream messages containing URLs, credentials or response bodies.
        _ => unsupported("The source or saved transfer cannot be downloaded safely"),
    }
}

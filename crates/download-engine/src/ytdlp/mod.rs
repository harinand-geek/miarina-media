//! yt-dlp engine (Windows). yt-dlp runs as a managed child process:
//! argument arrays only, `--ignore-config`, `--` before the URL, output
//! treated as untrusted, process tree killed on cancellation.

pub mod info;
pub mod offers;

use std::collections::VecDeque;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::{Duration, Instant};

use futures_util::FutureExt;
use futures_util::future::BoxFuture;
use media_core::ValidatedUrl;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, BufReader};
use tokio::process::Command;
use tokio_util::sync::CancellationToken;

use crate::components::Components;
use crate::engine::{DownloadJob, Engine, Outcome, ProgressFn};
use crate::fsops::finalize_no_clobber;
use crate::process::{ProcessTree, configure};
use crate::progress::{SpeedMeter, Throttle};
use crate::{EngineError, Progress, Stage};
pub use info::RawInfo;
pub use offers::{FormatSpec, Offer, Offers, build_offers};

const ANALYZE_TIMEOUT: Duration = Duration::from_secs(90);
const STDERR_TAIL: usize = 30;
const MAX_LINE: usize = 4096;
/// Prefix of the progress lines we ask yt-dlp to print.
const PROGRESS_TAG: &str = "MMDL";
const POSTPROCESS_TAG: &str = "MMPP";

/// Options that keep yt-dlp self-contained and predictable.
fn base_args(components: &Components) -> Vec<String> {
    let mut args: Vec<String> = vec![
        "--ignore-config".into(),
        "--no-plugin-dirs".into(),
        "--no-playlist".into(),
        "--no-color".into(),
        "--no-mtime".into(),
        "--cache-dir".into(),
        components.cache_dir().to_string_lossy().into_owned(),
    ];
    // Without a JavaScript runtime YouTube throttles downloads (measured
    // 2.4x slower) and may hide formats; see docs/decisions/0002.
    if let Some(qjs) = components.quickjs() {
        args.extend([
            "--js-runtimes".into(),
            format!("quickjs:{}", qjs.to_string_lossy()),
        ]);
    }
    args
}

/// What analysis produced, before UI formatting.
#[derive(Debug, Clone)]
pub struct Analysis {
    pub info: RawInfo,
    pub offers: Offers,
}

#[derive(Clone)]
pub struct YtDlpEngine {
    components: Components,
}

impl YtDlpEngine {
    pub fn new(components: Components) -> Self {
        Self { components }
    }

    pub fn components(&self) -> &Components {
        &self.components
    }

    fn executable(&self) -> Result<PathBuf, EngineError> {
        self.components
            .ytdlp()
            .ok_or_else(|| EngineError::Unsupported {
                reason: "the media extractor (yt-dlp) is not installed".into(),
            })
    }

    pub async fn analyze(
        &self,
        url: &ValidatedUrl,
        cancel: &CancellationToken,
    ) -> Result<Analysis, EngineError> {
        let exe = self.executable()?;
        let mut command = Command::new(exe);
        command
            .args(base_args(&self.components))
            .args(["--dump-single-json", "--no-warnings", "--", url.as_str()])
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        configure(&mut command, false);
        let mut child = command.spawn().map_err(EngineError::from_io)?;
        let _tree = ProcessTree::adopt(&child).ok();

        // Bounded reads: the extractor output is untrusted.
        let mut stdout = child
            .stdout
            .take()
            .expect("piped stdout")
            .take(info::MAX_JSON_BYTES as u64 + 1);
        let mut stderr = child.stderr.take().expect("piped stderr").take(64 * 1024);
        let read = async {
            let mut out = Vec::new();
            let mut err = Vec::new();
            let (a, b) = tokio::join!(stdout.read_to_end(&mut out), stderr.read_to_end(&mut err));
            a.and(b).map(|_| (out, err))
        };
        let (out, err) = tokio::select! {
            _ = cancel.cancelled() => return Err(EngineError::Canceled),
            _ = tokio::time::sleep(ANALYZE_TIMEOUT) => {
                return Err(EngineError::network("the source took too long to answer"));
            }
            r = read => r.map_err(EngineError::from_io)?,
        };
        let status = child.wait().await.map_err(EngineError::from_io)?;
        if !status.success() {
            let tail = String::from_utf8_lossy(&err);
            return Err(classify(tail.lines().rev().take(STDERR_TAIL)));
        }
        let info = RawInfo::parse(&out).map_err(|reason| EngineError::Unsupported { reason })?;
        if info.kind.as_deref() == Some("playlist") {
            return Err(EngineError::Unsupported {
                reason: "playlists are not supported yet".into(),
            });
        }
        if info.is_live() {
            return Err(EngineError::Unsupported {
                reason: "live streams are not supported".into(),
            });
        }
        let offers = build_offers(&info, self.components.ffmpeg_dir().is_some());
        if offers.video.is_empty() && offers.audio.is_empty() {
            let protected = info.formats().iter().any(|f| f.drm());
            return Err(EngineError::Unsupported {
                reason: if protected {
                    "this media is protected (DRM) and cannot be downloaded".into()
                } else {
                    "no downloadable format was found".into()
                },
            });
        }
        Ok(Analysis { info, offers })
    }

    async fn run(
        &self,
        job: &DownloadJob,
        progress: ProgressFn<'_>,
        cancel: CancellationToken,
    ) -> Result<Outcome, EngineError> {
        let exe = self.executable()?;
        let spec = FormatSpec::decode(job.format_id.as_deref().unwrap_or_default())
            .map_err(|reason| EngineError::Unsupported { reason })?;
        let work_dir = work_dir(&job.part_path);
        tokio::fs::create_dir_all(&work_dir)
            .await
            .map_err(EngineError::from_io)?;

        let mut args = base_args(&self.components);
        args.extend([
            "--newline".into(),
            "--progress".into(),
            "--progress-template".into(),
            format!(
                "download:{PROGRESS_TAG} %(progress.downloaded_bytes)s %(progress.total_bytes)s \
                 %(progress.total_bytes_estimate)s %(progress.speed)s %(progress.eta)s"
            ),
            "--progress-template".into(),
            format!("postprocess:{POSTPROCESS_TAG} %(progress.status)s"),
            "--continue".into(),
            "-N".into(),
            job.process.concurrent_fragments.max(1).to_string(),
            "-f".into(),
            spec.selector.clone(),
            "-P".into(),
            work_dir.to_string_lossy().into_owned(),
            "-o".into(),
            "media.%(ext)s".into(),
        ]);
        if let Some(merge) = &spec.merge {
            args.extend(["--merge-output-format".into(), merge.clone()]);
        }
        if let Some(audio) = &spec.extract_audio {
            args.extend([
                "-x".into(),
                "--audio-format".into(),
                audio.clone(),
                "--audio-quality".into(),
                // A fixed bitrate (e.g. "320K") or the best VBR.
                spec.audio_kbps
                    .map_or_else(|| "0".to_owned(), |kbps| format!("{kbps}K")),
            ]);
        }
        if let Some(ffmpeg) = self.components.ffmpeg_dir() {
            args.extend([
                "--ffmpeg-location".into(),
                ffmpeg.to_string_lossy().into_owned(),
                "--postprocessor-args".into(),
                format!("ffmpeg:-threads {}", job.process.ffmpeg_threads.max(1)),
            ]);
        }
        args.extend(["--".into(), job.url.as_str().to_owned()]);

        let mut command = Command::new(exe);
        command
            .args(&args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        configure(&mut command, job.process.low_priority);
        let mut child = command.spawn().map_err(EngineError::from_io)?;
        let tree = ProcessTree::adopt(&child).ok();

        let stdout = child.stdout.take().expect("piped stdout");
        let stderr = child.stderr.take().expect("piped stderr");
        let stderr_task = tokio::spawn(async move {
            let mut tail = VecDeque::with_capacity(STDERR_TAIL);
            let mut lines = BufReader::new(stderr).lines();
            while let Ok(Some(line)) = lines.next_line().await {
                if tail.len() == STDERR_TAIL {
                    tail.pop_front();
                }
                tail.push_back(line.chars().take(MAX_LINE).collect::<String>());
            }
            tail
        });

        let mut tracker = Tracker::new(job.progress_interval);
        let mut lines = BufReader::new(stdout).lines();
        loop {
            let line = tokio::select! {
                _ = cancel.cancelled() => {
                    drop(tree); // kills yt-dlp and FFmpeg
                    let _ = child.kill().await;
                    return Err(EngineError::Canceled);
                }
                l = lines.next_line() => l.map_err(EngineError::from_io)?,
            };
            let Some(line) = line else { break };
            if line.len() > MAX_LINE {
                continue;
            }
            if let Some(update) = tracker.on_line(&line, Instant::now()) {
                progress(update);
            }
        }
        let status = child.wait().await.map_err(EngineError::from_io)?;
        drop(tree);
        let tail = stderr_task.await.unwrap_or_default();
        if !status.success() {
            return Err(classify(tail.iter().rev().map(String::as_str)));
        }

        let produced = produced_file(&work_dir).await?;
        let size = tokio::fs::metadata(&produced)
            .await
            .map_err(EngineError::from_io)?
            .len();
        let file_name = with_extension(&job.file_name, &produced);
        let final_path = finalize_no_clobber(&produced, &job.dest_dir, &file_name)?;
        let _ = tokio::fs::remove_dir_all(&work_dir).await;
        progress(Progress {
            downloaded: size,
            total: Some(size),
            bytes_per_sec: 0.0,
            supports_resume: true,
            stage: Stage::Downloading,
        });
        Ok(Outcome {
            final_path,
            bytes: size,
            supports_resume: true,
        })
    }
}

impl Engine for YtDlpEngine {
    fn id(&self) -> &'static str {
        "ytdlp"
    }

    fn download<'a>(
        &'a self,
        job: &'a DownloadJob,
        progress: ProgressFn<'a>,
        cancel: CancellationToken,
    ) -> BoxFuture<'a, Result<Outcome, EngineError>> {
        self.run(job, progress, cancel).boxed()
    }
}

/// Per-task working directory (yt-dlp keeps its `.part` files there, so a
/// re-run continues them).
pub fn work_dir(part_path: &Path) -> PathBuf {
    let mut name = part_path.as_os_str().to_owned();
    name.push(".d");
    PathBuf::from(name)
}

/// The finished file: anything left that is not a temporary artifact.
async fn produced_file(dir: &Path) -> Result<PathBuf, EngineError> {
    let mut entries = tokio::fs::read_dir(dir)
        .await
        .map_err(EngineError::from_io)?;
    let mut best: Option<(u64, PathBuf)> = None;
    while let Some(entry) = entries.next_entry().await.map_err(EngineError::from_io)? {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_ascii_lowercase();
        let temporary = [".part", ".ytdl", ".temp", ".tmp"]
            .iter()
            .any(|s| name.ends_with(s))
            || name.contains(".part-frag");
        if temporary || !path.is_file() {
            continue;
        }
        let len = entry.metadata().await.map(|m| m.len()).unwrap_or(0);
        if best.as_ref().is_none_or(|(l, _)| len > *l) {
            best = Some((len, path));
        }
    }
    best.map(|(_, p)| p).ok_or_else(|| EngineError::Io {
        message: "the extractor finished without producing a file".into(),
    })
}

/// Keeps the sanitized stem but uses the real container extension.
fn with_extension(file_name: &str, produced: &Path) -> String {
    let ext = produced
        .extension()
        .and_then(|e| e.to_str())
        .filter(|e| e.len() <= 8 && e.chars().all(|c| c.is_ascii_alphanumeric()))
        .map(str::to_ascii_lowercase);
    let stem = Path::new(file_name)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("download");
    match ext {
        Some(ext) => format!("{stem}.{ext}"),
        None => file_name.to_owned(),
    }
}

/// Maps yt-dlp's last error lines to an engine error.
fn classify<'a>(lines: impl Iterator<Item = &'a str>) -> EngineError {
    let lines: Vec<&str> = lines.collect();
    let error = lines
        .iter()
        .find(|l| l.contains("ERROR:"))
        .or_else(|| lines.first())
        .map(|l| l.trim())
        .unwrap_or("the extractor failed");
    let lower = error.to_ascii_lowercase();
    let message: String = error
        .trim_start_matches("ERROR:")
        .trim()
        .chars()
        .take(300)
        .collect();
    if let Some(pos) = lower.find("http error ") {
        let code: String = lower[pos + 11..]
            .chars()
            .take_while(char::is_ascii_digit)
            .collect();
        if let Ok(status) = code.parse() {
            return EngineError::Http { status };
        }
    }
    if lower.contains("drm") {
        return EngineError::Unsupported {
            reason: "this media is protected (DRM) and cannot be downloaded".into(),
        };
    }
    if lower.contains("sign in") || lower.contains("login") || lower.contains("private") {
        return EngineError::Unsupported {
            reason: "this media requires an account or is private".into(),
        };
    }
    if lower.contains("unsupported url") {
        return EngineError::Unsupported {
            reason: "this website is not supported".into(),
        };
    }
    if lower.contains("no space left") || lower.contains("disk full") {
        return EngineError::DiskFull;
    }
    if [
        "timed out",
        "connection",
        "temporary failure",
        "network",
        "getaddrinfo",
    ]
    .iter()
    .any(|k| lower.contains(k))
    {
        return EngineError::network(message);
    }
    EngineError::Unsupported { reason: message }
}

fn field(value: Option<&str>) -> Option<f64> {
    value
        .filter(|v| *v != "NA" && *v != "None")
        .and_then(|v| v.parse().ok())
}

/// Converts yt-dlp progress lines into monotonic progress. Separate video
/// and audio streams are downloaded one after the other; their bytes add up.
struct Tracker {
    base: u64,
    last_downloaded: u64,
    last_total: u64,
    meter: SpeedMeter,
    throttle: Throttle,
    stage: Stage,
}

impl Tracker {
    fn new(interval: Duration) -> Self {
        Self {
            base: 0,
            last_downloaded: 0,
            last_total: 0,
            meter: SpeedMeter::new(Instant::now(), 0),
            throttle: Throttle::new(interval),
            stage: Stage::Downloading,
        }
    }

    fn on_line(&mut self, line: &str, now: Instant) -> Option<Progress> {
        let line = line.trim();
        if line.starts_with(POSTPROCESS_TAG) {
            if self.stage != Stage::Processing {
                self.stage = Stage::Processing;
                return Some(self.snapshot(now, 0.0));
            }
            return None;
        }
        let rest = line.strip_prefix(PROGRESS_TAG)?;
        let mut parts = rest.split_whitespace();
        let downloaded = field(parts.next())? as u64;
        let total = field(parts.next())
            .or(field(parts.next()))
            .map(|t| t as u64);
        let _speed = field(parts.next());
        // A new stream started: keep the bytes of the previous one.
        if downloaded < self.last_downloaded {
            self.base += self.last_total.max(self.last_downloaded);
        }
        self.last_downloaded = downloaded;
        self.last_total = total.unwrap_or(downloaded);
        let all = self.base + downloaded;
        let rate = self.meter.update(now, all);
        self.throttle.ready(now).then(|| self.snapshot(now, rate))
    }

    fn snapshot(&self, _now: Instant, rate: f64) -> Progress {
        Progress {
            downloaded: self.base + self.last_downloaded,
            total: Some(self.base + self.last_total.max(self.last_downloaded)),
            bytes_per_sec: rate,
            supports_resume: true,
            stage: self.stage,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn javascript_runtime_is_passed_only_when_installed() {
        let dir = tempfile::tempdir().unwrap();
        let components = Components::new(dir.path().to_path_buf()).unwrap();
        assert!(!base_args(&components).contains(&"--js-runtimes".to_owned()));

        let bundled = dir.path().join("bundled");
        let qjs_dir = bundled.join("quickjs").join("2aeabf0092c3262d");
        std::fs::create_dir_all(&qjs_dir).unwrap();
        std::fs::write(qjs_dir.join("qjs.exe"), b"exe").unwrap();
        let args = base_args(&components.with_bundled(bundled));
        let at = args.iter().position(|a| a == "--js-runtimes").unwrap();
        assert_eq!(
            args[at + 1],
            format!("quickjs:{}", qjs_dir.join("qjs.exe").to_string_lossy())
        );
    }

    #[test]
    fn progress_lines_are_parsed_and_streams_add_up() {
        let mut t = Tracker::new(Duration::ZERO);
        let start = Instant::now();
        let p = t.on_line("MMDL 500 1000 NA 100.0 5", start).unwrap();
        assert_eq!((p.downloaded, p.total), (500, Some(1000)));
        t.on_line("MMDL 1000 1000 NA NA NA", start + Duration::from_secs(1));
        // Second stream (audio) starts from zero.
        let p = t
            .on_line("MMDL 100 200 NA NA NA", start + Duration::from_secs(2))
            .unwrap();
        assert_eq!((p.downloaded, p.total), (1100, Some(1200)));
        assert_eq!(p.stage, Stage::Downloading);
        let p = t
            .on_line("MMPP started", start + Duration::from_secs(3))
            .unwrap();
        assert_eq!(p.stage, Stage::Processing);
    }

    #[test]
    fn estimates_and_noise_are_handled() {
        let mut t = Tracker::new(Duration::ZERO);
        let p = t.on_line("MMDL 10 NA 400 NA NA", Instant::now()).unwrap();
        assert_eq!(p.total, Some(400));
        assert!(
            t.on_line("[download] Destination: x", Instant::now())
                .is_none()
        );
        assert!(t.on_line("MMDL NA NA NA NA NA", Instant::now()).is_none());
    }

    #[test]
    fn errors_are_classified() {
        let e = |s: &str| classify(std::iter::once(s));
        assert_eq!(
            e("ERROR: unable to download: HTTP Error 403: Forbidden"),
            EngineError::Http { status: 403 }
        );
        assert!(
            matches!(e("ERROR: [generic] Unsupported URL: https://x"), EngineError::Unsupported { reason } if reason.contains("not supported"))
        );
        assert!(
            matches!(e("ERROR: Sign in to confirm your age"), EngineError::Unsupported { reason } if reason.contains("account"))
        );
        assert!(
            matches!(e("ERROR: This video is DRM protected"), EngineError::Unsupported { reason } if reason.contains("DRM"))
        );
        assert!(e("ERROR: Connection reset by peer").is_retryable());
        assert_eq!(
            e("ERROR: [Errno 28] No space left on device"),
            EngineError::DiskFull
        );
    }

    #[test]
    fn final_name_uses_the_real_extension() {
        assert_eq!(
            with_extension("Tears of Steel (1080p).mp4", Path::new("x/media.webm")),
            "Tears of Steel (1080p).webm"
        );
        assert_eq!(
            with_extension("song.mp3", Path::new("x/media.mp3")),
            "song.mp3"
        );
        assert_eq!(with_extension("a.mp4", Path::new("x/media")), "a.mp4");
    }

    #[test]
    fn work_dir_is_next_to_the_part_path() {
        assert_eq!(
            work_dir(Path::new("C:/V/a.mp4.123.part")),
            PathBuf::from("C:/V/a.mp4.123.part.d")
        );
    }

    #[tokio::test]
    async fn produced_file_ignores_temporary_artifacts() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("media.f137.mp4.part"), vec![0; 50]).unwrap();
        std::fs::write(dir.path().join("media.mp4.ytdl"), b"x").unwrap();
        std::fs::write(dir.path().join("media.mp4"), vec![0; 10]).unwrap();
        assert_eq!(
            produced_file(dir.path()).await.unwrap(),
            dir.path().join("media.mp4")
        );
    }
}

//! Convertir (Outils PC, handoff `design_handoff_outils_pc`): a queue of
//! FFmpeg jobs. FFmpeg is the one shipped with the app; it always runs with
//! an argument array, writes to a temporary file renamed at the end, and is
//! killed (with its temporary file) when stopped. Kept outside `api` so the
//! bridge generator does not expose it.

use std::path::{Path, PathBuf};
use std::sync::{LazyLock, Mutex, OnceLock};
use std::time::{Duration, Instant};

use anyhow::{Result, anyhow};
use tokio_util::sync::CancellationToken;

use crate::api::converter::{ConvertJob, ConvertOptions};
use crate::frb_generated::StreamSink;

/// What a job makes: a format of its category, or a tool.
pub const VIDEO_FORMATS: [&str; 7] = ["mp4", "mkv", "webm", "avi", "mov", "3gp", "gif"];
pub const AUDIO_FORMATS: [&str; 6] = ["mp3", "m4a", "flac", "wav", "ogg", "opus"];
pub const IMAGE_FORMATS: [&str; 5] = ["png", "jpg", "webp", "ico", "bmp"];
pub const VIDEO_TOOLS: [&str; 5] = ["join", "cut", "crop", "compress", "frames"];
pub const AUDIO_TOOLS: [&str; 3] = ["extract", "cut", "join"];
pub const IMAGE_TOOLS: [&str; 1] = ["resize"];

/// Files added at once, at most.
pub const MAX_INPUTS: usize = 200;
/// Progress events per job, at most this often.
const PROGRESS_EVERY: Duration = Duration::from_secs(1);

// ------------------------------------------------------------------ jobs

struct Job {
    info: ConvertJob,
    options: ConvertOptions,
    cancel: Option<CancellationToken>,
}

#[derive(Default)]
struct State {
    jobs: Vec<Job>,
    running: bool,
    stop: Option<CancellationToken>,
}

static STATE: LazyLock<Mutex<State>> = LazyLock::new(Mutex::default);
static SINK: Mutex<Option<StreamSink<ConvertJob>>> = Mutex::new(None);
/// The H.264 encoder that works on this PC (hardware first).
static H264: OnceLock<String> = OnceLock::new();

fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|p| p.into_inner())
}

fn emit(job: &ConvertJob) {
    if let Some(sink) = lock(&SINK).as_ref() {
        let _ = sink.add(job.clone());
    }
}

pub fn set_sink(sink: StreamSink<ConvertJob>) {
    *lock(&SINK) = Some(sink);
}

fn update(id: &str, f: impl FnOnce(&mut ConvertJob)) {
    let snapshot = {
        let mut state = lock(&STATE);
        let Some(job) = state.jobs.iter_mut().find(|j| j.info.id == id) else {
            return;
        };
        f(&mut job.info);
        job.info.clone()
    };
    emit(&snapshot);
}

pub fn jobs() -> Vec<ConvertJob> {
    lock(&STATE).jobs.iter().map(|j| j.info.clone()).collect()
}

pub fn running() -> bool {
    lock(&STATE).running
}

fn kind_of(category: &str, target: &str) -> Result<()> {
    let ok = match category {
        "video" => VIDEO_FORMATS.contains(&target) || VIDEO_TOOLS.contains(&target),
        "audio" => AUDIO_FORMATS.contains(&target) || AUDIO_TOOLS.contains(&target),
        "image" => IMAGE_FORMATS.contains(&target) || IMAGE_TOOLS.contains(&target),
        _ => false,
    };
    if ok {
        Ok(())
    } else {
        Err(anyhow!("unknown conversion"))
    }
}

fn new_id() -> String {
    use std::sync::atomic::{AtomicU32, Ordering};
    static SEQ: AtomicU32 = AtomicU32::new(0);
    format!(
        "c{}-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_millis()),
        SEQ.fetch_add(1, Ordering::Relaxed)
    )
}

/// Adds jobs: one per file, or one for all of them (join).
pub fn add(
    category: String,
    target: String,
    inputs: Vec<String>,
    options: ConvertOptions,
    probe: impl Fn(&Path) -> crate::api::converter::SourceInfo,
) -> Result<Vec<ConvertJob>> {
    kind_of(&category, &target)?;
    if inputs.is_empty() || inputs.len() > MAX_INPUTS {
        return Err(anyhow!("no files"));
    }
    let paths: Vec<PathBuf> = inputs.iter().map(PathBuf::from).collect();
    if let Some(missing) = paths.iter().find(|p| !p.is_file()) {
        return Err(anyhow!("not a file: {}", missing.display()));
    }
    validate_options(&options)?;
    let groups: Vec<Vec<PathBuf>> = if target == "join" {
        if paths.len() < 2 {
            return Err(anyhow!("join needs two files"));
        }
        vec![paths]
    } else {
        paths.into_iter().map(|p| vec![p]).collect()
    };
    let mut added = Vec::new();
    let mut state = lock(&STATE);
    for group in groups {
        let first = &group[0];
        let source = probe(first);
        let info = ConvertJob {
            id: new_id(),
            inputs: group
                .iter()
                .map(|p| p.to_string_lossy().into_owned())
                .collect(),
            name: first
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_default(),
            category: category.clone(),
            target: target.clone(),
            source,
            state: "waiting".into(),
            percent: 0.0,
            out_path: None,
            out_size: None,
            error: None,
        };
        state.jobs.push(Job {
            info: info.clone(),
            options: options.clone(),
            cancel: None,
        });
        added.push(info);
    }
    Ok(added)
}

fn validate_options(o: &ConvertOptions) -> Result<()> {
    let ok = ["source", "high", "medium", "small"].contains(&o.quality.as_str())
        && [0, 2160, 1080, 720, 480].contains(&o.height)
        && [0, 128, 192, 256, 320].contains(&o.audio_kbps)
        && ["", "16:9", "4:3", "1:1", "9:16"].contains(&o.crop.as_str())
        && [0, 1, 5, 10, 30].contains(&o.frame_every)
        && [0, 3840, 1920, 1280, 800, 400].contains(&o.width)
        && (o.to_ms == 0 || o.to_ms > o.from_ms)
        && !o.out_dir.trim().is_empty();
    if ok {
        Ok(())
    } else {
        Err(anyhow!("invalid options"))
    }
}

pub fn remove(id: &str) {
    let mut state = lock(&STATE);
    if let Some(job) = state.jobs.iter().find(|j| j.info.id == id)
        && let Some(cancel) = &job.cancel
    {
        cancel.cancel();
    }
    state.jobs.retain(|j| j.info.id != id);
}

pub fn clear() {
    stop();
    lock(&STATE).jobs.clear();
}

/// Stops the running jobs (their temporary files go); the others wait.
pub fn stop() {
    let mut state = lock(&STATE);
    if let Some(stop) = state.stop.take() {
        stop.cancel();
    }
    for job in &state.jobs {
        if let Some(cancel) = &job.cancel {
            cancel.cancel();
        }
    }
}

/// Converts the waiting and stopped jobs, [parallel] at a time.
pub fn start(runtime: &tokio::runtime::Handle, ffmpeg: PathBuf, parallel: usize) -> Result<()> {
    let stop = CancellationToken::new();
    {
        let mut state = lock(&STATE);
        if state.running {
            return Ok(());
        }
        let mut any = false;
        for job in &mut state.jobs {
            if job.info.state == "waiting" || job.info.state == "stopped" {
                job.info.state = "waiting".into();
                job.info.percent = 0.0;
                job.info.error = None;
                any = true;
            }
        }
        if !any {
            return Ok(());
        }
        state.running = true;
        state.stop = Some(stop.clone());
    }
    let encoder = h264_encoder(&ffmpeg);
    let parallel = parallel.clamp(1, 4);
    runtime.spawn(async move {
        let workers: Vec<_> = (0..parallel)
            .map(|_| {
                let (ffmpeg, encoder, stop) = (ffmpeg.clone(), encoder.clone(), stop.clone());
                tokio::spawn(async move {
                    while !stop.is_cancelled() {
                        let Some((id, info, options, cancel)) = next_job() else {
                            break;
                        };
                        let result = tokio::select! {
                            r = run_job(&ffmpeg, &encoder, &info, &options, &cancel) => r,
                            _ = stop.cancelled() => Err(Stopped.into()),
                        };
                        finish(&id, result);
                    }
                })
            })
            .collect();
        for w in workers {
            let _ = w.await;
        }
        let mut state = lock(&STATE);
        state.running = false;
        state.stop = None;
        // Jobs left waiting by a stop are "stopped".
        let stopped: Vec<ConvertJob> = state
            .jobs
            .iter_mut()
            .filter(|j| j.info.state == "waiting" && stop.is_cancelled())
            .map(|j| {
                j.info.state = "stopped".into();
                j.info.clone()
            })
            .collect();
        drop(state);
        for job in &stopped {
            emit(job);
        }
    });
    Ok(())
}

#[derive(Debug)]
struct Stopped;
impl std::fmt::Display for Stopped {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("stopped")
    }
}
impl std::error::Error for Stopped {}

fn next_job() -> Option<(String, ConvertJob, ConvertOptions, CancellationToken)> {
    let mut state = lock(&STATE);
    let job = state.jobs.iter_mut().find(|j| j.info.state == "waiting")?;
    let cancel = CancellationToken::new();
    job.cancel = Some(cancel.clone());
    job.info.state = "converting".into();
    let out = (
        job.info.id.clone(),
        job.info.clone(),
        job.options.clone(),
        cancel,
    );
    drop(state);
    emit(&out.1);
    Some(out)
}

fn finish(id: &str, result: Result<(PathBuf, u64)>) {
    update(id, |job| match result {
        Ok((path, size)) => {
            job.state = "done".into();
            job.percent = 100.0;
            job.out_path = Some(path.to_string_lossy().into_owned());
            job.out_size = Some(size);
        }
        Err(e) if e.is::<Stopped>() => {
            job.state = "stopped".into();
            job.percent = 0.0;
        }
        Err(e) => {
            job.state = "failed".into();
            job.error = Some(e.to_string().chars().take(300).collect());
        }
    });
    if let Some(job) = lock(&STATE).jobs.iter_mut().find(|j| j.info.id == id) {
        job.cancel = None;
    }
}

// ------------------------------------------------------------- encoders

/// The first H.264 encoder that works here: NVIDIA, Intel, Media
/// Foundation, then OpenH264 (software, always there).
pub(crate) fn h264_encoder(ffmpeg: &Path) -> String {
    H264.get_or_init(|| {
        for e in ["h264_nvenc", "h264_qsv", "h264_mf"] {
            let mut cmd = std::process::Command::new(ffmpeg);
            cmd.args([
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=c=black:s=320x240:d=0.2",
                "-c:v",
                e,
                "-f",
                "null",
                "-",
            ])
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null());
            #[cfg(windows)]
            {
                use std::os::windows::process::CommandExt;
                cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
            }
            if cmd.status().is_ok_and(|s| s.success()) {
                return e.to_owned();
            }
        }
        "libopenh264".to_owned()
    })
    .clone()
}

// ---------------------------------------------------------------- output

/// Extension of what a job writes (None: a folder of images).
pub fn out_ext(category: &str, target: &str, input: &Path) -> Option<String> {
    let own = input
        .extension()
        .and_then(|e| e.to_str())
        .map(str::to_ascii_lowercase)
        .filter(|e| e.len() <= 5 && e.chars().all(|c| c.is_ascii_alphanumeric()));
    Some(match (category, target) {
        (_, "frames") => return None,
        ("video", "join" | "compress") => "mp4".into(),
        ("video", "cut" | "crop") => own.unwrap_or_else(|| "mp4".into()),
        ("audio", "join" | "extract") => "mp3".into(),
        ("audio", "cut") => own.unwrap_or_else(|| "mp3".into()),
        ("image", "resize") => own.unwrap_or_else(|| "png".into()),
        (_, format) => format.into(),
    })
}

/// The name of what a job writes: "Film.mp4", "Film (extrait).mkv"…
fn out_stem(target: &str, input: &Path, options: &ConvertOptions) -> String {
    let stem = input
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| "conversion".into());
    match target {
        "cut" => format!("{stem} (extrait)"),
        "join" => format!("{stem} (fusion)"),
        "compress" => format!("{stem} (compressé)"),
        "crop" => format!("{stem} ({})", options.crop.replace(':', "x")),
        "resize" => format!("{stem} ({} px)", options.width),
        "frames" => format!("{stem} (images)"),
        _ => stem,
    }
}

/// A free name in [dir]: "name.ext", else "name (1).ext"…
pub(crate) fn free_path(dir: &Path, stem: &str, ext: Option<&str>) -> Result<PathBuf> {
    let clean = media_core::sanitize_filename(stem, ext.unwrap_or("d"))?;
    let base = match ext {
        Some(_) => clean.clone(),
        None => clean.trim_end_matches(".d").to_owned(),
    };
    let name = media_core::unique_filename(&base, |n| dir.join(n).exists())?;
    Ok(dir.join(name))
}

// ------------------------------------------------------------------ args

/// Bit rate for a height and quality (H.264), in kbit/s.
fn video_kbps(height: u32, quality: &str, source_kbps: u32) -> u32 {
    let base = match height {
        h if h >= 2000 => 16_000,
        h if h >= 1000 => 8_000,
        h if h >= 700 => 5_000,
        h if h >= 470 => 2_500,
        _ => 1_200,
    };
    match quality {
        "source" if source_kbps > 0 => source_kbps.clamp(800, 40_000),
        "source" | "high" => base,
        "medium" => base * 6 / 10,
        _ => base * 35 / 100,
    }
}

fn scale_filter(height: u32) -> Option<String> {
    (height > 0).then(|| format!("scale=-2:'min({height},ih)'"))
}

fn crop_filter(ratio: &str) -> Option<String> {
    let (w, h) = match ratio {
        "16:9" => (16, 9),
        "4:3" => (4, 3),
        "1:1" => (1, 1),
        "9:16" => (9, 16),
        _ => return None,
    };
    // The largest centred w:h rectangle, even sizes.
    Some(format!(
        "crop='trunc(min(iw,ih*{w}/{h})/2)*2':'trunc(min(ih,iw*{h}/{w})/2)*2'"
    ))
}

fn ms(v: u64) -> String {
    format!("{}.{:03}", v / 1000, v % 1000)
}

/// SVT-AV1 quality for Compresser: haute, équilibrée, petite.
fn compress_crf(quality: &str) -> u32 {
    match quality {
        "high" | "source" => 26,
        "small" => 36,
        _ => 30,
    }
}

/// The video bit rate that makes a file of [target_mb] MiB over [secs]
/// (128 kbit/s of sound taken out, 7 % kept in hand so the file stays
/// under), or None when compressing by quality.
pub fn compress_target_kbps(target_mb: u32, secs: f64) -> Option<u32> {
    if target_mb == 0 || secs <= 0.0 {
        return None;
    }
    let total = f64::from(target_mb) * 1024.0 * 1024.0 * 8.0 / 1000.0 / secs;
    Some(((total - 128.0) * 0.93).max(100.0) as u32)
}

/// Compresser in H.264: constant quality where the encoder has it
/// (NVIDIA, Intel), else a bit rate for the height.
fn compress_h264(a: &mut Vec<String>, h264: &str, quality: &str, target: Option<u32>, height: u32) {
    let s = |v: &str| v.to_owned();
    a.extend([s("-c:v"), h264.to_owned(), s("-pix_fmt"), s("yuv420p")]);
    if let Some(k) = target {
        a.extend([
            s("-b:v"),
            format!("{k}k"),
            s("-maxrate"),
            format!("{}k", k * 3 / 2),
            s("-bufsize"),
            format!("{}k", k * 2),
        ]);
        return;
    }
    let level = match quality {
        "high" | "source" => 0,
        "small" => 2,
        _ => 1,
    };
    match h264 {
        "h264_nvenc" => a.extend([
            s("-preset"),
            s("p7"),
            s("-tune"),
            s("hq"),
            s("-rc"),
            s("vbr"),
            s("-b:v"),
            s("0"),
            s("-cq"),
            [23, 26, 29][level].to_string(),
            s("-spatial-aq"),
            s("1"),
            s("-temporal-aq"),
            s("1"),
            s("-rc-lookahead"),
            s("32"),
            s("-bf"),
            s("3"),
        ]),
        "h264_qsv" => a.extend([
            s("-preset"),
            s("veryslow"),
            s("-global_quality"),
            [22, 25, 28][level].to_string(),
        ]),
        _ => {
            let kbps = video_kbps(height.max(1), ["high", "medium", "small"][level], 0);
            a.extend([s("-b:v"), format!("{kbps}k")]);
        }
    }
}

/// FFmpeg arguments of one job (after the common ones, before the output).
/// [height]: the source's, for the bit rate. Pure: tested on its own.
#[allow(clippy::too_many_arguments)]
pub fn job_args(
    category: &str,
    target: &str,
    inputs: &[PathBuf],
    options: &ConvertOptions,
    h264: &str,
    source_height: u32,
    source_kbps: u32,
    source_secs: f64,
) -> Vec<String> {
    let mut a: Vec<String> = Vec::new();
    let s = |v: &str| v.to_owned();
    let cut = target == "cut";
    if cut && options.from_ms > 0 {
        a.extend([s("-ss"), ms(options.from_ms)]);
    }
    for input in inputs {
        a.extend([s("-i"), input.to_string_lossy().into_owned()]);
    }
    if cut && options.to_ms > 0 {
        a.extend([s("-t"), ms(options.to_ms - options.from_ms)]);
    }
    let out_height = if options.height > 0 {
        options.height.min(source_height.max(1))
    } else {
        source_height
    };
    let vkbps = video_kbps(out_height, &options.quality, source_kbps);
    let h264_args = |a: &mut Vec<String>, kbps: u32| {
        a.extend([
            s("-c:v"),
            h264.to_owned(),
            s("-b:v"),
            format!("{kbps}k"),
            s("-maxrate"),
            format!("{}k", kbps * 3 / 2),
            s("-bufsize"),
            format!("{}k", kbps * 2),
            s("-pix_fmt"),
            s("yuv420p"),
        ]);
    };
    let akbps = if options.audio_kbps > 0 {
        options.audio_kbps
    } else {
        192
    };
    let vf = |extra: Option<String>| -> Vec<String> {
        let filters: Vec<String> = [extra, scale_filter(options.height)]
            .into_iter()
            .flatten()
            .collect();
        if filters.is_empty() {
            Vec::new()
        } else {
            vec![s("-vf"), filters.join(",")]
        }
    };
    match (category, target) {
        // A copy of the part: fast, cut at the nearest key frame.
        (_, "cut") => a.extend([s("-map"), s("0"), s("-c"), s("copy")]),
        ("video", "join") => {
            // Every part scaled to the first one's picture, then chained.
            let n = inputs.len();
            let h = if out_height > 0 { out_height } else { 720 };
            let mut graph = String::new();
            for i in 0..n {
                graph.push_str(&format!(
                    "[{i}:v:0]scale=-2:{h},setsar=1,fps=30,format=yuv420p[v{i}];[{i}:a:0]aresample=48000[a{i}];"
                ));
            }
            for i in 0..n {
                graph.push_str(&format!("[v{i}][a{i}]"));
            }
            graph.push_str(&format!("concat=n={n}:v=1:a=1[v][a]"));
            a.extend([
                s("-filter_complex"),
                graph,
                s("-map"),
                s("[v]"),
                s("-map"),
                s("[a]"),
            ]);
            h264_args(&mut a, video_kbps(h, &options.quality, 0));
            a.extend([
                s("-c:a"),
                s("aac"),
                s("-b:a"),
                s("192k"),
                s("-movflags"),
                s("+faststart"),
            ]);
        }
        ("audio", "join") => {
            let n = inputs.len();
            let mut graph = String::new();
            for i in 0..n {
                graph.push_str(&format!("[{i}:a:0]"));
            }
            graph.push_str(&format!("concat=n={n}:v=0:a=1[a]"));
            a.extend([
                s("-filter_complex"),
                graph,
                s("-map"),
                s("[a]"),
                s("-c:a"),
                s("libmp3lame"),
                s("-b:a"),
                format!("{akbps}k"),
            ]);
        }
        ("video", "compress") => {
            // Measured on 1080p film scenes against the source (VMAF,
            // docs/compression.md): SVT-AV1 preset 8 is 12–35 % smaller
            // than the best H.264 / HEVC of the PC at the same quality,
            // at about 1.8 x real time on a 4-core laptop. H.264 stays for
            // players that lack AV1.
            let h = match options.height {
                0 => out_height.min(1080),
                h => h.min(source_height.max(1)),
            };
            if source_height > h && h > 0 {
                a.extend([s("-vf"), format!("scale=-2:{h}")]);
            }
            let target_kbps = compress_target_kbps(options.target_mb, source_secs);
            if options.codec == "h264" {
                compress_h264(&mut a, h264, &options.quality, target_kbps, h);
            } else {
                a.extend([
                    s("-c:v"),
                    s("libsvtav1"),
                    s("-preset"),
                    s("8"),
                    s("-pix_fmt"),
                    s("yuv420p10le"),
                ]);
                match target_kbps {
                    Some(k) => a.extend([s("-b:v"), format!("{k}k")]),
                    None => a.extend([s("-crf"), compress_crf(&options.quality).to_string()]),
                }
            }
            a.extend([
                s("-c:a"),
                s("aac"),
                s("-b:a"),
                s("128k"),
                s("-ac"),
                s("2"),
                s("-movflags"),
                s("+faststart"),
            ]);
        }
        ("video", "crop") => {
            a.extend(vf(crop_filter(&options.crop)));
            h264_args(&mut a, vkbps);
            a.extend([s("-c:a"), s("copy")]);
        }
        ("video", "frames") => {
            let every = options.frame_every.max(1);
            let mut filters = vec![format!("fps=1/{every}")];
            if let Some(f) = scale_filter(options.height) {
                filters.push(f);
            }
            a.extend([s("-vf"), filters.join(","), s("-q:v"), s("3")]);
        }
        ("video", "mp4" | "mov") => {
            a.extend(vf(None));
            h264_args(&mut a, vkbps);
            a.extend([s("-c:a"), s("aac"), s("-b:a"), format!("{akbps}k")]);
            if target == "mp4" {
                a.extend([s("-movflags"), s("+faststart")]);
            }
        }
        ("video", "mkv") => {
            // Every track and subtitle kept; a copy when nothing changes.
            a.extend([s("-map"), s("0")]);
            if options.quality == "source" && options.height == 0 {
                a.extend([s("-c"), s("copy")]);
            } else {
                a.extend(vf(None));
                h264_args(&mut a, vkbps);
                a.extend([s("-c:a"), s("copy"), s("-c:s"), s("copy")]);
            }
        }
        ("video", "webm") => {
            a.extend(vf(None));
            a.extend([
                s("-c:v"),
                s("libvpx-vp9"),
                s("-b:v"),
                format!("{}k", vkbps * 7 / 10),
                s("-row-mt"),
                s("1"),
                s("-deadline"),
                s("good"),
                s("-cpu-used"),
                s("4"),
                s("-c:a"),
                s("libopus"),
                s("-b:a"),
                s("128k"),
            ]);
        }
        // Old and simple phones (3GPP): H.264 Constrained Baseline from
        // OpenH264 (always there, a small picture is quick in software),
        // 480p and 30 images a second at most, AAC sound.
        ("video", "3gp") => {
            let h = match options.height {
                0 => 480,
                h => h.min(480),
            };
            let kbps = match options.quality.as_str() {
                "small" => 300,
                "medium" => 600,
                _ => 900,
            } * h
                / 480;
            a.extend([
                s("-vf"),
                format!("scale=-2:'min({h},ih)'"),
                s("-fpsmax"),
                s("30"),
                s("-c:v"),
                s("libopenh264"),
                s("-profile:v"),
                s("constrained_baseline"),
                s("-b:v"),
                format!("{kbps}k"),
                s("-maxrate"),
                format!("{}k", kbps * 3 / 2),
                s("-bufsize"),
                format!("{}k", kbps * 2),
                s("-pix_fmt"),
                s("yuv420p"),
                s("-c:a"),
                s("aac"),
                s("-b:a"),
                s(if h <= 240 { "64k" } else { "96k" }),
                s("-ac"),
                s("2"),
                s("-ar"),
                s("44100"),
                s("-f"),
                s("3gp"),
            ]);
        }
        ("video", "avi") => {
            a.extend(vf(None));
            a.extend([
                s("-c:v"),
                s("mpeg4"),
                s("-b:v"),
                format!("{vkbps}k"),
                s("-c:a"),
                s("libmp3lame"),
                s("-b:a"),
                format!("{akbps}k"),
            ]);
        }
        ("video", "gif") => {
            let w = match options.height {
                0 => 480,
                h => (h * 16 / 9).min(960),
            };
            a.extend([
                s("-vf"),
                format!(
                    "fps=12,scale={w}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
                ),
                s("-an"),
            ]);
        }
        ("audio", fmt) => {
            a.extend([s("-vn")]);
            match fmt {
                "mp3" | "extract" => {
                    a.extend([s("-c:a"), s("libmp3lame"), s("-b:a"), format!("{akbps}k")])
                }
                "m4a" => a.extend([s("-c:a"), s("aac"), s("-b:a"), format!("{akbps}k")]),
                "flac" => a.extend([s("-c:a"), s("flac")]),
                "wav" => a.extend([s("-c:a"), s("pcm_s16le")]),
                "ogg" => a.extend([s("-c:a"), s("libvorbis"), s("-b:a"), format!("{akbps}k")]),
                _ => a.extend([
                    s("-c:a"),
                    s("libopus"),
                    s("-b:a"),
                    format!("{}k", akbps.min(256)),
                ]),
            }
        }
        ("image", fmt) => {
            let q = match options.quality.as_str() {
                "source" | "high" => 2,
                "medium" => 5,
                _ => 9,
            };
            let mut filters = Vec::new();
            if fmt == "resize" && options.width > 0 {
                filters.push(format!("scale='min({},iw)':-2", options.width));
            }
            if fmt == "ico" {
                filters.push(s(
                    "scale='min(256,iw)':'min(256,ih)':force_original_aspect_ratio=decrease",
                ));
            }
            if !filters.is_empty() {
                a.extend([s("-vf"), filters.join(",")]);
            }
            match fmt {
                "jpg" => a.extend([s("-q:v"), q.to_string()]),
                "webp" => a.extend([
                    s("-c:v"),
                    s("libwebp"),
                    s("-quality"),
                    (100 - q * 7).to_string(),
                ]),
                _ => {}
            }
            a.extend([s("-frames:v"), s("1")]);
        }
        _ => {}
    }
    a
}

// ------------------------------------------------------------------- run

async fn run_job(
    ffmpeg: &Path,
    h264: &str,
    job: &ConvertJob,
    options: &ConvertOptions,
    cancel: &CancellationToken,
) -> Result<(PathBuf, u64)> {
    use download_engine::process::{ProcessTree, configure};
    use tokio::io::AsyncBufReadExt;

    let inputs: Vec<PathBuf> = job.inputs.iter().map(PathBuf::from).collect();
    let first = &inputs[0];
    let out_dir = PathBuf::from(&options.out_dir);
    tokio::fs::create_dir_all(&out_dir).await?;
    let ext = out_ext(&job.category, &job.target, first);
    let final_path = free_path(
        &out_dir,
        &out_stem(&job.target, first, options),
        ext.as_deref(),
    )?;
    // Images of a video go in a folder of their own; anything else is
    // written next to its final name, then renamed.
    let (write_to, temp) = match &ext {
        None => {
            tokio::fs::create_dir_all(&final_path).await?;
            (final_path.join("%04d.jpg"), None)
        }
        Some(ext) => {
            let tmp = out_dir.join(format!(".{}.part.{ext}", job.id));
            (tmp.clone(), Some(tmp))
        }
    };
    let total = total_secs(job, options);
    let mut args: Vec<String> = [
        "-hide_banner",
        "-nostdin",
        "-y",
        "-loglevel",
        "error",
        "-progress",
        "pipe:1",
        "-nostats",
    ]
    .iter()
    .map(|s| (*s).to_owned())
    .collect();
    args.extend(job_args(
        &job.category,
        &job.target,
        &inputs,
        options,
        h264,
        job.source.height,
        job.source.kbps,
        total_secs(job, options),
    ));
    args.push(write_to.to_string_lossy().into_owned());

    let mut command = tokio::process::Command::new(ffmpeg);
    command
        .args(&args)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());
    configure(&mut command, true);
    let mut child = command.spawn()?;
    let tree = ProcessTree::adopt(&child).ok();
    let stdout = child.stdout.take().ok_or_else(|| anyhow!("no output"))?;
    let mut stderr = child.stderr.take().ok_or_else(|| anyhow!("no output"))?;
    let errors = tokio::spawn(async move {
        use tokio::io::AsyncReadExt;
        let mut buf = Vec::new();
        let _ = (&mut stderr).take(16 * 1024).read_to_end(&mut buf).await;
        // Drained to the end so FFmpeg never blocks.
        let _ = tokio::io::copy(&mut stderr, &mut tokio::io::sink()).await;
        String::from_utf8_lossy(&buf).into_owned()
    });
    let mut lines = tokio::io::BufReader::new(stdout).lines();
    let mut last = Instant::now() - PROGRESS_EVERY;
    let cleanup = |temp: &Option<PathBuf>| {
        if let Some(t) = temp {
            let _ = std::fs::remove_file(t);
        }
    };
    loop {
        let line = tokio::select! {
            _ = cancel.cancelled() => {
                drop(tree);
                let _ = child.kill().await;
                cleanup(&temp);
                if ext.is_none() {
                    let _ = std::fs::remove_dir_all(&final_path);
                }
                return Err(Stopped.into());
            }
            l = lines.next_line() => l?,
        };
        let Some(line) = line else { break };
        if let Some(us) = line
            .strip_prefix("out_time_us=")
            .and_then(|v| v.trim().parse::<i64>().ok())
            && total > 0.0
            && last.elapsed() >= PROGRESS_EVERY
        {
            last = Instant::now();
            let pct = (us as f64 / 1e6 / total * 100.0).clamp(0.0, 99.0);
            update(&job.id, |j| j.percent = pct);
        }
    }
    let status = child.wait().await?;
    drop(tree);
    let message = errors.await.unwrap_or_default();
    if !status.success() {
        cleanup(&temp);
        if ext.is_none() {
            let _ = std::fs::remove_dir_all(&final_path);
        }
        let reason = message
            .lines()
            .rev()
            .find(|l| !l.trim().is_empty())
            .unwrap_or("FFmpeg failed")
            .trim()
            .to_owned();
        return Err(anyhow!(reason));
    }
    let size = match &temp {
        Some(t) => {
            tokio::fs::rename(t, &final_path).await?;
            tokio::fs::metadata(&final_path).await?.len()
        }
        None => folder_size(&final_path),
    };
    Ok((final_path, size))
}

fn folder_size(dir: &Path) -> u64 {
    std::fs::read_dir(dir)
        .map(|d| {
            d.filter_map(|e| e.ok()?.metadata().ok())
                .map(|m| m.len())
                .sum()
        })
        .unwrap_or(0)
}

/// Seconds the output lasts, for the progress (0: not known).
fn total_secs(job: &ConvertJob, options: &ConvertOptions) -> f64 {
    let d = job.source.duration_secs;
    match job.target.as_str() {
        "cut" => {
            let end = if options.to_ms > 0 {
                options.to_ms as f64 / 1000.0
            } else {
                d
            };
            (end - options.from_ms as f64 / 1000.0).max(0.0)
        }
        "join" => job.source.total_secs,
        _ => d,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn opts() -> ConvertOptions {
        ConvertOptions {
            quality: "high".into(),
            height: 0,
            audio_kbps: 0,
            from_ms: 0,
            to_ms: 0,
            crop: String::new(),
            frame_every: 0,
            width: 0,
            codec: String::new(),
            target_mb: 0,
            out_dir: r"C:\out".into(),
        }
    }

    #[test]
    fn compress_settings() {
        let has = |a: &[String], w: &[&str]| a.windows(w.len()).any(|x| x == w);
        // By quality: SVT-AV1, 10-bit, CRF per level; 4K comes down to 1080p.
        let mut o = opts();
        o.quality = "medium".into();
        let a = job_args(
            "video",
            "compress",
            &[PathBuf::from("in.mp4")],
            &o,
            "h264_nvenc",
            2160,
            0,
            300.0,
        );
        assert!(has(&a, &["-vf", "scale=-2:1080"]));
        assert!(has(&a, &["-c:v", "libsvtav1", "-preset", "8"]));
        assert!(has(&a, &["-crf", "30"]));
        assert!(has(&a, &["-c:a", "aac", "-b:a", "128k", "-ac", "2"]));
        // A size aimed at: 200 MiB over 5 min.
        o.target_mb = 200;
        let a = job_args(
            "video",
            "compress",
            &[PathBuf::from("in.mp4")],
            &o,
            "h264_nvenc",
            1080,
            0,
            300.0,
        );
        assert!(has(&a, &["-b:v", "5081k"]), "{a:?}");
        assert!(!a.contains(&"-crf".to_owned()));
        // H.264 for players without AV1: NVIDIA's constant quality.
        o.target_mb = 0;
        o.codec = "h264".into();
        o.quality = "small".into();
        let a = job_args(
            "video",
            "compress",
            &[PathBuf::from("in.mp4")],
            &o,
            "h264_nvenc",
            720,
            0,
            300.0,
        );
        assert!(has(&a, &["-cq", "29"]));
        assert!(
            !a.iter().any(|x| x == "scale=-2:1080"),
            "720p is not upscaled"
        );
        let a = job_args(
            "video",
            "compress",
            &[PathBuf::from("in.mp4")],
            &o,
            "libopenh264",
            720,
            0,
            300.0,
        );
        assert!(has(
            &a,
            &["-c:v", "libopenh264", "-pix_fmt", "yuv420p", "-b:v"]
        ));
        assert_eq!(compress_target_kbps(0, 300.0), None);
        assert_eq!(compress_target_kbps(1, 60.0), Some(100), "never below 100k");
    }

    fn args(cat: &str, target: &str, o: &ConvertOptions) -> Vec<String> {
        job_args(
            cat,
            target,
            &[PathBuf::from(r"C:\in\film.mkv")],
            o,
            "libopenh264",
            1080,
            4000,
            60.0,
        )
    }

    fn has(a: &[String], pair: [&str; 2]) -> bool {
        a.windows(2).any(|w| w[0] == pair[0] && w[1] == pair[1])
    }

    #[test]
    fn video_formats_use_the_working_encoders() {
        let a = args("video", "mp4", &opts());
        assert!(has(&a, ["-c:v", "libopenh264"]));
        assert!(has(&a, ["-b:v", "8000k"]));
        assert!(has(&a, ["-c:a", "aac"]));
        assert!(has(&a, ["-movflags", "+faststart"]));
        let w = args("video", "webm", &opts());
        assert!(has(&w, ["-c:v", "libvpx-vp9"]) && has(&w, ["-c:a", "libopus"]));
        let mut small = opts();
        small.quality = "small".into();
        small.height = 720;
        let s = args("video", "mp4", &small);
        assert!(has(&s, ["-b:v", "1750k"]));
        assert!(s.iter().any(|v| v.starts_with("scale=-2:'min(720,ih)'")));
        // MKV kept as it is: every track copied.
        let mut source = opts();
        source.quality = "source".into();
        let m = args("video", "mkv", &source);
        assert!(has(&m, ["-map", "0"]) && has(&m, ["-c", "copy"]));
    }

    #[test]
    fn tools_cut_join_and_frames() {
        let mut cut = opts();
        cut.from_ms = 1500;
        cut.to_ms = 31_500;
        let a = args("video", "cut", &cut);
        assert_eq!(&a[..4], ["-ss", "1.500", "-i", r"C:\in\film.mkv"]);
        assert!(has(&a, ["-t", "30.000"]) && has(&a, ["-c", "copy"]));

        let join = job_args(
            "video",
            "join",
            &[PathBuf::from("a.mp4"), PathBuf::from("b.mp4")],
            &opts(),
            "h264_nvenc",
            720,
            0,
            60.0,
        );
        let graph = join
            .iter()
            .find(|v| v.contains("concat=n=2"))
            .expect("concat graph");
        assert!(graph.contains("[0:v:0]scale=-2:720"));
        assert!(has(&join, ["-c:v", "h264_nvenc"]));

        let mut frames = opts();
        frames.frame_every = 10;
        let f = args("video", "frames", &frames);
        assert!(has(&f, ["-vf", "fps=1/10"]));
        assert_eq!(out_ext("video", "frames", Path::new("film.mkv")), None);
        assert_eq!(
            out_ext("video", "cut", Path::new("film.mkv")).as_deref(),
            Some("mkv")
        );
    }

    #[test]
    fn audio_and_images() {
        let mut o = opts();
        o.audio_kbps = 320;
        let a = args("audio", "mp3", &o);
        assert!(has(&a, ["-c:a", "libmp3lame"]) && has(&a, ["-b:a", "320k"]));
        assert!(a.contains(&"-vn".to_owned()));
        let f = args("audio", "flac", &o);
        assert!(has(&f, ["-c:a", "flac"]));
        let mut r = opts();
        r.width = 800;
        let i = job_args(
            "image",
            "resize",
            &[PathBuf::from("photo.jpg")],
            &r,
            "",
            0,
            0,
            60.0,
        );
        assert!(has(&i, ["-vf", "scale='min(800,iw)':-2"]));
        assert!(has(&i, ["-frames:v", "1"]));
    }

    #[test]
    fn options_and_kinds_are_checked() {
        assert!(kind_of("video", "mp4").is_ok());
        assert!(kind_of("video", "mp3").is_err());
        assert!(kind_of("image", "resize").is_ok());
        assert!(validate_options(&opts()).is_ok());
        let mut bad = opts();
        bad.audio_kbps = 999;
        assert!(validate_options(&bad).is_err());
        let mut cut = opts();
        cut.from_ms = 5000;
        cut.to_ms = 1000;
        assert!(validate_options(&cut).is_err());
    }

    /// Every operation with the real FFmpeg (`MM_FFMPEG`): a 3 s test clip
    /// made by FFmpeg itself, converted, then checked on disk.
    #[test]
    #[ignore = "needs FFmpeg (MM_FFMPEG)"]
    fn every_operation_with_the_real_ffmpeg() {
        let ffmpeg = PathBuf::from(std::env::var("MM_FFMPEG").expect("MM_FFMPEG"));
        let dir = std::env::temp_dir().join(format!("mm-conv-live-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let clip = dir.join("clip.mkv");
        let made = std::process::Command::new(&ffmpeg)
            .args([
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "testsrc=duration=3:size=640x360:rate=25",
                "-f",
                "lavfi",
                "-i",
                "sine=frequency=440:duration=3",
                "-c:v",
                "mpeg4",
                "-c:a",
                "libvorbis",
                "-shortest",
            ])
            .arg(&clip)
            .status()
            .unwrap();
        assert!(made.success());
        let h264 = h264_encoder(&ffmpeg);
        eprintln!("H.264 encoder: {h264}");
        let rt = tokio::runtime::Runtime::new().unwrap();
        let source = crate::api::converter::SourceInfo {
            size: std::fs::metadata(&clip).unwrap().len(),
            width: 640,
            height: 360,
            kbps: 500,
            duration_secs: 3.0,
            total_secs: 6.0,
        };
        let cases: &[(&str, &str, u32, u64, u64, &str)] = &[
            ("video", "mp4", 0, 0, 0, ""),
            ("video", "webm", 0, 0, 0, ""),
            ("video", "mkv", 0, 0, 0, ""),
            ("video", "avi", 0, 0, 0, ""),
            ("video", "3gp", 0, 0, 0, ""),
            ("video", "gif", 0, 0, 0, ""),
            ("video", "cut", 0, 500, 2000, ""),
            ("video", "crop", 0, 0, 0, "1:1"),
            ("video", "compress", 0, 0, 0, ""),
            ("video", "frames", 1, 0, 0, ""),
            ("video", "join", 0, 0, 0, ""),
            ("audio", "extract", 0, 0, 0, ""),
            ("audio", "flac", 0, 0, 0, ""),
            ("audio", "opus", 0, 0, 0, ""),
        ];
        for (cat, target, every, from, to, crop) in cases {
            let mut o = opts();
            o.out_dir = dir.join("out").to_string_lossy().into_owned();
            o.frame_every = *every;
            o.from_ms = *from;
            o.to_ms = *to;
            o.crop = (*crop).to_owned();
            let inputs = if *target == "join" {
                vec![clip.to_string_lossy().into_owned(); 2]
            } else {
                vec![clip.to_string_lossy().into_owned()]
            };
            let job = ConvertJob {
                id: format!("t-{target}"),
                inputs,
                name: "clip.mkv".into(),
                category: (*cat).into(),
                target: (*target).into(),
                source: source.clone(),
                state: "converting".into(),
                percent: 0.0,
                out_path: None,
                out_size: None,
                error: None,
            };
            let started = Instant::now();
            let (path, size) = rt
                .block_on(run_job(&ffmpeg, &h264, &job, &o, &CancellationToken::new()))
                .unwrap_or_else(|e| panic!("{cat} {target}: {e}"));
            eprintln!(
                "{cat:>5} {target:<8} -> {} ({size} bytes, {:.1} s)",
                path.file_name().unwrap().to_string_lossy(),
                started.elapsed().as_secs_f64()
            );
            assert!(size > 0, "{target} wrote nothing");
        }
        // An image from the frames, resized and turned into each format.
        let frames = std::fs::read_dir(dir.join("out"))
            .unwrap()
            .filter_map(|e| e.ok().map(|e| e.path()))
            .find(|p| p.is_dir())
            .unwrap();
        let image = std::fs::read_dir(&frames)
            .unwrap()
            .next()
            .unwrap()
            .unwrap()
            .path();
        for target in ["png", "jpg", "webp", "ico", "bmp", "resize"] {
            let mut o = opts();
            o.out_dir = dir.join("img").to_string_lossy().into_owned();
            o.width = 400;
            let job = ConvertJob {
                id: format!("i-{target}"),
                inputs: vec![image.to_string_lossy().into_owned()],
                name: "0001.jpg".into(),
                category: "image".into(),
                target: target.into(),
                source: crate::api::converter::SourceInfo::default(),
                state: "converting".into(),
                percent: 0.0,
                out_path: None,
                out_size: None,
                error: None,
            };
            let (path, size) = rt
                .block_on(run_job(&ffmpeg, &h264, &job, &o, &CancellationToken::new()))
                .unwrap_or_else(|e| panic!("image {target}: {e}"));
            eprintln!(
                "image {target:<8} -> {} ({size} bytes)",
                path.file_name().unwrap().to_string_lossy()
            );
            assert!(size > 0);
        }
        // A stop kills FFmpeg and leaves no temporary file.
        let cancel = CancellationToken::new();
        cancel.cancel();
        let mut o = opts();
        o.out_dir = dir.join("stop").to_string_lossy().into_owned();
        let job = ConvertJob {
            id: "t-stop".into(),
            inputs: vec![clip.to_string_lossy().into_owned()],
            name: "clip.mkv".into(),
            category: "video".into(),
            target: "webm".into(),
            source: source.clone(),
            state: "converting".into(),
            percent: 0.0,
            out_path: None,
            out_size: None,
            error: None,
        };
        let r = rt.block_on(run_job(&ffmpeg, &h264, &job, &o, &cancel));
        assert!(r.is_err());
        let left = std::fs::read_dir(dir.join("stop"))
            .map(|d| d.count())
            .unwrap_or(0);
        assert_eq!(left, 0, "no temporary file left");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn output_names_are_free_and_safe() {
        let dir = std::env::temp_dir().join(format!("mm-conv-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("Film.mp4"), b"x").unwrap();
        let p = free_path(&dir, "Film", Some("mp4")).unwrap();
        assert_eq!(p.file_name().unwrap(), "Film (1).mp4");
        let q = free_path(&dir, "a/b:c", Some("mp3")).unwrap();
        assert!(
            !q.file_name()
                .unwrap()
                .to_string_lossy()
                .contains(['/', ':'])
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}

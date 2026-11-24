//! Enregistrer l'écran (Outils PC, handoff § 3). FFmpeg (the app's own)
//! films the desktop, a zone or a window with gdigrab; the PC's sound
//! (WASAPI loopback) and the microphone are captured here, mixed and sent
//! to FFmpeg through a named pipe. Each pause closes a Matroska segment
//! (readable even if the PC stops); the end joins them into the chosen
//! format next to its final name, then renames it. Windows only.

use std::collections::VecDeque;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, LazyLock, Mutex};
use std::time::{Duration, Instant};

use anyhow::{Result, anyhow, bail};

use crate::api::recorder::{RecordOptions, RecorderStatus, Recording};
use crate::frb_generated::StreamSink;

/// The mix sent to FFmpeg: 48 kHz stereo, 32-bit float.
pub const RATE: u32 = 48_000;
const CHANNELS: usize = 2;
/// Captured sound kept waiting at most (beyond: the oldest goes), so a
/// device whose clock runs a little fast never adds delay.
const MAX_LAG: usize = RATE as usize * CHANNELS * 3 / 10;
const FEED_EVERY: Duration = Duration::from_millis(10);
const STOP_WAIT: Duration = Duration::from_secs(10);

fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

// ------------------------------------------------------------- planning

/// What is filmed.
#[derive(Clone, Debug, PartialEq)]
pub enum Source {
    /// A rectangle of the desktop, physical pixels (a screen or a zone).
    Desktop { x: i32, y: i32, w: u32, h: u32 },
    /// The window with this exact title.
    Window(String),
}

/// Checked options.
#[derive(Clone, Debug)]
pub struct Plan {
    pub source: Source,
    pub fps: u32,
    /// medium, high, original.
    pub quality: String,
    /// mp4, mkv, webm, gif.
    pub format: String,
    pub cursor: bool,
    pub system_audio: bool,
    pub mic: bool,
    pub out_dir: PathBuf,
}

impl Plan {
    pub fn audio(&self) -> bool {
        (self.system_audio || self.mic) && self.format != "gif"
    }
}

pub fn plan(o: &RecordOptions) -> Result<Plan> {
    let source = match o.source.as_str() {
        "screen" | "region" => {
            // Even sizes (H.264 4:2:0), at least 16 pixels.
            let w = o.width & !1;
            let h = o.height & !1;
            if w < 16 || h < 16 || w > 16_384 || h > 16_384 {
                bail!("zone too small");
            }
            Source::Desktop {
                x: o.x,
                y: o.y,
                w,
                h,
            }
        }
        "window" => {
            let title = o.window_title.trim();
            if title.is_empty() || title.len() > 512 || title.contains(['\0', '\n', '\r']) {
                bail!("window not chosen");
            }
            Source::Window(o.window_title.clone())
        }
        other => bail!("source {other} not supported"),
    };
    if ![24, 30, 60].contains(&o.fps) {
        bail!("fps {} not supported", o.fps);
    }
    if !["medium", "high", "original"].contains(&o.quality.as_str()) {
        bail!("quality {} not supported", o.quality);
    }
    if !["mp4", "mkv", "webm", "gif"].contains(&o.format.as_str()) {
        bail!("format {} not supported", o.format);
    }
    let out_dir = PathBuf::from(&o.out_dir);
    if !out_dir.is_absolute() {
        bail!("folder must be absolute");
    }
    Ok(Plan {
        source,
        fps: o.fps,
        quality: o.quality.clone(),
        format: o.format.clone(),
        cursor: o.cursor,
        system_audio: o.system_audio,
        mic: o.mic,
        out_dir,
    })
}

/// H.264 bit rate for a picture size, rate and quality, in kbit/s.
pub fn video_kbps(w: u32, h: u32, fps: u32, quality: &str) -> u32 {
    let bits_per_pixel = match quality {
        "original" => 0.25,
        "high" => 0.14,
        _ => 0.08,
    };
    let kbps = f64::from(w) * f64::from(h) * f64::from(fps) * bits_per_pixel / 1000.0;
    (kbps as u32).clamp(1_000, 60_000)
}

fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|s| (*s).to_owned()).collect()
}

/// FFmpeg's arguments for one segment: `pipe` is the sound's named pipe
/// (None: no sound). FFmpeg's standard input stays open: "q" ends it.
pub fn segment_args(plan: &Plan, h264: &str, pipe: Option<&str>, out: &Path) -> Vec<String> {
    let mut a = strings(&["-hide_banner", "-loglevel", "error", "-y"]);
    a.extend(strings(&["-thread_queue_size", "512", "-f", "gdigrab"]));
    a.extend(["-framerate".into(), plan.fps.to_string()]);
    a.extend([
        "-draw_mouse".into(),
        if plan.cursor { "1" } else { "0" }.into(),
    ]);
    let (w, h) = match &plan.source {
        Source::Desktop { x, y, w, h } => {
            a.extend(["-offset_x".into(), x.to_string()]);
            a.extend(["-offset_y".into(), y.to_string()]);
            a.extend(["-video_size".into(), format!("{w}x{h}")]);
            a.extend(["-i".into(), "desktop".into()]);
            (*w, *h)
        }
        Source::Window(title) => {
            a.extend(["-i".into(), format!("title={title}")]);
            (1920, 1080)
        }
    };
    if let Some(pipe) = pipe {
        a.extend(strings(&[
            "-thread_queue_size",
            "1024",
            "-f",
            "f32le",
            "-ar",
            "48000",
            "-ac",
            "2",
            "-i",
        ]));
        a.push(pipe.to_owned());
    }
    a.extend(strings(&["-map", "0:v"]));
    if pipe.is_some() {
        a.extend(strings(&["-map", "1:a"]));
    }
    // A window may have an odd size.
    a.extend(strings(&[
        "-vf",
        "crop=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p",
    ]));
    let kbps = video_kbps(w, h, plan.fps, &plan.quality);
    a.extend(["-c:v".into(), h264.to_owned()]);
    match h264 {
        "h264_nvenc" => a.extend(strings(&["-preset", "p4", "-tune", "ll"])),
        "h264_qsv" => a.extend(strings(&["-preset", "veryfast"])),
        _ => {}
    }
    a.extend(["-b:v".into(), format!("{kbps}k")]);
    a.extend(["-maxrate".into(), format!("{}k", kbps * 3 / 2)]);
    a.extend(["-bufsize".into(), format!("{}k", kbps * 2)]);
    a.extend(["-g".into(), (plan.fps * 2).to_string()]);
    if pipe.is_some() {
        a.extend(strings(&["-c:a", "aac", "-b:a", "160k"]));
    }
    a.extend(strings(&["-f", "matroska"]));
    a.push(out.to_string_lossy().into_owned());
    a
}

/// The concat list of the segments (FFmpeg's quoting).
pub fn concat_list(segments: &[PathBuf]) -> String {
    let mut out = String::new();
    for s in segments {
        let p = s.to_string_lossy().replace('\'', r"'\''");
        out.push_str(&format!("file '{p}'\n"));
    }
    out
}

/// FFmpeg's arguments that join the segments (`input`: the only segment,
/// or the concat list) into the chosen format.
pub fn finish_args(plan: &Plan, input: &Path, concat: bool, out: &Path) -> Vec<String> {
    let mut a = strings(&["-hide_banner", "-nostdin", "-loglevel", "error", "-y"]);
    if concat {
        a.extend(strings(&["-f", "concat", "-safe", "0"]));
    }
    a.extend(["-i".into(), input.to_string_lossy().into_owned()]);
    match plan.format.as_str() {
        "mp4" => a.extend(strings(&[
            "-map",
            "0",
            "-c",
            "copy",
            "-movflags",
            "+faststart",
            "-f",
            "mp4",
        ])),
        "mkv" => a.extend(strings(&["-map", "0", "-c", "copy", "-f", "matroska"])),
        "webm" => a.extend(strings(&[
            "-map",
            "0:v",
            "-map",
            "0:a?",
            "-c:v",
            "libvpx-vp9",
            "-b:v",
            "0",
            "-crf",
            "33",
            "-deadline",
            "good",
            "-cpu-used",
            "5",
            "-row-mt",
            "1",
            "-c:a",
            "libopus",
            "-b:a",
            "128k",
            "-f",
            "webm",
        ])),
        _ => {
            let fps = plan.fps.min(15);
            a.extend(strings(&["-map", "0:v", "-vf"]));
            a.push(format!(
                "fps={fps},scale='min(960,iw)':-2:flags=lanczos,split[a][b];\
                 [a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer"
            ));
            a.extend(strings(&["-loop", "0", "-f", "gif"]));
        }
    }
    a.push(out.to_string_lossy().into_owned());
    a
}

/// Adds what [ring] holds (interleaved stereo) into [out], muted or not.
pub fn mix_into(out: &mut [f32], ring: &mut VecDeque<f32>, muted: bool) {
    let n = out.len().min(ring.len());
    for (o, s) in out.iter_mut().zip(ring.drain(..n)) {
        if !muted {
            *o += s;
        }
    }
}

// ---------------------------------------------------------------- state

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Phase {
    Idle,
    Recording,
    Paused,
    Finalizing,
}

impl Phase {
    fn name(self) -> &'static str {
        match self {
            Phase::Idle => "idle",
            Phase::Recording => "recording",
            Phase::Paused => "paused",
            Phase::Finalizing => "finalizing",
        }
    }
}

/// What status readers see (kept apart from the session, which waits on
/// FFmpeg).
struct Status {
    phase: Phase,
    done_ms: u64,
    since: Option<Instant>,
    mic_muted: bool,
}

static STATUS: Mutex<Status> = Mutex::new(Status {
    phase: Phase::Idle,
    done_ms: 0,
    since: None,
    mic_muted: false,
});
static SINK: Mutex<Option<StreamSink<RecorderStatus>>> = Mutex::new(None);
static MIC_MUTED: LazyLock<Arc<AtomicBool>> = LazyLock::new(|| Arc::new(AtomicBool::new(false)));
static SESSION: LazyLock<tokio::sync::Mutex<Option<Session>>> =
    LazyLock::new(|| tokio::sync::Mutex::new(None));

/// A recording is under way (an update would cut it).
pub fn active() -> bool {
    lock(&STATUS).phase != Phase::Idle
}

pub fn status() -> RecorderStatus {
    let s = lock(&STATUS);
    RecorderStatus {
        phase: s.phase.name().to_owned(),
        elapsed_ms: s.done_ms + s.since.map_or(0, |t| t.elapsed().as_millis() as u64),
        mic_muted: s.mic_muted,
    }
}

fn emit() {
    if let Some(sink) = lock(&SINK).as_ref() {
        let _ = sink.add(status());
    }
}

fn set_status(f: impl FnOnce(&mut Status)) {
    f(&mut lock(&STATUS));
    emit();
}

pub fn set_sink(sink: StreamSink<RecorderStatus>, runtime: &tokio::runtime::Handle) {
    *lock(&SINK) = Some(sink);
    emit();
    // The time once a second while it runs.
    static TICKING: AtomicBool = AtomicBool::new(false);
    if !TICKING.swap(true, Ordering::SeqCst) {
        runtime.spawn(async {
            let mut tick = tokio::time::interval(Duration::from_secs(1));
            loop {
                tick.tick().await;
                if lock(&STATUS).phase == Phase::Recording {
                    emit();
                }
            }
        });
    }
}

pub fn set_mic_muted(muted: bool) {
    MIC_MUTED.store(muted, Ordering::SeqCst);
    set_status(|s| s.mic_muted = muted);
}

struct Session {
    plan: Plan,
    ffmpeg: PathBuf,
    h264: String,
    dir: PathBuf,
    segments: Vec<PathBuf>,
    current: Option<Segment>,
}

struct Segment {
    child: tokio::process::Child,
    stdin: Option<tokio::process::ChildStdin>,
    _tree: Option<download_engine::process::ProcessTree>,
    audio: Option<Audio>,
    errors: tokio::task::JoinHandle<String>,
}

// ------------------------------------------------------------- the work

pub async fn start(plan: Plan, ffmpeg: PathBuf, h264: String) -> Result<()> {
    let mut guard = SESSION.lock().await;
    if guard.is_some() {
        bail!("already recording");
    }
    tokio::fs::create_dir_all(&plan.out_dir).await?;
    let dir = plan.out_dir.join(format!(
        ".miarina-rec-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis())
            .unwrap_or(0)
    ));
    tokio::fs::create_dir_all(&dir).await?;
    let mut session = Session {
        plan,
        ffmpeg,
        h264,
        dir,
        segments: Vec::new(),
        current: None,
    };
    let began = match open_segment(&mut session).await {
        Ok(t) => t,
        Err(e) => {
            let _ = tokio::fs::remove_dir_all(&session.dir).await;
            return Err(e);
        }
    };
    set_status(|s| {
        s.phase = Phase::Recording;
        s.done_ms = 0;
        s.since = Some(began);
    });
    *guard = Some(session);
    Ok(())
}

pub async fn pause() -> Result<()> {
    let mut guard = SESSION.lock().await;
    let session = guard.as_mut().ok_or_else(|| anyhow!("not recording"))?;
    if session.current.is_none() {
        return Ok(());
    }
    close_segment(session).await;
    set_status(|s| {
        s.done_ms += s.since.take().map_or(0, |t| t.elapsed().as_millis() as u64);
        s.phase = Phase::Paused;
    });
    Ok(())
}

pub async fn resume() -> Result<()> {
    let mut guard = SESSION.lock().await;
    let session = guard.as_mut().ok_or_else(|| anyhow!("not recording"))?;
    if session.current.is_some() {
        return Ok(());
    }
    let began = open_segment(session).await?;
    set_status(|s| {
        s.since = Some(began);
        s.phase = Phase::Recording;
    });
    Ok(())
}

/// Ends the recording: the file in the chosen format, or an error (the
/// segments then stay in their folder, nothing is lost).
pub async fn stop(stem: &str) -> Result<Recording> {
    let mut guard = SESSION.lock().await;
    let mut session = guard.take().ok_or_else(|| anyhow!("not recording"))?;
    if session.current.is_some() {
        close_segment(&mut session).await;
    }
    let elapsed_ms = {
        let mut s = lock(&STATUS);
        s.done_ms += s.since.take().map_or(0, |t| t.elapsed().as_millis() as u64);
        s.phase = Phase::Finalizing;
        s.done_ms
    };
    emit();
    let result = finish(&session, elapsed_ms, stem).await;
    set_status(|s| {
        s.phase = Phase::Idle;
        s.done_ms = 0;
        s.since = None;
    });
    result
}

async fn finish(session: &Session, elapsed_ms: u64, stem: &str) -> Result<Recording> {
    let segments: Vec<PathBuf> = session
        .segments
        .iter()
        .filter(|p| std::fs::metadata(p).is_ok_and(|m| m.len() > 1024))
        .cloned()
        .collect();
    if segments.is_empty() {
        let _ = tokio::fs::remove_dir_all(&session.dir).await;
        bail!("nothing recorded");
    }
    let plan = &session.plan;
    let final_path = crate::converter::free_path(&plan.out_dir, stem, Some(&plan.format))?;
    let part = session.dir.join(format!("final.part.{}", plan.format));
    let (input, concat) = if segments.len() == 1 {
        (segments[0].clone(), false)
    } else {
        let list = session.dir.join("list.txt");
        tokio::fs::write(&list, concat_list(&segments)).await?;
        (list, true)
    };
    let mut command = tokio::process::Command::new(&session.ffmpeg);
    command
        .args(finish_args(plan, &input, concat, &part))
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped());
    download_engine::process::configure(&mut command, true);
    let out = command.output().await?;
    if !out.status.success() {
        let _ = tokio::fs::remove_file(&part).await;
        let text = String::from_utf8_lossy(&out.stderr);
        bail!(
            "finish_failed: {}",
            text.chars().take(300).collect::<String>()
        );
    }
    tokio::fs::rename(&part, &final_path).await?;
    let _ = tokio::fs::remove_dir_all(&session.dir).await;
    let size = tokio::fs::metadata(&final_path).await?.len();
    // Into the library, like a downloaded file (a GIF is not a media).
    if let Ok(parts) = crate::api::indexer::shared() {
        let _ = parts.library.add_opened(std::slice::from_ref(&final_path));
    }
    Ok(Recording {
        path: final_path.to_string_lossy().into_owned(),
        duration_secs: elapsed_ms as f64 / 1000.0,
        size,
        format: plan.format.clone(),
    })
}

/// Stops everything at once (the app closes): the segments stay.
pub fn abort() {
    if let Ok(mut guard) = SESSION.try_lock()
        && let Some(mut session) = guard.take()
        && let Some(seg) = session.current.take()
    {
        if let Some(a) = seg.audio {
            a.stop();
        }
        drop(seg.child);
    }
}

fn pipe_name(dir: &Path, n: usize) -> String {
    use std::hash::{Hash, Hasher};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    dir.hash(&mut h);
    format!(
        r"\\.\pipe\miarina-rec-{}-{:x}-{n}",
        std::process::id(),
        h.finish()
    )
}

/// Starts FFmpeg on a new segment; returns when it started filming.
async fn open_segment(session: &mut Session) -> Result<Instant> {
    use download_engine::process::{ProcessTree, configure};

    let n = session.segments.len();
    let out = session.dir.join(format!("part-{n:03}.mkv"));
    let pipe = session.plan.audio().then(|| pipe_name(&session.dir, n));
    let audio = match &pipe {
        Some(name) => Some(Audio::start(
            name,
            session.plan.system_audio,
            session.plan.mic,
        )?),
        None => None,
    };
    let args = segment_args(&session.plan, &session.h264, pipe.as_deref(), &out);
    let mut command = tokio::process::Command::new(&session.ffmpeg);
    command
        .args(&args)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped());
    // Normal priority: frames must not be dropped.
    configure(&mut command, false);
    let mut child = match command.spawn() {
        Ok(c) => c,
        Err(e) => {
            if let Some(a) = audio {
                a.stop();
            }
            return Err(e.into());
        }
    };
    let began = Instant::now();
    let tree = ProcessTree::adopt(&child).ok();
    let stdin = child.stdin.take();
    let mut stderr = child.stderr.take().ok_or_else(|| anyhow!("no output"))?;
    let errors = tokio::spawn(async move {
        use tokio::io::AsyncReadExt;
        let mut buf = Vec::new();
        let _ = (&mut stderr).take(16 * 1024).read_to_end(&mut buf).await;
        let _ = tokio::io::copy(&mut stderr, &mut tokio::io::sink()).await;
        String::from_utf8_lossy(&buf).into_owned()
    });
    // A window that does not exist, a zone off the screens: FFmpeg stops
    // at once.
    tokio::time::sleep(Duration::from_millis(1200)).await;
    if let Ok(Some(_)) = child.try_wait() {
        if let Some(a) = audio {
            a.stop();
        }
        let text = errors.await.unwrap_or_default();
        let _ = tokio::fs::remove_file(&out).await;
        bail!(
            "record_failed: {}",
            text.trim().chars().take(300).collect::<String>()
        );
    }
    session.segments.push(out);
    session.current = Some(Segment {
        child,
        stdin,
        _tree: tree,
        audio,
        errors,
    });
    Ok(began)
}

async fn close_segment(session: &mut Session) {
    use tokio::io::AsyncWriteExt;
    let Some(mut seg) = session.current.take() else {
        return;
    };
    if let Some(mut stdin) = seg.stdin.take() {
        let _ = stdin.write_all(b"q").await;
        let _ = stdin.flush().await;
    }
    if tokio::time::timeout(STOP_WAIT, seg.child.wait())
        .await
        .is_err()
    {
        let _ = seg.child.kill().await;
    }
    if let Some(a) = seg.audio.take() {
        a.stop();
    }
    seg.errors.abort();
}

// ---------------------------------------------------------------- sound

/// The sound of one segment: capture threads and the mixer that feeds the
/// pipe.
struct Audio {
    stop: Arc<AtomicBool>,
    threads: Vec<std::thread::JoinHandle<()>>,
    feed: tokio::task::JoinHandle<()>,
}

impl Audio {
    #[cfg(windows)]
    fn start(pipe: &str, system: bool, mic: bool) -> Result<Self> {
        use tokio::net::windows::named_pipe::ServerOptions;

        let server = ServerOptions::new()
            .first_pipe_instance(true)
            .out_buffer_size(1 << 20)
            .create(pipe)?;
        let stop = Arc::new(AtomicBool::new(false));
        let mut rings = Vec::new();
        let mut threads = Vec::new();
        for (on, loopback) in [(system, true), (mic, false)] {
            if !on {
                continue;
            }
            let ring = Arc::new(Mutex::new(VecDeque::<f32>::new()));
            let (r, s) = (ring.clone(), stop.clone());
            threads.push(std::thread::spawn(move || {
                if let Err(e) = capture(loopback, &r, &s) {
                    eprintln!("recorder: sound capture: {e}");
                }
            }));
            rings.push((ring, !loopback));
        }
        let s = stop.clone();
        let feed = tokio::spawn(async move {
            if let Err(e) = feed(server, rings, s).await {
                eprintln!("recorder: sound feed: {e}");
            }
        });
        Ok(Self {
            stop,
            threads,
            feed,
        })
    }

    #[cfg(not(windows))]
    fn start(_pipe: &str, _system: bool, _mic: bool) -> Result<Self> {
        bail!("Windows only")
    }

    fn stop(self) {
        self.stop.store(true, Ordering::SeqCst);
        self.feed.abort();
        for t in self.threads {
            let _ = t.join();
        }
    }
}

/// Writes the mix in real time: what the devices gave, silence for the
/// rest (a PC that plays nothing gives no sound at all).
#[cfg(windows)]
async fn feed(
    mut pipe: tokio::net::windows::named_pipe::NamedPipeServer,
    rings: Vec<(Arc<Mutex<VecDeque<f32>>>, bool)>,
    stop: Arc<AtomicBool>,
) -> Result<()> {
    use tokio::io::AsyncWriteExt;
    pipe.connect().await?;
    let started = Instant::now();
    let mut written: u64 = 0;
    let mut tick = tokio::time::interval(FEED_EVERY);
    let mut bytes = Vec::new();
    while !stop.load(Ordering::SeqCst) {
        tick.tick().await;
        let due = (started.elapsed().as_secs_f64() * f64::from(RATE)) as u64;
        let frames = (due - written) as usize;
        if frames == 0 {
            continue;
        }
        let mut out = vec![0f32; frames * CHANNELS];
        for (ring, is_mic) in &rings {
            let muted = *is_mic && MIC_MUTED.load(Ordering::SeqCst);
            mix_into(&mut out, &mut lock(ring), muted);
        }
        bytes.clear();
        for s in &out {
            bytes.extend_from_slice(&s.clamp(-1.0, 1.0).to_le_bytes());
        }
        // FFmpeg closing its end is how a segment ends.
        if pipe.write_all(&bytes).await.is_err() {
            break;
        }
        written = due;
    }
    Ok(())
}

/// One device into its ring: the default output (what the speakers play)
/// or the default microphone, converted by Windows to 48 kHz stereo float.
#[cfg(windows)]
fn capture(loopback: bool, ring: &Mutex<VecDeque<f32>>, stop: &AtomicBool) -> Result<()> {
    use wasapi::{DeviceEnumerator, Direction, SampleType, StreamMode, WaveFormat};

    let _ = wasapi::initialize_mta();
    let device = DeviceEnumerator::new()?.get_default_device(if loopback {
        Direction::Render
    } else {
        Direction::Capture
    })?;
    let mut client = device.get_iaudioclient()?;
    let format = WaveFormat::new(32, 32, SampleType::Float, RATE as usize, CHANNELS, None);
    let (period, _) = client.get_device_period()?;
    client.initialize_client(
        &format,
        Direction::Capture,
        StreamMode::PollingShared {
            autoconvert: true,
            buffer_duration_hns: period * 10,
        },
        None,
    )?;
    let reader = client.get_audiocaptureclient()?;
    client.start_stream()?;
    let mut raw = VecDeque::<u8>::new();
    while !stop.load(Ordering::SeqCst) {
        std::thread::sleep(FEED_EVERY);
        while reader.get_next_packet_size()?.unwrap_or(0) > 0 {
            reader.read_from_device_to_deque(&mut raw)?;
        }
        let whole = raw.len() / 4 * 4;
        if whole == 0 {
            continue;
        }
        let mut r = lock(ring);
        let bytes: Vec<u8> = raw.drain(..whole).collect();
        for sample in bytes.as_chunks::<4>().0 {
            r.push_back(f32::from_le_bytes(*sample));
        }
        if r.len() > MAX_LAG {
            let extra = r.len() - MAX_LAG;
            // Whole frames only, so left and right stay in place.
            r.drain(..extra + extra % CHANNELS);
        }
    }
    let _ = client.stop_stream();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn options() -> RecordOptions {
        RecordOptions {
            source: "region".into(),
            x: 100,
            y: 50,
            width: 641,
            height: 361,
            window_title: String::new(),
            format: "mp4".into(),
            fps: 30,
            quality: "high".into(),
            system_audio: true,
            mic: false,
            cursor: true,
            out_dir: r"C:\Users\x\Videos\Miarina".into(),
        }
    }

    #[test]
    fn plans_check_the_options() {
        let p = plan(&options()).unwrap();
        assert_eq!(
            p.source,
            Source::Desktop {
                x: 100,
                y: 50,
                w: 640,
                h: 360
            }
        );
        assert!(p.audio());
        let mut o = options();
        o.width = 10;
        assert!(plan(&o).is_err());
        let mut o = options();
        o.fps = 25;
        assert!(plan(&o).is_err());
        let mut o = options();
        o.format = "avi".into();
        assert!(plan(&o).is_err());
        let mut o = options();
        o.source = "window".into();
        assert!(plan(&o).is_err(), "no title");
        o.window_title = "Bloc-notes".into();
        assert_eq!(
            plan(&o).unwrap().source,
            Source::Window("Bloc-notes".into())
        );
        let mut o = options();
        o.out_dir = "relative".into();
        assert!(plan(&o).is_err());
        let mut o = options();
        o.format = "gif".into();
        assert!(!plan(&o).unwrap().audio(), "a GIF has no sound");
    }

    #[test]
    fn segment_arguments() {
        let p = plan(&options()).unwrap();
        let a = segment_args(&p, "h264_nvenc", Some(r"\\.\pipe\x"), Path::new("s.mkv"));
        let has = |w: &[&str]| a.windows(w.len()).any(|x| x == w);
        assert!(has(&[
            "-f",
            "gdigrab",
            "-framerate",
            "30",
            "-draw_mouse",
            "1"
        ]));
        assert!(has(&[
            "-offset_x",
            "100",
            "-offset_y",
            "50",
            "-video_size",
            "640x360"
        ]));
        assert!(has(&["-i", "desktop"]));
        assert!(has(&[
            "-f",
            "f32le",
            "-ar",
            "48000",
            "-ac",
            "2",
            "-i",
            r"\\.\pipe\x"
        ]));
        assert!(has(&["-map", "1:a"]));
        assert!(has(&["-c:v", "h264_nvenc", "-preset", "p4"]));
        assert!(has(&["-c:a", "aac"]));
        assert!(!a.contains(&"-nostdin".to_owned()), "q ends it");
        assert_eq!(a.last().unwrap(), "s.mkv");

        let mut o = options();
        o.source = "window".into();
        o.window_title = "Sans titre - Bloc-notes".into();
        o.cursor = false;
        let p = plan(&o).unwrap();
        let a = segment_args(&p, "libopenh264", None, Path::new("s.mkv"));
        assert!(a.contains(&"title=Sans titre - Bloc-notes".to_owned()));
        assert!(a.windows(2).any(|w| w == ["-draw_mouse", "0"]));
        assert!(!a.iter().any(|x| x == "1:a"));
    }

    #[test]
    fn finishing_arguments() {
        let p = plan(&options()).unwrap();
        let a = finish_args(&p, Path::new("list.txt"), true, Path::new("o.mp4"));
        assert!(a.windows(4).any(|w| w == ["-f", "concat", "-safe", "0"]));
        assert!(a.windows(2).any(|w| w == ["-c", "copy"]));
        assert!(a.windows(2).any(|w| w == ["-movflags", "+faststart"]));
        let mut o = options();
        o.format = "gif".into();
        o.fps = 60;
        let a = finish_args(
            &plan(&o).unwrap(),
            Path::new("s.mkv"),
            false,
            Path::new("o.gif"),
        );
        assert!(a.iter().any(|x| x.starts_with("fps=15,")));
        assert!(!a.contains(&"concat".to_owned()));
        let mut o = options();
        o.format = "webm".into();
        let a = finish_args(
            &plan(&o).unwrap(),
            Path::new("s.mkv"),
            false,
            Path::new("o.webm"),
        );
        assert!(a.windows(2).any(|w| w == ["-c:v", "libvpx-vp9"]));
        assert_eq!(
            concat_list(&[PathBuf::from(r"C:\a\l'x.mkv")]),
            "file 'C:\\a\\l'\\''x.mkv'\n"
        );
    }

    #[test]
    fn rates_names_and_mixing() {
        assert_eq!(video_kbps(1920, 1080, 30, "medium"), 4976);
        assert_eq!(video_kbps(320, 240, 24, "medium"), 1000, "floor");
        assert!(video_kbps(1920, 1080, 30, "original") > video_kbps(1920, 1080, 30, "high"));
        let mut out = vec![0.5f32; 4];
        let mut ring: VecDeque<f32> = [0.25, 0.25].into_iter().collect();
        mix_into(&mut out, &mut ring, false);
        assert_eq!(out, [0.75, 0.75, 0.5, 0.5]);
        assert!(ring.is_empty());
        let mut ring: VecDeque<f32> = [1.0; 4].into_iter().collect();
        mix_into(&mut out, &mut ring, true);
        assert_eq!(out, [0.75, 0.75, 0.5, 0.5], "muted: taken, not heard");
        assert!(ring.is_empty());
    }

    /// A real two-segment recording (a pause in the middle) with the PC's
    /// sound: `MM_FFMPEG=<ffmpeg.exe> MM_REC_WINDOW=<title> cargo test
    /// recorder -- --ignored`. Films only that window (Miarina Media's own:
    /// never the user's screen), checks the file, deletes it.
    #[test]
    #[ignore]
    fn live_recording() {
        let ffmpeg = PathBuf::from(std::env::var("MM_FFMPEG").expect("MM_FFMPEG"));
        let dir = std::env::temp_dir().join(format!("mm-rec-{}", std::process::id()));
        let rt = tokio::runtime::Runtime::new().unwrap();
        let mut o = options();
        o.source = "window".into();
        o.window_title = std::env::var("MM_REC_WINDOW").expect("MM_REC_WINDOW");
        o.out_dir = dir.to_string_lossy().into_owned();
        let h264 = crate::converter::h264_encoder(&ffmpeg);
        let rec = rt.block_on(async {
            start(plan(&o).unwrap(), ffmpeg.clone(), h264)
                .await
                .unwrap();
            tokio::time::sleep(Duration::from_secs(2)).await;
            pause().await.unwrap();
            assert_eq!(status().phase, "paused");
            tokio::time::sleep(Duration::from_millis(500)).await;
            resume().await.unwrap();
            tokio::time::sleep(Duration::from_secs(2)).await;
            stop("Enregistrement test").await.unwrap()
        });
        println!("{} {} s {} bytes", rec.path, rec.duration_secs, rec.size);
        assert!(rec.path.ends_with(".mp4"));
        // Two segments of about 1.2 s (FFmpeg's start check) + 2 s.
        assert!((rec.duration_secs - 6.4).abs() < 1.5);
        let probe = std::process::Command::new(&ffmpeg)
            .args(["-hide_banner", "-i", &rec.path])
            .output()
            .unwrap();
        let text = String::from_utf8_lossy(&probe.stderr);
        println!("{text}");
        // The time shown is the file's own.
        let file_secs = text
            .split("Duration: ")
            .nth(1)
            .and_then(|d| d.split(',').next())
            .map(|d| {
                d.split(':')
                    .filter_map(|x| x.trim().parse::<f64>().ok())
                    .fold(0.0, |acc, x| acc * 60.0 + x)
            })
            .unwrap();
        assert!((file_secs - rec.duration_secs).abs() < 1.0, "{file_secs}");
        assert!(text.contains("Video: h264"));
        assert!(text.contains("Audio: aac"));
        let leftovers: Vec<_> = std::fs::read_dir(&dir).unwrap().flatten().collect();
        assert_eq!(leftovers.len(), 1, "only the recording stays");
        std::fs::remove_dir_all(&dir).unwrap();
    }
}

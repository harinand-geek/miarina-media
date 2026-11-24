//! Enregistrer l'écran (Outils PC): start, pause, resume, stop; the time
//! once a second. Windows only; FFmpeg is the app's own. Implementation in
//! `crate::recorder`.

use std::path::Path;

use anyhow::{Result, anyhow};

use crate::frb_generated::StreamSink;
use crate::recorder as imp;

/// What to film and how (the recorder screen's choices).
#[derive(Clone)]
pub struct RecordOptions {
    /// screen, window, region.
    pub source: String,
    /// The screen or the zone on the desktop, physical pixels.
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
    /// The window's exact title (source window).
    pub window_title: String,
    /// mp4, mkv, webm, gif.
    pub format: String,
    /// 24, 30, 60.
    pub fps: u32,
    /// medium, high, original.
    pub quality: String,
    pub system_audio: bool,
    pub mic: bool,
    pub cursor: bool,
    pub out_dir: String,
}

pub struct RecorderStatus {
    /// idle, recording, paused, finalizing.
    pub phase: String,
    pub elapsed_ms: u64,
    pub mic_muted: bool,
}

/// A finished recording.
pub struct Recording {
    pub path: String,
    pub duration_secs: f64,
    pub size: u64,
    pub format: String,
}

fn runtime() -> Result<tokio::runtime::Handle> {
    Ok(crate::api::indexer::shared()?.runtime)
}

fn ffmpeg() -> Result<std::path::PathBuf> {
    crate::api::get::ffmpeg_tools()
        .map(|(f, _)| f)
        .ok_or_else(|| anyhow!("ffmpeg_missing"))
}

pub fn recorder_start(options: RecordOptions) -> Result<()> {
    let plan = imp::plan(&options)?;
    let ffmpeg = ffmpeg()?;
    let h264 = crate::converter::h264_encoder(&ffmpeg);
    runtime()?.block_on(imp::start(plan, ffmpeg, h264))
}

pub fn recorder_pause() -> Result<()> {
    runtime()?.block_on(imp::pause())
}

pub fn recorder_resume() -> Result<()> {
    runtime()?.block_on(imp::resume())
}

/// Ends it; `stem` is the file's name without extension ("Enregistrement
/// 2026-11-17 14-32"), made free with " (1)" when taken.
pub fn recorder_stop(stem: String) -> Result<Recording> {
    runtime()?.block_on(imp::stop(&stem))
}

#[flutter_rust_bridge::frb(sync)]
pub fn recorder_set_mic_muted(muted: bool) {
    imp::set_mic_muted(muted);
}

#[flutter_rust_bridge::frb(sync)]
pub fn recorder_status() -> RecorderStatus {
    imp::status()
}

pub fn recorder_events(sink: StreamSink<RecorderStatus>) -> Result<()> {
    imp::set_sink(sink, &runtime()?);
    Ok(())
}

/// The app closes: FFmpeg stops, the segments stay on disk.
#[flutter_rust_bridge::frb(sync)]
pub fn recorder_abort() {
    imp::abort();
}

/// Videos\Miarina, the handoff's default.
#[flutter_rust_bridge::frb(sync)]
pub fn recorder_default_dir() -> String {
    let home = std::env::var("USERPROFILE").unwrap_or_default();
    Path::new(&home)
        .join("Videos")
        .join("Miarina")
        .to_string_lossy()
        .into_owned()
}

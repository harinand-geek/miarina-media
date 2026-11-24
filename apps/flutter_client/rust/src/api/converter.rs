//! Convertir (Outils PC): the conversion queue for the screen. Windows
//! only; FFmpeg is the app's own. Implementation in `crate::converter`.

use std::path::{Path, PathBuf};

use anyhow::{Result, anyhow};

use crate::converter as imp;
use crate::frb_generated::StreamSink;

/// What a source file is, for the queue's line.
#[derive(Clone, Default)]
pub struct SourceInfo {
    pub size: u64,
    pub width: u32,
    pub height: u32,
    /// Overall kbit/s (size over duration).
    pub kbps: u32,
    pub duration_secs: f64,
    /// Every file of a join, end to end.
    pub total_secs: f64,
}

/// Options of the format or tool dialog.
#[derive(Clone)]
pub struct ConvertOptions {
    /// source, high, medium, small.
    pub quality: String,
    /// 0 = the source's; 2160, 1080, 720, 480.
    pub height: u32,
    /// 0 = 192; 128, 192, 256, 320.
    pub audio_kbps: u32,
    /// Découper: keep from … to (ms; 0 = the end).
    pub from_ms: u64,
    pub to_ms: u64,
    /// Rogner: 16:9, 4:3, 1:1, 9:16.
    pub crop: String,
    /// Exporter les images: one every N seconds.
    pub frame_every: u32,
    /// Redimensionner: width in pixels.
    pub width: u32,
    /// Compresser: av1 (smallest, the default) or h264 (plays everywhere).
    pub codec: String,
    /// Compresser: size aimed at per file, in MiB (0: by quality).
    pub target_mb: u32,
    pub out_dir: String,
}

#[derive(Clone)]
pub struct ConvertJob {
    pub id: String,
    pub inputs: Vec<String>,
    pub name: String,
    /// video, audio, image.
    pub category: String,
    /// A format (mp4…) or a tool (join, cut, crop, compress, frames,
    /// extract, resize).
    pub target: String,
    pub source: SourceInfo,
    /// waiting, converting, done, stopped, failed.
    pub state: String,
    pub percent: f64,
    pub out_path: Option<String>,
    pub out_size: Option<u64>,
    /// FFmpeg's own last words when it failed.
    pub error: Option<String>,
}

fn tools() -> Result<(PathBuf, PathBuf)> {
    crate::api::get::ffmpeg_tools().ok_or_else(|| anyhow!("ffmpeg_missing"))
}

fn probe(ffprobe: &Path, file: &Path) -> SourceInfo {
    let size = std::fs::metadata(file).map(|m| m.len()).unwrap_or(0);
    let Ok(parts) = crate::api::indexer::shared() else {
        return SourceInfo {
            size,
            ..SourceInfo::default()
        };
    };
    let probed = parts
        .runtime
        .block_on(library::probe::probe(ffprobe, file))
        .ok();
    let duration = probed.as_ref().and_then(|p| p.duration_secs).unwrap_or(0.0);
    SourceInfo {
        size,
        width: probed.as_ref().and_then(|p| p.width).unwrap_or(0),
        height: probed.as_ref().and_then(|p| p.height).unwrap_or(0),
        kbps: if duration > 0.0 {
            (size as f64 * 8.0 / duration / 1000.0) as u32
        } else {
            0
        },
        duration_secs: duration,
        total_secs: duration,
    }
}

/// Adds files with a format or a tool: one job per file, or one for all
/// (join). Each file is probed for its line.
pub fn converter_add(
    category: String,
    target: String,
    inputs: Vec<String>,
    options: ConvertOptions,
) -> Result<Vec<ConvertJob>> {
    let (_, ffprobe) = tools()?;
    let join = target == "join";
    // A join lasts as long as all its files.
    let total: f64 = if join {
        inputs
            .iter()
            .map(|i| probe(&ffprobe, Path::new(i)).duration_secs)
            .sum()
    } else {
        0.0
    };
    imp::add(category, target, inputs, options, |f| {
        let mut info = probe(&ffprobe, f);
        if join {
            info.total_secs = total;
        }
        info
    })
}

pub fn converter_jobs() -> Vec<ConvertJob> {
    imp::jobs()
}

/// Converts what waits; [multi]: as many at once as the resource mode
/// allows for conversions, else one.
pub fn converter_start(multi: bool) -> Result<()> {
    let (ffmpeg, _) = tools()?;
    let parallel = if multi {
        crate::api::get::get_settings()?.max_conversions as usize
    } else {
        1
    };
    let parts = crate::api::indexer::shared()?;
    imp::start(&parts.runtime, ffmpeg, parallel)
}

pub fn converter_stop() {
    imp::stop();
}

pub fn converter_remove(id: String) {
    imp::remove(&id);
}

pub fn converter_clear() {
    imp::clear();
}

#[flutter_rust_bridge::frb(sync)]
pub fn converter_running() -> bool {
    imp::running()
}

/// Job changes for the screen (one listener: the latest replaces it).
pub fn converter_events(sink: StreamSink<ConvertJob>) -> Result<()> {
    imp::set_sink(sink);
    Ok(())
}

/// Videos\Miarina\Converti, the handoff's default.
#[flutter_rust_bridge::frb(sync)]
pub fn converter_default_dir() -> String {
    let home = std::env::var("USERPROFILE").unwrap_or_default();
    Path::new(&home)
        .join("Videos")
        .join("Miarina")
        .join("Converti")
        .to_string_lossy()
        .into_owned()
}

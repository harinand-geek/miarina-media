//! ffprobe metadata and FFmpeg thumbnails. Both run as bounded child
//! processes (argument arrays, timeout, killed with their process tree).

use std::path::Path;
use std::process::Stdio;
use std::time::Duration;

use download_engine::process::{ProcessTree, configure};
use serde::Deserialize;
use storage::MediaProbe;
use tokio::io::AsyncReadExt;
use tokio::process::Command;

use crate::LibraryError;

const PROBE_TIMEOUT: Duration = Duration::from_secs(30);
const THUMBNAIL_TIMEOUT: Duration = Duration::from_secs(60);
const MAX_PROBE_OUTPUT: u64 = 4 * 1024 * 1024;

#[derive(Debug, Deserialize)]
struct ProbeOutput {
    #[serde(default)]
    streams: Vec<ProbeStream>,
    format: Option<ProbeFormat>,
}

#[derive(Debug, Deserialize)]
struct ProbeStream {
    codec_type: Option<String>,
    codec_name: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
    /// Audio: Hz, as text.
    sample_rate: Option<String>,
    /// Bits per sample of lossless codecs, as text ("24").
    bits_per_raw_sample: Option<String>,
    /// Bits per sample of PCM.
    bits_per_sample: Option<u32>,
    /// bit/s, as text.
    bit_rate: Option<String>,
    /// Cover art is a video stream flagged as attached picture.
    disposition: Option<Disposition>,
}

#[derive(Debug, Deserialize)]
struct Disposition {
    attached_pic: Option<u8>,
}

#[derive(Debug, Deserialize)]
struct ProbeFormat {
    format_name: Option<String>,
    duration: Option<String>,
    bit_rate: Option<String>,
}

/// Codecs whose bit depth is the file's own (not a decoder setting).
fn lossless(codec: &str) -> bool {
    matches!(
        codec,
        "flac" | "alac" | "ape" | "wavpack" | "tta" | "truehd" | "mlp" | "tak"
    ) || codec.starts_with("pcm_")
}

fn number(text: Option<&str>) -> Option<u64> {
    text.and_then(|t| t.trim().parse::<u64>().ok())
        .filter(|n| *n > 0)
}

/// Parses ffprobe JSON (untrusted).
pub fn parse_probe(json: &[u8]) -> Result<MediaProbe, LibraryError> {
    let output: ProbeOutput =
        serde_json::from_slice(json).map_err(|e| LibraryError::Probe(e.to_string()))?;
    let video = output.streams.iter().find(|s| {
        s.codec_type.as_deref() == Some("video")
            && s.disposition.as_ref().and_then(|d| d.attached_pic) != Some(1)
    });
    let audio = output
        .streams
        .iter()
        .find(|s| s.codec_type.as_deref() == Some("audio"));
    let format = output.format.as_ref();
    Ok(MediaProbe {
        duration_secs: format
            .and_then(|f| f.duration.as_deref())
            .and_then(|d| d.parse::<f64>().ok())
            .filter(|d| d.is_finite() && *d >= 0.0),
        width: video.and_then(|v| v.width),
        height: video.and_then(|v| v.height),
        video_codec: video.and_then(|v| v.codec_name.clone()),
        audio_codec: audio.and_then(|a| a.codec_name.clone()),
        container: format
            .and_then(|f| f.format_name.as_deref())
            .and_then(|n| n.split(',').next())
            .map(str::to_owned),
        has_video: video.is_some(),
        sample_rate: audio
            .and_then(|a| number(a.sample_rate.as_deref()))
            .filter(|r| *r <= 12_288_000)
            .map(|r| r as u32),
        bit_depth: audio
            .filter(|a| a.codec_name.as_deref().is_some_and(lossless))
            .and_then(|a| {
                number(a.bits_per_raw_sample.as_deref())
                    .or(a.bits_per_sample.filter(|b| *b > 0).map(u64::from))
            })
            .filter(|b| *b <= 64)
            .map(|b| b as u32),
        // Kbit/s; the container's rate stands in for an audio-only file.
        bit_rate: audio
            .and_then(|a| number(a.bit_rate.as_deref()))
            .or_else(|| {
                (video.is_none())
                    .then(|| number(format.and_then(|f| f.bit_rate.as_deref())))
                    .flatten()
            })
            .map(|b| ((b + 500) / 1000).min(100_000) as u32),
    })
}

/// Paths given to FFmpeg tools are always absolute, so they can never be
/// read as an option.
fn ensure_absolute(path: &Path) -> Result<(), LibraryError> {
    if path.is_absolute() {
        Ok(())
    } else {
        Err(LibraryError::Probe("relative media path".into()))
    }
}

pub async fn probe(ffprobe: &Path, media: &Path) -> Result<MediaProbe, LibraryError> {
    ensure_absolute(media)?;
    let mut command = Command::new(ffprobe);
    command
        .args([
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            "-i",
        ])
        .arg(media)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    configure(&mut command, true);
    let mut child = command
        .spawn()
        .map_err(|e| LibraryError::Probe(e.to_string()))?;
    let _tree = ProcessTree::adopt(&child).ok();
    let mut stdout = child.stdout.take().expect("piped").take(MAX_PROBE_OUTPUT);
    let mut out = Vec::new();
    let read = tokio::time::timeout(PROBE_TIMEOUT, stdout.read_to_end(&mut out)).await;
    let status = tokio::time::timeout(Duration::from_secs(5), child.wait()).await;
    match (read, status) {
        (Ok(Ok(_)), Ok(Ok(status))) if status.success() => parse_probe(&out),
        (Err(_), _) => Err(LibraryError::Probe("ffprobe timed out".into())),
        _ => Err(LibraryError::Probe(
            "ffprobe could not read the file".into(),
        )),
    }
}

/// Grabs one frame (10 % into the video, at most 30 s) as a JPEG whose
/// longest edge is at most `max_px`.
pub async fn thumbnail(
    ffmpeg: &Path,
    media: &Path,
    out: &Path,
    duration: Option<f64>,
    max_px: u32,
    threads: usize,
) -> Result<(), LibraryError> {
    let at = duration.map(|d| (d * 0.1).min(30.0)).unwrap_or(1.0);
    jpeg(ffmpeg, media, out, Some(at), max_px, threads).await
}

/// Writes a JPEG (longest edge at most `max_px`) from the frame at `at`
/// seconds of a video, or from a picture file when `at` is `None`.
pub async fn jpeg(
    ffmpeg: &Path,
    media: &Path,
    out: &Path,
    at: Option<f64>,
    max_px: u32,
    threads: usize,
) -> Result<(), LibraryError> {
    ensure_absolute(media)?;
    ensure_absolute(out)?;
    let scale =
        format!("scale='if(gt(iw,ih),min({max_px},iw),-2)':'if(gt(iw,ih),-2,min({max_px},ih))'");
    let mut command = Command::new(ffmpeg);
    command
        .args([
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-y",
            "-threads",
        ])
        .arg(threads.max(1).to_string());
    if let Some(at) = at {
        command.arg("-ss").arg(format!("{:.2}", at.max(0.0)));
    }
    command
        .arg("-i")
        .arg(media)
        .args(["-frames:v", "1", "-vf"])
        .arg(scale)
        .args(["-q:v", "4", "-f", "image2"])
        .arg(out)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    configure(&mut command, true);
    let mut child = command
        .spawn()
        .map_err(|e| LibraryError::Thumbnail(e.to_string()))?;
    let tree = ProcessTree::adopt(&child).ok();
    let status = match tokio::time::timeout(THUMBNAIL_TIMEOUT, child.wait()).await {
        Ok(status) => status.map_err(|e| LibraryError::Thumbnail(e.to_string()))?,
        Err(_) => {
            drop(tree);
            let _ = child.kill().await;
            return Err(LibraryError::Thumbnail("ffmpeg timed out".into()));
        }
    };
    if status.success() && out.is_file() {
        Ok(())
    } else {
        let _ = std::fs::remove_file(out);
        Err(LibraryError::Thumbnail(
            "no frame could be extracted".into(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn video_files_are_described() {
        let json = br#"{"streams":[
            {"codec_type":"video","codec_name":"h264","width":1920,"height":800},
            {"codec_type":"audio","codec_name":"aac"}],
            "format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"734.400000"}}"#;
        let p = parse_probe(json).unwrap();
        assert_eq!(p.duration_secs, Some(734.4));
        assert_eq!((p.width, p.height), (Some(1920), Some(800)));
        assert_eq!(p.video_codec.as_deref(), Some("h264"));
        assert_eq!(p.audio_codec.as_deref(), Some("aac"));
        assert_eq!(p.container.as_deref(), Some("mov"));
        assert!(p.has_video);
    }

    #[test]
    fn cover_art_does_not_make_audio_a_video() {
        let json = br#"{"streams":[
            {"codec_type":"audio","codec_name":"mp3"},
            {"codec_type":"video","codec_name":"mjpeg","width":500,"height":500,"disposition":{"attached_pic":1}}],
            "format":{"format_name":"mp3","duration":"302.1"}}"#;
        let p = parse_probe(json).unwrap();
        assert!(!p.has_video);
        assert_eq!(p.width, None);
    }

    #[test]
    fn audio_quality_is_read() {
        // FLAC 24/96: depth from the lossless codec.
        let flac = br#"{"streams":[{"codec_type":"audio","codec_name":"flac",
            "sample_rate":"96000","bits_per_raw_sample":"24","bits_per_sample":0}],
            "format":{"format_name":"flac","bit_rate":"2870000"}}"#;
        let p = parse_probe(flac).unwrap();
        assert_eq!((p.sample_rate, p.bit_depth), (Some(96_000), Some(24)));
        // MP3 320: no depth for a lossy codec, rate in kbit/s.
        let mp3 = br#"{"streams":[{"codec_type":"audio","codec_name":"mp3",
            "sample_rate":"44100","bits_per_raw_sample":"16","bit_rate":"320000"}],
            "format":{"format_name":"mp3"}}"#;
        let p = parse_probe(mp3).unwrap();
        assert_eq!((p.bit_depth, p.bit_rate), (None, Some(320)));
        // WAV 16/44: PCM depth; the container's rate when the stream has none.
        let wav = br#"{"streams":[{"codec_type":"audio","codec_name":"pcm_s16le",
            "sample_rate":"44100","bits_per_sample":16}],
            "format":{"format_name":"wav","bit_rate":"1411200"}}"#;
        let p = parse_probe(wav).unwrap();
        assert_eq!(
            (p.sample_rate, p.bit_depth, p.bit_rate),
            (Some(44_100), Some(16), Some(1411))
        );
        // Untrusted values out of range are dropped.
        let odd = br#"{"streams":[{"codec_type":"audio","codec_name":"flac",
            "sample_rate":"-5","bits_per_raw_sample":"999"}]}"#;
        let p = parse_probe(odd).unwrap();
        assert_eq!((p.sample_rate, p.bit_depth), (None, None));
    }

    #[test]
    fn garbage_is_rejected_and_bad_durations_ignored() {
        assert!(parse_probe(b"not json").is_err());
        let p = parse_probe(br#"{"format":{"duration":"N/A"}}"#).unwrap();
        assert_eq!(p.duration_secs, None);
        assert!(!p.has_video);
    }
}

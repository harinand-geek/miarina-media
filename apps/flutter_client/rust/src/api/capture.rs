//! Capture d'écran (Outils PC): the folder and the JPG / WebP encoding of a
//! screen picture. The picture itself is taken by the Windows runner and
//! cropped by Flutter (PNG); FFmpeg (the app's own) makes the lighter
//! formats. Windows only.

use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{Result, anyhow, bail};

/// Pictures\Miarina\Captures, the handoff's default.
#[flutter_rust_bridge::frb(sync)]
pub fn capture_default_dir() -> String {
    let home = std::env::var("USERPROFILE").unwrap_or_default();
    Path::new(&home)
        .join("Pictures")
        .join("Miarina")
        .join("Captures")
        .to_string_lossy()
        .into_owned()
}

/// FFmpeg's arguments to turn the PNG `input` into `output` (`format`: jpg
/// or webp). Pure, for the tests.
#[flutter_rust_bridge::frb(ignore)]
pub fn encode_args(input: &Path, output: &Path, format: &str) -> Result<Vec<String>> {
    let codec: &[&str] = match format {
        // Close to the source: a screen has sharp text.
        "jpg" => &["-c:v", "mjpeg", "-q:v", "2", "-pix_fmt", "yuvj444p"],
        "webp" => &["-c:v", "libwebp", "-quality", "90", "-lossless", "0"],
        _ => bail!("format {format} not supported"),
    };
    let mut args: Vec<String> = ["-hide_banner", "-loglevel", "error", "-y", "-i"]
        .iter()
        .map(|s| (*s).to_owned())
        .collect();
    args.push(input.to_string_lossy().into_owned());
    args.extend(codec.iter().map(|s| (*s).to_owned()));
    args.extend(["-frames:v", "1", "-f"].iter().map(|s| (*s).to_owned()));
    args.push(if format == "jpg" { "mjpeg" } else { "webp" }.to_owned());
    args.push(output.to_string_lossy().into_owned());
    Ok(args)
}

/// Encodes the PNG `input` as `format` (jpg, webp) into `output`: written
/// next to it under a temporary name, renamed when complete. 30 s at most.
pub fn capture_encode(input: String, output: String, format: String) -> Result<()> {
    let (ffmpeg, _) = crate::api::get::ffmpeg_tools().ok_or_else(|| anyhow!("ffmpeg_missing"))?;
    let runtime = crate::api::indexer::shared()?.runtime;
    runtime.block_on(encode(ffmpeg, input, PathBuf::from(output), format))
}

async fn encode(ffmpeg: PathBuf, input: String, output: PathBuf, format: String) -> Result<()> {
    let part = output.with_extension(format!("part.{format}"));
    let args = encode_args(Path::new(&input), &part, &format)?;
    let mut command = tokio::process::Command::new(ffmpeg);
    command
        .args(&args)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped());
    download_engine::process::configure(&mut command, false);
    let done = tokio::time::timeout(Duration::from_secs(30), command.output()).await;
    let ok = matches!(&done, Ok(Ok(out)) if out.status.success());
    if !ok {
        let _ = tokio::fs::remove_file(&part).await;
        bail!("encode_failed");
    }
    tokio::fs::rename(&part, &output).await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn args_per_format() {
        let jpg = encode_args(Path::new("in.png"), Path::new("out.part.jpg"), "jpg").unwrap();
        assert!(jpg.windows(2).any(|w| w == ["-c:v", "mjpeg"]));
        assert_eq!(jpg.last().unwrap(), "out.part.jpg");
        assert!(jpg.windows(2).any(|w| w == ["-f", "mjpeg"]));
        let webp = encode_args(Path::new("in.png"), Path::new("o.webp"), "webp").unwrap();
        assert!(webp.windows(2).any(|w| w == ["-c:v", "libwebp"]));
        assert!(encode_args(Path::new("a"), Path::new("b"), "gif").is_err());
    }

    #[test]
    fn folder_is_pictures() {
        assert!(capture_default_dir().ends_with(r"Pictures\Miarina\Captures") || !cfg!(windows));
    }
}

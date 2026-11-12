//! Prepares yt-dlp, FFmpeg, QuickJS-NG and libVLC for the Windows installer.
//!
//! `cargo run -p download-engine --example fetch_tools -- <dir>` downloads
//! the pinned archives, checks their size and SHA-256, and unpacks them into
//! `<dir>/<id>/<sha prefix>/`: the layout the app looks for in its install
//! folder. Already prepared components are not downloaded again.
//!
//! libVLC's module cache (`plugins/plugins.dat`) is generated here with the
//! official `vlc-cache-gen.exe` of the same archive, which is then removed:
//! without a valid cache libVLC scans every module at start (~1.6 s
//! measured, decision 0005).

use std::path::Path;

use download_engine::components::{ALL, Components, LIBVLC};
use tokio_util::sync::CancellationToken;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let Some(dir) = std::env::args_os().nth(1) else {
        eprintln!("usage: fetch_tools <output dir>");
        std::process::exit(2);
    };
    let dir = std::path::PathBuf::from(dir);
    let components = Components::new(dir.clone()).expect("HTTP client");
    let cancel = CancellationToken::new();
    for spec in ALL.iter().chain(std::iter::once(&LIBVLC)) {
        let progress = |done: u64, total: u64| {
            eprint!("\r{} {:>3}%", spec.name, done * 100 / total.max(1));
        };
        match components.install(spec, &progress, &cancel).await {
            Ok(path) => eprintln!("\r{} {} ready: {}", spec.name, spec.version, path.display()),
            Err(err) => {
                eprintln!("\r{} failed: {err}", spec.name);
                std::process::exit(1);
            }
        }
    }
    if let Some(libvlc) = components.libvlc_dir() {
        prepare_libvlc_cache(&libvlc);
    }
    // Only the unpacked components go into the installer.
    let _ = std::fs::remove_dir_all(dir.join(".staging"));
}

/// A cache listing the modules is tens of kilobytes; an empty one (a few
/// bytes) makes libVLC believe it has no module and refuse to start.
const MIN_CACHE_BYTES: u64 = 10_000;

fn cache_ok(plugins: &Path) -> bool {
    std::fs::metadata(plugins.join("plugins.dat")).is_ok_and(|m| m.len() >= MIN_CACHE_BYTES)
}

fn prepare_libvlc_cache(dir: &Path) {
    // vlc-cache-gen needs an absolute path (a relative one yields an empty
    // cache).
    let dir = std::path::absolute(dir).unwrap_or_else(|_| dir.to_path_buf());
    let generator = dir.join("vlc-cache-gen.exe");
    let plugins = dir.join("plugins");
    if !cache_ok(&plugins) {
        if !generator.is_file() {
            eprintln!("libVLC: vlc-cache-gen.exe missing, module cache not generated");
            std::process::exit(1);
        }
        let status = std::process::Command::new(&generator)
            .arg(&plugins)
            .status();
        match status {
            Ok(s) if s.success() && cache_ok(&plugins) => {
                eprintln!("libVLC module cache generated");
            }
            other => {
                eprintln!("libVLC module cache failed: {other:?}");
                std::process::exit(1);
            }
        }
    }
    // Not needed at run time.
    let _ = std::fs::remove_file(generator);
}

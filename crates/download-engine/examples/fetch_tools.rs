//! Prepares yt-dlp and FFmpeg for the Windows installer.
//!
//! `cargo run -p download-engine --example fetch_tools -- <dir>` downloads
//! the pinned archives, checks their size and SHA-256, and unpacks them into
//! `<dir>/<id>/<sha prefix>/`: the layout the app looks for in its install
//! folder. Already prepared components are not downloaded again.

use download_engine::components::{ALL, Components};
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
    for spec in ALL {
        let progress = |done: u64, total: u64| {
            eprint!("\r{} {:>3}%", spec.name, done * 100 / total.max(1));
        };
        match components.install(&spec, &progress, &cancel).await {
            Ok(path) => eprintln!("\r{} {} ready: {}", spec.name, spec.version, path.display()),
            Err(err) => {
                eprintln!("\r{} failed: {err}", spec.name);
                std::process::exit(1);
            }
        }
    }
    // Only the unpacked components go into the installer.
    let _ = std::fs::remove_dir_all(dir.join(".staging"));
}

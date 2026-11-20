//! Prepares yt-dlp, FFmpeg, QuickJS-NG and libVLC for the Windows installer.
//!
//! `cargo run -p download-engine --example fetch_tools -- <dir>` downloads
//! the pinned archives, checks their size and SHA-256, and unpacks them into
//! `<dir>/<id>/<sha prefix>/`: the layout the app looks for in its install
//! folder. Already prepared components are not downloaded again.
//!
//! `... -- <dir> --flutter` prepares the Flutter app (plan R2): the same
//! tools without libVLC (its player is libmpv), plus the pinned libmpv
//! build in `<dir>/libmpv/<sha prefix>/libmpv-2.dll`, which replaces the
//! older one media_kit downloads.
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
    let flutter = std::env::args().any(|a| a == "--flutter");
    let components = Components::new(dir.clone()).expect("HTTP client");
    let cancel = CancellationToken::new();
    let libvlc = (!flutter).then_some(&LIBVLC);
    for spec in ALL.iter().chain(libvlc) {
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
    if flutter {
        if let Err(err) = libmpv::prepare(&dir).await {
            eprintln!("libmpv failed: {err}");
            std::process::exit(1);
        }
    } else if let Some(libvlc) = components.libvlc_dir() {
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

/// libmpv for the Flutter player (media_kit), from the official build of
/// the mpv Windows builds project, pinned like the other tools.
mod libmpv {
    use std::io::Write;
    use std::path::Path;

    use sha2::{Digest, Sha256};

    pub const VERSION: &str = "20261111-git-bcde6b93cc";
    const URL: &str = "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/\
20261111/mpv-dev-x86_64-20261111-git-bcde6b93cc.7z";
    /// Published by GitHub for the release asset.
    pub const SHA256: &str = "273c079b11ea5575822f972756f4c9a71149a5c10130353abeb8586738938452";
    const SIZE: u64 = 31_776_374;
    const DLL: &str = "libmpv-2.dll";

    pub async fn prepare(dir: &Path) -> Result<(), String> {
        let out = dir.join("libmpv").join(&SHA256[..12]);
        if out.join(DLL).is_file() {
            eprintln!("libmpv {VERSION} ready: {}", out.display());
            return Ok(());
        }
        let staging = dir.join(".staging");
        std::fs::create_dir_all(&staging).map_err(|e| e.to_string())?;
        let archive = staging.join("libmpv.7z");
        // Streamed to disk, size bounded, digest checked before use.
        let response = reqwest::get(URL).await.map_err(|e| e.to_string())?;
        if !response.status().is_success() {
            return Err(format!("HTTP {}", response.status()));
        }
        let mut file = std::fs::File::create(&archive).map_err(|e| e.to_string())?;
        let mut hash = Sha256::new();
        let mut done = 0u64;
        let mut response = response;
        while let Some(chunk) = response.chunk().await.map_err(|e| e.to_string())? {
            done += chunk.len() as u64;
            if done > SIZE {
                return Err("archive larger than pinned".into());
            }
            hash.update(&chunk);
            file.write_all(&chunk).map_err(|e| e.to_string())?;
            eprint!(
                "
libmpv {:>3}%",
                done * 100 / SIZE
            );
        }
        drop(file);
        let digest = hash
            .finalize()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>();
        if done != SIZE || digest != SHA256 {
            let _ = std::fs::remove_file(&archive);
            return Err(format!("size or SHA-256 mismatch ({done} bytes, {digest})"));
        }
        let unpacked = staging.join("libmpv");
        sevenz_rust2::decompress_file(&archive, &unpacked).map_err(|e| e.to_string())?;
        std::fs::create_dir_all(&out).map_err(|e| e.to_string())?;
        std::fs::copy(unpacked.join(DLL), out.join(DLL)).map_err(|e| e.to_string())?;
        let _ = std::fs::remove_dir_all(&unpacked);
        let _ = std::fs::remove_file(&archive);
        eprintln!("\rlibmpv {VERSION} ready: {}", out.display());
        Ok(())
    }
}

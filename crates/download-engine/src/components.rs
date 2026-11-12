//! External tools (yt-dlp, FFmpeg): shipped with the Windows installer
//! (decision 0002), downloaded on first use only when missing (decision D3).
//!
//! Versions and SHA-256 digests are pinned in the source: an archive whose
//! size or digest differs is rejected, both when preparing the installer and
//! when downloading. Nothing is executed before it has been verified.
//! Updates ship with new application versions.

use std::path::{Path, PathBuf};

use reqwest::Client;
use serde::Serialize;
use sha2::{Digest, Sha256};
use tokio::io::AsyncWriteExt;
use tokio_util::sync::CancellationToken;

use crate::EngineError;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ComponentId {
    YtDlp,
    Ffmpeg,
    /// JavaScript runtime yt-dlp needs for YouTube's challenges.
    #[serde(rename = "quickjs")]
    QuickJs,
    /// Video engine of the Windows player (decision 0005).
    #[serde(rename = "libvlc")]
    LibVlc,
}

#[derive(Debug, Clone, Copy)]
enum Archive {
    /// The download is the executable itself.
    Executable { file_name: &'static str },
    /// A zip; files whose name matches are taken from its `bin/` folder.
    Zip { wanted: fn(&str) -> bool },
    /// A zip whose files under `prefix` keep their relative folders when
    /// `keep` accepts that relative path (`plugins/codec/x.dll`).
    Tree {
        prefix: &'static str,
        keep: fn(&str) -> bool,
    },
}

#[derive(Debug, Clone, Copy)]
pub struct ComponentSpec {
    pub id: ComponentId,
    pub name: &'static str,
    pub version: &'static str,
    pub license: &'static str,
    url: &'static str,
    sha256: &'static str,
    pub download_bytes: u64,
    archive: Archive,
    /// Executable checked to decide whether the component is installed.
    main_file: &'static str,
}

pub const YTDLP: ComponentSpec = ComponentSpec {
    id: ComponentId::YtDlp,
    name: "yt-dlp",
    version: "2026.08.19",
    license: "Unlicense (bundled Python runtime under its own licenses)",
    url: "https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp.exe",
    sha256: "66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a",
    download_bytes: 17_840_399,
    archive: Archive::Executable {
        file_name: "yt-dlp.exe",
    },
    main_file: "yt-dlp.exe",
};

pub const FFMPEG: ComponentSpec = ComponentSpec {
    id: ComponentId::Ffmpeg,
    name: "FFmpeg",
    version: "n8.1.2-50-g1a748fe2cd (LGPL, shared)",
    // The build is configured with --enable-version3 (no --enable-gpl).
    license: "LGPL-3.0-or-later",
    url: "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-08-31-13-27/ffmpeg-n8.1.2-50-g1a748fe2cd-win64-lgpl-shared-8.1.zip",
    sha256: "e9712ffbdb03ef71bbab660c75b835bfe698ef6fad0247c76d8d394a39a3db63",
    download_bytes: 70_835_150,
    archive: Archive::Zip {
        wanted: |name| {
            let lower = name.to_ascii_lowercase();
            lower == "ffmpeg.exe" || lower == "ffprobe.exe" || lower.ends_with(".dll")
        },
    },
    main_file: "ffmpeg.exe",
};

pub const QUICKJS: ComponentSpec = ComponentSpec {
    id: ComponentId::QuickJs,
    name: "QuickJS-NG",
    version: "0.17.0",
    license: "MIT",
    url: "https://github.com/quickjs-ng/quickjs/releases/download/v0.17.0/qjs-windows-x86_64.exe",
    sha256: "2aeabf0092c3262d6b2609824418f7dd7ed1f1df939f73b2b15645230cac0d77",
    download_bytes: 2_151_363,
    archive: Archive::Executable {
        file_name: "qjs.exe",
    },
    main_file: "qjs.exe",
};

pub const ALL: [ComponentSpec; 3] = [YTDLP, FFMPEG, QUICKJS];

/// libVLC 3 for the Windows player (decision 0005): shipped with the
/// installer only (never downloaded on demand: the WebView2 player is the
/// fallback). Only what local playback needs is kept.
pub const LIBVLC: ComponentSpec = ComponentSpec {
    id: ComponentId::LibVlc,
    name: "libVLC",
    version: "3.0.24",
    license: "LGPL-2.1-or-later (libvlc, libvlccore); modules under their own licenses (COPYING.txt)",
    url: "https://download.videolan.org/pub/videolan/vlc/3.0.24/win64/vlc-3.0.24-win64.zip",
    sha256: "fcf30850371ad10c9373cc4f0f4501e7dee49e3e9ae9f20c72fb2661a1ca6323",
    download_bytes: 82_765_861,
    archive: Archive::Tree {
        prefix: "vlc-3.0.24/",
        keep: libvlc_keep,
    },
    main_file: "libvlc.dll",
};

/// Module folders local playback does not use (interfaces, streaming out,
/// muxers, scripting, visualizations, network discovery, video walls).
const LIBVLC_DROPPED_FOLDERS: [&str; 9] = [
    "gui",
    "access_output",
    "stream_out",
    "mux",
    "lua",
    "visualization",
    "services_discovery",
    "control",
    "video_splitter",
];
/// Encoders and capture / disc / broadcast inputs, by file name.
const LIBVLC_DROPPED_NAMES: [&str; 21] = [
    "x264", "x265", "shine", "twolame", "qsv", "vpx_enc", "srt", "rist", "vnc", "dcp", "dvb",
    "sftp", "smb", "nfs", "rdp", "dshow", "screen", "bluray", "dvdnav", "dvdread", "decklink",
];

fn libvlc_keep(rel: &str) -> bool {
    match rel.split('/').collect::<Vec<_>>().as_slice() {
        [file] => matches!(
            *file,
            "libvlc.dll" | "libvlccore.dll" | "vlc-cache-gen.exe" | "COPYING.txt" | "AUTHORS.txt"
        ),
        ["plugins", folder, file] => {
            let lower = file.to_ascii_lowercase();
            lower.ends_with(".dll")
                && !LIBVLC_DROPPED_FOLDERS.contains(folder)
                && !LIBVLC_DROPPED_NAMES.iter().any(|n| lower.contains(n))
        }
        _ => false,
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ComponentStatus {
    pub id: ComponentId,
    pub name: &'static str,
    pub version: String,
    pub license: &'static str,
    pub download_bytes: u64,
    pub installed: bool,
    /// Shipped with the application rather than downloaded.
    pub bundled: bool,
}

/// Where components live: `<root>/<id>/<pinned sha prefix>/…`.
///
/// The Windows installer ships them in a read-only `bundled` root with the
/// same layout (see `examples/fetch_tools.rs`); it is checked first, and the
/// writable `root` only receives downloads when they are missing.
#[derive(Clone)]
pub struct Components {
    root: PathBuf,
    bundled: Option<PathBuf>,
    client: Client,
}

impl Components {
    pub fn new(root: PathBuf) -> Result<Self, EngineError> {
        let client = Client::builder()
            .user_agent(concat!("MiarinaMedia/", env!("CARGO_PKG_VERSION")))
            .connect_timeout(std::time::Duration::from_secs(15))
            .read_timeout(std::time::Duration::from_secs(60))
            .build()
            .map_err(EngineError::network)?;
        Ok(Self {
            root,
            bundled: None,
            client,
        })
    }

    /// Also looks for components shipped with the application.
    pub fn with_bundled(mut self, bundled: PathBuf) -> Self {
        self.bundled = Some(bundled);
        self
    }

    fn dir_in(root: &Path, spec: &ComponentSpec) -> PathBuf {
        let id = match spec.id {
            ComponentId::YtDlp => "yt-dlp",
            ComponentId::Ffmpeg => "ffmpeg",
            ComponentId::QuickJs => "quickjs",
            ComponentId::LibVlc => "libvlc",
        };
        root.join(id).join(&spec.sha256[..16])
    }

    fn dir(&self, spec: &ComponentSpec) -> PathBuf {
        Self::dir_in(&self.root, spec)
    }

    /// Path of the main executable if the pinned version is shipped with the
    /// application or installed.
    pub fn path(&self, spec: &ComponentSpec) -> Option<PathBuf> {
        self.bundled
            .iter()
            .chain(std::iter::once(&self.root))
            .map(|root| Self::dir_in(root, spec).join(spec.main_file))
            .find(|path| path.is_file())
    }

    /// yt-dlp to run: a verified update newer than the pinned version
    /// (`ytdlp::update`), else the pinned one.
    pub fn ytdlp(&self) -> Option<PathBuf> {
        self.updated_ytdlp()
            .map(|(_, path)| path)
            .or_else(|| self.path(&YTDLP))
    }

    /// Writable folder holding downloaded components.
    pub(crate) fn root(&self) -> &Path {
        &self.root
    }

    pub(crate) fn client(&self) -> &Client {
        &self.client
    }

    /// JavaScript runtime for yt-dlp (`--js-runtimes quickjs:<path>`).
    pub fn quickjs(&self) -> Option<PathBuf> {
        self.path(&QUICKJS)
    }

    /// Directory to pass as `--ffmpeg-location`.
    pub fn ffmpeg_dir(&self) -> Option<PathBuf> {
        self.path(&FFMPEG)
            .and_then(|p| p.parent().map(Path::to_path_buf))
    }

    /// Folder holding `libvlc.dll`, `libvlccore.dll` and `plugins/`, when
    /// shipped with the application.
    pub fn libvlc_dir(&self) -> Option<PathBuf> {
        self.path(&LIBVLC)
            .and_then(|p| p.parent().map(Path::to_path_buf))
    }

    /// yt-dlp cache (kept inside the app data directory).
    pub fn cache_dir(&self) -> PathBuf {
        self.root.join("cache")
    }

    pub fn status(&self) -> Vec<ComponentStatus> {
        ALL.iter()
            .map(|spec| {
                let path = self.path(spec);
                ComponentStatus {
                    id: spec.id,
                    name: spec.name,
                    version: match spec.id {
                        ComponentId::YtDlp => self.ytdlp_version(),
                        _ => spec.version.to_owned(),
                    },
                    license: spec.license,
                    download_bytes: spec.download_bytes,
                    installed: path.is_some(),
                    bundled: matches!((&path, &self.bundled), (Some(p), Some(b)) if p.starts_with(b)),
                }
            })
            .collect()
    }

    /// Downloads, verifies and installs a component. `progress` receives
    /// (downloaded, total) bytes.
    pub async fn install(
        &self,
        spec: &ComponentSpec,
        progress: &(dyn Fn(u64, u64) + Send + Sync),
        cancel: &CancellationToken,
    ) -> Result<PathBuf, EngineError> {
        if let Some(path) = self.path(spec) {
            return Ok(path);
        }
        let staging = self.root.join(".staging");
        tokio::fs::create_dir_all(&staging)
            .await
            .map_err(EngineError::from_io)?;
        let archive = staging.join(format!("{}.download", &spec.sha256[..16]));
        let result = self.fetch_verified(spec, &archive, progress, cancel).await;
        if let Err(err) = result {
            let _ = tokio::fs::remove_file(&archive).await;
            return Err(err);
        }

        let unpacked = staging.join(&spec.sha256[..16]);
        let _ = tokio::fs::remove_dir_all(&unpacked).await;
        tokio::fs::create_dir_all(&unpacked)
            .await
            .map_err(EngineError::from_io)?;
        let spec_copy = *spec;
        let (archive_c, unpacked_c) = (archive.clone(), unpacked.clone());
        tokio::task::spawn_blocking(move || unpack(&spec_copy, &archive_c, &unpacked_c))
            .await
            .map_err(|e| EngineError::Io {
                message: e.to_string(),
            })??;
        let _ = tokio::fs::remove_file(&archive).await;

        // Atomic publish: the component appears complete or not at all.
        let target = self.dir(spec);
        if let Some(parent) = target.parent() {
            tokio::fs::create_dir_all(parent)
                .await
                .map_err(EngineError::from_io)?;
        }
        let _ = tokio::fs::remove_dir_all(&target).await;
        tokio::fs::rename(&unpacked, &target)
            .await
            .map_err(EngineError::from_io)?;
        self.path(spec).ok_or_else(|| EngineError::Io {
            message: format!("{} was not found in the archive", spec.main_file),
        })
    }

    async fn fetch_verified(
        &self,
        spec: &ComponentSpec,
        archive: &Path,
        progress: &(dyn Fn(u64, u64) + Send + Sync),
        cancel: &CancellationToken,
    ) -> Result<(), EngineError> {
        let mut response = self
            .client
            .get(spec.url)
            .send()
            .await
            .map_err(EngineError::from_reqwest)?;
        if !response.status().is_success() {
            return Err(EngineError::Http {
                status: response.status().as_u16(),
            });
        }
        crate::fsops::ensure_space(&self.root, spec.download_bytes * 3)?;
        let mut file = tokio::fs::File::create(archive)
            .await
            .map_err(EngineError::from_io)?;
        let mut hasher = Sha256::new();
        let mut downloaded = 0u64;
        let mut last_report = std::time::Instant::now();
        loop {
            let chunk = tokio::select! {
                _ = cancel.cancelled() => return Err(EngineError::Canceled),
                c = response.chunk() => c.map_err(EngineError::from_reqwest)?,
            };
            let Some(chunk) = chunk else { break };
            downloaded += chunk.len() as u64;
            if downloaded > spec.download_bytes {
                return Err(integrity_error(spec));
            }
            hasher.update(&chunk);
            file.write_all(&chunk).await.map_err(EngineError::from_io)?;
            if last_report.elapsed().as_millis() >= 500 {
                progress(downloaded, spec.download_bytes);
                last_report = std::time::Instant::now();
            }
        }
        file.flush().await.map_err(EngineError::from_io)?;
        file.sync_all().await.map_err(EngineError::from_io)?;
        progress(downloaded, spec.download_bytes);
        let digest = hex(&hasher.finalize());
        if downloaded != spec.download_bytes || digest != spec.sha256 {
            return Err(integrity_error(spec));
        }
        Ok(())
    }
}

fn integrity_error(spec: &ComponentSpec) -> EngineError {
    EngineError::Unsupported {
        reason: format!("{} failed its integrity check and was discarded", spec.name),
    }
}

pub(crate) fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Extracts only the expected files, flattening paths: archive entry names
/// never decide where a file is written (zip-slip safe).
fn unpack(spec: &ComponentSpec, archive: &Path, dest: &Path) -> Result<(), EngineError> {
    match spec.archive {
        Archive::Executable { file_name } => {
            std::fs::copy(archive, dest.join(file_name)).map_err(EngineError::from_io)?;
            Ok(())
        }
        Archive::Zip { wanted } => {
            let file = std::fs::File::open(archive).map_err(EngineError::from_io)?;
            let mut zip = zip::ZipArchive::new(file).map_err(|e| EngineError::Io {
                message: e.to_string(),
            })?;
            for i in 0..zip.len() {
                let mut entry = zip.by_index(i).map_err(|e| EngineError::Io {
                    message: e.to_string(),
                })?;
                if !entry.is_file() {
                    continue;
                }
                let name = entry.name().replace('\\', "/");
                let mut parts = name.rsplit('/');
                let (Some(file_name), Some(parent)) = (parts.next(), parts.next()) else {
                    continue;
                };
                if parent != "bin" || !wanted(file_name) || file_name.contains("..") {
                    continue;
                }
                let mut out =
                    std::fs::File::create(dest.join(file_name)).map_err(EngineError::from_io)?;
                std::io::copy(&mut entry, &mut out).map_err(EngineError::from_io)?;
            }
            Ok(())
        }
        Archive::Tree { prefix, keep } => {
            let file = std::fs::File::open(archive).map_err(EngineError::from_io)?;
            let mut zip = zip::ZipArchive::new(file).map_err(|e| EngineError::Io {
                message: e.to_string(),
            })?;
            for i in 0..zip.len() {
                let mut entry = zip.by_index(i).map_err(|e| EngineError::Io {
                    message: e.to_string(),
                })?;
                if !entry.is_file() {
                    continue;
                }
                let name = entry.name().replace('\\', "/");
                let Some(rel) = name.strip_prefix(prefix) else {
                    continue;
                };
                // Only plain relative names: never `..`, roots or drives.
                let safe = !rel.is_empty()
                    && rel.split('/').all(|part| {
                        !part.is_empty() && part != "." && part != ".." && !part.contains(':')
                    });
                if !safe || !keep(rel) {
                    continue;
                }
                let target = rel
                    .split('/')
                    .fold(dest.to_path_buf(), |p, part| p.join(part));
                if let Some(parent) = target.parent() {
                    std::fs::create_dir_all(parent).map_err(EngineError::from_io)?;
                }
                let mut out = std::fs::File::create(&target).map_err(EngineError::from_io)?;
                std::io::copy(&mut entry, &mut out).map_err(EngineError::from_io)?;
            }
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn hex_encoding() {
        assert_eq!(hex(&[0x00, 0xab, 0xff]), "00abff");
    }

    #[test]
    fn libvlc_keeps_playback_modules_only() {
        assert!(libvlc_keep("libvlc.dll"));
        assert!(libvlc_keep("COPYING.txt"));
        assert!(libvlc_keep("plugins/codec/libavcodec_plugin.dll"));
        assert!(libvlc_keep("plugins/video_output/libdirect3d11_plugin.dll"));
        assert!(!libvlc_keep("vlc.exe"));
        assert!(!libvlc_keep("plugins/gui/libqt_plugin.dll"));
        assert!(!libvlc_keep("plugins/codec/libx265_plugin.dll"));
        assert!(!libvlc_keep("plugins/access/libaccess_srt_plugin.dll"));
        assert!(!libvlc_keep("plugins/codec/sub/x.dll"));
        assert!(!libvlc_keep("lua/intf/http.lua"));
        assert_eq!(LIBVLC.sha256.len(), 64);
        assert!(LIBVLC.url.starts_with("https://download.videolan.org/"));
    }

    #[test]
    fn tree_archives_keep_folders_and_refuse_escapes() {
        let dir = tempfile::tempdir().unwrap();
        let archive = dir.path().join("a.zip");
        {
            let mut zip = zip::ZipWriter::new(std::fs::File::create(&archive).unwrap());
            let opts = zip::write::SimpleFileOptions::default();
            for (name, body) in [
                ("vlc-3.0.24/libvlc.dll", "dll"),
                ("vlc-3.0.24/plugins/codec/libavcodec_plugin.dll", "codec"),
                ("vlc-3.0.24/plugins/gui/libqt_plugin.dll", "qt"),
                ("vlc-3.0.24/plugins/../../evil.dll", "evil"),
                ("other/libvlc.dll", "other"),
            ] {
                zip.start_file(name, opts).unwrap();
                zip.write_all(body.as_bytes()).unwrap();
            }
            zip.finish().unwrap();
        }
        let out = dir.path().join("out");
        std::fs::create_dir_all(&out).unwrap();
        unpack(&LIBVLC, &archive, &out).unwrap();
        assert_eq!(
            std::fs::read_to_string(out.join("libvlc.dll")).unwrap(),
            "dll"
        );
        assert!(out.join("plugins/codec/libavcodec_plugin.dll").is_file());
        assert!(!out.join("plugins/gui").exists());
        assert!(!dir.path().join("evil.dll").exists());
    }

    #[test]
    fn pinned_digests_are_well_formed() {
        for spec in ALL {
            assert_eq!(spec.sha256.len(), 64);
            assert!(
                spec.sha256
                    .chars()
                    .all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
            );
            assert!(spec.url.starts_with("https://github.com/"));
        }
    }

    #[test]
    fn unpack_takes_only_bin_files_and_ignores_traversal() {
        let dir = tempfile::tempdir().unwrap();
        let archive = dir.path().join("a.zip");
        {
            let file = std::fs::File::create(&archive).unwrap();
            let mut zip = zip::ZipWriter::new(file);
            let opts = zip::write::SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Stored);
            for (name, data) in [
                ("ffmpeg-x/bin/ffmpeg.exe", "exe"),
                ("ffmpeg-x/bin/avcodec-62.dll", "dll"),
                ("ffmpeg-x/bin/ffplay.exe", "player"),
                ("ffmpeg-x/doc/readme.txt", "doc"),
                ("../../evil/bin/ffprobe.exe", "evil"),
            ] {
                zip.start_file(name, opts).unwrap();
                zip.write_all(data.as_bytes()).unwrap();
            }
            zip.finish().unwrap();
        }
        let out = dir.path().join("out");
        std::fs::create_dir_all(&out).unwrap();
        unpack(&FFMPEG, &archive, &out).unwrap();

        let mut names: Vec<_> = std::fs::read_dir(&out)
            .unwrap()
            .map(|e| e.unwrap().file_name().into_string().unwrap())
            .collect();
        names.sort();
        // The traversal entry is flattened into `out`, never written outside it.
        assert_eq!(names, ["avcodec-62.dll", "ffmpeg.exe", "ffprobe.exe"]);
        assert!(!dir.path().join("evil").exists());
    }

    #[test]
    fn missing_components_are_reported() {
        let dir = tempfile::tempdir().unwrap();
        let components = Components::new(dir.path().to_path_buf()).unwrap();
        assert!(components.ytdlp().is_none());
        assert!(components.status().iter().all(|s| !s.installed));
    }

    #[test]
    fn bundled_components_are_preferred() {
        let dir = tempfile::tempdir().unwrap();
        let bundled = dir.path().join("bundled");
        let shipped = Components::dir_in(&bundled, &YTDLP);
        std::fs::create_dir_all(&shipped).unwrap();
        std::fs::write(shipped.join("yt-dlp.exe"), "exe").unwrap();
        // An older version left in the bundle is ignored.
        let stale = bundled.join("ffmpeg").join("0000000000000000");
        std::fs::create_dir_all(&stale).unwrap();
        std::fs::write(stale.join("ffmpeg.exe"), "old").unwrap();

        let components = Components::new(dir.path().join("data"))
            .unwrap()
            .with_bundled(bundled);
        assert_eq!(components.ytdlp(), Some(shipped.join("yt-dlp.exe")));
        assert!(components.ffmpeg_dir().is_none());
        let status = components.status();
        assert!(status[0].installed && status[0].bundled);
        assert!(!status[1].installed && !status[1].bundled);
    }
}

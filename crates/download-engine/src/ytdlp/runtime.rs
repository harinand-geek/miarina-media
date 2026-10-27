//! APK-owned runtime paths, supplied only by the native Android plugin.
//! The frontend never chooses an executable or its environment.
use std::path::PathBuf;

use serde::Deserialize;
use tokio::process::Command;

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AndroidRuntime {
    pub python: PathBuf,
    pub script: PathBuf,
    pub ffmpeg: PathBuf,
    pub quickjs: PathBuf,
    pub python_home: PathBuf,
    pub library_path: String,
    pub certificates: PathBuf,
    pub temp: PathBuf,
    pub bin: PathBuf,
}

impl AndroidRuntime {
    pub fn validate(&self) -> bool {
        [
            &self.python,
            &self.script,
            &self.ffmpeg,
            &self.quickjs,
            &self.certificates,
        ]
        .iter()
        .all(|p| p.is_absolute() && p.is_file())
            && [&self.python_home, &self.temp, &self.bin]
                .iter()
                .all(|p| p.is_absolute() && p.is_dir())
    }

    pub(super) fn command(&self) -> Command {
        let mut command = Command::new(&self.python);
        command
            .arg(&self.script)
            .env("PYTHONHOME", &self.python_home)
            .env("HOME", &self.python_home)
            .env("LD_LIBRARY_PATH", &self.library_path)
            .env("SSL_CERT_FILE", &self.certificates)
            .env("TMPDIR", &self.temp)
            .env("PATH", format!("/system/bin:{}", self.bin.display()));
        command
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_apk_tools_are_rejected_before_spawning() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("native path with spaces");
        std::fs::create_dir(&path).unwrap();
        let runtime = AndroidRuntime {
            python: path.join("libpython.so"),
            script: path.join("yt-dlp"),
            ffmpeg: path.join("libffmpeg.so"),
            quickjs: path.join("libqjs.so"),
            certificates: path.join("cert.pem"),
            python_home: path.clone(),
            library_path: path.to_string_lossy().into_owned(),
            temp: path.clone(),
            bin: path,
        };
        assert!(!runtime.validate());
        for file in [
            &runtime.python,
            &runtime.script,
            &runtime.ffmpeg,
            &runtime.quickjs,
            &runtime.certificates,
        ] {
            std::fs::write(file, "fixture").unwrap();
        }
        assert!(runtime.validate());
        let command = runtime.command();
        assert_eq!(command.as_std().get_program(), runtime.python.as_os_str());
        assert_eq!(
            command.as_std().get_args().collect::<Vec<_>>(),
            [runtime.script.as_os_str()]
        );
        std::fs::remove_file(&runtime.ffmpeg).unwrap();
        assert!(!runtime.validate());
    }
}

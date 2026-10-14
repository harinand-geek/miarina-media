//! What counts as a media file, and folder scanning.

use std::path::{Path, PathBuf};

use storage::MediaKind;

pub const VIDEO_EXTENSIONS: [&str; 7] = ["mp4", "m4v", "webm", "mkv", "mov", "avi", "ogv"];
pub const AUDIO_EXTENSIONS: [&str; 9] = [
    "mp3", "m4a", "flac", "ogg", "oga", "opus", "wav", "aac", "weba",
];
/// Depth of subfolders scanned under the library folder.
pub const MAX_SCAN_DEPTH: usize = 3;
/// Safety bound on the number of files examined per scan.
pub const MAX_SCAN_FILES: usize = 50_000;

pub fn extension(path: &Path) -> Option<String> {
    path.extension()
        .and_then(|e| e.to_str())
        .map(str::to_ascii_lowercase)
}

/// Kind guessed from the extension; ffprobe confirms it later.
pub fn kind_for(path: &Path) -> Option<MediaKind> {
    let ext = extension(path)?;
    if VIDEO_EXTENSIONS.contains(&ext.as_str()) {
        Some(MediaKind::Video)
    } else if AUDIO_EXTENSIONS.contains(&ext.as_str()) {
        Some(MediaKind::Audio)
    } else {
        None
    }
}

/// Title shown in the library: the file stem.
pub fn title_for(path: &Path) -> String {
    path.file_stem()
        .and_then(|s| s.to_str())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or("Untitled")
        .to_owned()
}

/// Temporary artifacts of downloads in progress are never indexed.
fn is_work_file(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    name.starts_with('.')
        || lower.ends_with(".part")
        || lower.ends_with(".part.d")
        || lower.ends_with(".ytdl")
        || lower.contains(".part-frag")
}

/// Media files under `root` (bounded depth and count, symlinks not followed).
pub fn media_files(root: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let mut stack = vec![(root.to_path_buf(), 0usize)];
    let mut seen = 0usize;
    while let Some((dir, depth)) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            seen += 1;
            if seen > MAX_SCAN_FILES {
                return found;
            }
            let name = entry.file_name().to_string_lossy().into_owned();
            if is_work_file(&name) {
                continue;
            }
            let Ok(file_type) = entry.file_type() else {
                continue;
            };
            let path = entry.path();
            if file_type.is_dir() && depth < MAX_SCAN_DEPTH {
                stack.push((path, depth + 1));
            } else if file_type.is_file() && kind_for(&path).is_some() {
                found.push(path);
            }
        }
    }
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kinds_follow_extensions() {
        assert_eq!(kind_for(Path::new("a/B.MP4")), Some(MediaKind::Video));
        assert_eq!(kind_for(Path::new("song.flac")), Some(MediaKind::Audio));
        assert_eq!(kind_for(Path::new("notes.txt")), None);
        assert_eq!(kind_for(Path::new("noext")), None);
        assert_eq!(
            title_for(Path::new("C:/V/Tears of Steel (1080p).mp4")),
            "Tears of Steel (1080p)"
        );
    }

    #[test]
    fn scanning_skips_work_files_and_respects_depth() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("a.mp4"), b"x").unwrap();
        std::fs::write(root.join("b.mp3"), b"x").unwrap();
        std::fs::write(root.join("readme.txt"), b"x").unwrap();
        std::fs::write(root.join("c.mp4.1a2b.part"), b"x").unwrap();
        std::fs::create_dir(root.join("d.mp4.1a2b.part.d")).unwrap();
        std::fs::write(root.join("d.mp4.1a2b.part.d").join("media.mp4"), b"x").unwrap();
        let mut deep = root.to_path_buf();
        for level in 0..5 {
            deep = deep.join(format!("l{level}"));
            std::fs::create_dir(&deep).unwrap();
            std::fs::write(deep.join(format!("v{level}.webm")), b"x").unwrap();
        }
        let mut names: Vec<String> = media_files(root)
            .iter()
            .map(|p| p.file_name().unwrap().to_string_lossy().into_owned())
            .collect();
        names.sort();
        assert_eq!(names, ["a.mp4", "b.mp3", "v0.webm", "v1.webm", "v2.webm"]);
    }
}

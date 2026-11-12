//! M3U / M3U8 playlists (CDC COM-11). Import only resolves local paths to
//! library entries; web addresses and unknown files are counted, never
//! fetched or added.

use std::path::{Path, PathBuf};

use storage::MediaRecord;

/// Largest playlist file read.
pub const M3U_MAX_BYTES: u64 = 2 * 1024 * 1024;

#[derive(Debug, Default, PartialEq)]
pub struct Parsed {
    /// Local paths, absolute, in file order.
    pub paths: Vec<PathBuf>,
    /// Web addresses and other entries that cannot be local files.
    pub skipped: usize,
}

/// `%20` and other escapes of `file://` addresses.
fn percent_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    let hex = |b: u8| (b as char).to_digit(16).map(|d| d as u8);
    while i < bytes.len() {
        if bytes[i] == b'%'
            && i + 2 < bytes.len()
            && let (Some(h), Some(l)) = (hex(bytes[i + 1]), hex(bytes[i + 2]))
        {
            out.push(h * 16 + l);
            i += 3;
            continue;
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// Reads entries of an M3U text; relative paths are taken from `base`.
pub fn parse(text: &str, base: &Path) -> Parsed {
    let mut parsed = Parsed::default();
    for line in text.trim_start_matches('\u{feff}').lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let lower = line.to_ascii_lowercase();
        let path = if let Some(rest) = lower.strip_prefix("file:///").map(|_| &line[8..]) {
            PathBuf::from(percent_decode(rest))
        } else if lower.contains("://") {
            parsed.skipped += 1;
            continue;
        } else {
            let p = PathBuf::from(line);
            if p.is_absolute() || line.starts_with('/') {
                p
            } else {
                base.join(p)
            }
        };
        parsed.paths.push(path);
    }
    parsed
}

/// Extended M3U, UTF-8 (`.m3u8`), absolute paths.
pub fn export(name: &str, items: &[MediaRecord]) -> String {
    let mut out = String::from("#EXTM3U\n");
    let name: String = name.chars().filter(|c| !c.is_control()).collect();
    out.push_str(&format!("#PLAYLIST:{name}\n"));
    for m in items {
        let secs = m.duration_secs.map_or(-1, |d| d.round() as i64);
        let title: String = match &m.artist {
            Some(artist) => format!("{artist} - {}", m.title),
            None => m.title.clone(),
        }
        .chars()
        .filter(|c| !c.is_control())
        .collect();
        out.push_str(&format!("#EXTINF:{secs},{title}\n{}\n", m.path));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_absolute_relative_and_file_entries() {
        let base = Path::new("C:/Music/Lists");
        let text = "\u{feff}#EXTM3U\n#EXTINF:271,Ankorabe - Hira\nC:/Music/hira.mp3\n\n\
                    ../Album/02 - Lalana.flac\nfile:///C:/Music/My%20Song.mp3\n\
                    https://example.org/stream.mp3\n# comment\n";
        let parsed = parse(text, base);
        assert_eq!(
            parsed.paths,
            vec![
                PathBuf::from("C:/Music/hira.mp3"),
                base.join("../Album/02 - Lalana.flac"),
                PathBuf::from("C:/Music/My Song.mp3"),
            ]
        );
        assert_eq!(parsed.skipped, 1, "web addresses are never fetched");
    }

    #[test]
    fn writes_extended_m3u() {
        let text = export("Matin\ncalme", &[]);
        assert_eq!(text, "#EXTM3U\n#PLAYLIST:Matincalme\n");
    }
}

//! File name sanitizing for titles coming from untrusted metadata.
//!
//! Rules follow the strictest target (Windows), which also covers Android
//! shared storage.

use thiserror::Error;

/// Maximum length in bytes of the final name, extension included.
/// Leaves room for the destination folder under Windows' 260-char limit.
pub const MAX_FILENAME_BYTES: usize = 180;
const FALLBACK_STEM: &str = "download";
const MAX_DUPLICATES: u32 = 9_999;

const RESERVED_WINDOWS_NAMES: [&str; 22] = [
    "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8",
    "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
];

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum FilenameError {
    #[error("invalid file extension")]
    InvalidExtension,
    #[error("too many files with the same name")]
    TooManyDuplicates,
}

/// Builds a safe `stem.extension` file name from an untrusted title.
///
/// The extension must be a short alphanumeric token chosen by the
/// application (e.g. `mp4`), never taken verbatim from the source.
pub fn sanitize_filename(title: &str, extension: &str) -> Result<String, FilenameError> {
    let extension = extension.trim_start_matches('.');
    if extension.is_empty()
        || extension.len() > 8
        || !extension.chars().all(|c| c.is_ascii_alphanumeric())
    {
        return Err(FilenameError::InvalidExtension);
    }
    let extension = extension.to_ascii_lowercase();

    let cleaned: String = title
        .chars()
        .map(|c| match c {
            '<' | '>' | ':' | '"' | '/' | '\\' | '|' | '?' | '*' => '_',
            c if c.is_control() => ' ',
            c => c,
        })
        .collect();
    let collapsed = cleaned.split_whitespace().collect::<Vec<_>>().join(" ");

    let max_stem = MAX_FILENAME_BYTES - extension.len() - 1;
    let mut stem = truncate_to_bytes(&collapsed, max_stem)
        .trim_end_matches(['.', ' '])
        .trim_start_matches(['.', ' '])
        .to_owned();
    if stem.is_empty() || stem.chars().all(|c| c == '_') {
        stem = FALLBACK_STEM.to_owned();
    }
    if is_reserved_windows_name(&stem) {
        stem.insert(0, '_');
    }

    Ok(format!("{stem}.{extension}"))
}

/// Longest folder name made from a title, in bytes: the files inside keep
/// room under Windows' path limit.
pub const MAX_DIRNAME_BYTES: usize = 48;

/// A safe folder name (one path component) from an untrusted title, e.g. a
/// playlist's: same rules as file names, shorter, never empty.
pub fn sanitize_dirname(title: &str) -> String {
    let name = sanitize_filename(title, "d").unwrap_or_default();
    let stem = name.strip_suffix(".d").unwrap_or(&name);
    let mut dir = truncate_to_bytes(stem, MAX_DIRNAME_BYTES)
        .trim_end_matches(['.', ' '])
        .to_owned();
    if dir.is_empty() {
        dir = FALLBACK_STEM.to_owned();
    }
    if is_reserved_windows_name(&dir) {
        dir.insert(0, '_');
    }
    dir
}

/// Returns `name` or the first free `stem (n).ext` variant according to
/// `exists`. The check is advisory: callers must still finalize with an
/// operation that fails if the target appears in the meantime.
pub fn unique_filename(
    name: &str,
    mut exists: impl FnMut(&str) -> bool,
) -> Result<String, FilenameError> {
    if !exists(name) {
        return Ok(name.to_owned());
    }
    let (stem, ext) = match name.rsplit_once('.') {
        Some((stem, ext)) if !stem.is_empty() => (stem, Some(ext)),
        _ => (name, None),
    };
    for n in 1..=MAX_DUPLICATES {
        let suffix = format!(" ({n})");
        let ext_len = ext.map_or(0, |e| e.len() + 1);
        let stem = truncate_to_bytes(stem, MAX_FILENAME_BYTES - suffix.len() - ext_len);
        let candidate = match ext {
            Some(ext) => format!("{stem}{suffix}.{ext}"),
            None => format!("{stem}{suffix}"),
        };
        if !exists(&candidate) {
            return Ok(candidate);
        }
    }
    Err(FilenameError::TooManyDuplicates)
}

fn is_reserved_windows_name(stem: &str) -> bool {
    // Windows also reserves the name when followed by an extension ("CON.tar").
    let base = stem.split('.').next().unwrap_or(stem).trim_end();
    RESERVED_WINDOWS_NAMES
        .iter()
        .any(|r| r.eq_ignore_ascii_case(base))
}

fn truncate_to_bytes(s: &str, max: usize) -> &str {
    if s.len() <= max {
        return s;
    }
    let mut end = max;
    while !s.is_char_boundary(end) {
        end -= 1;
    }
    &s[..end]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn folder_names_are_one_short_safe_component() {
        assert_eq!(
            sanitize_dirname("Ma playlist : été 2026"),
            "Ma playlist _ été 2026"
        );
        assert_eq!(sanitize_dirname("../../Windows"), "_.._Windows");
        assert_eq!(sanitize_dirname("..."), "download");
        assert_eq!(sanitize_dirname("nul"), "_nul");
        let long = sanitize_dirname(&"é".repeat(100));
        assert!(long.len() <= MAX_DIRNAME_BYTES && !long.is_empty());
        assert!(!sanitize_dirname(r"a/b\c").contains(['/', '\\']));
    }

    #[test]
    fn keeps_normal_titles() {
        assert_eq!(
            sanitize_filename("Tears of Steel (1080p)", "mp4").unwrap(),
            "Tears of Steel (1080p).mp4"
        );
        assert_eq!(
            sanitize_filename("Gymnopédie No. 1 — Satie", "flac").unwrap(),
            "Gymnopédie No. 1 — Satie.flac"
        );
    }

    #[test]
    fn replaces_reserved_characters_and_separators() {
        assert_eq!(
            sanitize_filename("a/b\\c:d*e?f\"g<h>i|j", "mp4").unwrap(),
            "a_b_c_d_e_f_g_h_i_j.mp4"
        );
    }

    #[test]
    fn neutralizes_traversal_attempts() {
        let name = sanitize_filename("../../Windows/System32/evil", "exe").unwrap();
        assert!(!name.contains('/') && !name.contains('\\'));
        assert!(!name.starts_with('.'));
    }

    #[test]
    fn strips_control_characters_and_collapses_whitespace() {
        assert_eq!(
            sanitize_filename("  line\nbreak\t\u{0}tab  ", "mp3").unwrap(),
            "line break tab.mp3"
        );
    }

    #[test]
    fn trims_trailing_dots_and_spaces() {
        assert_eq!(sanitize_filename("title. . .", "mp4").unwrap(), "title.mp4");
    }

    #[test]
    fn falls_back_for_empty_titles() {
        assert_eq!(sanitize_filename("", "mp4").unwrap(), "download.mp4");
        assert_eq!(sanitize_filename("???", "mp4").unwrap(), "download.mp4");
        assert_eq!(sanitize_filename("...", "mp4").unwrap(), "download.mp4");
    }

    #[test]
    fn prefixes_reserved_windows_names() {
        assert_eq!(sanitize_filename("con", "mp4").unwrap(), "_con.mp4");
        assert_eq!(sanitize_filename("LPT1", "mp3").unwrap(), "_LPT1.mp3");
        assert_eq!(
            sanitize_filename("NUL.backup", "mp4").unwrap(),
            "_NUL.backup.mp4"
        );
        assert_eq!(sanitize_filename("Console", "mp4").unwrap(), "Console.mp4");
    }

    #[test]
    fn truncates_on_char_boundary() {
        let long = "é".repeat(500);
        let name = sanitize_filename(&long, "webm").unwrap();
        assert!(name.len() <= MAX_FILENAME_BYTES);
        assert!(name.ends_with(".webm"));
    }

    #[test]
    fn rejects_untrusted_extensions() {
        assert_eq!(
            sanitize_filename("x", ""),
            Err(FilenameError::InvalidExtension)
        );
        assert_eq!(
            sanitize_filename("x", "mp4/../a"),
            Err(FilenameError::InvalidExtension)
        );
        assert_eq!(
            sanitize_filename("x", "verylongext"),
            Err(FilenameError::InvalidExtension)
        );
        assert_eq!(sanitize_filename("x", ".MP4").unwrap(), "x.mp4");
    }

    #[test]
    fn unique_filename_adds_counter() {
        let taken = ["a.mp4", "a (1).mp4"];
        assert_eq!(
            unique_filename("b.mp4", |n| taken.contains(&n)).unwrap(),
            "b.mp4"
        );
        assert_eq!(
            unique_filename("a.mp4", |n| taken.contains(&n)).unwrap(),
            "a (2).mp4"
        );
        assert_eq!(
            unique_filename("noext", |n| n == "noext").unwrap(),
            "noext (1)"
        );
    }

    #[test]
    fn unique_filename_gives_up_eventually() {
        assert_eq!(
            unique_filename("a.mp4", |_| true),
            Err(FilenameError::TooManyDuplicates)
        );
    }
}

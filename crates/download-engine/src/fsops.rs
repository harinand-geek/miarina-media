//! File system helpers: atomic, non-clobbering finalization and free space.

use std::io;
use std::path::{Path, PathBuf};

use media_core::unique_filename;

use crate::EngineError;

/// Moves `part` to `dir/name`, or to the first free `name (n)` variant.
/// Never overwrites an existing file, even if one appears concurrently.
pub fn finalize_no_clobber(part: &Path, dir: &Path, name: &str) -> Result<PathBuf, EngineError> {
    finalize_with(part, dir, name, move_no_replace)
}

/// Names the system may refuse in a row before finalization gives up.
const MAX_REFUSED_NAMES: usize = 32;

/// `finalize_no_clobber` with the move as a parameter (tests). A name the
/// move refuses as existing is never retried, even when `exists()` says it
/// is free (Android: a stale media index entry blocks the name), so the
/// loop always ends (at most `MAX_REFUSED_NAMES` refusals).
fn finalize_with(
    part: &Path,
    dir: &Path,
    name: &str,
    mut move_to: impl FnMut(&Path, &Path) -> io::Result<()>,
) -> Result<PathBuf, EngineError> {
    let mut refused: Vec<String> = Vec::new();
    loop {
        let chosen = unique_filename(name, |candidate| {
            refused.iter().any(|r| r == candidate) || dir.join(candidate).exists()
        })
        .map_err(|e| EngineError::Io {
            message: e.to_string(),
        })?;
        let target = dir.join(&chosen);
        match move_to(part, &target) {
            Ok(()) => return Ok(target),
            // Taken (another writer, or a name the system holds): next one.
            Err(err) if err.kind() == io::ErrorKind::AlreadyExists => {
                refused.push(chosen);
                if refused.len() >= MAX_REFUSED_NAMES {
                    return Err(EngineError::from_io(err));
                }
            }
            Err(err) => return Err(EngineError::from_io(err)),
        }
    }
}

#[cfg(windows)]
fn move_no_replace(from: &Path, to: &Path) -> io::Result<()> {
    use std::os::windows::ffi::OsStrExt;
    use windows_sys::Win32::Storage::FileSystem::{MOVEFILE_WRITE_THROUGH, MoveFileExW};

    let wide = |p: &Path| -> Vec<u16> { p.as_os_str().encode_wide().chain(Some(0)).collect() };
    let (from, to) = (wide(from), wide(to));
    // Without MOVEFILE_REPLACE_EXISTING the call fails if the target exists.
    let ok = unsafe { MoveFileExW(from.as_ptr(), to.as_ptr(), MOVEFILE_WRITE_THROUGH) };
    if ok != 0 {
        Ok(())
    } else {
        let err = io::Error::last_os_error();
        // ERROR_FILE_EXISTS (80) / ERROR_ALREADY_EXISTS (183)
        match err.raw_os_error() {
            Some(80 | 183) => Err(io::Error::from(io::ErrorKind::AlreadyExists)),
            _ => Err(err),
        }
    }
}

#[cfg(not(windows))]
fn move_no_replace(from: &Path, to: &Path) -> io::Result<()> {
    // hard_link fails with AlreadyExists if the target exists, which makes
    // the check-and-move atomic on file systems that support links.
    match std::fs::hard_link(from, to) {
        Ok(()) => std::fs::remove_file(from),
        Err(err) if err.kind() == io::ErrorKind::AlreadyExists => Err(err),
        Err(_) => {
            if to.exists() {
                return Err(io::Error::from(io::ErrorKind::AlreadyExists));
            }
            match std::fs::rename(from, to) {
                // Android: the temporary file is in the app's folder, the
                // final one in shared storage (another file system).
                Err(err) if err.kind() == io::ErrorKind::CrossesDevices => {
                    copy_then_remove(from, to)
                }
                other => other,
            }
        }
    }
}

/// Streams `from` into a new file `to` (never overwriting), syncs it, then
/// removes `from`. On failure the partial copy is removed and `from` kept.
#[cfg(not(windows))]
fn copy_then_remove(from: &Path, to: &Path) -> io::Result<()> {
    let copy = || -> io::Result<()> {
        let mut source = std::fs::File::open(from)?;
        let mut target = std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(to)?;
        io::copy(&mut source, &mut target)?;
        target.sync_all()
    };
    match copy() {
        Ok(()) => std::fs::remove_file(from),
        Err(err) => {
            if err.kind() != io::ErrorKind::AlreadyExists {
                let _ = std::fs::remove_file(to);
            }
            Err(err)
        }
    }
}

/// Free bytes available to the user on the volume containing `dir`, when
/// the platform exposes it.
pub fn available_space(dir: &Path) -> Option<u64> {
    disk_space(dir).map(|(free, _)| free)
}

/// (free for the user, total) bytes of the volume containing `dir`. The
/// directory may not exist yet: its closest existing ancestor is used.
pub fn disk_space(dir: &Path) -> Option<(u64, u64)> {
    let existing = dir.ancestors().find(|p| p.exists())?;
    #[cfg(windows)]
    {
        use std::os::windows::ffi::OsStrExt;
        use windows_sys::Win32::Storage::FileSystem::GetDiskFreeSpaceExW;

        let wide: Vec<u16> = existing.as_os_str().encode_wide().chain(Some(0)).collect();
        let (mut available, mut total) = (0u64, 0u64);
        let ok = unsafe {
            GetDiskFreeSpaceExW(
                wide.as_ptr(),
                &mut available,
                &mut total,
                std::ptr::null_mut(),
            )
        };
        (ok != 0).then_some((available, total))
    }
    #[cfg(not(windows))]
    {
        let _ = existing;
        None
    }
}

/// Space kept free on the volume in addition to the file itself.
pub const SPACE_MARGIN: u64 = 200 * 1024 * 1024;

/// Fails early when the remaining bytes cannot fit on the destination volume.
pub fn ensure_space(dir: &Path, remaining: u64) -> Result<(), EngineError> {
    match available_space(dir) {
        Some(available) if available < remaining.saturating_add(SPACE_MARGIN) => {
            Err(EngineError::InsufficientSpace {
                needed: remaining,
                available,
            })
        }
        _ => Ok(()),
    }
}

#[cfg(test)]
mod tests {

    #[test]
    fn a_name_refused_by_the_system_is_skipped_not_retried_forever() {
        let dir = tempfile::tempdir().unwrap();
        let part = dir.path().join("a.part");
        std::fs::write(&part, b"x").unwrap();
        let mut tries = Vec::new();
        // "a.mp4" looks free but the move always reports it as existing.
        let target = finalize_with(&part, dir.path(), "a.mp4", |from, to| {
            tries.push(to.file_name().unwrap().to_string_lossy().into_owned());
            if to.ends_with("a.mp4") {
                Err(io::Error::from(io::ErrorKind::AlreadyExists))
            } else {
                std::fs::rename(from, to)
            }
        })
        .unwrap();
        assert_eq!(target, dir.path().join("a (1).mp4"));
        assert_eq!(tries, ["a.mp4", "a (1).mp4"]);

        // Every name refused: an error, not an endless loop.
        std::fs::write(&part, b"x").unwrap();
        let result = finalize_with(&part, dir.path(), "b.mp4", |_, _| {
            Err(io::Error::from(io::ErrorKind::AlreadyExists))
        });
        assert!(result.is_err());
    }
    use super::*;

    #[test]
    fn finalize_picks_a_free_name_and_never_overwrites() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("a.mp4"), b"existing").unwrap();
        let part = dir.path().join("a.mp4.part");
        std::fs::write(&part, b"new").unwrap();

        let target = finalize_no_clobber(&part, dir.path(), "a.mp4").unwrap();
        assert_eq!(target.file_name().unwrap(), "a (1).mp4");
        assert_eq!(
            std::fs::read(dir.path().join("a.mp4")).unwrap(),
            b"existing"
        );
        assert_eq!(std::fs::read(&target).unwrap(), b"new");
        assert!(!part.exists());
    }

    #[test]
    fn finalize_uses_the_requested_name_when_free() {
        let dir = tempfile::tempdir().unwrap();
        let part = dir.path().join("x.part");
        std::fs::write(&part, b"data").unwrap();
        let target = finalize_no_clobber(&part, dir.path(), "b.mp3").unwrap();
        assert_eq!(target, dir.path().join("b.mp3"));
    }

    #[cfg(windows)]
    #[test]
    fn free_space_is_reported_on_windows() {
        let dir = tempfile::tempdir().unwrap();
        assert!(available_space(dir.path()).unwrap() > 0);
        assert!(matches!(
            ensure_space(dir.path(), u64::MAX / 2),
            Err(EngineError::InsufficientSpace { .. })
        ));
        assert!(ensure_space(dir.path(), 1).is_ok());
    }
}

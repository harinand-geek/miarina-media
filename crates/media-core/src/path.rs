//! Lexical guard against writing outside an allowed directory.
//!
//! This check is pure; adapters must additionally canonicalize the final
//! path on disk (symlinks, junctions) before writing.

use std::path::{Component, Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum PathError {
    #[error("the relative path is empty")]
    Empty,
    #[error("the path escapes its base directory")]
    Escapes,
}

/// Joins `relative` to `base`, rejecting absolute paths, drive prefixes,
/// `..` components and anything else that could leave `base`.
pub fn join_within(base: &Path, relative: &Path) -> Result<PathBuf, PathError> {
    let mut joined = base.to_path_buf();
    let mut pushed = false;
    for component in relative.components() {
        match component {
            Component::Normal(part) => {
                joined.push(part);
                pushed = true;
            }
            Component::CurDir => {}
            Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                return Err(PathError::Escapes);
            }
        }
    }
    if pushed {
        Ok(joined)
    } else {
        Err(PathError::Empty)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn base() -> PathBuf {
        PathBuf::from("library")
    }

    #[test]
    fn joins_simple_relative_paths() {
        assert_eq!(
            join_within(&base(), Path::new("blender.org/a.mp4")).unwrap(),
            base().join("blender.org").join("a.mp4")
        );
        assert_eq!(
            join_within(&base(), Path::new("./a.mp4")).unwrap(),
            base().join("a.mp4")
        );
    }

    #[test]
    fn rejects_parent_components() {
        assert_eq!(
            join_within(&base(), Path::new("../a.mp4")),
            Err(PathError::Escapes)
        );
        assert_eq!(
            join_within(&base(), Path::new("x/../../a.mp4")),
            Err(PathError::Escapes)
        );
    }

    #[test]
    fn rejects_absolute_paths() {
        assert_eq!(
            join_within(&base(), Path::new("/etc/passwd")),
            Err(PathError::Escapes)
        );
        #[cfg(windows)]
        {
            assert_eq!(
                join_within(&base(), Path::new(r"C:\Windows\a.exe")),
                Err(PathError::Escapes)
            );
            assert_eq!(
                join_within(&base(), Path::new(r"\\server\share\a")),
                Err(PathError::Escapes)
            );
        }
    }

    #[test]
    fn rejects_empty_paths() {
        assert_eq!(join_within(&base(), Path::new("")), Err(PathError::Empty));
        assert_eq!(join_within(&base(), Path::new(".")), Err(PathError::Empty));
    }
}

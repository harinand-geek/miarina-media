//! Domain core shared by every Miarina Media platform adapter.
//!
//! This crate performs no I/O: it holds the task state machine and the
//! validation rules applied to untrusted input (URLs, file names, paths).

pub mod detect;
pub mod filename;
pub mod path;
pub mod task;
pub mod url;

pub use filename::{
    FilenameError, MAX_DIRNAME_BYTES, sanitize_dirname, sanitize_filename, unique_filename,
};
pub use path::{PathError, join_within};
pub use task::{TaskState, TransitionError};
pub use url::{UrlError, ValidatedUrl, validate_media_url};

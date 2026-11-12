//! Download engines and the persistent scheduler of Miarina Media.

pub mod components;
mod engine;
mod error;
pub mod fsops;
mod http;
mod manager;
pub mod net;
pub mod process;
mod progress;
mod retry;
mod thumbnail;
pub mod ytdlp;

pub use engine::{DownloadJob, Engine, Outcome, ProcessLimits, ProgressFn};
pub use error::EngineError;
pub use http::{DirectMedia, HttpEngine, identity_path, media_extension};
pub use manager::{
    Connectivity, Manager, ManagerError, ManagerEvent, ProgressEvent, RetryNotice, part_path,
};
pub use progress::{Progress, Stage};
pub use retry::RetryPolicy;
pub use thumbnail::{MAX_THUMBNAIL_BYTES, image_extension};
pub use ytdlp::YtDlpEngine;

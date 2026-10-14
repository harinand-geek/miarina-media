//! Download engines and the persistent scheduler of Miarina Media.

pub mod components;
mod engine;
mod error;
pub mod fsops;
mod http;
mod manager;
mod process;
mod progress;
mod retry;
pub mod ytdlp;

pub use engine::{DownloadJob, Engine, Outcome, ProcessLimits, ProgressFn};
pub use error::EngineError;
pub use http::{DirectMedia, HttpEngine, media_extension};
pub use manager::{Manager, ManagerError, ManagerEvent, ProgressEvent, RetryNotice, part_path};
pub use progress::{Progress, Stage};
pub use retry::RetryPolicy;
pub use ytdlp::YtDlpEngine;

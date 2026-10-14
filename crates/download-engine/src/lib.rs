//! Download engines and the persistent scheduler of Miarina Media.

mod engine;
mod error;
pub mod fsops;
mod http;
mod manager;
mod progress;
mod retry;

pub use engine::{DownloadJob, Engine, Outcome, ProgressFn};
pub use error::EngineError;
pub use http::{DirectMedia, HttpEngine, media_extension};
pub use manager::{Manager, ManagerError, ManagerEvent, ProgressEvent, RetryNotice, part_path};
pub use progress::Progress;
pub use retry::RetryPolicy;

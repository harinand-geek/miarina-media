//! Built-in browser (decision 0001). Desktop: a dedicated window with child
//! webviews (`desktop.rs`). Mobile: the same command names answer
//! "unavailable"; Android gets a native WebView adapter (Phase 4).

#[cfg(desktop)]
mod desktop;
#[cfg(desktop)]
pub use desktop::*;

#[cfg(mobile)]
mod mobile;
#[cfg(mobile)]
pub use mobile::*;

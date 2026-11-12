//! Built-in browser (decision 0001). Desktop: a dedicated window with child
//! webviews (`desktop.rs`). Android: a native WebView placed by the
//! interface (`mobile.rs`, `page_state.rs`). Same command names everywhere.

pub mod address;
mod favorites;
pub use favorites::*;
mod history;
pub use history::*;
#[cfg_attr(desktop, allow(dead_code))]
mod page_state;

#[cfg(desktop)]
mod desktop;
#[cfg(desktop)]
pub use desktop::*;

#[cfg(mobile)]
mod mobile;
#[cfg(mobile)]
pub use mobile::*;

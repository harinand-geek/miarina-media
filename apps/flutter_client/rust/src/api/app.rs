//! Closing the app, as the Tauri app does on exit: the torrent session
//! stops (no more sharing), then running downloads flush their partial
//! files so they resume at the next launch.

use anyhow::Result;

/// Called once when the window is closing; never fails the closing.
pub fn app_shutdown() -> Result<()> {
    let torrents = crate::torrent_engine::disable().is_ok();
    crate::api::get::shutdown_downloads();
    // One line, no names or paths: the closing went through.
    eprintln!("miarina: closed cleanly (torrent session stopped: {torrents})");
    Ok(())
}

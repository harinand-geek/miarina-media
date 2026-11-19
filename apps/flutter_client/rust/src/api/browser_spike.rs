//! Phase 1 feasibility spike (decision 0007): a WebView2 hosted inside the
//! Flutter window on Windows, reporting media seen on the network with the
//! same `media_core::detect` rules as the Tauri browser. Not the final API.

use anyhow::Result;

use crate::webview_spike as imp;

pub struct DetectedMediaItem {
    pub kind: String,
    pub url: String,
    pub size_bytes: Option<u64>,
}

pub struct WebviewSpikeInfo {
    /// The calling thread owns the Flutter window, so WebView2 callbacks are
    /// dispatched by Flutter's own message loop.
    pub on_window_thread: bool,
}

/// Opens `url` in a WebView2 placed at the given physical-pixel rectangle of
/// the Flutter window's client area.
#[flutter_rust_bridge::frb(sync)]
pub fn webview_spike_open(
    url: String,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
) -> Result<WebviewSpikeInfo> {
    imp::open(&url, x, y, width, height)
}

#[flutter_rust_bridge::frb(sync)]
pub fn webview_spike_detections() -> Vec<DetectedMediaItem> {
    imp::detections()
}

#[flutter_rust_bridge::frb(sync)]
pub fn webview_spike_close() {
    imp::close();
}

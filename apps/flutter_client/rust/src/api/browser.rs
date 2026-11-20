//! Built-in browser on Windows (decision 0001), ported from the Tauri app:
//! one WebView2 per tab inside the Flutter window, placed where the
//! browser screen leaves room for the page. Pages are untrusted remote
//! content: http(s) only, popups become tabs, no browser-native downloads
//! (the app's engine downloads), media seen on the network and in the
//! page filtered by `media_core::detect`. WebView2 objects belong to the
//! window's thread: these functions are synchronous, called from it.

use anyhow::Result;

use crate::browser::webview as imp;
use crate::frb_generated::StreamSink;

pub struct DetectedMediaInfo {
    /// video, audio, hls, dash.
    pub kind: String,
    pub url: String,
    pub host: String,
    /// File name from the address, when it has one.
    pub name: String,
    pub size_bytes: Option<u64>,
}

pub struct BrowserTab {
    pub id: u32,
    /// start, web, history.
    pub kind: String,
    pub title: String,
    pub url: String,
    /// Media found on its page.
    pub media: u32,
    pub loading: bool,
    pub active: bool,
}

/// The selected tab, and the list of tabs.
pub struct BrowserSnapshot {
    pub kind: String,
    pub url: String,
    pub title: String,
    pub loading: bool,
    pub can_go_back: bool,
    pub can_go_forward: bool,
    pub media: Vec<DetectedMediaInfo>,
    /// The page plays a stream only the extractor can read (from the page
    /// address).
    pub stream_player: bool,
    pub tabs: Vec<BrowserTab>,
}

/// A change of the browser, or a shortcut pressed while the page had the
/// keyboard (Ctrl+L, Ctrl+T, Ctrl+W, Ctrl+Tab, Ctrl+Shift+Tab, Ctrl+H, F5).
pub struct BrowserEvent {
    pub snapshot: Option<BrowserSnapshot>,
    pub shortcut: Option<String>,
    /// A page asked for a new window: opened as a tab by the screen.
    pub open_tab: Option<String>,
    /// A page offered a file: the browser does not save it, the app's
    /// engine analyzes it.
    pub download: Option<String>,
}

/// Prepares the browser (tabs of the last run restored, pages not loaded
/// until shown). `data_dir`: the app's data folder (the browser profile
/// goes in `browser/`). False when not called from the window's thread.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_init(data_dir: String) -> Result<bool> {
    imp::init(&data_dir)
}

/// Browser changes for the screen (one listener: the latest replaces it).
pub fn browser_events(sink: StreamSink<BrowserEvent>) -> Result<()> {
    imp::set_sink(sink);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn browser_snapshot() -> BrowserSnapshot {
    imp::snapshot()
}

/// Shows the selected page in this rectangle (physical pixels of the
/// window's client area).
#[flutter_rust_bridge::frb(sync)]
pub fn browser_show(x: i32, y: i32, width: i32, height: i32) -> Result<()> {
    imp::show((x, y, width, height))
}

/// Hides every page (screen left, or something drawn over it).
#[flutter_rust_bridge::frb(sync)]
pub fn browser_hide() {
    imp::hide();
}

/// Opens an address, or searches the text, in the selected tab.
/// Errors: `not_a_web_address`, `unsupported_address`.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_navigate(address: String) -> Result<String> {
    imp::navigate(&address)
}

/// back, forward, reload, stop, home.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_nav(action: String) -> Result<()> {
    imp::nav(&action)
}

/// A new tab (start page, or `url`), selected. Error when 12 are open.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_tab_new(url: Option<String>) -> Result<()> {
    imp::tab_new(url.as_deref())
}

#[flutter_rust_bridge::frb(sync)]
pub fn browser_tab_close(id: u32) -> Result<()> {
    imp::tab_close(id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn browser_tab_select(id: u32) -> Result<()> {
    imp::tab_select(id)
}

/// Next (1) or previous (-1) tab.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_cycle(step: i32) -> Result<()> {
    imp::cycle(step as isize)
}

/// Asks the selected page for its `<video>`/`<audio>` sources (players
/// often attach them after loading; the screen calls this every few
/// seconds).
#[flutter_rust_bridge::frb(sync)]
pub fn browser_scan() {
    imp::scan();
}

pub struct BrowserFavorite {
    pub url: String,
    pub title: String,
}

pub struct BrowserVisit {
    pub id: i64,
    pub url: String,
    pub title: String,
    /// Milliseconds since the epoch.
    pub visited_at: i64,
}

/// Selects the history and favorites tab, opened if needed.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_tab_history() -> Result<()> {
    imp::tab_history()
}

/// Starred pages, newest first.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_favorites() -> Result<Vec<BrowserFavorite>> {
    imp::favorites()
}

/// Stars or unstars a web page; returns the new list.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_favorite_toggle(url: String, title: String) -> Result<Vec<BrowserFavorite>> {
    imp::favorite_toggle(&url, &title)
}

/// Visited pages, newest first; `query` matches the title or the address.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_history(query: String, limit: u32) -> Result<Vec<BrowserVisit>> {
    imp::history(&query, limit)
}

#[flutter_rust_bridge::frb(sync)]
pub fn browser_history_delete(id: i64) -> Result<()> {
    imp::history_delete(id)
}

/// Forgets the visited pages (downloads, library and favorites stay);
/// returns how many.
#[flutter_rust_bridge::frb(sync)]
pub fn browser_history_clear() -> Result<u32> {
    imp::history_clear()
}

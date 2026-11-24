//! Torrents (Obtenir, Windows v2 screen 9), ported from the Tauri app
//! (`apps/client/src-tauri/src/torrents.rs`) on the same engine
//! (`mdm-torrent`). No session and no network activity until the user
//! enables it; outgoing connections and DHT only (no UPnP, no LAN
//! announcements, no listening port); sharing is visible and stoppable;
//! each torrent gets a fresh folder of its own under Téléchargements.
//! Errors are stable codes; the screen words them.

use anyhow::Result;

use crate::torrent_engine as imp;

pub struct TorrentFile {
    pub index: u32,
    pub path: String,
    pub size: u64,
}

/// Files of a magnet link or .torrent file, before anything is fetched.
pub struct TorrentPreview {
    pub hash: String,
    pub name: String,
    pub files: Vec<TorrentFile>,
}

pub struct TorrentRow {
    pub hash: String,
    pub name: String,
    pub folder: String,
    /// initializing, checking, downloading, finished (sharing), paused,
    /// error, inactive (session off).
    pub phase: String,
    pub done: u64,
    pub total: u64,
    pub uploaded: u64,
    pub down_speed: f64,
    pub up_speed: f64,
    pub peers: u32,
}

pub struct TorrentSnapshot {
    pub enabled: bool,
    pub rows: Vec<TorrentRow>,
    /// Bytes per second, 0 = unlimited.
    pub download_limit: u64,
    pub upload_limit: u64,
    /// Finished torrents stop sharing at this ratio (0 = no rule).
    pub target_ratio: f64,
    /// ... or after sharing this many hours (0 = no rule).
    pub seed_hours: u32,
}

/// Starts the session (`data_dir`: the app's data folder; the session
/// state goes in `torrents/`).
pub fn torrents_enable(data_dir: String) -> Result<()> {
    imp::enable(&data_dir)
}

/// Stops everything, sharing included.
pub fn torrents_disable() -> Result<()> {
    imp::disable()
}

pub fn torrents_list() -> Result<TorrentSnapshot> {
    imp::list()
}

/// Reads a magnet link, or a .torrent file chosen by the user.
pub fn torrents_preview(magnet: Option<String>, file: Option<String>) -> Result<TorrentPreview> {
    imp::preview(magnet, file)
}

/// Starts a previewed torrent with the chosen files.
pub fn torrents_start(hash: String, files: Vec<u32>, sequential: bool) -> Result<()> {
    imp::start(hash, files, sequential)
}

/// pause (also "stop sharing"), resume, remove (files stay on disk).
pub fn torrents_action(hash: String, action: String) -> Result<()> {
    imp::action(hash, action)
}

/// Bytes per second, 0 = unlimited.
pub fn torrents_limits(download: u64, upload: u64) -> Result<()> {
    imp::limits(download, upload)
}

/// Sharing rules for finished torrents: ratio, hours (0 = no rule).
pub fn torrents_sharing(ratio: f64, hours: u32) -> Result<()> {
    imp::set_sharing(ratio, hours)
}

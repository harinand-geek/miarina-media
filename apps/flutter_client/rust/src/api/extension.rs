//! Chrome and Edge extension (Windows, Settings › Extension navigateur,
//! EXT-01). Connecting registers the native host `org.miarina.media.bridge`
//! for this Windows user: a manifest in the app's data folder, pointing at
//! `miarina-browser-bridge.exe` next to the app and allowing only the
//! Miarina Media extension (fixed ID), and one registry value per browser.
//! A link sent from the extension opens its analysis in the app.

use anyhow::Result;

use crate::extension as imp;

pub struct ExtensionStatus {
    /// The bridge is installed next to the app (not in development builds).
    pub bridge: bool,
    pub chrome: bool,
    pub edge: bool,
    /// The browser's registration points at another copy of the app.
    pub other: bool,
    /// The extension's folder, for « Charger l'extension non empaquetée ».
    pub folder: Option<String>,
}

/// `data_dir`: the app's data folder (the manifest goes in
/// `browser-bridge/`).
#[flutter_rust_bridge::frb(sync)]
pub fn extension_status(data_dir: String) -> ExtensionStatus {
    imp::status(&data_dir)
}

/// Connects (Chrome and Edge) or disconnects this computer. Errors:
/// `bridge_missing`, or the system's.
#[flutter_rust_bridge::frb(sync)]
pub fn extension_set_enabled(data_dir: String, enabled: bool) -> Result<ExtensionStatus> {
    imp::set_enabled(&data_dir, enabled)?;
    Ok(imp::status(&data_dir))
}

/// Runs the bridge as a browser would, with a ping: true when it answers.
pub fn extension_test(data_dir: String) -> bool {
    imp::test(&data_dir)
}

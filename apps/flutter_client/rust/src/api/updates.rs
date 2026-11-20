//! App updates (plan R3, Réglages › Mises à jour), ported from 0.1.x on the
//! same signed manifests: see `update_engine.rs` and docs/app-updates.md.
//! Errors are `code: message` (`update`, `update_network`,
//! `update_canceled`, `update_converting`).

use anyhow::{Result, anyhow};

use crate::update_engine as imp;

pub struct UpdateRelease {
    pub version: String,
    pub notes: String,
    pub size: u64,
}

pub struct UpdateStatusInfo {
    pub installed: String,
    pub release: Option<UpdateRelease>,
    pub ready: bool,
    pub downloaded: u64,
    pub downloading: bool,
}

pub struct UpdatePrefsInfo {
    /// "stable" or "beta".
    pub channel: String,
    pub auto_download: bool,
}

fn release(r: imp::Release) -> UpdateRelease {
    UpdateRelease {
        version: r.version,
        notes: r.notes,
        size: r.size,
    }
}

/// Once at launch (release builds only): `installed` = MM_VERSION, the
/// 0.1.x cache folder, the library database. Drops what an installed or
/// abandoned update left and restores a finished download.
pub fn updates_start(installed: String, cache_dir: String, db_path: String) -> Result<()> {
    imp::configure(imp::Config {
        installed,
        cache_dir: cache_dir.into(),
        db_path,
    })
    .map_err(|e| anyhow!(e))?;
    imp::restore();
    Ok(())
}

pub fn updates_check() -> Result<Option<UpdateRelease>> {
    imp::run(imp::check()).map(|r| r.map(release))
}

pub fn updates_status() -> Result<UpdateStatusInfo> {
    let s = imp::run(imp::status())?;
    Ok(UpdateStatusInfo {
        installed: s.installed,
        release: s.release.map(release),
        ready: s.ready,
        downloaded: s.downloaded,
        downloading: s.downloading,
    })
}

/// Downloads (or resumes) the newest release; returns once verified.
pub fn updates_download() -> Result<UpdateRelease> {
    imp::run(imp::download()).map(release)
}

#[flutter_rust_bridge::frb(sync)]
pub fn updates_cancel() {
    imp::cancel();
}

#[flutter_rust_bridge::frb(sync)]
pub fn updates_progress() -> u64 {
    imp::progress()
}

/// Starts the verified installer; the interface then closes the app.
pub fn updates_install() -> Result<()> {
    let converting = crate::api::get::converting();
    imp::run(imp::install(converting))
}

pub fn updates_prefs() -> UpdatePrefsInfo {
    let p = imp::prefs();
    UpdatePrefsInfo {
        channel: if p.channel == imp::Channel::Beta {
            "beta".into()
        } else {
            "stable".into()
        },
        auto_download: p.auto_download,
    }
}

pub fn updates_set_prefs(channel: String, auto_download: bool) -> Result<UpdatePrefsInfo> {
    let channel = if channel == "beta" {
        imp::Channel::Beta
    } else {
        imp::Channel::Stable
    };
    imp::set_prefs(imp::UpdatePrefs {
        channel,
        auto_download,
    })
    .map_err(|e| anyhow!(e))?;
    Ok(updates_prefs())
}

/// UPD-05: automatic download allowed now (option on, unmetered network,
/// battery saver off). Never installs.
pub fn updates_auto_allowed() -> bool {
    imp::auto_allowed()
}

//! Windows system media controls (SMTC): the media keys of the keyboard,
//! headset buttons and the media panel of Windows (volume flyout, lock
//! screen) act on Miarina Media, which shows what plays there: title,
//! artist, album, cover, position. Elsewhere these calls do nothing
//! (Android has its own media session, PlaybackService).

use anyhow::Result;

use crate::frb_generated::StreamSink;
use crate::system_media as imp;

/// What plays, as the system shows it.
pub struct SystemMediaState {
    /// Nothing loaded: the controls are hidden.
    pub has_media: bool,
    pub playing: bool,
    pub is_video: bool,
    pub title: String,
    /// Artist (music) or subtitle (video).
    pub artist: String,
    pub album: String,
    /// Cover image file, when there is one.
    pub artwork: Option<String>,
    pub can_next: bool,
    pub can_previous: bool,
    pub position_ms: u64,
    pub duration_ms: u64,
}

/// Shows `state` in the system's media controls (the window's thread).
#[flutter_rust_bridge::frb(sync)]
pub fn system_media_update(state: SystemMediaState) -> Result<()> {
    imp::update(state)
}

/// Buttons pressed: play, pause, stop, next, previous (one listener: the
/// latest replaces it).
pub fn system_media_buttons(sink: StreamSink<String>) -> Result<()> {
    imp::set_sink(sink);
    Ok(())
}

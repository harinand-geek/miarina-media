//! Native media playback. Android: Media3 through `NativePlayerPlugin.kt`
//! (the WebView cannot stream local files). Desktop plays through the asset
//! protocol in the WebView, so the same commands answer "unavailable".

#[cfg(target_os = "android")]
mod android;
#[cfg(target_os = "android")]
pub use android::*;

#[cfg(not(target_os = "android"))]
mod other;
#[cfg(not(target_os = "android"))]
pub use other::*;

use serde::{Deserialize, Serialize};

use crate::commands::CommandError;

/// Live state reported by the native player.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlayerStatus {
    /// Absent from the `close` reply (the player is gone by then).
    #[serde(default)]
    pub open: bool,
    #[serde(default)]
    pub position_ms: i64,
    /// -1 while unknown.
    #[serde(default)]
    pub duration_ms: i64,
    #[serde(default)]
    pub buffered_ms: i64,
    #[serde(default)]
    pub playing: bool,
    #[serde(default)]
    pub ended: bool,
    #[serde(default)]
    pub rate: f64,
    /// Media3 error code name, e.g. `ERROR_CODE_DECODING_FORMAT_UNSUPPORTED`.
    #[serde(default)]
    pub error: Option<String>,
    /// Position in the queue; the native player moves on by itself.
    #[serde(default)]
    pub index: Option<i64>,
    /// Library id of the current item.
    #[serde(default)]
    pub media_id: Option<i64>,
}

/// Longest queue handed to the native player.
pub const MAX_QUEUE: usize = 500;

/// Repeat modes of the queue.
#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub fn check_repeat(mode: &str) -> Result<&str, CommandError> {
    match mode {
        "off" | "all" | "one" => Ok(mode),
        _ => Err(CommandError::new("invalid_request", "unknown repeat mode")),
    }
}

/// A queue from the page: 1..=MAX_QUEUE ids and a position inside it.
#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub fn check_queue(ids: &[i64], index: usize) -> Result<(), CommandError> {
    if ids.is_empty() || ids.len() > MAX_QUEUE || index >= ids.len() {
        Err(CommandError::new("invalid_request", "invalid play queue"))
    } else {
        Ok(())
    }
}

/// Where the video is drawn, in CSS pixels of the WebView viewport.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SurfaceRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub visible: bool,
}

/// Speeds the player UI can ask for.
pub const RATE_RANGE: std::ops::RangeInclusive<f64> = 0.25..=4.0;
/// Larger than any screen: anything bigger is not a real layout.
const MAX_CSS_PX: f64 = 20_000.0;

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub fn check_rate(rate: f64) -> Result<f64, CommandError> {
    if rate.is_finite() && RATE_RANGE.contains(&rate) {
        Ok(rate)
    } else {
        Err(CommandError::new(
            "invalid_request",
            "unsupported playback speed",
        ))
    }
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub fn check_rect(rect: SurfaceRect) -> Result<SurfaceRect, CommandError> {
    let ok = |v: f64| v.is_finite() && (-MAX_CSS_PX..=MAX_CSS_PX).contains(&v);
    if ok(rect.x)
        && ok(rect.y)
        && ok(rect.width)
        && ok(rect.height)
        && rect.width >= 0.0
        && rect.height >= 0.0
    {
        Ok(rect)
    } else {
        Err(CommandError::new("invalid_request", "invalid video area"))
    }
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub fn to_ms(secs: f64) -> Result<i64, CommandError> {
    if secs.is_finite() && (0.0..=1.0e7).contains(&secs) {
        Ok((secs * 1000.0) as i64)
    } else {
        Err(CommandError::new("invalid_request", "invalid position"))
    }
}

/// Track kind and id ("group:track", small numbers) for `player_select_track`;
/// only subtitles can be turned off (`None`).
pub fn check_track(kind: &str, id: Option<String>) -> Result<(&str, Option<String>), CommandError> {
    let invalid = || CommandError::new("invalid_request", "invalid track");
    let kind = match kind {
        "audio" | "text" => kind,
        _ => return Err(invalid()),
    };
    match id {
        None if kind == "text" => Ok((kind, None)),
        None => Err(invalid()),
        Some(id) => {
            let parts: Vec<&str> = id.split(':').collect();
            let numbers = parts.len() == 2
                && parts.iter().all(|p| {
                    !p.is_empty() && p.len() <= 4 && p.bytes().all(|b| b.is_ascii_digit())
                });
            if numbers {
                Ok((kind, Some(id)))
            } else {
                Err(invalid())
            }
        }
    }
}

/// Gesture level kind and value (0..1) for `player_level`.
pub fn check_level(kind: &str, value: Option<f64>) -> Result<(&str, Option<f64>), CommandError> {
    let invalid = || CommandError::new("invalid_request", "invalid level");
    let kind = match kind {
        "brightness" | "volume" => kind,
        _ => return Err(invalid()),
    };
    match value {
        Some(v) if !(v.is_finite() && (0.0..=1.0).contains(&v)) => Err(invalid()),
        v => Ok((kind, v)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inputs_from_the_page_are_bounded() {
        assert!(check_rate(1.5).is_ok());
        for bad in [0.0, 10.0, f64::NAN, f64::INFINITY] {
            assert!(check_rate(bad).is_err());
        }
        let rect = SurfaceRect {
            x: 0.0,
            y: 56.0,
            width: 412.0,
            height: 232.0,
            visible: true,
        };
        assert!(check_rect(rect).is_ok());
        assert!(
            check_rect(SurfaceRect {
                width: -1.0,
                ..rect
            })
            .is_err()
        );
        assert!(
            check_rect(SurfaceRect {
                x: f64::NAN,
                ..rect
            })
            .is_err()
        );
        assert!(
            check_rect(SurfaceRect {
                height: 1e9,
                ..rect
            })
            .is_err()
        );
        assert_eq!(to_ms(12.5).unwrap(), 12_500);
        // The Kotlin `close` reply has no `open` field.
        let closed: PlayerStatus =
            serde_json::from_str(r#"{"positionMs":25177,"durationMs":52209}"#).unwrap();
        assert_eq!((closed.open, closed.position_ms), (false, 25_177));
        assert!(to_ms(-1.0).is_err());
        assert!(to_ms(f64::NAN).is_err());
    }

    #[test]
    fn queues_and_repeat_modes_are_bounded() {
        assert!(check_queue(&[1, 2, 3], 2).is_ok());
        assert!(check_queue(&[], 0).is_err());
        assert!(check_queue(&[1, 2], 2).is_err());
        assert!(check_queue(&vec![1; MAX_QUEUE + 1], 0).is_err());
        assert!(check_repeat("all").is_ok());
        assert!(check_repeat("shuffle").is_err());
        let status: PlayerStatus =
            serde_json::from_str(r#"{"open":true,"index":2,"mediaId":17}"#).unwrap();
        assert_eq!((status.index, status.media_id), (Some(2), Some(17)));
    }

    #[test]
    fn tracks_and_levels_are_checked() {
        assert!(check_track("audio", Some("1:0".into())).is_ok());
        assert!(check_track("text", None).is_ok());
        assert!(check_track("audio", None).is_err());
        assert!(check_track("video", Some("1:0".into())).is_err());
        for bad in ["1", "a:b", "1:2:3", ":1", "99999:1", "1:-1"] {
            assert!(check_track("text", Some(bad.into())).is_err(), "{bad}");
        }
        assert!(check_level("volume", Some(0.5)).is_ok());
        assert!(check_level("brightness", None).is_ok());
        assert!(check_level("volume", Some(1.5)).is_err());
        assert!(check_level("volume", Some(f64::NAN)).is_err());
        assert!(check_level("zoom", Some(0.5)).is_err());
    }
}

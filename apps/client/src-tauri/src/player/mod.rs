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
}

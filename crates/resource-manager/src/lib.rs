//! Resource modes and the limits they impose (docs/architecture.md §8).
//!
//! Every field of [`Limits`] is consumed by the download engine or the UI,
//! so a mode change always alters concurrency or processing behavior. The
//! starting values are hypotheses; Phase 5 measures their effect.

use std::time::Duration;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResourceMode {
    Eco,
    #[default]
    Balanced,
    Performance,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Platform {
    Windows,
    Android,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProcessPriority {
    BelowNormal,
    Normal,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Limits {
    /// Simultaneous downloads.
    pub max_downloads: usize,
    /// Simultaneous FFmpeg conversions or merges, bounded separately.
    pub max_conversions: usize,
    /// `-threads` passed to FFmpeg.
    pub ffmpeg_threads: usize,
    /// Concurrent fragments for segmented (HLS/DASH) downloads.
    pub concurrent_fragments: usize,
    /// Minimum delay between two progress events for one task.
    #[serde(serialize_with = "as_millis")]
    pub progress_interval: Duration,
    /// Longest edge of generated thumbnails, in pixels.
    pub thumbnail_px: u32,
    pub child_priority: ProcessPriority,
    /// Replace movement with short fades in the UI.
    pub reduced_motion: bool,
}

/// Highest value accepted for the user "Simultaneous downloads" setting.
pub const MAX_USER_DOWNLOADS: usize = 8;
/// Upper bound of the task queue (pending + active).
pub const MAX_QUEUE_LEN: usize = 500;

fn as_millis<S: serde::Serializer>(d: &Duration, s: S) -> Result<S::Ok, S::Error> {
    s.serialize_u64(d.as_millis() as u64)
}

/// Computes the limits for a mode.
///
/// * `user_downloads` — the "Simultaneous downloads" setting (clamped 1–8).
/// * `cpu_count` — logical CPUs available to the process.
pub fn limits(
    mode: ResourceMode,
    platform: Platform,
    user_downloads: usize,
    cpu_count: usize,
) -> Limits {
    let user_downloads = user_downloads.clamp(1, MAX_USER_DOWNLOADS);
    let cpus = cpu_count.max(1);
    match mode {
        ResourceMode::Eco => Limits {
            max_downloads: 1,
            max_conversions: 1,
            ffmpeg_threads: 1,
            concurrent_fragments: 1,
            progress_interval: Duration::from_millis(2000),
            thumbnail_px: 240,
            child_priority: ProcessPriority::BelowNormal,
            reduced_motion: true,
        },
        ResourceMode::Balanced => Limits {
            // Design: "up to 3 at once" on Windows; Android stays at 2.
            max_downloads: user_downloads.min(match platform {
                Platform::Windows => 3,
                Platform::Android => 2,
            }),
            max_conversions: 1,
            ffmpeg_threads: (cpus / 2).max(1),
            concurrent_fragments: 2,
            progress_interval: Duration::from_millis(1000),
            thumbnail_px: 360,
            child_priority: ProcessPriority::Normal,
            reduced_motion: false,
        },
        ResourceMode::Performance => Limits {
            max_downloads: user_downloads,
            max_conversions: 2.min(cpus),
            ffmpeg_threads: cpus,
            concurrent_fragments: 4,
            progress_interval: Duration::from_millis(1000),
            thumbnail_px: 480,
            child_priority: ProcessPriority::Normal,
            reduced_motion: false,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eco_is_strictly_lighter_than_balanced() {
        let eco = limits(ResourceMode::Eco, Platform::Windows, 8, 8);
        let balanced = limits(ResourceMode::Balanced, Platform::Windows, 8, 8);
        assert!(eco.max_downloads < balanced.max_downloads);
        assert!(eco.ffmpeg_threads < balanced.ffmpeg_threads);
        assert!(eco.concurrent_fragments < balanced.concurrent_fragments);
        assert!(eco.progress_interval > balanced.progress_interval);
        assert!(eco.thumbnail_px < balanced.thumbnail_px);
        assert_eq!(eco.child_priority, ProcessPriority::BelowNormal);
        assert!(eco.reduced_motion);
    }

    #[test]
    fn balanced_caps_user_setting_per_platform() {
        assert_eq!(
            limits(ResourceMode::Balanced, Platform::Windows, 8, 4).max_downloads,
            3
        );
        assert_eq!(
            limits(ResourceMode::Balanced, Platform::Android, 8, 4).max_downloads,
            2
        );
        assert_eq!(
            limits(ResourceMode::Balanced, Platform::Windows, 2, 4).max_downloads,
            2
        );
    }

    #[test]
    fn performance_uses_user_setting_and_all_cpus() {
        let perf = limits(ResourceMode::Performance, Platform::Windows, 6, 12);
        assert_eq!(perf.max_downloads, 6);
        assert_eq!(perf.ffmpeg_threads, 12);
        assert_eq!(perf.max_conversions, 2);
    }

    #[test]
    fn inputs_are_clamped() {
        let perf = limits(ResourceMode::Performance, Platform::Windows, 99, 0);
        assert_eq!(perf.max_downloads, MAX_USER_DOWNLOADS);
        assert_eq!((perf.ffmpeg_threads, perf.max_conversions), (1, 1));
        assert_eq!(
            limits(ResourceMode::Balanced, Platform::Windows, 0, 1).max_downloads,
            1
        );
    }

    #[test]
    fn serializes_for_the_ui() {
        let json =
            serde_json::to_value(limits(ResourceMode::Eco, Platform::Windows, 3, 4)).unwrap();
        assert_eq!(json["maxDownloads"], 1);
        assert_eq!(json["progressInterval"], 2000);
        assert_eq!(json["childPriority"], "below_normal");
        assert_eq!(
            serde_json::to_value(ResourceMode::Performance).unwrap(),
            "performance"
        );
    }
}

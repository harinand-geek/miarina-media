use std::time::{Duration, Instant};

use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Progress {
    pub downloaded: u64,
    pub total: Option<u64>,
    pub bytes_per_sec: f64,
    /// Whether the source accepted byte ranges for this transfer.
    pub supports_resume: bool,
}

impl Progress {
    pub fn eta(&self) -> Option<Duration> {
        let remaining = self.total?.checked_sub(self.downloaded)?;
        (self.bytes_per_sec > 1.0)
            .then(|| Duration::from_secs_f64(remaining as f64 / self.bytes_per_sec))
    }
}

/// Exponential moving average of the transfer rate, sampled at most every
/// `SAMPLE` so tiny chunks do not make the speed jitter.
pub(crate) struct SpeedMeter {
    last_at: Instant,
    last_bytes: u64,
    rate: f64,
}

const SAMPLE: Duration = Duration::from_millis(250);
/// Time constant of the average (≈ the last 5 s weigh most).
const WINDOW_SECS: f64 = 5.0;

impl SpeedMeter {
    pub(crate) fn new(now: Instant, bytes: u64) -> Self {
        Self {
            last_at: now,
            last_bytes: bytes,
            rate: 0.0,
        }
    }

    pub(crate) fn update(&mut self, now: Instant, bytes: u64) -> f64 {
        let dt = now.duration_since(self.last_at);
        if dt >= SAMPLE {
            let secs = dt.as_secs_f64();
            let instant = bytes.saturating_sub(self.last_bytes) as f64 / secs;
            let alpha = 1.0 - (-secs / WINDOW_SECS).exp();
            self.rate = if self.rate == 0.0 {
                instant
            } else {
                self.rate + alpha * (instant - self.rate)
            };
            self.last_at = now;
            self.last_bytes = bytes;
        }
        self.rate
    }
}

/// Lets an event through at most once per `interval`.
pub(crate) struct Throttle {
    interval: Duration,
    last: Option<Instant>,
}

impl Throttle {
    pub(crate) fn new(interval: Duration) -> Self {
        Self {
            interval,
            last: None,
        }
    }

    pub(crate) fn ready(&mut self, now: Instant) -> bool {
        match self.last {
            Some(last) if now.duration_since(last) < self.interval => false,
            _ => {
                self.last = Some(now);
                true
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn speed_converges_to_a_steady_rate() {
        let start = Instant::now();
        let mut meter = SpeedMeter::new(start, 0);
        let mut rate = 0.0;
        for i in 1..=40 {
            // 1 MB every 500 ms = 2 MB/s.
            rate = meter.update(start + Duration::from_millis(500 * i), 1_000_000 * i);
        }
        assert!((rate - 2_000_000.0).abs() < 1.0, "{rate}");
    }

    #[test]
    fn speed_ignores_too_frequent_samples() {
        let start = Instant::now();
        let mut meter = SpeedMeter::new(start, 0);
        assert_eq!(meter.update(start + Duration::from_millis(10), 10_000), 0.0);
    }

    #[test]
    fn throttle_limits_rate() {
        let start = Instant::now();
        let mut throttle = Throttle::new(Duration::from_secs(1));
        assert!(throttle.ready(start));
        assert!(!throttle.ready(start + Duration::from_millis(400)));
        assert!(throttle.ready(start + Duration::from_millis(1000)));
    }

    #[test]
    fn eta_needs_total_and_speed() {
        let p = Progress {
            downloaded: 500,
            total: Some(1500),
            bytes_per_sec: 100.0,
            supports_resume: false,
        };
        assert_eq!(p.eta(), Some(Duration::from_secs(10)));
        assert_eq!(Progress { total: None, ..p }.eta(), None);
        assert_eq!(
            Progress {
                bytes_per_sec: 0.0,
                ..p
            }
            .eta(),
            None
        );
    }
}

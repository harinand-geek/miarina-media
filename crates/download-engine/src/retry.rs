use std::time::Duration;

/// Bounded exponential backoff with jitter.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RetryPolicy {
    /// Retries after the first attempt.
    pub max_retries: u32,
    pub base: Duration,
    pub max_delay: Duration,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_retries: 5,
            base: Duration::from_secs(2),
            max_delay: Duration::from_secs(60),
        }
    }
}

impl RetryPolicy {
    /// Delay before retry number `retry` (1-based): base × 2^(retry−1),
    /// capped, then ±20 % jitter so parallel tasks do not retry in lockstep.
    /// `seed` makes the jitter deterministic in tests.
    pub fn delay(&self, retry: u32, seed: u64) -> Duration {
        let exp = self
            .base
            .saturating_mul(1u32 << retry.saturating_sub(1).min(16))
            .min(self.max_delay);
        let jitter = (splitmix(seed) % 401) as f64 / 1000.0 - 0.2; // [-0.2, 0.2]
        exp.mul_f64(1.0 + jitter).min(self.max_delay)
    }
}

fn splitmix(mut x: u64) -> u64 {
    x = x.wrapping_add(0x9E37_79B9_7F4A_7C15);
    x = (x ^ (x >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    x = (x ^ (x >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    x ^ (x >> 31)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn grows_exponentially_within_bounds() {
        let policy = RetryPolicy::default();
        for (retry, nominal) in [(1, 2.0), (2, 4.0), (3, 8.0), (4, 16.0)] {
            for seed in 0..50 {
                let d = policy.delay(retry, seed).as_secs_f64();
                assert!(
                    d >= nominal * 0.8 - 1e-9 && d <= nominal * 1.2 + 1e-9,
                    "{retry}: {d}"
                );
            }
        }
    }

    #[test]
    fn never_exceeds_the_cap() {
        let policy = RetryPolicy::default();
        for seed in 0..50 {
            assert!(policy.delay(30, seed) <= policy.max_delay);
        }
    }
}

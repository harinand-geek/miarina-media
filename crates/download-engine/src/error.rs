use serde::Serialize;
use thiserror::Error;

/// Engine failures, classified so the scheduler knows what to retry and the
/// UI can show the message defined by the design.
#[derive(Debug, Clone, PartialEq, Eq, Error, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum EngineError {
    #[error("network error: {message}")]
    Network { message: String },
    #[error("the server answered HTTP {status}")]
    Http { status: u16 },
    #[error("the link does not point to a downloadable media file")]
    NotMedia,
    #[error("the disk is full")]
    DiskFull,
    #[error("not enough free space ({needed} bytes needed, {available} available)")]
    InsufficientSpace { needed: u64, available: u64 },
    #[error("file system error: {message}")]
    Io { message: String },
    #[error("canceled")]
    Canceled,
    #[error("unsupported source: {reason}")]
    Unsupported { reason: String },
}

impl EngineError {
    /// Transient failures worth a bounded retry with backoff.
    pub fn is_retryable(&self) -> bool {
        match self {
            Self::Network { .. } => true,
            Self::Http { status } => matches!(status, 408 | 425 | 429 | 500..=599),
            _ => false,
        }
    }

    /// Stable code persisted with failed tasks.
    pub fn code(&self) -> &'static str {
        match self {
            Self::Network { .. } => "network",
            Self::Http { .. } => "http",
            Self::NotMedia => "not_media",
            Self::DiskFull => "disk_full",
            Self::InsufficientSpace { .. } => "insufficient_space",
            Self::Io { .. } => "io",
            Self::Canceled => "canceled",
            Self::Unsupported { .. } => "unsupported",
        }
    }

    pub(crate) fn network(err: impl std::fmt::Display) -> Self {
        Self::Network {
            message: err.to_string(),
        }
    }

    pub(crate) fn from_reqwest(err: reqwest::Error) -> Self {
        match err.status() {
            Some(status) => Self::Http {
                status: status.as_u16(),
            },
            // Never include the URL: it may carry tokens.
            None => Self::network(err.without_url()),
        }
    }

    pub(crate) fn from_io(err: std::io::Error) -> Self {
        if is_disk_full(&err) {
            Self::DiskFull
        } else {
            Self::Io {
                message: err.to_string(),
            }
        }
    }
}

fn is_disk_full(err: &std::io::Error) -> bool {
    if err.kind() == std::io::ErrorKind::StorageFull {
        return true;
    }
    // ERROR_HANDLE_DISK_FULL (39), ERROR_DISK_FULL (112) on Windows; ENOSPC elsewhere.
    match err.raw_os_error() {
        #[cfg(windows)]
        Some(39 | 112) => true,
        #[cfg(not(windows))]
        Some(28) => true,
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn retry_classification() {
        assert!(EngineError::network("reset").is_retryable());
        for status in [408, 429, 500, 502, 503] {
            assert!(EngineError::Http { status }.is_retryable(), "{status}");
        }
        for status in [400, 401, 403, 404, 410, 416] {
            assert!(!EngineError::Http { status }.is_retryable(), "{status}");
        }
        assert!(!EngineError::DiskFull.is_retryable());
        assert!(!EngineError::NotMedia.is_retryable());
        assert!(!EngineError::Canceled.is_retryable());
    }

    #[test]
    fn disk_full_is_detected() {
        let err = std::io::Error::from(std::io::ErrorKind::StorageFull);
        assert_eq!(EngineError::from_io(err), EngineError::DiskFull);
        #[cfg(windows)]
        assert_eq!(
            EngineError::from_io(std::io::Error::from_raw_os_error(112)),
            EngineError::DiskFull
        );
    }
}

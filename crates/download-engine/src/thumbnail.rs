//! Source thumbnails: the picture a website publishes for a media, cached
//! locally at analysis time so the UI never loads remote images.
//!
//! The URL comes from untrusted extractor output: it is validated like a
//! media link, the body is bounded, and only JPEG, PNG and WebP files
//! (checked by their signature, not by the server's headers) are kept.

use std::path::{Path, PathBuf};

use media_core::ValidatedUrl;
use sha2::{Digest, Sha256};

use crate::EngineError;
use crate::components::hex;
use crate::http::HttpEngine;

/// Larger pictures are refused (a thumbnail is typically 20–300 KB).
pub const MAX_THUMBNAIL_BYTES: usize = 2 * 1024 * 1024;

/// File extension for a supported picture, from its first bytes.
pub fn image_extension(bytes: &[u8]) -> Option<&'static str> {
    if bytes.starts_with(&[0xFF, 0xD8, 0xFF]) {
        Some("jpg")
    } else if bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
        Some("png")
    } else if bytes.len() >= 12 && &bytes[..4] == b"RIFF" && &bytes[8..12] == b"WEBP" {
        Some("webp")
    } else {
        None
    }
}

impl HttpEngine {
    /// Downloads the picture at `url` into `dir` and returns its path. The
    /// name derives from the URL, so analyzing the same page twice reuses it.
    pub async fn fetch_thumbnail(
        &self,
        url: &ValidatedUrl,
        dir: &Path,
    ) -> Result<PathBuf, EngineError> {
        let stem = hex(&Sha256::digest(url.as_str().as_bytes()))[..16].to_owned();
        for ext in ["jpg", "png", "webp"] {
            let cached = dir.join(format!("{stem}.{ext}"));
            if cached.is_file() {
                return Ok(cached);
            }
        }
        let mut response = self
            .client()
            .get(url.as_str())
            .send()
            .await
            .map_err(EngineError::from_reqwest)?;
        if !response.status().is_success() {
            return Err(EngineError::Http {
                status: response.status().as_u16(),
            });
        }
        if response
            .content_length()
            .is_some_and(|len| len > MAX_THUMBNAIL_BYTES as u64)
        {
            return Err(too_large());
        }
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(EngineError::from_reqwest)? {
            if body.len() + chunk.len() > MAX_THUMBNAIL_BYTES {
                return Err(too_large());
            }
            body.extend_from_slice(&chunk);
        }
        let ext = image_extension(&body).ok_or_else(|| EngineError::Unsupported {
            reason: "the thumbnail is not a JPEG, PNG or WebP picture".into(),
        })?;
        tokio::fs::create_dir_all(dir)
            .await
            .map_err(EngineError::from_io)?;
        let target = dir.join(format!("{stem}.{ext}"));
        let staging = dir.join(format!("{stem}.part"));
        tokio::fs::write(&staging, &body)
            .await
            .map_err(EngineError::from_io)?;
        tokio::fs::rename(&staging, &target)
            .await
            .map_err(EngineError::from_io)?;
        Ok(target)
    }
}

fn too_large() -> EngineError {
    EngineError::Unsupported {
        reason: "the thumbnail is too large".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pictures_are_recognized_by_signature() {
        assert_eq!(image_extension(&[0xFF, 0xD8, 0xFF, 0xE0]), Some("jpg"));
        assert_eq!(image_extension(b"\x89PNG\r\n\x1a\n...."), Some("png"));
        assert_eq!(image_extension(b"RIFF\0\0\0\0WEBPVP8 "), Some("webp"));
        assert_eq!(image_extension(b"<html><script>"), None);
        assert_eq!(image_extension(b"RIFF\0\0\0\0WAVE"), None);
        assert_eq!(image_extension(b""), None);
    }
}

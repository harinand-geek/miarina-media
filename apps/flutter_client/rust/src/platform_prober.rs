//! Android: technical details and pictures read by the platform
//! (MediaMetadataRetriever, `MediaProbeChannel.kt`) instead of FFmpeg, as the
//! Tauri app does. The library worker asks; the Dart side forwards to Kotlin.

use std::future::Future;
use std::path::Path;
use std::pin::Pin;
use std::sync::Arc;

use library::{LibraryError, ProbeFuture, ProbeResult, Prober};
use storage::MediaProbe;

/// What the platform read: details, and whether it wrote the picture asked.
#[derive(Debug, Clone, Default)]
pub(crate) struct PlatformReading {
    pub probe: MediaProbe,
    pub thumbnail_written: bool,
}

/// `(media, thumbnail to write, longest edge)` → reading, `None` when the
/// file could not be read.
pub(crate) type ProbeCall = Arc<
    dyn Fn(String, Option<String>, u32) -> Pin<Box<dyn Future<Output = Option<PlatformReading>> + Send>>
        + Send
        + Sync,
>;

pub(crate) struct PlatformProber(pub ProbeCall);

impl Prober for PlatformProber {
    fn probe<'a>(
        &'a self,
        media: &'a Path,
        thumbnail: Option<&'a Path>,
        max_px: u32,
    ) -> ProbeFuture<'a> {
        let call = self.0.clone();
        let media = media.to_string_lossy().into_owned();
        let thumbnail = thumbnail.map(|t| t.to_string_lossy().into_owned());
        Box::pin(async move {
            let reading = call(media, thumbnail, max_px)
                .await
                .ok_or_else(|| LibraryError::Probe("the file could not be read".into()))?;
            Ok(ProbeResult {
                probe: reading.probe,
                thumbnail_written: reading.thumbnail_written,
            })
        })
    }
}

//! Android media tools (`MediaToolsPlugin.kt`): library metadata and
//! thumbnails with platform APIs, since ffprobe/FFmpeg do not run there.

use std::path::Path;
use std::sync::Arc;

use library::{LibraryError, ProbeFuture, ProbeResult, Prober};
use serde::{Deserialize, Serialize};
use storage::MediaProbe;
use tauri::plugin::{Builder, PluginHandle, TauriPlugin};
use tauri::{Manager, Wry};

/// Handle kept in app state until the library is created.
pub struct MediaTools(Arc<PluginHandle<Wry>>);

pub fn init() -> TauriPlugin<Wry> {
    Builder::new("media-tools")
        .setup(|app, api| {
            let handle = api.register_android_plugin("org.miarina.media", "MediaToolsPlugin")?;
            app.manage(MediaTools(Arc::new(handle)));
            Ok(())
        })
        .build()
}

impl MediaTools {
    pub fn prober(&self) -> Arc<dyn Prober> {
        Arc::new(AndroidProber(self.0.clone()))
    }
}

struct AndroidProber(Arc<PluginHandle<Wry>>);

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ProbeArgs<'a> {
    path: &'a str,
    thumbnail: Option<&'a str>,
    max_px: u32,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ProbeReply {
    probe: MediaProbe,
    #[serde(default)]
    thumbnail_written: bool,
}

impl Prober for AndroidProber {
    fn probe<'a>(
        &'a self,
        media: &'a Path,
        thumbnail: Option<&'a Path>,
        max_px: u32,
    ) -> ProbeFuture<'a> {
        Box::pin(async move {
            let path = media.to_string_lossy();
            let thumbnail = thumbnail.map(|t| t.to_string_lossy());
            let reply: ProbeReply = self
                .0
                .run_mobile_plugin_async(
                    "probe",
                    ProbeArgs {
                        path: &path,
                        thumbnail: thumbnail.as_deref(),
                        max_px,
                    },
                )
                .await
                .map_err(|e| LibraryError::Probe(e.to_string()))?;
            Ok(ProbeResult {
                probe: reply.probe,
                thumbnail_written: reply.thumbnail_written,
            })
        })
    }
}

//! Network test against the real pinned yt-dlp and FFmpeg builds.
//! Not part of the default suite:
//!   MIARINA_COMPONENTS_DIR=<dir> cargo test -p download-engine --test ytdlp_live -- --ignored --nocapture

use std::path::PathBuf;
use std::sync::Mutex;
use std::time::Duration;

use download_engine::components::{Components, FFMPEG, YTDLP};
use download_engine::{DownloadJob, Engine, Progress, Stage, YtDlpEngine};
use media_core::validate_media_url;
use tokio_util::sync::CancellationToken;

/// Public CC BY 3.0 film on Wikimedia Commons (Blender Foundation).
const PAGE: &str = "https://commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm";

fn components() -> Components {
    let dir = std::env::var("MIARINA_COMPONENTS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::temp_dir().join("miarina-components-test"));
    Components::new(dir).unwrap()
}

#[tokio::test]
#[ignore = "downloads ~90 MB of tools and media from the network"]
async fn installs_verified_components_then_analyzes_and_downloads() {
    let components = components();
    let cancel = CancellationToken::new();
    for spec in [YTDLP, FFMPEG] {
        let path = components
            .install(
                &spec,
                &|done, total| eprintln!("{}: {done}/{total}", spec.name),
                &cancel,
            )
            .await
            .unwrap_or_else(|e| panic!("{} install failed: {e}", spec.name));
        eprintln!("{} installed at {}", spec.name, path.display());
    }
    assert!(components.status().iter().all(|s| s.installed));

    let engine = YtDlpEngine::new(components);
    let url = validate_media_url(PAGE).unwrap();
    let analysis = engine.analyze(&url, &cancel).await.expect("analysis");
    eprintln!("title: {:?}", analysis.info.title);
    for offer in analysis.offers.video.iter().chain(&analysis.offers.audio) {
        eprintln!(
            "  {} | {} | {:?} | {}",
            offer.quality,
            offer.detail,
            offer.size_bytes,
            offer.spec.encode()
        );
    }
    assert!(!analysis.offers.video.is_empty());

    // Smallest video offer keeps the test short.
    let offer = analysis
        .offers
        .video
        .iter()
        .min_by_key(|o| o.size_bytes.unwrap_or(u64::MAX))
        .unwrap();
    let dir = tempfile::tempdir().unwrap();
    let job = DownloadJob {
        url,
        part_path: dir.path().join("bbb.webm.test.part"),
        dest_dir: dir.path().to_path_buf(),
        file_name: "Big Buck Bunny.webm".into(),
        progress_interval: Duration::from_millis(500),
        format_id: Some(offer.spec.encode()),
        process: Default::default(),
    };
    let seen = Mutex::new(Vec::<Progress>::new());
    let outcome = engine
        .download(&job, &|p| seen.lock().unwrap().push(p), cancel.clone())
        .await
        .expect("download");
    let size = std::fs::metadata(&outcome.final_path).unwrap().len();
    eprintln!("saved {} ({size} bytes)", outcome.final_path.display());
    assert!(size > 0);
    assert_eq!(outcome.final_path.parent().unwrap(), dir.path());
    assert!(!yt_work_dir_exists(&job), "work folder cleaned up");
    let seen = seen.into_inner().unwrap();
    assert!(seen.windows(2).all(|w| w[0].downloaded <= w[1].downloaded));
    assert!(
        seen.iter()
            .all(|p| p.stage == Stage::Downloading || p.stage == Stage::Processing)
    );
}

fn yt_work_dir_exists(job: &DownloadJob) -> bool {
    download_engine::ytdlp::work_dir(&job.part_path).exists()
}

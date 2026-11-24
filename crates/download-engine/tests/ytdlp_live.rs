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
/// Sintel (Blender Foundation, CC BY 3.0) on the Blender channel: Wikimedia
/// publishes no thumbnail, YouTube does.
const PAGE_WITH_THUMBNAIL: &str = "https://www.youtube.com/watch?v=eRsGyueVLvQ";

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

#[tokio::test]
#[ignore = "analyzes a real page and downloads its thumbnail"]
async fn analysis_exposes_a_thumbnail_that_is_cached_locally() {
    let engine = YtDlpEngine::new(components());
    let cancel = CancellationToken::new();
    let analysis = engine
        .analyze(&validate_media_url(PAGE_WITH_THUMBNAIL).unwrap(), &cancel)
        .await
        .expect("analysis (needs installed components)");
    let thumbnail = analysis
        .info
        .thumbnail
        .expect("the page publishes a picture");
    eprintln!("thumbnail URL: {thumbnail}");

    let http = download_engine::HttpEngine::new().unwrap();
    let dir = tempfile::tempdir().unwrap();
    let url = validate_media_url(&thumbnail).unwrap();
    let path = http.fetch_thumbnail(&url, dir.path()).await.expect("fetch");
    let bytes = std::fs::read(&path).unwrap();
    eprintln!("saved {} ({} bytes)", path.display(), bytes.len());
    assert!(download_engine::image_extension(&bytes).is_some());
    assert!(bytes.len() <= download_engine::MAX_THUMBNAIL_BYTES);
    // Analyzing again reuses the cached file.
    assert_eq!(http.fetch_thumbnail(&url, dir.path()).await.unwrap(), path);
}

#[tokio::test]
#[ignore = "downloads ~14 MB of audio from YouTube"]
async fn youtube_downloads_with_the_javascript_runtime() {
    let components = components();
    assert!(components.quickjs().is_some(), "QuickJS-NG installed");
    let engine = YtDlpEngine::new(components);
    let dir = tempfile::tempdir().unwrap();
    let job = DownloadJob {
        url: validate_media_url(PAGE_WITH_THUMBNAIL).unwrap(),
        part_path: dir.path().join("sintel.webm.test.part"),
        dest_dir: dir.path().to_path_buf(),
        file_name: "Sintel.webm".into(),
        progress_interval: Duration::from_millis(500),
        format_id: Some(r#"{"s":"251"}"#.into()),
        process: Default::default(),
    };
    let started = std::time::Instant::now();
    let outcome = engine
        .download(&job, &|_| {}, CancellationToken::new())
        .await
        .expect("download");
    let size = std::fs::metadata(&outcome.final_path).unwrap().len();
    eprintln!("{size} bytes in {:.1} s", started.elapsed().as_secs_f64());
    assert!(size > 1_000_000);
}

/// Accented title (CC BY-SA, Lingua Libre). yt-dlp used to print titles in
/// the Windows console code page, which failed every such download.
const PAGE_WITH_ACCENTS: &str =
    "https://commons.wikimedia.org/wiki/File:LL-Q33302_(fsl)-Laura_Jauvert-%C3%89t%C3%A9.webm";

#[tokio::test]
#[ignore = "downloads a small video from Wikimedia Commons"]
async fn accented_titles_download() {
    let engine = YtDlpEngine::new(components());
    let cancel = CancellationToken::new();
    let url = validate_media_url(PAGE_WITH_ACCENTS).unwrap();
    let analysis = engine.analyze(&url, &cancel).await.expect("analysis");
    let title = analysis.info.title.clone().unwrap_or_default();
    eprintln!("title: {title}");
    assert!(title.contains("Été"), "title decoded as UTF-8: {title}");
    let offer = analysis
        .offers
        .video
        .iter()
        .min_by_key(|o| o.size_bytes.unwrap_or(u64::MAX))
        .expect("a video offer");
    let dir = tempfile::tempdir().unwrap();
    let job = DownloadJob {
        url,
        part_path: dir.path().join("ete.webm.test.part"),
        dest_dir: dir.path().to_path_buf(),
        file_name: format!("{title}.webm"),
        progress_interval: Duration::from_millis(500),
        format_id: Some(offer.spec.encode()),
        process: Default::default(),
    };
    let outcome = engine
        .download(&job, &|_| {}, cancel)
        .await
        .expect("download");
    eprintln!("saved {}", outcome.final_path.display());
    assert!(std::fs::metadata(&outcome.final_path).unwrap().len() > 0);
}

#[tokio::test]
#[ignore = "downloads yt-dlp (~18 MB) from GitHub and verifies its signature"]
async fn a_signed_ytdlp_release_installs_and_activates() {
    let dir = tempfile::tempdir().unwrap();
    let components = Components::new(dir.path().to_path_buf()).unwrap();
    components
        .install_release("2026.08.19", &CancellationToken::new())
        .await
        .expect("signature, digest and --version all check out");
    let (active, path) = components.active_ytdlp().expect("recorded as active");
    eprintln!("active {} at {}", active.version, path.display());
    assert_eq!(active.version, "2026.08.19");
    assert!(path.is_file());
    // Same version as the pinned one: the pinned executable stays in use.
    assert_eq!(components.ytdlp_version(), "2026.08.19");
}

/// The public videos tab of the Blender Studio channel: a playlist.
const PLAYLIST: &str = "https://www.youtube.com/@BlenderStudio/videos";

/// Components, with the app's shipped tools when `MIARINA_BUNDLED_DIR` says
/// where they are (e.g. `apps/flutter_client/build/tools-cache`).
fn components_with_bundled() -> Components {
    match std::env::var("MIARINA_BUNDLED_DIR") {
        Ok(dir) => components().with_bundled(PathBuf::from(dir)),
        Err(_) => components(),
    }
}

#[tokio::test]
#[ignore = "lists a real playlist, then downloads its shortest entry as MP3"]
async fn a_playlist_is_listed_flat_then_an_entry_downloads_with_a_preset() {
    let engine = YtDlpEngine::new(components_with_bundled());
    let cancel = CancellationToken::new();
    let started = std::time::Instant::now();
    let analysis = engine
        .analyze_with(&validate_media_url(PLAYLIST).unwrap(), true, &cancel)
        .await
        .expect("analysis");
    let list = analysis.playlist.expect("a playlist");
    eprintln!(
        "{:?}: {} entries ({} available), count {:?}, truncated {}, in {:.1} s",
        analysis.info.title,
        list.items.len(),
        list.available(),
        list.count,
        list.truncated,
        started.elapsed().as_secs_f64()
    );
    assert!(list.available() > 0);
    assert!(list.items.len() <= download_engine::ytdlp::MAX_PLAYLIST_ITEMS);
    assert!(list.items.windows(2).all(|w| w[0].index + 1 == w[1].index));

    // The shortest entry keeps the test short; one preset for all entries.
    let entry = list
        .items
        .iter()
        .filter(|i| i.url.is_some() && i.duration.is_some())
        .min_by(|a, b| a.duration.partial_cmp(&b.duration).unwrap())
        .expect("an entry with a duration");
    eprintln!(
        "entry {}: {:?} ({:?} s)",
        entry.index, entry.title, entry.duration
    );
    let offer = analysis
        .offers
        .audio
        .iter()
        .find(|o| o.spec.audio_kbps == Some(192))
        .expect("MP3 192 kbps (FFmpeg installed)");
    let dir = tempfile::tempdir().unwrap();
    let job = DownloadJob {
        url: validate_media_url(entry.url.as_deref().unwrap()).unwrap(),
        part_path: dir.path().join("entry.mp3.test.part"),
        dest_dir: dir.path().to_path_buf(),
        file_name: format!("{:02} - entry.mp3", entry.index),
        progress_interval: Duration::from_millis(500),
        format_id: Some(offer.spec.encode()),
        process: Default::default(),
    };
    let outcome = engine
        .download(&job, &|_| {}, cancel)
        .await
        .expect("download");
    let size = std::fs::metadata(&outcome.final_path).unwrap().len();
    eprintln!("saved {} ({size} bytes)", outcome.final_path.display());
    assert!(size > 0);
    assert_eq!(
        outcome.final_path.extension().and_then(|e| e.to_str()),
        Some("mp3")
    );
}

/// Sintel (Blender Foundation, CC BY 3.0) on Wikimedia Commons.
const PAGE_WITH_SUBTITLES: &str = "https://commons.wikimedia.org/wiki/File:Sintel_movie_4K.webm";

#[tokio::test]
#[ignore = "analyzes a real page, then downloads one subtitle file"]
async fn subtitles_are_listed_and_one_language_downloads() {
    let engine = YtDlpEngine::new(components_with_bundled());
    let cancel = CancellationToken::new();
    // Sintel on Wikimedia Commons publishes ~30 subtitle languages (YouTube
    // often answers 429 to subtitle requests).
    let url = validate_media_url(PAGE_WITH_SUBTITLES).unwrap();
    let analysis = engine.analyze(&url, &cancel).await.expect("analysis");
    let langs: Vec<_> = analysis
        .offers
        .subtitles
        .iter()
        .map(|o| o.spec.subtitles.clone().unwrap())
        .collect();
    eprintln!("subtitles: {langs:?}");
    let offer = analysis
        .offers
        .subtitles
        .iter()
        .find(|o| {
            o.spec
                .subtitles
                .as_deref()
                .is_some_and(|l| l.starts_with("fr"))
        })
        .or_else(|| analysis.offers.subtitles.first())
        .expect("the page publishes subtitles");
    let dir = tempfile::tempdir().unwrap();
    let job = DownloadJob {
        url,
        part_path: dir.path().join("sintel.srt.test.part"),
        dest_dir: dir.path().to_path_buf(),
        file_name: "Sintel (sous-titres).srt".into(),
        progress_interval: Duration::from_millis(500),
        format_id: Some(offer.spec.encode()),
        process: Default::default(),
    };
    let outcome = engine
        .download(&job, &|_| {}, cancel)
        .await
        .expect("download");
    let text = std::fs::read_to_string(&outcome.final_path).unwrap();
    eprintln!(
        "saved {} ({} bytes): {:?}",
        outcome.final_path.display(),
        text.len(),
        text.lines().take(4).collect::<Vec<_>>()
    );
    assert!(text.contains("-->"), "a subtitle file");
    assert!(!yt_work_dir_exists(&job));
}

#[tokio::test]
#[ignore = "downloads ~3 MB at a limited rate"]
async fn the_speed_limit_holds_a_video_page_back() {
    let engine = YtDlpEngine::new(components_with_bundled());
    let dir = tempfile::tempdir().unwrap();
    let job = DownloadJob {
        url: validate_media_url(PAGE_WITH_THUMBNAIL).unwrap(),
        part_path: dir.path().join("sintel.m4a.test.part"),
        dest_dir: dir.path().to_path_buf(),
        file_name: "Sintel.m4a".into(),
        progress_interval: Duration::from_millis(500),
        // The smallest audio stream of the page.
        format_id: Some(r#"{"s":"worstaudio"}"#.into()),
        process: download_engine::ProcessLimits {
            rate_limit: Some(512 * 1024),
            ..Default::default()
        },
    };
    let started = std::time::Instant::now();
    let outcome = engine
        .download(&job, &|_| {}, CancellationToken::new())
        .await
        .expect("download");
    let size = std::fs::metadata(&outcome.final_path).unwrap().len();
    let secs = started.elapsed().as_secs_f64();
    let rate = size as f64 / secs;
    eprintln!("{size} bytes in {secs:.1} s = {:.0} KiB/s", rate / 1024.0);
    // yt-dlp's own pacing, plus its start-up time.
    assert!(rate < 700.0 * 1024.0, "limited to about 512 KiB/s");
}

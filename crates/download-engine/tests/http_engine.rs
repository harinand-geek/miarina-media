mod support;

use std::sync::Mutex;
use std::time::Duration;

use download_engine::{DownloadJob, Engine, EngineError, HttpEngine, Progress};
use media_core::validate_media_url;
use support::{Behavior, body, serve};
use tokio_util::sync::CancellationToken;

fn job(url: &str, dir: &std::path::Path) -> DownloadJob {
    DownloadJob {
        url: validate_media_url(url).unwrap(),
        part_path: dir.join("movie.mp4.part"),
        dest_dir: dir.to_path_buf(),
        file_name: "movie.mp4".into(),
        progress_interval: Duration::from_millis(0),
        format_id: None,
        process: Default::default(),
    }
}

async fn run(
    engine: &HttpEngine,
    job: &DownloadJob,
) -> (Result<download_engine::Outcome, EngineError>, Vec<Progress>) {
    let seen = Mutex::new(Vec::new());
    let cb = |p: Progress| seen.lock().unwrap().push(p);
    let result = engine.download(job, &cb, CancellationToken::new()).await;
    (result, seen.into_inner().unwrap())
}

#[tokio::test]
async fn downloads_the_whole_file_and_finalizes() {
    let data = body(300_000);
    let server = serve(
        data.clone(),
        Behavior {
            support_ranges: true,
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let job = job(&server.url("/movie.mp4"), dir.path());

    let (result, progress) = run(&HttpEngine::new().unwrap(), &job).await;
    let outcome = result.unwrap();
    assert_eq!(outcome.final_path, dir.path().join("movie.mp4"));
    assert_eq!(std::fs::read(&outcome.final_path).unwrap(), data);
    assert!(!job.part_path.exists(), "no partial file left behind");
    assert!(outcome.supports_resume);

    assert!(
        progress
            .windows(2)
            .all(|w| w[0].downloaded <= w[1].downloaded)
    );
    let last = progress.last().unwrap();
    assert_eq!((last.downloaded, last.total), (300_000, Some(300_000)));
}

#[tokio::test]
async fn resumes_from_the_partial_file_with_a_range_request() {
    let data = body(200_000);
    let server = serve(
        data.clone(),
        Behavior {
            support_ranges: true,
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let job = job(&server.url("/movie.mp4"), dir.path());
    std::fs::write(&job.part_path, &data[..80_000]).unwrap();

    let (result, progress) = run(&HttpEngine::new().unwrap(), &job).await;
    let outcome = result.unwrap();
    assert_eq!(server.ranges(), vec![Some("bytes=80000-".to_owned())]);
    assert_eq!(progress.first().unwrap().downloaded, 80_000);
    assert_eq!(std::fs::read(outcome.final_path).unwrap(), data);
}

#[tokio::test]
async fn restarts_from_zero_when_the_server_ignores_ranges() {
    let data = body(100_000);
    let server = serve(
        data.clone(),
        Behavior {
            support_ranges: false,
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let job = job(&server.url("/movie.mp4"), dir.path());
    std::fs::write(&job.part_path, b"stale partial data").unwrap();

    let (result, _) = run(&HttpEngine::new().unwrap(), &job).await;
    let outcome = result.unwrap();
    assert!(!outcome.supports_resume);
    assert_eq!(
        std::fs::read(outcome.final_path).unwrap(),
        data,
        "stale bytes were truncated"
    );
}

#[tokio::test]
async fn a_complete_partial_file_is_finalized_on_416() {
    let data = body(50_000);
    let server = serve(
        data.clone(),
        Behavior {
            support_ranges: true,
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let job = job(&server.url("/movie.mp4"), dir.path());
    std::fs::write(&job.part_path, &data).unwrap();

    let (result, _) = run(&HttpEngine::new().unwrap(), &job).await;
    assert_eq!(std::fs::read(result.unwrap().final_path).unwrap(), data);
}

#[tokio::test]
async fn truncated_transfers_are_retryable_and_keep_the_partial_data() {
    let data = body(200_000);
    let behavior = Behavior {
        support_ranges: true,
        ..Default::default()
    };
    *behavior.cut_after.lock().unwrap() = Some(70_000);
    let server = serve(data.clone(), behavior).await;
    let dir = tempfile::tempdir().unwrap();
    let job = job(&server.url("/movie.mp4"), dir.path());
    let engine = HttpEngine::new().unwrap();

    let (result, _) = run(&engine, &job).await;
    let err = result.unwrap_err();
    assert!(err.is_retryable(), "{err:?}");
    let kept = std::fs::metadata(&job.part_path).unwrap().len();
    assert!(kept > 0 && kept < 200_000);

    // The second attempt resumes and completes.
    let (result, _) = run(&engine, &job).await;
    assert_eq!(std::fs::read(result.unwrap().final_path).unwrap(), data);
    assert_eq!(server.ranges()[1], Some(format!("bytes={kept}-")));
}

#[tokio::test]
async fn http_errors_are_classified() {
    let server = serve(
        body(10),
        Behavior {
            status: Some(404),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let (result, _) = run(
        &HttpEngine::new().unwrap(),
        &job(&server.url("/x.mp4"), dir.path()),
    )
    .await;
    let err = result.unwrap_err();
    assert_eq!(err, EngineError::Http { status: 404 });
    assert!(!err.is_retryable());

    let busy = serve(
        body(10),
        Behavior {
            fail_first: 1.into(),
            ..Default::default()
        },
    )
    .await;
    let (result, _) = run(
        &HttpEngine::new().unwrap(),
        &job(&busy.url("/x.mp4"), dir.path()),
    )
    .await;
    assert!(result.unwrap_err().is_retryable());
}

#[tokio::test]
async fn cancellation_stops_promptly_and_keeps_the_part() {
    let server = serve(
        body(2_000_000),
        Behavior {
            support_ranges: true,
            chunk_delay: Duration::from_millis(20),
            ..Default::default()
        },
    )
    .await;
    let dir = tempfile::tempdir().unwrap();
    let job = job(&server.url("/movie.mp4"), dir.path());
    let token = CancellationToken::new();
    let engine = HttpEngine::new().unwrap();
    let cancel = token.clone();
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_millis(150)).await;
        cancel.cancel();
    });
    let started = std::time::Instant::now();
    let result = engine.download(&job, &|_| {}, token).await;
    assert_eq!(result.unwrap_err(), EngineError::Canceled);
    assert!(started.elapsed() < Duration::from_secs(2));
    assert!(job.part_path.exists());
    assert!(!dir.path().join("movie.mp4").exists());
}

#[tokio::test]
async fn existing_files_are_never_overwritten() {
    let data = body(1000);
    let server = serve(data.clone(), Behavior::default()).await;
    let dir = tempfile::tempdir().unwrap();
    std::fs::write(dir.path().join("movie.mp4"), b"mine").unwrap();
    let (result, _) = run(
        &HttpEngine::new().unwrap(),
        &job(&server.url("/movie.mp4"), dir.path()),
    )
    .await;
    assert_eq!(result.unwrap().final_path, dir.path().join("movie (1).mp4"));
    assert_eq!(
        std::fs::read(dir.path().join("movie.mp4")).unwrap(),
        b"mine"
    );
}

#[tokio::test]
async fn probe_accepts_media_and_rejects_pages() {
    let media = serve(
        body(5000),
        Behavior {
            support_ranges: true,
            ..Default::default()
        },
    )
    .await;
    let url = validate_media_url(&media.url("/files/Tears%20of%20Steel.mp4")).unwrap();
    let info = HttpEngine::new().unwrap().probe(&url).await.unwrap();
    assert_eq!(info.suggested_name, "Tears of Steel.mp4");
    assert_eq!(info.total_bytes, Some(5000));
    assert!(info.supports_resume);

    let page = serve(
        b"<html></html>".to_vec(),
        Behavior {
            content_type: "text/html; charset=utf-8",
            ..Default::default()
        },
    )
    .await;
    let url = validate_media_url(&page.url("/watch")).unwrap();
    assert_eq!(
        HttpEngine::new().unwrap().probe(&url).await.unwrap_err(),
        EngineError::NotMedia
    );
}

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use download_engine::components::{Components, FFMPEG};
use library::{Library, WorkLimits};
use storage::{MediaKind, MediaQuery, Storage};

struct Harness {
    library: Library,
    storage: Arc<Mutex<Storage>>,
    changes: Arc<AtomicUsize>,
    _dir: tempfile::TempDir,
    root: PathBuf,
}

fn harness_with(components: Components) -> Harness {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().join("Videos");
    std::fs::create_dir_all(&root).unwrap();
    let storage = Arc::new(Mutex::new(Storage::open_in_memory().unwrap()));
    let changes = Arc::new(AtomicUsize::new(0));
    let counter = changes.clone();
    let library = Library::new(
        storage.clone(),
        components,
        dir.path().join("thumbs"),
        Arc::new(move || {
            counter.fetch_add(1, Ordering::SeqCst);
        }),
    );
    Harness {
        library,
        storage,
        changes,
        _dir: dir,
        root,
    }
}

fn harness() -> Harness {
    let empty = tempfile::tempdir().unwrap().keep();
    harness_with(Components::new(empty).unwrap())
}

fn titles(h: &Harness) -> Vec<String> {
    let mut t: Vec<String> = h
        .storage
        .lock()
        .unwrap()
        .query_media(&MediaQuery::default())
        .unwrap()
        .items
        .into_iter()
        .map(|m| m.title)
        .collect();
    t.sort();
    t
}

#[test]
fn scan_adds_marks_missing_and_restores() {
    let h = harness();
    std::fs::write(h.root.join("Sintel.mp4"), b"video").unwrap();
    std::fs::write(h.root.join("Clair de Lune.flac"), b"audio").unwrap();
    std::fs::write(h.root.join("x.mp4.123.part"), b"partial").unwrap();

    let report = h.library.scan(&h.root).unwrap();
    assert_eq!((report.added, report.missing), (2, 0));
    assert_eq!(titles(&h), ["Clair de Lune", "Sintel"]);
    assert_eq!(
        h.library.scan(&h.root).unwrap(),
        Default::default(),
        "idempotent"
    );

    std::fs::rename(
        h.root.join("Sintel.mp4"),
        h.root.join("..").join("away.mp4"),
    )
    .unwrap();
    assert_eq!(h.library.scan(&h.root).unwrap().missing, 1);
    assert_eq!(titles(&h), ["Clair de Lune"]);

    std::fs::rename(
        h.root.join("..").join("away.mp4"),
        h.root.join("Sintel.mp4"),
    )
    .unwrap();
    assert_eq!(h.library.scan(&h.root).unwrap().restored, 1);
    assert_eq!(titles(&h).len(), 2);
    assert!(h.changes.load(Ordering::SeqCst) >= 3);
}

#[test]
fn downloads_are_added_with_their_source() {
    let h = harness();
    let file = h.root.join("trailer.mov");
    std::fs::write(&file, vec![0u8; 1234]).unwrap();
    let record = h
        .library
        .add_download(
            &file,
            "download.blender.org",
            "https://download.blender.org/x.mov",
            "t1",
        )
        .unwrap()
        .unwrap();
    assert_eq!(record.kind, MediaKind::Video);
    assert_eq!(record.size_bytes, 1234);
    assert_eq!(record.source_host.as_deref(), Some("download.blender.org"));
    // Non-media files are ignored.
    let txt = h.root.join("notes.txt");
    std::fs::write(&txt, b"x").unwrap();
    assert!(
        h.library
            .add_download(&txt, "a", "b", "t2")
            .unwrap()
            .is_none()
    );
}

#[test]
fn rename_sanitizes_and_never_overwrites() {
    let h = harness();
    std::fs::write(h.root.join("a.mp4"), b"A").unwrap();
    std::fs::write(h.root.join("Taken.mp4"), b"B").unwrap();
    h.library.scan(&h.root).unwrap();
    let id = h
        .storage
        .lock()
        .unwrap()
        .media_by_path(&h.root.join("a.mp4").to_string_lossy())
        .unwrap()
        .unwrap()
        .id;

    let renamed = h.library.rename(id, "../Taken").unwrap();
    assert_eq!(
        Path::new(&renamed.path).parent().unwrap(),
        h.root,
        "stays in its folder"
    );
    // "../Taken": separators replaced, leading dots trimmed.
    assert_eq!(Path::new(&renamed.path).file_name().unwrap(), "_Taken.mp4");
    assert_eq!(
        std::fs::read(h.root.join("Taken.mp4")).unwrap(),
        b"B",
        "existing file untouched"
    );
    assert!(!h.root.join("a.mp4").exists());
}

#[test]
fn delete_removes_the_file_and_the_entry() {
    let h = harness();
    let file = h.root.join("gone.mp3");
    std::fs::write(&file, b"x").unwrap();
    h.library.scan(&h.root).unwrap();
    let id = h
        .storage
        .lock()
        .unwrap()
        .media_by_path(&file.to_string_lossy())
        .unwrap()
        .unwrap()
        .id;
    h.library.delete(id).unwrap();
    assert!(!file.exists());
    assert!(titles(&h).is_empty());
}

#[test]
fn check_detects_vanished_files() {
    let h = harness();
    let file = h.root.join("v.webm");
    std::fs::write(&file, b"x").unwrap();
    h.library.scan(&h.root).unwrap();
    let id = h
        .storage
        .lock()
        .unwrap()
        .media_by_path(&file.to_string_lossy())
        .unwrap()
        .unwrap()
        .id;
    std::fs::remove_file(&file).unwrap();
    assert!(h.library.check(id).unwrap().missing);
}

/// Real ffprobe/ffmpeg: set MIARINA_COMPONENTS_DIR to an installed
/// components folder (see download-engine tests/ytdlp_live.rs).
#[tokio::test]
#[ignore = "needs the FFmpeg component installed"]
async fn worker_reads_metadata_and_builds_thumbnails() {
    let components = Components::new(PathBuf::from(
        std::env::var("MIARINA_COMPONENTS_DIR").expect("MIARINA_COMPONENTS_DIR"),
    ))
    .unwrap();
    let ffmpeg = components.path(&FFMPEG).expect("FFmpeg installed");
    let h = harness_with(components);
    // Generate a 3 s test clip and a 2 s tone with FFmpeg itself.
    let clip = h.root.join("clip.mp4");
    let tone = h.root.join("tone.mp3");
    for args in [
        vec![
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=3:size=640x360:rate=10",
            "-f",
            "lavfi",
            "-i",
            "sine=duration=3",
            "-shortest",
            "-c:v",
            "mpeg4",
            "-c:a",
            "aac",
        ],
        vec!["-f", "lavfi", "-i", "sine=duration=2", "-c:a", "libmp3lame"],
    ] {
        let out = if args.len() > 6 { &clip } else { &tone };
        let status = std::process::Command::new(&ffmpeg)
            .args(["-hide_banner", "-loglevel", "error", "-y"])
            .args(&args)
            .arg(out)
            .status()
            .unwrap();
        assert!(status.success());
    }
    h.library.set_limits(WorkLimits {
        max_conversions: 2,
        thumbnail_px: 240,
        ffmpeg_threads: 1,
    });
    h.library.scan(&h.root).unwrap();
    h.library.process_pending().await;

    let storage = h.storage.lock().unwrap();
    let clip = storage
        .media_by_path(&clip.to_string_lossy())
        .unwrap()
        .unwrap();
    assert!(clip.probed);
    assert_eq!((clip.width, clip.height), (Some(640), Some(360)));
    assert!((clip.duration_secs.unwrap() - 3.0).abs() < 0.2);
    let thumb = clip.thumbnail.expect("thumbnail");
    assert!(Path::new(&thumb).is_file());
    let tone = storage
        .media_by_path(&tone.to_string_lossy())
        .unwrap()
        .unwrap();
    assert_eq!(tone.kind, MediaKind::Audio);
    assert!(tone.thumbnail.is_none());
    assert!(storage.media_to_probe(10).unwrap().is_empty());
}

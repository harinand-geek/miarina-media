use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use download_engine::components::{Components, FFMPEG};
use library::{Library, WorkLimits};
use storage::{MediaKind, MediaQuery, MediaTags, Storage};

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
    // Tests must not fill the developer's Recycle Bin.
    library.set_use_trash(false);
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
            None,
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
            .add_download(&txt, "a", "b", "t2", None)
            .unwrap()
            .is_none()
    );
}

#[test]
fn source_thumbnails_are_adopted_and_others_refused() {
    let h = harness();
    let sources = h.library.source_thumbnails_dir();
    std::fs::create_dir_all(&sources).unwrap();
    let picture = sources.join("0123456789abcdef.jpg");
    std::fs::write(&picture, [0xFF, 0xD8, 0xFF, 0xE0]).unwrap();
    assert!(h.library.is_source_thumbnail(&picture));

    let file = h.root.join("song.m4a");
    std::fs::write(&file, b"audio").unwrap();
    let record = h
        .library
        .add_download(
            &file,
            "example.org",
            "https://example.org/a",
            "t1",
            Some(&picture),
        )
        .unwrap()
        .unwrap();
    let own = PathBuf::from(record.thumbnail.expect("picture adopted"));
    assert_eq!(own.parent(), Some(h.library.thumbnails_dir()));
    assert_ne!(
        own, picture,
        "copied, so deleting the entry keeps the source"
    );
    h.library.delete(record.id).unwrap();
    assert!(picture.is_file());

    // Anything outside the source folder (or not a picture) is refused.
    let outside = h.root.join("evil.jpg");
    std::fs::write(&outside, [0xFF, 0xD8, 0xFF]).unwrap();
    let not_picture = sources.join("x.exe");
    std::fs::write(&not_picture, b"MZ").unwrap();
    let traversal = sources
        .join("..")
        .join("..")
        .join("Videos")
        .join("evil.jpg");
    for path in [
        &outside,
        &not_picture,
        &traversal,
        &sources.join("gone.jpg"),
    ] {
        assert!(!h.library.is_source_thumbnail(path), "{}", path.display());
    }
    let file = h.root.join("other.m4a");
    std::fs::write(&file, b"audio").unwrap();
    let record = h
        .library
        .add_download(
            &file,
            "example.org",
            "https://example.org/b",
            "t2",
            Some(&outside),
        )
        .unwrap()
        .unwrap();
    assert_eq!(record.thumbnail, None);
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
fn remove_keeps_the_file_and_scans_do_not_add_it_back() {
    let h = harness();
    let file = h.root.join("kept.mp3");
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
    h.library.remove(id).unwrap();
    assert!(file.exists());
    assert!(titles(&h).is_empty());
    assert_eq!(h.library.scan(&h.root).unwrap(), Default::default());
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

/// Stands in for Android's MediaMetadataRetriever.
struct FakeProber {
    asked_thumbnail: Mutex<Vec<bool>>,
}

impl library::Prober for FakeProber {
    fn probe<'a>(
        &'a self,
        media: &'a Path,
        thumbnail: Option<&'a Path>,
        _max_px: u32,
    ) -> library::ProbeFuture<'a> {
        Box::pin(async move {
            self.asked_thumbnail
                .lock()
                .unwrap()
                .push(thumbnail.is_some());
            if media.to_string_lossy().contains("broken") {
                return Err(library::LibraryError::Probe("unreadable".into()));
            }
            if let Some(out) = thumbnail {
                std::fs::write(out, [0xFF, 0xD8, 0xFF]).unwrap();
            }
            Ok(library::ProbeResult {
                probe: storage::MediaProbe {
                    duration_secs: Some(52.2),
                    width: Some(854),
                    height: Some(480),
                    video_codec: Some("h264".into()),
                    audio_codec: Some("aac".into()),
                    container: Some("mp4".into()),
                    has_video: true,
                },
                thumbnail_written: thumbnail.is_some(),
            })
        })
    }
}

#[tokio::test]
async fn a_platform_prober_replaces_ffmpeg() {
    let h = harness();
    std::fs::write(h.root.join("Sintel.mp4"), b"video").unwrap();
    std::fs::write(h.root.join("broken.bad.mp4"), b"x").unwrap();
    h.library.scan(&h.root).unwrap();
    let prober = Arc::new(FakeProber {
        asked_thumbnail: Mutex::new(Vec::new()),
    });
    h.library.set_prober(prober.clone());
    h.library.process_pending().await;

    let items = h
        .storage
        .lock()
        .unwrap()
        .query_media(&MediaQuery::default())
        .unwrap()
        .items;
    let sintel = items.iter().find(|m| m.title == "Sintel").unwrap();
    assert!(sintel.probed);
    assert_eq!(sintel.duration_secs, Some(52.2));
    assert_eq!(sintel.height, Some(480));
    let thumb = PathBuf::from(sintel.thumbnail.as_deref().expect("thumbnail stored"));
    assert!(thumb.starts_with(h.library.thumbnails_dir()) && thumb.is_file());
    // An unreadable file is marked, so it is not retried on every start.
    let broken = items
        .iter()
        .find(|m| m.title.starts_with("broken"))
        .unwrap();
    assert!(broken.probed && broken.thumbnail.is_none());
    assert_eq!(*prober.asked_thumbnail.lock().unwrap(), [true, true]);
}

/// Smallest valid PCM WAV (lofty can tag it with ID3v2).
fn write_wav(path: &Path) {
    let samples = vec![0u8; 1600];
    let mut wav = Vec::new();
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + samples.len() as u32).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16u32.to_le_bytes());
    wav.extend_from_slice(&1u16.to_le_bytes()); // PCM
    wav.extend_from_slice(&1u16.to_le_bytes()); // mono
    wav.extend_from_slice(&8000u32.to_le_bytes());
    wav.extend_from_slice(&16000u32.to_le_bytes());
    wav.extend_from_slice(&2u16.to_le_bytes());
    wav.extend_from_slice(&16u16.to_le_bytes());
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&(samples.len() as u32).to_le_bytes());
    wav.extend_from_slice(&samples);
    std::fs::write(path, wav).unwrap();
}

fn id_of(h: &Harness, path: &Path) -> i64 {
    h.storage
        .lock()
        .unwrap()
        .media_by_path(&path.to_string_lossy())
        .unwrap()
        .unwrap()
        .id
}

fn sample_tags() -> MediaTags {
    MediaTags {
        title: Some("Hira vaovao".into()),
        artist: Some("Ankorabe Sound".into()),
        album: Some("Tany Maitso".into()),
        album_artist: Some("Ankorabe Sound".into()),
        year: Some(2024),
        genre: Some("Hira gasy".into()),
        track_no: Some(3),
        disc_no: Some(1),
        comment: Some("Test".into()),
        lyrics: Some("Tononkira".into()),
    }
}

#[test]
fn tags_are_written_through_a_copy_and_read_back() {
    let h = harness();
    let file = h.root.join("01 hira.wav");
    write_wav(&file);
    h.library.scan(&h.root).unwrap();
    let id = id_of(&h, &file);

    let updated = h.library.update_tags(id, &sample_tags(), true).unwrap();
    assert_eq!(updated.title, "Hira vaovao");
    assert_eq!(updated.album.as_deref(), Some("Tany Maitso"));

    let read = library::tags::read(&file).expect("tags in the file");
    assert_eq!(read.artist.as_deref(), Some("Ankorabe Sound"));
    assert_eq!(read.album_artist.as_deref(), Some("Ankorabe Sound"));
    assert_eq!(read.year, Some(2024));
    assert_eq!(read.track_no, Some(3));
    assert_eq!(read.lyrics.as_deref(), Some("Tononkira"));
    let leftovers: Vec<_> = std::fs::read_dir(&h.root)
        .unwrap()
        .flatten()
        .filter(|e| e.file_name().to_string_lossy().ends_with(".tmp"))
        .collect();
    assert!(leftovers.is_empty(), "no temporary copy left");
}

#[tokio::test]
async fn tags_read_at_indexing_name_the_track() {
    let h = harness();
    let file = h.root.join("track01.wav");
    write_wav(&file);
    library::tags::write(&file, &sample_tags()).unwrap();
    h.library.scan(&h.root).unwrap();
    h.library.read_pending_tags().await;
    assert_eq!(titles(&h), ["Hira vaovao"]);
    let tags = h.library.tags(id_of(&h, &file)).unwrap();
    assert_eq!(tags.genre.as_deref(), Some("Hira gasy"));
}

#[test]
fn video_tags_stay_in_the_library() {
    let h = harness();
    let file = h.root.join("clip.mp4");
    std::fs::write(&file, b"not really a video").unwrap();
    h.library.scan(&h.root).unwrap();
    let id = id_of(&h, &file);
    assert!(h.library.update_tags(id, &sample_tags(), true).is_err());
    assert_eq!(h.library.tags(id).unwrap().artist, None, "nothing saved");
    let saved = h.library.update_tags(id, &sample_tags(), false).unwrap();
    assert_eq!(saved.artist.as_deref(), Some("Ankorabe Sound"));
    assert_eq!(std::fs::read(&file).unwrap(), b"not really a video");
}

#[tokio::test]
async fn covers_are_checked_before_ffmpeg_runs() {
    let h = harness();
    let song = h.root.join("song.wav");
    write_wav(&song);
    let clip = h.root.join("clip.mp4");
    std::fs::write(&clip, b"not really a video").unwrap();
    h.library.scan(&h.root).unwrap();
    let (song, clip) = (id_of(&h, &song), id_of(&h, &clip));

    let text = h.root.join("notes.txt");
    std::fs::write(&text, b"hello").unwrap();
    let refused = |r: Result<storage::MediaRecord, library::LibraryError>| {
        matches!(r, Err(library::LibraryError::Cover(_)))
    };
    assert!(
        refused(h.library.cover_from_image(song, &text).await),
        "not a picture"
    );
    let picture = h.root.join("cover.png");
    std::fs::write(&picture, b"").unwrap();
    assert!(
        refused(h.library.cover_from_image(song, &picture).await),
        "empty file"
    );
    std::fs::write(&picture, b"png").unwrap();
    assert!(
        refused(h.library.cover_from_image(song, &picture).await),
        "FFmpeg is not installed here"
    );
    assert!(
        refused(h.library.cover_from_frame(song, 1.0).await),
        "audio has no frames"
    );
    assert!(
        refused(h.library.cover_from_source(clip).await),
        "not downloaded"
    );
    assert!(!h.library.has_source_thumbnail(clip));
    assert!(
        std::fs::read_dir(h.library.covers_dir()).map_or(true, |mut d| d.next().is_none()),
        "nothing left behind"
    );
}

#[test]
fn removing_a_cover_deletes_only_our_picture() {
    let h = harness();
    let clip = h.root.join("clip.mp4");
    std::fs::write(&clip, b"not really a video").unwrap();
    h.library.scan(&h.root).unwrap();
    let id = id_of(&h, &clip);
    let covers = h.library.covers_dir();
    std::fs::create_dir_all(&covers).unwrap();
    let chosen = covers.join(format!("{id}-1.jpg"));
    std::fs::write(&chosen, b"jpeg").unwrap();
    h.storage
        .lock()
        .unwrap()
        .set_media_cover(id, Some(&chosen.to_string_lossy()))
        .unwrap();

    let before = h.changes.load(Ordering::SeqCst);
    let record = h.library.remove_cover(id).unwrap();
    assert_eq!((record.thumbnail, record.cover_custom), (None, true));
    assert!(!chosen.exists(), "our cover is deleted");
    assert!(h.changes.load(Ordering::SeqCst) > before, "the UI is told");

    // A picture outside our folders (e.g. next to the media) is never deleted.
    let outside = h.root.join("folder.jpg");
    std::fs::write(&outside, b"jpeg").unwrap();
    h.storage
        .lock()
        .unwrap()
        .set_media_cover(id, Some(&outside.to_string_lossy()))
        .unwrap();
    h.library.remove_cover(id).unwrap();
    assert!(outside.exists());
}

#[test]
fn opened_files_are_indexed_even_after_removal() {
    let h = harness();
    let song = h.root.join("song.wav");
    write_wav(&song);
    let notes = h.root.join("notes.txt");
    std::fs::write(&notes, b"x").unwrap();
    h.library.scan(&h.root).unwrap();
    let id = id_of(&h, &song);
    h.library.remove(id).unwrap();
    // A scan respects the removal; opening the file on purpose does not.
    h.library.scan(&h.root).unwrap();
    assert!(titles(&h).is_empty());

    let opened = h
        .library
        .add_opened(&[notes.clone(), song.clone(), h.root.join("gone.mp3")])
        .unwrap();
    assert_eq!(opened.len(), 1, "only existing media files");
    assert_eq!(opened[0].path, song.to_string_lossy());
    h.library.scan(&h.root).unwrap();
    assert_eq!(titles(&h).len(), 1, "no longer skipped by scans");
}

#[test]
fn a_large_folder_is_indexed_quickly() {
    let h = harness();
    for i in 0..2000 {
        std::fs::write(h.root.join(format!("clip {i}.mp4")), b"x").unwrap();
    }
    let started = std::time::Instant::now();
    let report = h.library.scan(&h.root).unwrap();
    assert_eq!(report.added, 2000);
    // One transaction (was one commit per file); generous for debug builds.
    assert!(started.elapsed().as_secs() < 20, "{:?}", started.elapsed());
    // A second scan finds them all known (hash lookup, no new rows).
    assert_eq!(h.library.scan(&h.root).unwrap().added, 0);
}

#[test]
fn listed_files_are_indexed_and_vanished_ones_marked_missing() {
    let h = harness();
    let phone = h.root.join("..").join("Phone");
    std::fs::create_dir_all(&phone).unwrap();
    let song = phone.join("Song.mp3");
    let clip = phone.join("Clip.mp4");
    let removed = phone.join("Removed.mp3");
    for f in [&song, &clip, &removed] {
        std::fs::write(f, b"x").unwrap();
    }
    // A downloaded file of the app's own folder, not in the platform list.
    let own = h.root.join("Own.mp3");
    std::fs::write(&own, b"x").unwrap();
    h.library.scan(&h.root).unwrap();

    let listed = vec![
        song.clone(),
        song.clone(),
        clip.clone(),
        removed.clone(),
        phone.join("gone.mp3"),
        phone.join("notes.txt"),
        PathBuf::from("relative.mp3"),
    ];
    let report = h.library.sync_listed(&listed).unwrap();
    assert_eq!((report.added, report.missing), (3, 0));
    assert_eq!(titles(&h), ["Clip", "Own", "Removed", "Song"]);

    // Removed from the library: never added back by later lists.
    let removed_id = id_of(&h, &removed);
    h.library.remove(removed_id).unwrap();
    assert_eq!(h.library.sync_listed(&listed).unwrap(), Default::default());

    // The song is deleted on the phone: missing; the own file, absent from
    // the list but present, is kept.
    std::fs::remove_file(&song).unwrap();
    let report = h.library.sync_listed(std::slice::from_ref(&clip)).unwrap();
    assert_eq!((report.added, report.missing), (0, 1));
    assert_eq!(titles(&h), ["Clip", "Own"]);

    // Back on the phone: restored.
    std::fs::write(&song, b"x").unwrap();
    assert_eq!(
        h.library
            .sync_listed(&[song.clone(), clip])
            .unwrap()
            .restored,
        1
    );
    assert_eq!(titles(&h), ["Clip", "Own", "Song"]);
}

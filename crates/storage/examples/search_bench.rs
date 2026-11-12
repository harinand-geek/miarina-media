//! L00 measurement: library search with 10 000 entries (CDC §13: p95
//! ≤ 500 ms, index ready).
//!
//! `cargo run --release -p storage --example search_bench`
//!
//! Builds a library on disk in a temporary folder (realistic titles,
//! artists, albums, folders), then times every keystroke of a few searches
//! (the UI searches as the user types) on the first page of results.

use std::time::Instant;

use storage::{MediaKind, MediaQuery, MediaSort, MediaTags, NewMedia, Storage};

const ENTRIES: usize = 10_000;

fn main() {
    let dir = std::env::temp_dir().join(format!("miarina-search-bench-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("temp dir");
    let db = dir.join("bench.db");
    let storage = Storage::open(&db).expect("open");

    let words = [
        "sunset",
        "rivière",
        "concert",
        "été",
        "nuit",
        "voyage",
        "piano",
        "Antananarivo",
        "cover",
        "live",
        "remix",
        "documentaire",
        "lecture",
        "orage",
        "marché",
    ];
    let artists = [
        "Tsiory",
        "Ankorabe Sound",
        "Erik Satie",
        "NASA",
        "Mahaleo",
        "Rossy",
    ];
    let started = Instant::now();
    // One transaction, as library scans do since L00.
    storage
        .with_batch(|storage| {
            for i in 0..ENTRIES {
                let kind = if i % 3 == 0 {
                    MediaKind::Video
                } else {
                    MediaKind::Audio
                };
                let title = format!(
                    "{} {} {} {i}",
                    words[i % words.len()],
                    words[(i / 7) % words.len()],
                    words[(i / 31) % words.len()]
                );
                let record = storage
                    .upsert_media(&NewMedia {
                        path: format!(
                            "C:/Media/{}/{}/{title}.mp3",
                            artists[i % artists.len()],
                            i / 100
                        ),
                        title: title.clone(),
                        kind,
                        source_host: None,
                        source_url: None,
                        task_id: None,
                        size_bytes: 1_000_000 + i as u64,
                    })
                    .expect("insert");
                if kind == MediaKind::Audio {
                    storage
                        .update_media_tags(
                            record.id,
                            &MediaTags {
                                artist: Some(artists[i % artists.len()].into()),
                                album: Some(format!("Album {}", i / 12)),
                                ..Default::default()
                            },
                        )
                        .expect("tags");
                }
            }
            Ok(())
        })
        .expect("batch");
    println!("{ENTRIES} entries indexed in {:?}", started.elapsed());

    let searches = [
        "antananarivo",
        "piano nuit",
        "tsiory",
        "album 42",
        "été",
        "zzz-nothing",
    ];
    let mut times = Vec::new();
    for search in searches {
        let chars: Vec<char> = search.chars().collect();
        for n in 1..=chars.len() {
            let typed: String = chars[..n].iter().collect();
            let t = Instant::now();
            let page = storage
                .query_media(&MediaQuery {
                    search: typed.clone(),
                    sort: MediaSort::Title,
                    limit: 100,
                    ..Default::default()
                })
                .expect("query");
            let ms = t.elapsed().as_secs_f64() * 1000.0;
            times.push(ms);
            if n == chars.len() {
                println!("{typed:>14}: {:>5} results, {ms:.1} ms", page.total);
            }
        }
    }
    times.sort_by(|a, b| a.total_cmp(b));
    let pct = |p: f64| times[((p / 100.0) * times.len() as f64).ceil() as usize - 1];
    println!(
        "{} keystrokes: p50 {:.1} ms, p95 {:.1} ms, max {:.1} ms",
        times.len(),
        pct(50.0),
        pct(95.0),
        times[times.len() - 1]
    );
    drop(storage);
    let _ = std::fs::remove_dir_all(&dir);
}

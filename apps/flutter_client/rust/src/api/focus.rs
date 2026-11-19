//! Focus space (handoff W-F1 / W-F2): podcasts, courses and audiobooks
//! sorted from the library's audio entries with the rules of
//! [`crate::focus`]. Read-only.

use std::collections::HashMap;
use std::path::Path;

use anyhow::Result;
use storage::{MediaKind, MediaQuery, MediaRecord, MediaSort, Storage};

use super::library::{LibraryItem, item, with_db};
use crate::focus::{self, Kind};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FocusKind {
    Podcast,
    Course,
    Audiobook,
}

impl From<Kind> for FocusKind {
    fn from(k: Kind) -> Self {
        match k {
            Kind::Podcast => Self::Podcast,
            Kind::Course => Self::Course,
            Kind::Audiobook => Self::Audiobook,
        }
    }
}

pub struct FocusItem {
    pub item: LibraryItem,
    pub kind: FocusKind,
    /// Show, course or book it belongs to.
    pub program: String,
    /// 1-based place in the program, in play order.
    pub number: u32,
    /// Number of items of the program.
    pub of: u32,
    /// Milliseconds since the epoch.
    pub added_at: i64,
}

pub struct FocusProgram {
    pub name: String,
    pub kind: FocusKind,
    pub artist: Option<String>,
    pub count: u32,
    pub duration_secs: f64,
    pub thumbnail: Option<String>,
    pub latest_added: i64,
}

pub struct FocusLibrary {
    /// Alphabetical.
    pub programs: Vec<FocusProgram>,
    pub podcast_count: u32,
    pub course_count: u32,
    pub audiobook_count: u32,
    pub duration_secs: f64,
}

fn file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

/// Every Focus file, grouped by program and in play order.
fn programs(db: &Storage) -> Result<Vec<(String, FocusKind, Vec<MediaRecord>)>> {
    let page = db.query_media(&MediaQuery {
        kind: Some(MediaKind::Audio),
        sort: MediaSort::Added,
        ..MediaQuery::default()
    })?;
    let mut groups: HashMap<(String, Kind), (String, Vec<MediaRecord>)> = HashMap::new();
    for m in page.items {
        let Some(kind) = focus::classify(m.genre.as_deref(), &m.path) else {
            continue;
        };
        let name = focus::program(
            kind,
            m.album.as_deref(),
            m.artist.as_deref(),
            &m.path,
            &m.title,
        );
        groups
            .entry((name.to_lowercase(), kind))
            .or_insert_with(|| (name, Vec::new()))
            .1
            .push(m);
    }
    let mut out: Vec<_> = groups
        .into_iter()
        .map(|((_, kind), (name, mut items))| {
            items.sort_by(|a, b| {
                (a.disc_no.unwrap_or(0), a.track_no.unwrap_or(u32::MAX))
                    .cmp(&(b.disc_no.unwrap_or(0), b.track_no.unwrap_or(u32::MAX)))
                    .then_with(|| focus::natural_cmp(&file_name(&a.path), &file_name(&b.path)))
            });
            (name, kind.into(), items)
        })
        .collect();
    out.sort_by_key(|p| p.0.to_lowercase());
    Ok(out)
}

fn focus_item(
    program: &str,
    kind: FocusKind,
    number: usize,
    of: usize,
    m: MediaRecord,
) -> FocusItem {
    FocusItem {
        kind,
        program: program.to_owned(),
        number: number as u32 + 1,
        of: of as u32,
        added_at: m.added_at,
        item: item(m),
    }
}

/// Programs of the Focus space with their counters.
pub fn focus_library(db_path: String) -> Result<FocusLibrary> {
    with_db(&db_path, |db| {
        let mut lib = FocusLibrary {
            programs: Vec::new(),
            podcast_count: 0,
            course_count: 0,
            audiobook_count: 0,
            duration_secs: 0.0,
        };
        for (name, kind, items) in programs(db)? {
            match kind {
                FocusKind::Podcast => lib.podcast_count += 1,
                FocusKind::Course => lib.course_count += 1,
                FocusKind::Audiobook => lib.audiobook_count += 1,
            }
            let duration: f64 = items.iter().filter_map(|m| m.duration_secs).sum();
            lib.duration_secs += duration;
            lib.programs.push(FocusProgram {
                artist: items
                    .iter()
                    .find_map(|m| m.album_artist.clone().or(m.artist.clone())),
                count: items.len() as u32,
                duration_secs: duration,
                thumbnail: items.iter().find_map(|m| m.thumbnail.clone()),
                latest_added: items.iter().map(|m| m.added_at).max().unwrap_or_default(),
                name,
                kind,
            });
        }
        Ok(lib)
    })
}

/// Items of one program, in play order (empty when it no longer exists).
pub fn focus_program(db_path: String, name: String) -> Result<Vec<FocusItem>> {
    with_db(&db_path, |db| {
        let key = name.to_lowercase();
        for (program, kind, items) in programs(db)? {
            if program.to_lowercase() == key {
                let of = items.len();
                return Ok(items
                    .into_iter()
                    .enumerate()
                    .map(|(i, m)| focus_item(&program, kind, i, of, m))
                    .collect());
            }
        }
        Ok(Vec::new())
    })
}

/// One Focus item by library id; None for music or a removed entry.
pub fn focus_entry(db_path: String, media_id: i64) -> Result<Option<FocusItem>> {
    with_db(&db_path, |db| {
        let m = match db.media(media_id) {
            Ok(m) => m,
            Err(storage::StorageError::NotFound(_)) => return Ok(None),
            Err(e) => return Err(e.into()),
        };
        if m.kind != MediaKind::Audio {
            return Ok(None);
        }
        let Some(kind) = focus::classify(m.genre.as_deref(), &m.path) else {
            return Ok(None);
        };
        let name = focus::program(
            kind,
            m.album.as_deref(),
            m.artist.as_deref(),
            &m.path,
            &m.title,
        );
        for (program, kind, items) in programs(db)? {
            if program.to_lowercase() != name.to_lowercase() {
                continue;
            }
            let of = items.len();
            if let Some(i) = items.iter().position(|x| x.id == media_id) {
                let m = items.into_iter().nth(i).expect("position found above");
                return Ok(Some(focus_item(&program, kind, i, of, m)));
            }
        }
        Ok(None)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use storage::{MediaTags, NewMedia};

    fn add(db: &Storage, path: &str) -> i64 {
        db.upsert_media(&NewMedia {
            path: path.into(),
            title: Path::new(path)
                .file_stem()
                .unwrap()
                .to_string_lossy()
                .into_owned(),
            kind: MediaKind::Audio,
            source_host: None,
            source_url: None,
            task_id: None,
            size_bytes: 1,
        })
        .unwrap()
        .id
    }

    #[test]
    fn groups_courses_podcasts_and_books_in_play_order() {
        let dir = std::env::temp_dir().join(format!("mm-focus-db-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let db_path = dir.join("miarina.db").to_string_lossy().into_owned();
        let mut ids = Vec::new();
        with_db(&db_path, |db| {
            ids.push(add(db, "D:/Cours/Architecture/Cours 10 - Sécurité.mp3"));
            ids.push(add(db, "D:/Cours/Architecture/Cours 2 - Processus.mp3"));
            ids.push(add(db, "D:/Cours/Architecture/Cours 1 - Intro.mp3"));
            add(db, "D:/Musique/Album/01.flac");
            add(db, "D:/Livres audio/Le Petit Prince.m4b");
            let ep = add(db, "D:/Téléchargements/episode-12.mp3");
            db.update_media_tags(
                ep,
                &MediaTags {
                    genre: Some("Podcast".into()),
                    album: Some("Radio Miarina".into()),
                    ..MediaTags::default()
                },
            )
            .unwrap();
            Ok(())
        })
        .unwrap();

        let lib = focus_library(db_path.clone()).unwrap();
        let names: Vec<_> = lib
            .programs
            .iter()
            .map(|p| (p.name.as_str(), p.kind, p.count))
            .collect();
        assert_eq!(
            names,
            [
                ("Architecture", FocusKind::Course, 3),
                // Straight in the category folder: named after the file.
                ("Le Petit Prince", FocusKind::Audiobook, 1),
                ("Radio Miarina", FocusKind::Podcast, 1),
            ]
        );
        assert_eq!(
            (lib.course_count, lib.podcast_count, lib.audiobook_count),
            (1, 1, 1)
        );

        let course = focus_program(db_path.clone(), "architecture".into()).unwrap();
        let order: Vec<_> = course
            .iter()
            .map(|i| (i.number, i.item.title.as_str()))
            .collect();
        assert_eq!(
            order,
            [
                (1, "Cours 1 - Intro"),
                (2, "Cours 2 - Processus"),
                (3, "Cours 10 - Sécurité")
            ]
        );
        let one = focus_entry(db_path.clone(), ids[1]).unwrap().unwrap();
        assert_eq!(
            (one.number, one.of, one.program.as_str()),
            (2, 3, "Architecture")
        );
        assert!(focus_entry(db_path, 999).unwrap().is_none());
        let _ = std::fs::remove_dir_all(&dir);
    }
}

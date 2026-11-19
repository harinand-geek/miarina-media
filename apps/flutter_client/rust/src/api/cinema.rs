//! Cinema space (handoff W-C1 / W-C2): films, series and personal videos,
//! sorted from the library's video entries with the rules of
//! [`crate::cinema`]. Read-only: nothing is written to the database.

use std::collections::{BTreeSet, HashMap};
use std::path::Path;

use anyhow::Result;
use storage::{MediaKind, MediaQuery, MediaRecord, MediaSort, Storage};

use super::library::{LibraryItem, item, with_db};
use crate::cinema::{self, FILM_MIN_SECS};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CinemaKind {
    Film,
    Episode,
    Personal,
}

pub struct CinemaItem {
    pub item: LibraryItem,
    pub kind: CinemaKind,
    /// Series name (episodes only).
    pub series: Option<String>,
    pub season: Option<u32>,
    pub episode: Option<u32>,
    pub episode_title: Option<String>,
    pub year: Option<i32>,
    pub genre: Option<String>,
    /// Milliseconds since the epoch.
    pub added_at: i64,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub video_codec: Option<String>,
    /// Local poster of a film, when the folder has one.
    pub poster: Option<String>,
    /// Languages of the subtitle files next to the video ("FR"); filled by
    /// [`cinema_series`] only.
    pub subtitle_languages: Vec<String>,
}

pub struct SeriesSummary {
    pub name: String,
    pub seasons: u32,
    pub episodes: u32,
    /// Local poster of the series folder.
    pub poster: Option<String>,
    /// Picture of the first episode, when there is no poster.
    pub thumbnail: Option<String>,
    pub year: Option<i32>,
    pub latest_added: i64,
}

pub struct CinemaLibrary {
    /// Alphabetical.
    pub films: Vec<CinemaItem>,
    /// Alphabetical.
    pub series: Vec<SeriesSummary>,
    /// Newest first.
    pub personal: Vec<CinemaItem>,
}

pub struct SeriesDetail {
    pub name: String,
    pub poster: Option<String>,
    /// Local 16:9 background (fanart.jpg…), else a picture of an episode.
    pub backdrop: Option<String>,
    /// From a local tvshow.nfo; None hides the line.
    pub plot: Option<String>,
    pub year: Option<i32>,
    pub genre: Option<String>,
    /// By season, then episode.
    pub episodes: Vec<CinemaItem>,
    /// Languages of subtitle files next to the episodes ("FR", "EN").
    pub subtitle_languages: Vec<String>,
    /// Formats of those files ("SRT", "ASS").
    pub subtitle_formats: Vec<String>,
    /// "1080p HEVC", from the first probed episode.
    pub video_label: Option<String>,
}

fn file_stem(path: &str) -> String {
    Path::new(path)
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn classify(m: MediaRecord) -> CinemaItem {
    let parsed =
        cinema::parse_episode(&file_stem(&m.path)).or_else(|| cinema::parse_episode(&m.title));
    let tagged_series = m.album.clone().filter(|a| !a.trim().is_empty());
    let kind = if parsed.is_some() || tagged_series.is_some() {
        CinemaKind::Episode
    } else if m.duration_secs.is_some_and(|d| d >= FILM_MIN_SECS) {
        CinemaKind::Film
    } else {
        CinemaKind::Personal
    };
    let (series, season, episode, episode_title, parsed_year) = if kind == CinemaKind::Episode {
        let series = tagged_series
            .or_else(|| parsed.as_ref().and_then(|p| p.series.clone()))
            .or_else(|| cinema::series_from_folder(Path::new(&m.path)))
            .unwrap_or_else(|| m.title.clone());
        (
            Some(series),
            m.disc_no.or(parsed.as_ref().map(|p| p.season)).or(Some(1)),
            m.track_no.or(parsed.as_ref().map(|p| p.episode)),
            parsed.as_ref().and_then(|p| p.title.clone()),
            parsed.as_ref().and_then(|p| p.year),
        )
    } else {
        (None, None, None, None, None)
    };
    CinemaItem {
        kind,
        series,
        season,
        episode,
        episode_title,
        year: m.year.or(parsed_year),
        genre: m.genre.clone(),
        added_at: m.added_at,
        width: m.width,
        height: m.height,
        video_codec: m.video_codec.clone(),
        poster: None,
        subtitle_languages: Vec::new(),
        item: item(m),
    }
}

fn all_videos(db: &Storage) -> Result<Vec<CinemaItem>> {
    let page = db.query_media(&MediaQuery {
        kind: Some(MediaKind::Video),
        sort: MediaSort::Added,
        ..MediaQuery::default()
    })?;
    Ok(page.items.into_iter().map(classify).collect())
}

fn series_key(name: &str) -> String {
    name.trim().to_lowercase()
}

fn episode_order(a: &CinemaItem, b: &CinemaItem) -> std::cmp::Ordering {
    (a.season, a.episode, a.item.title.to_lowercase()).cmp(&(
        b.season,
        b.episode,
        b.item.title.to_lowercase(),
    ))
}

fn parent(path: &str) -> String {
    Path::new(path)
        .parent()
        .map(|p| p.to_string_lossy().to_lowercase())
        .unwrap_or_default()
}

/// Films, series and personal videos of the library.
pub fn cinema_library(db_path: String) -> Result<CinemaLibrary> {
    with_db(&db_path, |db| {
        let videos = all_videos(db)?;
        // A poster.jpg / folder.jpg belongs to a film only when the film is
        // the only video of its folder.
        let mut per_folder: HashMap<String, u32> = HashMap::new();
        for v in &videos {
            *per_folder.entry(parent(&v.item.path)).or_default() += 1;
        }

        let mut films = Vec::new();
        let mut personal = Vec::new();
        let mut series: HashMap<String, Vec<CinemaItem>> = HashMap::new();
        for mut v in videos {
            match v.kind {
                CinemaKind::Film => {
                    if !v.item.missing {
                        let own = per_folder.get(&parent(&v.item.path)) == Some(&1);
                        v.poster = cinema::film_poster(Path::new(&v.item.path), own);
                    }
                    films.push(v);
                }
                CinemaKind::Personal => personal.push(v),
                CinemaKind::Episode => {
                    let key = series_key(v.series.as_deref().unwrap_or_default());
                    series.entry(key).or_default().push(v);
                }
            }
        }
        films.sort_by_key(|f| f.item.title.to_lowercase());

        let mut summaries: Vec<SeriesSummary> = series
            .into_values()
            .map(|mut eps| {
                eps.sort_by(episode_order);
                let first = &eps[0];
                let poster = eps
                    .iter()
                    .filter(|e| !e.item.missing)
                    .find_map(|e| cinema::series_folder(Path::new(&e.item.path)))
                    .and_then(|f| cinema::series_poster(&f));
                SeriesSummary {
                    name: first.series.clone().unwrap_or_default(),
                    seasons: eps
                        .iter()
                        .filter_map(|e| e.season)
                        .collect::<BTreeSet<_>>()
                        .len() as u32,
                    episodes: eps.len() as u32,
                    thumbnail: eps.iter().find_map(|e| e.item.thumbnail.clone()),
                    poster,
                    year: eps.iter().filter_map(|e| e.year).min(),
                    latest_added: eps.iter().map(|e| e.added_at).max().unwrap_or_default(),
                }
            })
            .collect();
        summaries.sort_by_key(|s| s.name.to_lowercase());

        Ok(CinemaLibrary {
            films,
            series: summaries,
            personal,
        })
    })
}

fn language_label(raw: &str) -> String {
    // "fr", "en.forced", "pt-br.sdh": the first part, upper-case.
    raw.split(['.', '_']).next().unwrap_or(raw).to_uppercase()
}

/// One series with its episodes; None when no episode carries that name.
pub fn cinema_series(db_path: String, name: String) -> Result<Option<SeriesDetail>> {
    with_db(&db_path, |db| {
        let key = series_key(&name);
        let mut episodes: Vec<CinemaItem> = all_videos(db)?
            .into_iter()
            .filter(|v| {
                v.kind == CinemaKind::Episode
                    && series_key(v.series.as_deref().unwrap_or_default()) == key
            })
            .collect();
        if episodes.is_empty() {
            return Ok(None);
        }
        episodes.sort_by(episode_order);

        let folder = episodes
            .iter()
            .filter(|e| !e.item.missing)
            .find_map(|e| cinema::series_folder(Path::new(&e.item.path)));
        let nfo = folder
            .as_ref()
            .and_then(|f| cinema::read_nfo(&f.join("tvshow.nfo")));

        let mut languages = BTreeSet::new();
        let mut formats = BTreeSet::new();
        for e in episodes.iter_mut().filter(|e| !e.item.missing) {
            let mut own = BTreeSet::new();
            for s in cinema::sidecar_subtitles(Path::new(&e.item.path)) {
                if let Some(l) = s.language.as_deref() {
                    own.insert(language_label(l));
                }
                formats.insert(s.format);
            }
            languages.extend(own.iter().cloned());
            e.subtitle_languages = own.into_iter().collect();
        }

        let video_label = episodes.iter().find(|e| e.height.is_some()).map(|e| {
            let mut parts = Vec::new();
            if let Some(h) = e.height {
                parts.push(format!("{h}p"));
            }
            if let Some(c) = &e.video_codec {
                parts.push(c.to_uppercase());
            }
            parts.join(" ")
        });

        let first = &episodes[0];
        Ok(Some(SeriesDetail {
            name: first.series.clone().unwrap_or(name),
            poster: folder.as_ref().and_then(|f| cinema::series_poster(f)),
            backdrop: folder
                .as_ref()
                .and_then(|f| cinema::series_backdrop(f))
                .or_else(|| episodes.iter().find_map(|e| e.item.thumbnail.clone())),
            plot: nfo.as_ref().and_then(|n| n.plot.clone()),
            year: nfo
                .as_ref()
                .and_then(|n| n.year)
                .or_else(|| episodes.iter().filter_map(|e| e.year).min()),
            genre: nfo
                .as_ref()
                .and_then(|n| n.genre.clone())
                .or_else(|| episodes.iter().find_map(|e| e.genre.clone())),
            subtitle_languages: languages.into_iter().collect(),
            subtitle_formats: formats.into_iter().collect(),
            video_label,
            episodes,
        }))
    })
}

/// One video with its cinema details (player title, next episode).
pub fn cinema_item(db_path: String, media_id: i64) -> Result<Option<CinemaItem>> {
    with_db(&db_path, |db| match db.media(media_id) {
        Ok(m) if m.kind == MediaKind::Video => Ok(Some(classify(m))),
        Ok(_) | Err(storage::StorageError::NotFound(_)) => Ok(None),
        Err(e) => Err(e.into()),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use storage::{MediaProbe, MediaTags, NewMedia};

    fn add(db: &Storage, path: &str, minutes: Option<f64>) -> i64 {
        let m = db
            .upsert_media(&NewMedia {
                path: path.into(),
                title: file_stem(path),
                kind: MediaKind::Video,
                source_host: None,
                source_url: None,
                task_id: None,
                size_bytes: 1,
            })
            .unwrap();
        if let Some(min) = minutes {
            let probe = MediaProbe {
                duration_secs: Some(min * 60.0),
                width: Some(1920),
                height: Some(1080),
                video_codec: Some("hevc".into()),
                has_video: true,
                ..MediaProbe::default()
            };
            db.set_media_probe(m.id, &probe, None).unwrap();
        }
        m.id
    }

    #[test]
    fn sorts_videos_into_films_series_and_personal_videos() {
        let dir = std::env::temp_dir().join(format!("mm-cinema-db-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let db_path = dir.join("miarina.db").to_string_lossy().into_owned();
        with_db(&db_path, |db| {
            add(
                db,
                "D:/Séries/Les Hautes Terres/Saison 1/Les.Hautes.Terres.S01E02.Le.gué.mkv",
                Some(48.0),
            );
            add(
                db,
                "D:/Séries/Les Hautes Terres/Saison 1/Les.Hautes.Terres.S01E01.mkv",
                Some(50.0),
            );
            add(
                db,
                "D:/Séries/Les Hautes Terres/Saison 2/les hautes terres 2x01.mkv",
                Some(47.0),
            );
            add(db, "D:/Films/Le Dernier Ferry.mkv", Some(102.0));
            add(db, "D:/Vidéos/VID_20240512.mp4", Some(3.0));
            add(db, "D:/Vidéos/pas encore analysée.mp4", None);
            let tagged = add(db, "D:/Vidéos/mariage-part1.mp4", Some(60.0));
            db.update_media_tags(
                tagged,
                &MediaTags {
                    album: Some("Mariage de Lova".into()),
                    track_no: Some(1),
                    ..MediaTags::default()
                },
            )
            .unwrap();
            Ok(())
        })
        .unwrap();

        let lib = cinema_library(db_path.clone()).unwrap();
        let films: Vec<_> = lib.films.iter().map(|f| f.item.title.as_str()).collect();
        assert_eq!(films, ["Le Dernier Ferry"]);
        let series: Vec<_> = lib
            .series
            .iter()
            .map(|s| (s.name.as_str(), s.seasons, s.episodes))
            .collect();
        assert_eq!(
            series,
            [("Les Hautes Terres", 2, 3), ("Mariage de Lova", 1, 1)]
        );
        assert_eq!(lib.personal.len(), 2, "short and not yet probed videos");

        let detail = cinema_series(db_path.clone(), "les hautes terres".into())
            .unwrap()
            .unwrap();
        let order: Vec<_> = detail
            .episodes
            .iter()
            .map(|e| (e.season, e.episode, e.episode_title.clone()))
            .collect();
        assert_eq!(
            order,
            [
                (Some(1), Some(1), None),
                (Some(1), Some(2), Some("Le gué".into())),
                (Some(2), Some(1), None),
            ]
        );
        assert_eq!(detail.video_label.as_deref(), Some("1080p HEVC"));
        assert!(
            cinema_series(db_path.clone(), "inconnue".into())
                .unwrap()
                .is_none()
        );

        // The cached connection keeps the file open on Windows: removal is
        // best effort.
        let _ = std::fs::remove_dir_all(&dir);
    }
}

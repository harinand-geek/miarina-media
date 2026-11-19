//! Search of the whole local library (handoff W-02): titles, films, series
//! and Focus content, each tagged with the section it belongs to. Uses the
//! core's full-text index (accent-insensitive, word prefixes).

use anyhow::Result;
use storage::{MediaKind, MediaQuery, MediaSort};

use super::cinema::{CinemaItem, classify};
use super::focus::FocusKind;
use super::library::{LibraryItem, item, with_db};
use crate::focus;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SearchSection {
    Music,
    Cinema,
    Focus,
}

pub struct SearchHit {
    pub item: LibraryItem,
    pub section: SearchSection,
    /// Cinema details of a video.
    pub video: Option<CinemaItem>,
    /// Focus kind and program of a podcast, course or audiobook.
    pub focus_kind: Option<FocusKind>,
    pub program: Option<String>,
}

pub struct SearchResults {
    pub hits: Vec<SearchHit>,
    /// Matches in the library, beyond the returned page too.
    pub total: u64,
}

/// Library entries matching `query` (words, any order), at most `limit`.
/// An empty query returns nothing.
pub fn library_search(db_path: String, query: String, limit: u32) -> Result<SearchResults> {
    if storage::fts_query(&query).is_none() {
        return Ok(SearchResults {
            hits: Vec::new(),
            total: 0,
        });
    }
    with_db(&db_path, |db| {
        let page = db.query_media(&MediaQuery {
            search: query,
            sort: MediaSort::Title,
            limit: limit.clamp(1, 500),
            ..MediaQuery::default()
        })?;
        let hits = page
            .items
            .into_iter()
            .map(|m| {
                if m.kind == MediaKind::Video {
                    let v = classify(m.clone());
                    return SearchHit {
                        item: item(m),
                        section: SearchSection::Cinema,
                        video: Some(v),
                        focus_kind: None,
                        program: None,
                    };
                }
                match focus::classify(m.genre.as_deref(), &m.path) {
                    Some(kind) => SearchHit {
                        program: Some(focus::program(
                            kind,
                            m.album.as_deref(),
                            m.artist.as_deref(),
                            &m.path,
                            &m.title,
                        )),
                        focus_kind: Some(kind.into()),
                        section: SearchSection::Focus,
                        video: None,
                        item: item(m),
                    },
                    None => SearchHit {
                        item: item(m),
                        section: SearchSection::Music,
                        video: None,
                        focus_kind: None,
                        program: None,
                    },
                }
            })
            .collect();
        Ok(SearchResults {
            hits,
            total: page.total,
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use storage::NewMedia;

    #[test]
    fn finds_without_accents_and_tags_sections() {
        let dir = std::env::temp_dir().join(format!("mm-search-db-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let db_path = dir.join("miarina.db").to_string_lossy().into_owned();
        with_db(&db_path, |db| {
            for (path, title, kind) in [
                (
                    "D:/Musique/Marée haute.flac",
                    "Marée haute",
                    MediaKind::Audio,
                ),
                (
                    "D:/Podcasts/Ondes/Les marées expliquées.mp3",
                    "Les marées expliquées",
                    MediaKind::Audio,
                ),
                (
                    "D:/Vidéos/Grande marée.mp4",
                    "Grande marée",
                    MediaKind::Video,
                ),
                ("D:/Musique/Boussole.flac", "Boussole", MediaKind::Audio),
            ] {
                db.upsert_media(&NewMedia {
                    path: path.into(),
                    title: title.into(),
                    kind,
                    source_host: None,
                    source_url: None,
                    task_id: None,
                    size_bytes: 1,
                })?;
            }
            Ok(())
        })
        .unwrap();
        let r = library_search(db_path.clone(), "maree".into(), 50).unwrap();
        let found: Vec<_> = r
            .hits
            .iter()
            .map(|h| (h.item.title.as_str(), h.section))
            .collect();
        assert_eq!(r.total, 3);
        assert!(found.contains(&("Marée haute", SearchSection::Music)));
        assert!(found.contains(&("Grande marée", SearchSection::Cinema)));
        assert!(found.contains(&("Les marées expliquées", SearchSection::Focus)));
        let pod = r
            .hits
            .iter()
            .find(|h| h.section == SearchSection::Focus)
            .unwrap();
        assert_eq!(pod.program.as_deref(), Some("Ondes"));
        assert_eq!(
            library_search(db_path, "  ".into(), 50).unwrap().hits.len(),
            0
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}

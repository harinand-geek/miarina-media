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
        let limit = limit.clamp(1, 500);
        let page = db.query_media(&MediaQuery {
            search: query.clone(),
            sort: MediaSort::Title,
            limit,
            ..MediaQuery::default()
        })?;
        let mut total = page.total;
        let mut hits: Vec<SearchHit> = page.items.into_iter().map(hit).collect();
        // Few or no exact matches: close ones despite typos follow
        // (decision 0013, proposal 6).
        if total < FUZZY_BELOW && hits.len() < limit as usize {
            let seen: std::collections::HashSet<i64> = hits.iter().map(|h| h.item.id).collect();
            for m in db.fuzzy_media(&query, limit as usize)? {
                if hits.len() >= limit as usize {
                    break;
                }
                if !seen.contains(&m.id) {
                    hits.push(hit(m));
                    total += 1;
                }
            }
        }
        Ok(SearchResults { hits, total })
    })
}

/// Below this many exact matches, typo-tolerant ones are added.
const FUZZY_BELOW: u64 = 5;

fn hit(m: storage::MediaRecord) -> SearchHit {
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
        // Typos: the close ones still come.
        let typo = library_search(db_path.clone(), "marre haute".into(), 50).unwrap();
        assert_eq!(
            typo.hits.first().map(|h| h.item.title.as_str()),
            Some("Marée haute")
        );
        let typo = library_search(db_path.clone(), "bousole".into(), 50).unwrap();
        assert_eq!(typo.hits.len(), 1);
        assert_eq!(typo.hits[0].item.title, "Boussole");
        assert!(
            library_search(db_path.clone(), "zzzz".into(), 50)
                .unwrap()
                .hits
                .is_empty()
        );
        assert_eq!(
            library_search(db_path, "  ".into(), 50).unwrap().hits.len(),
            0
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}

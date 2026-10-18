//! Browser favorites (Windows and Android): pages the user starred, shown
//! as tiles on the start page. Kept in the SQLite settings table, on this
//! device only.

use serde::{Deserialize, Serialize};
use tauri::{State, Url};

use crate::commands::CommandError;
use crate::state::AppState;

const KEY_FAVORITES: &str = "browser.favorites";
/// More would not fit the start page anyway.
pub const MAX_FAVORITES: usize = 48;
const MAX_TITLE_CHARS: usize = 120;
const MAX_URL_LEN: usize = 2048;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Favorite {
    pub url: String,
    pub title: String,
}

/// A page that can be starred: http(s) only, title bounded (page data).
fn checked(url: &str, title: &str) -> Result<Favorite, CommandError> {
    let parsed = Url::parse(url)
        .ok()
        .filter(|u| matches!(u.scheme(), "http" | "https") && u.host_str().is_some())
        .filter(|_| url.len() <= MAX_URL_LEN)
        .ok_or_else(|| {
            CommandError::new(
                "invalid_favorite",
                "Only web pages can be added to favorites",
            )
        })?;
    let title: String = title
        .trim()
        .chars()
        .filter(|c| !c.is_control())
        .take(MAX_TITLE_CHARS)
        .collect();
    let title = if title.is_empty() {
        parsed.host_str().unwrap_or_default().to_owned()
    } else {
        title
    };
    Ok(Favorite {
        url: parsed.to_string(),
        title,
    })
}

/// Adds the page (newest first) or removes it when already there.
pub fn toggle(list: &mut Vec<Favorite>, favorite: Favorite) {
    if let Some(i) = list.iter().position(|f| f.url == favorite.url) {
        list.remove(i);
    } else {
        list.insert(0, favorite);
        list.truncate(MAX_FAVORITES);
    }
}

fn load(state: &AppState) -> Result<Vec<Favorite>, CommandError> {
    Ok(state
        .storage()
        .setting::<Vec<Favorite>>(KEY_FAVORITES)?
        .unwrap_or_default())
}

#[tauri::command]
pub fn browser_favorites(state: State<'_, AppState>) -> Result<Vec<Favorite>, CommandError> {
    load(&state)
}

/// Stars or unstars a page; returns the new list.
#[tauri::command]
pub fn browser_favorite_toggle(
    state: State<'_, AppState>,
    url: String,
    title: String,
) -> Result<Vec<Favorite>, CommandError> {
    let favorite = checked(&url, &title)?;
    let mut list = load(&state)?;
    toggle(&mut list, favorite);
    state.storage().set_setting(KEY_FAVORITES, &list)?;
    Ok(list)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_web_pages_are_starred_with_a_bounded_title() {
        let f = checked("https://archive.org/details/x", "  Internet\nArchive  ").unwrap();
        assert_eq!(f.title, "InternetArchive");
        assert_eq!(
            checked("https://archive.org/", "").unwrap().title,
            "archive.org"
        );
        assert!(checked("javascript:alert(1)", "x").is_err());
        assert!(checked("file:///c:/x", "x").is_err());
        assert_eq!(
            checked("https://a.org/", &"t".repeat(500))
                .unwrap()
                .title
                .len(),
            MAX_TITLE_CHARS
        );
    }

    #[test]
    fn toggling_adds_first_then_removes() {
        let mut list = Vec::new();
        let a = checked("https://a.org/", "A").unwrap();
        let b = checked("https://b.org/", "B").unwrap();
        toggle(&mut list, a.clone());
        toggle(&mut list, b.clone());
        assert_eq!(list, vec![b.clone(), a.clone()]);
        toggle(&mut list, a);
        assert_eq!(list, vec![b]);
        for i in 0..100 {
            toggle(
                &mut list,
                checked(&format!("https://s{i}.org/"), "s").unwrap(),
            );
        }
        assert_eq!(list.len(), MAX_FAVORITES);
    }
}

//! Artist pictures from the user's own folders (W-M1b, handoff D5): no
//! fetching online. For each artist, the folders of a few of its tracks
//! and their parents are looked at:
//! - `artist.jpg` (or .jpeg / .png / .webp) in the track folder when all
//!   its tracks are by that artist (a folder shared by several artists
//!   would give them all the same face);
//! - `artist.jpg` or `folder.jpg` in the parent when that folder bears the
//!   artist's name (Musique/Nafy Rakoto/folder.jpg); never the album
//!   folder's `folder.jpg`, which is the album cover.

use std::collections::{HashMap, HashSet};
use std::path::Path;

use crate::cinema::find_image;

/// Folders looked at per artist, at most.
const FOLDERS_PER_ARTIST: usize = 2;

fn parent(path: &str) -> Option<&Path> {
    Path::new(path).parent()
}

/// Same name, ignoring case and spacing differences.
fn same_name(folder: &Path, artist: &str) -> bool {
    let norm = |s: &str| {
        s.split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
            .to_lowercase()
    };
    folder
        .file_name()
        .is_some_and(|n| norm(&n.to_string_lossy()) == norm(artist))
}

/// The picture of one artist; `own` tells whether a track folder holds
/// this artist's tracks only.
fn picture(artist: &str, track_folders: &[&Path], own: impl Fn(&Path) -> bool) -> Option<String> {
    let artist_stem = ["artist".to_owned()];
    for dir in track_folders {
        if own(dir)
            && let Some(p) = find_image(dir, &artist_stem)
        {
            return Some(p);
        }
        if let Some(up) = dir.parent()
            && same_name(up, artist)
            && let Some(p) = find_image(up, &["artist".to_owned(), "folder".to_owned()])
        {
            return Some(p);
        }
    }
    None
}

/// Pictures by artist (lower case), for the artists that have one.
pub fn artist_pictures(rows: &[(String, String)]) -> HashMap<String, String> {
    let mut folders: HashMap<String, (String, Vec<&Path>)> = HashMap::new();
    // Artists found in each track folder.
    let mut owners: HashMap<&Path, HashSet<String>> = HashMap::new();
    for (artist, path) in rows {
        let Some(dir) = parent(path) else { continue };
        owners.entry(dir).or_default().insert(artist.to_lowercase());
        let entry = folders
            .entry(artist.to_lowercase())
            .or_insert_with(|| (artist.clone(), Vec::new()));
        if entry.1.len() < FOLDERS_PER_ARTIST && !entry.1.contains(&dir) {
            entry.1.push(dir);
        }
    }
    folders
        .into_iter()
        .filter_map(|(key, (name, dirs))| {
            let own = |dir: &Path| owners.get(dir).is_some_and(|a| a.len() == 1);
            picture(&name, &dirs, own).map(|p| (key, p))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn artist_pictures_come_from_the_artist_folders_only() {
        let root = std::env::temp_dir().join(format!("mm-artist-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        let nafy = root.join("Musique").join("Nafy Rakoto");
        let album = nafy.join("Saisons de sel");
        let toky = root.join("Musique").join("Toky").join("Ny lanitra");
        let iony = root.join("Musique").join("Divers");
        for d in [&album, &toky, &iony] {
            fs::create_dir_all(d).unwrap();
        }
        // Nafy: folder.jpg in a folder bearing the name; the album's own
        // folder.jpg is its cover, never the artist's.
        fs::write(nafy.join("folder.jpg"), b"x").unwrap();
        fs::write(album.join("folder.jpg"), b"x").unwrap();
        // Toky: artist.png next to the tracks.
        fs::write(toky.join("artist.png"), b"x").unwrap();
        // Iony: a folder.jpg in a folder of another name: not taken.
        fs::write(iony.join("folder.jpg"), b"x").unwrap();
        // A folder shared by two artists: its artist.jpg is nobody's.
        let flat = root.join("Musique").join("Vrac");
        fs::create_dir_all(&flat).unwrap();
        fs::write(flat.join("artist.jpg"), b"x").unwrap();
        let p = |d: &Path, f: &str| d.join(f).to_string_lossy().into_owned();
        let rows = vec![
            ("Nafy Rakoto".to_owned(), p(&album, "01.flac")),
            ("Nafy Rakoto".to_owned(), p(&album, "02.flac")),
            ("Toky".to_owned(), p(&toky, "01.mp3")),
            ("Iony".to_owned(), p(&iony.join("x"), "01.mp3")),
            ("Mira Sol".to_owned(), p(&flat, "a.mp3")),
            ("Rova".to_owned(), p(&flat, "b.mp3")),
        ];
        let pics = artist_pictures(&rows);
        assert!(pics["nafy rakoto"].ends_with(&format!(
            "Nafy Rakoto{}folder.jpg",
            std::path::MAIN_SEPARATOR
        )));
        assert!(pics["toky"].ends_with("artist.png"));
        assert!(!pics.contains_key("iony"));
        assert!(!pics.contains_key("mira sol") && !pics.contains_key("rova"));
        let _ = fs::remove_dir_all(&root);
    }
}

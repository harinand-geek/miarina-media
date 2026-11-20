//! Focus rules (handoff W-F1): which audio files are podcasts, courses or
//! audiobooks, which program (show, course, book) they belong to and in
//! which order they play. Only the user's tags and folder names are read.

use std::cmp::Ordering;
use std::path::{Path, PathBuf};
use std::sync::RwLock;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Kind {
    Podcast,
    Course,
    Audiobook,
}

const PODCAST_WORDS: &[&str] = &["podcast", "podcasts"];
const BOOK_WORDS: &[&str] = &[
    "audiobook",
    "audiobooks",
    "audio book",
    "livre audio",
    "livres audio",
    "livre-audio",
    "livres-audio",
    "hörbuch",
    "hörbücher",
    "audiolibro",
    "audiolibros",
];
const COURSE_WORDS: &[&str] = &[
    "cours",
    "course",
    "courses",
    "lecture",
    "lectures",
    "lesson",
    "lessons",
    "leçon",
    "leçons",
    "formation",
    "formations",
    "tutorial",
    "tutorials",
    "tutoriel",
    "tutoriels",
    "conférence",
    "conférences",
    "conference",
    "conferences",
];

fn norm(text: &str) -> String {
    text.trim().to_lowercase().replace('_', " ")
}

fn kind_of_words(text: &str) -> Option<Kind> {
    let t = norm(text);
    if t.is_empty() {
        return None;
    }
    if BOOK_WORDS.iter().any(|w| t == *w || t.contains(w)) {
        return Some(Kind::Audiobook);
    }
    if PODCAST_WORDS.iter().any(|w| t == *w || t.contains(w)) {
        return Some(Kind::Podcast);
    }
    // Course words are common words: only whole words count.
    let words: Vec<&str> = t.split(|c: char| !c.is_alphanumeric()).collect();
    if COURSE_WORDS.iter().any(|w| t == *w || words.contains(w)) {
        return Some(Kind::Course);
    }
    None
}

/// Kind of a folder name that stands for a whole category ("Podcasts").
fn category_folder(name: &str) -> Option<Kind> {
    let n = norm(name);
    if PODCAST_WORDS.contains(&n.as_str()) {
        Some(Kind::Podcast)
    } else if BOOK_WORDS.contains(&n.as_str()) {
        Some(Kind::Audiobook)
    } else if COURSE_WORDS.contains(&n.as_str()) {
        Some(Kind::Course)
    } else {
        None
    }
}

static FOCUS_ROOTS: RwLock<Vec<PathBuf>> = RwLock::new(Vec::new());

/// Folders the user typed "Focus" at import (W-O1b).
pub fn set_focus_roots(roots: Vec<PathBuf>) {
    if let Ok(mut r) = FOCUS_ROOTS.write() {
        *r = roots;
    }
}

fn in_focus_root(path: &Path) -> bool {
    FOCUS_ROOTS
        .read()
        .map(|roots| roots.iter().any(|r| path.starts_with(r)))
        .unwrap_or(false)
}

/// The Focus kind of an audio file: its genre tag first, then a category
/// folder above it, then the `.m4b` extension (audiobook), then a folder
/// typed "Focus" by the user (course). None = music.
pub fn classify(genre: Option<&str>, path: &str) -> Option<Kind> {
    if let Some(k) = genre.and_then(kind_of_words) {
        return Some(k);
    }
    let p = Path::new(path);
    for dir in p.ancestors().skip(1) {
        if let Some(k) = dir
            .file_name()
            .and_then(|n| category_folder(&n.to_string_lossy()))
        {
            return Some(k);
        }
    }
    let ext = p.extension().map(|e| e.to_string_lossy().to_lowercase());
    if ext.as_deref() == Some("m4b") {
        return Some(Kind::Audiobook);
    }
    in_focus_root(p).then_some(Kind::Course)
}

/// Program (show, course, book) of a Focus file: the album tag, else the
/// folder it sits in (unless that is the category folder itself), else for
/// a podcast the artist (the show), else its own title (an audiobook file
/// is the book itself).
pub fn program(
    kind: Kind,
    album: Option<&str>,
    artist: Option<&str>,
    path: &str,
    title: &str,
) -> String {
    if let Some(a) = album.map(str::trim).filter(|a| !a.is_empty()) {
        return a.to_owned();
    }
    let folder = Path::new(path)
        .parent()
        .and_then(|d| d.file_name())
        .map(|n| n.to_string_lossy().trim().to_owned())
        .filter(|n| !n.is_empty() && category_folder(n).is_none());
    if let Some(f) = folder {
        return f;
    }
    if kind == Kind::Podcast
        && let Some(a) = artist.map(str::trim).filter(|a| !a.is_empty())
    {
        return a.to_owned();
    }
    title.to_owned()
}

/// File-name order where numbers compare as numbers ("2" before "10").
pub fn natural_cmp(a: &str, b: &str) -> Ordering {
    let (a, b) = (a.to_lowercase(), b.to_lowercase());
    let (mut x, mut y) = (a.chars().peekable(), b.chars().peekable());
    loop {
        match (x.peek().copied(), y.peek().copied()) {
            (None, None) => return Ordering::Equal,
            (None, _) => return Ordering::Less,
            (_, None) => return Ordering::Greater,
            (Some(c), Some(d)) if c.is_ascii_digit() && d.is_ascii_digit() => {
                let mut n = String::new();
                while let Some(c) = x.peek().copied().filter(char::is_ascii_digit) {
                    n.push(c);
                    x.next();
                }
                let mut m = String::new();
                while let Some(d) = y.peek().copied().filter(char::is_ascii_digit) {
                    m.push(d);
                    y.next();
                }
                let (n, m) = (n.trim_start_matches('0'), m.trim_start_matches('0'));
                let o = n.len().cmp(&m.len()).then_with(|| n.cmp(m));
                if o != Ordering::Equal {
                    return o;
                }
            }
            (Some(c), Some(d)) => {
                if c != d {
                    return c.cmp(&d);
                }
                x.next();
                y.next();
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn genre_tags_come_first() {
        assert_eq!(
            classify(Some("Podcast"), "D:/Musique/a.mp3"),
            Some(Kind::Podcast)
        );
        assert_eq!(
            classify(Some("Tech Podcasts"), "D:/a.mp3"),
            Some(Kind::Podcast)
        );
        assert_eq!(
            classify(Some("Audiobook"), "D:/a.mp3"),
            Some(Kind::Audiobook)
        );
        assert_eq!(
            classify(Some("Livre audio"), "D:/a.mp3"),
            Some(Kind::Audiobook)
        );
        assert_eq!(classify(Some("Cours"), "D:/a.mp3"), Some(Kind::Course));
        assert_eq!(
            classify(Some("Rock"), "D:/Podcasts/a.mp3"),
            Some(Kind::Podcast)
        );
    }

    #[test]
    fn course_words_must_be_whole_words() {
        // "Concours" or "Discours" are not courses.
        assert_eq!(classify(Some("Concours"), "D:/Musique/a.mp3"), None);
        assert_eq!(classify(Some("Discours"), "D:/Musique/a.mp3"), None);
        assert_eq!(classify(Some("Pop"), "D:/Musique/a.mp3"), None);
        assert_eq!(classify(None, "D:/Musique/Cours d'eau.mp3"), None);
    }

    #[test]
    fn category_folders_and_m4b() {
        assert_eq!(
            classify(
                None,
                "D:/Cours/Architecture des systèmes/07 Ordonnancement.mp3"
            ),
            Some(Kind::Course)
        );
        assert_eq!(
            classify(None, "C:/Users/a/Livres audio/Le Petit Prince/01.mp3"),
            Some(Kind::Audiobook)
        );
        assert_eq!(
            classify(None, "D:/Musique/Livre.m4b"),
            Some(Kind::Audiobook)
        );
        assert_eq!(classify(None, "D:/Musique/Album/01.flac"), None);
    }

    #[test]
    fn program_names() {
        let p = "D:/Cours/Architecture des systèmes/07.mp3";
        let c = Kind::Course;
        assert_eq!(program(c, None, None, p, "07"), "Architecture des systèmes");
        assert_eq!(program(c, Some("Archi"), None, p, "07"), "Archi");
        // Straight in the category folder: a podcast is its show (artist)…
        let pod = "D:/Podcasts/ep1.mp3";
        assert_eq!(
            program(Kind::Podcast, None, Some("Radio M"), pod, "ep1"),
            "Radio M"
        );
        assert_eq!(program(Kind::Podcast, None, None, pod, "ep1"), "ep1");
        // …an audiobook file is the book, not its narrator.
        let book = "D:/Livres audio/Sous les acacias.m4b";
        let name = program(
            Kind::Audiobook,
            None,
            Some("Lu par Hery"),
            book,
            "Sous les acacias",
        );
        assert_eq!(name, "Sous les acacias");
    }

    #[test]
    fn folders_typed_focus_hold_courses() {
        let p = "E:/Enregistrements/Licence 3/seance-04.mp3";
        assert_eq!(classify(None, p), None);
        set_focus_roots(vec![PathBuf::from("E:/Enregistrements")]);
        assert_eq!(classify(None, p), Some(Kind::Course));
        // A genre still wins.
        assert_eq!(classify(Some("Podcast"), p), Some(Kind::Podcast));
        set_focus_roots(Vec::new());
    }

    #[test]
    fn numbers_sort_as_numbers() {
        let mut names = vec!["Cours 10", "Cours 2", "cours 1", "Cours 02b", "Intro"];
        names.sort_by(|a, b| natural_cmp(a, b));
        assert_eq!(
            names,
            ["cours 1", "Cours 2", "Cours 02b", "Cours 10", "Intro"]
        );
    }
}

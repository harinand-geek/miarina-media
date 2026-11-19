//! Cinema rules (handoff W-C1 / W-C2), kept free of the bridge so they can be
//! unit-tested: episode names, local artwork, `.nfo` plots and sidecar
//! subtitles. Everything is read from the user's own folders; nothing is
//! fetched online.

use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};

/// A video at least this long, without an episode number, is a film; shorter
/// ones are personal videos (clips, phone videos).
pub const FILM_MIN_SECS: f64 = 40.0 * 60.0;

/// Season, episode and the words around them in a file name.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EpisodeName {
    /// Text before the episode number, cleaned ("Les Hautes Terres").
    pub series: Option<String>,
    pub season: u32,
    pub episode: u32,
    /// Text after the episode number, up to the first release tag.
    pub title: Option<String>,
    /// A year written next to the series name ("Show.2023.S01E01").
    pub year: Option<i32>,
}

/// Release tags that end an episode title.
const RELEASE_TAGS: &[&str] = &[
    "2160p",
    "1080p",
    "1080i",
    "720p",
    "576p",
    "480p",
    "4k",
    "uhd",
    "x264",
    "x265",
    "h264",
    "h265",
    "hevc",
    "avc",
    "xvid",
    "divx",
    "web",
    "webrip",
    "web-dl",
    "webdl",
    "hdtv",
    "hdrip",
    "bluray",
    "blu-ray",
    "bdrip",
    "brrip",
    "dvdrip",
    "remux",
    "multi",
    "vostfr",
    "vf",
    "vff",
    "french",
    "truefrench",
    "english",
    "proper",
    "repack",
    "10bit",
    "hdr",
    "dts",
    "ac3",
    "aac",
    "ddp5",
    "dd5",
    "amzn",
    "nf",
    "dsnp",
    "hmax",
];

fn is_word_char(c: char) -> bool {
    c.is_alphanumeric()
}

/// Reads "S01E04" / "s1e4" / "1x04" anywhere in `name`, as a whole word.
pub fn parse_episode(name: &str) -> Option<EpisodeName> {
    let chars: Vec<char> = name.chars().collect();
    let n = chars.len();
    let digits = |from: usize, max: usize| -> (u32, usize) {
        let mut end = from;
        while end < n && end - from < max && chars[end].is_ascii_digit() {
            end += 1;
        }
        let value = chars[from..end]
            .iter()
            .collect::<String>()
            .parse()
            .unwrap_or(0);
        (value, end - from)
    };
    for start in 0..n {
        if start > 0 && is_word_char(chars[start - 1]) {
            continue;
        }
        // SxxEyy
        if matches!(chars[start], 's' | 'S') {
            let (season, ls) = digits(start + 1, 2);
            let e = start + 1 + ls;
            if ls > 0 && e < n && matches!(chars[e], 'e' | 'E') {
                let (episode, le) = digits(e + 1, 3);
                let end = e + 1 + le;
                if le > 0 && (end == n || !chars[end].is_ascii_digit()) {
                    // "S01E04E05": the first episode number is kept.
                    return Some(build(&chars, start, end, season, episode));
                }
            }
        }
        // NxNN
        if chars[start].is_ascii_digit() {
            let (season, ls) = digits(start, 2);
            let x = start + ls;
            if x < n && matches!(chars[x], 'x' | 'X') {
                let (episode, le) = digits(x + 1, 3);
                let end = x + 1 + le;
                if le >= 2 && (end == n || !is_word_char(chars[end])) {
                    return Some(build(&chars, start, end, season, episode));
                }
            }
        }
    }
    None
}

fn build(chars: &[char], start: usize, end: usize, season: u32, episode: u32) -> EpisodeName {
    let before: String = chars[..start].iter().collect();
    let after: String = chars[end..].iter().collect();
    let (series, year) = split_year(&clean(&before));
    EpisodeName {
        series: (!series.is_empty()).then_some(series),
        season,
        episode,
        title: episode_title(&after),
        year,
    }
}

/// Dots and underscores become spaces; separators at both ends go away.
pub fn clean(text: &str) -> String {
    let spaced: String = text
        .chars()
        .map(|c| if c == '.' || c == '_' { ' ' } else { c })
        .collect();
    let words: Vec<&str> = spaced.split_whitespace().collect();
    words
        .join(" ")
        .trim_matches(|c: char| c == '-' || c == '–' || c == '·' || c == ':' || c.is_whitespace())
        .to_owned()
}

/// "Show 2023" → ("Show", 2023); "(2023)" and "[2023]" too.
fn split_year(name: &str) -> (String, Option<i32>) {
    let words: Vec<&str> = name.split(' ').collect();
    if words.len() > 1 {
        let last =
            words[words.len() - 1].trim_matches(|c| c == '(' || c == ')' || c == '[' || c == ']');
        if last.len() == 4
            && let Ok(y) = last.parse::<i32>()
            && (1900..=2100).contains(&y)
        {
            return (clean(&words[..words.len() - 1].join(" ")), Some(y));
        }
    }
    (name.to_owned(), None)
}

fn episode_title(after: &str) -> Option<String> {
    let spaced = clean(after);
    let mut kept = Vec::new();
    for word in spaced.split(' ') {
        let lower = word.to_lowercase();
        if word.starts_with('[') || word.starts_with('(') || RELEASE_TAGS.contains(&lower.as_str())
        {
            break;
        }
        kept.push(word);
    }
    let title = clean(&kept.join(" "));
    (!title.is_empty()).then_some(title)
}

/// "Season 1", "Saison 02", "S01": a season folder, whose parent is the series.
pub fn is_season_folder(name: &str) -> bool {
    let lower = name.trim().to_lowercase();
    let rest = lower
        .strip_prefix("season")
        .or_else(|| lower.strip_prefix("saison"))
        .or_else(|| lower.strip_prefix('s'));
    match rest {
        Some(r) => {
            let r = r.trim();
            !r.is_empty() && r.chars().all(|c| c.is_ascii_digit())
        }
        None => false,
    }
}

/// The folder that stands for the series of an episode file: its folder, or
/// the one above when the episode sits in a season folder.
pub fn series_folder(episode: &Path) -> Option<PathBuf> {
    let dir = episode.parent()?;
    let name = dir.file_name()?.to_string_lossy();
    if is_season_folder(&name) {
        dir.parent().map(Path::to_path_buf)
    } else {
        Some(dir.to_path_buf())
    }
}

/// Series name from the folder layout when the file name has none.
pub fn series_from_folder(episode: &Path) -> Option<String> {
    let folder = series_folder(episode)?;
    let name = clean(&folder.file_name()?.to_string_lossy());
    let (name, _) = split_year(&name);
    (!name.is_empty()).then_some(name)
}

const IMAGE_EXT: &[&str] = &["jpg", "jpeg", "png", "webp"];

/// First existing `<dir>/<stem>.<image ext>` among `stems`.
pub fn find_image(dir: &Path, stems: &[String]) -> Option<String> {
    for stem in stems {
        for ext in IMAGE_EXT {
            let p = dir.join(format!("{stem}.{ext}"));
            if p.is_file() {
                return Some(p.to_string_lossy().into_owned());
            }
        }
    }
    None
}

/// Local poster of a series folder (Kodi / Jellyfin names).
pub fn series_poster(folder: &Path) -> Option<String> {
    find_image(folder, &["poster".into(), "folder".into(), "cover".into()])
}

/// Local 16:9 background of a series folder.
pub fn series_backdrop(folder: &Path) -> Option<String> {
    find_image(
        folder,
        &["fanart".into(), "backdrop".into(), "background".into()],
    )
}

/// Local poster of a film: `<name>-poster.jpg`, `<name>.jpg`, then the
/// folder's `poster.jpg` / `folder.jpg` when the film has a folder of its own.
pub fn film_poster(file: &Path, own_folder: bool) -> Option<String> {
    let dir = file.parent()?;
    let stem = file.file_stem()?.to_string_lossy().into_owned();
    let mut stems = vec![format!("{stem}-poster"), format!("{stem}.poster"), stem];
    if own_folder {
        stems.push("poster".into());
        stems.push("folder".into());
    }
    find_image(dir, &stems)
}

/// Plots read from `.nfo` files are capped at this many characters.
pub const PLOT_MAX: usize = 2_000;
const NFO_MAX_BYTES: u64 = 256 * 1024;

/// Plot, year and first genre of a Kodi-style `.nfo` file, if readable.
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct NfoInfo {
    pub plot: Option<String>,
    pub year: Option<i32>,
    pub genre: Option<String>,
}

pub fn read_nfo(path: &Path) -> Option<NfoInfo> {
    let file = fs::File::open(path).ok()?;
    let mut bytes = Vec::new();
    file.take(NFO_MAX_BYTES).read_to_end(&mut bytes).ok()?;
    let text = String::from_utf8_lossy(&bytes);
    let info = NfoInfo {
        plot: xml_tag(&text, "plot").map(|p| p.chars().take(PLOT_MAX).collect()),
        year: xml_tag(&text, "year").and_then(|y| y.parse().ok()),
        genre: xml_tag(&text, "genre"),
    };
    (info != NfoInfo::default()).then_some(info)
}

fn xml_tag(text: &str, tag: &str) -> Option<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let start = text.find(&open)? + open.len();
    let len = text[start..].find(&close)?;
    let raw = text[start..start + len].trim();
    let raw = raw
        .strip_prefix("<![CDATA[")
        .and_then(|r| r.strip_suffix("]]>"))
        .unwrap_or(raw);
    let value = raw
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&amp;", "&");
    let value = value.trim().to_owned();
    (!value.is_empty()).then_some(value)
}

/// A subtitle file next to a video ("Film.fr.srt").
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Sidecar {
    pub path: String,
    /// What sits between the video name and the extension ("fr", "en.forced").
    pub language: Option<String>,
    /// "SRT", "ASS", "SSA" or "VTT".
    pub format: String,
}

const SUB_EXT: &[&str] = &["srt", "ass", "ssa", "vtt"];

/// Subtitle files named after `video`, in name order. Reads one folder.
pub fn sidecar_subtitles(video: &Path) -> Vec<Sidecar> {
    let (Some(dir), Some(stem)) = (video.parent(), video.file_stem()) else {
        return Vec::new();
    };
    let stem = stem.to_string_lossy().to_lowercase();
    let Ok(entries) = fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut found: Vec<Sidecar> = entries
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let path = e.path();
            let ext = path.extension()?.to_string_lossy().to_lowercase();
            if !SUB_EXT.contains(&ext.as_str()) {
                return None;
            }
            let name = path.file_stem()?.to_string_lossy().into_owned();
            let lower = name.to_lowercase();
            let rest = lower.strip_prefix(&stem)?;
            if !(rest.is_empty()
                || rest.starts_with('.')
                || rest.starts_with('_')
                || rest.starts_with('-'))
            {
                return None;
            }
            let language = rest.trim_start_matches(['.', '_', '-']);
            Some(Sidecar {
                path: path.to_string_lossy().into_owned(),
                language: (!language.is_empty()).then(|| language.to_owned()),
                format: ext.to_uppercase(),
            })
        })
        .collect();
    found.sort_by(|a, b| a.path.cmp(&b.path));
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ep(name: &str) -> EpisodeName {
        parse_episode(name).unwrap_or_else(|| panic!("no episode in {name}"))
    }

    #[test]
    fn reads_common_episode_names() {
        let e = ep("Les.Hautes.Terres.S01E04.Le.col.1080p.WEB.x265");
        assert_eq!(e.series.as_deref(), Some("Les Hautes Terres"));
        assert_eq!((e.season, e.episode), (1, 4));
        assert_eq!(e.title.as_deref(), Some("Le col"));

        let e = ep("Port-Louis Nuit - 2x07 - Le quai");
        assert_eq!(e.series.as_deref(), Some("Port-Louis Nuit"));
        assert_eq!((e.season, e.episode), (2, 7));
        assert_eq!(e.title.as_deref(), Some("Le quai"));

        let e = ep("rova_s1e10");
        assert_eq!(e.series.as_deref(), Some("rova"));
        assert_eq!((e.season, e.episode), (1, 10));
        assert_eq!(e.title, None);

        let e = ep("S02E01 Retour");
        assert_eq!(e.series, None);
        assert_eq!(e.title.as_deref(), Some("Retour"));
    }

    #[test]
    fn keeps_a_year_apart_from_the_series_name() {
        let e = ep("Atelier.9.2021.S01E02.Bois");
        assert_eq!(e.series.as_deref(), Some("Atelier 9"));
        assert_eq!(e.year, Some(2021));
        let e = ep("Rova (2019) S01E01");
        assert_eq!(e.series.as_deref(), Some("Rova"));
        assert_eq!(e.year, Some(2019));
    }

    #[test]
    fn ignores_names_that_only_look_like_episodes() {
        for name in [
            "Mariage de Lova 2024",
            "1920x1080 test",
            "Boss1e2",
            "VID_20240512_183000",
            "Les secrets du 4x4",
            "Season finale",
        ] {
            assert_eq!(parse_episode(name), None, "{name}");
        }
    }

    #[test]
    fn season_folders_point_to_the_series_folder() {
        assert!(is_season_folder("Season 1"));
        assert!(is_season_folder("Saison 02"));
        assert!(is_season_folder("S1"));
        assert!(!is_season_folder("Saisons"));
        assert!(!is_season_folder("Specials"));
        let p = Path::new("D:/Séries/Les Hautes Terres (2023)/Saison 1/e04.mkv");
        assert_eq!(series_from_folder(p).as_deref(), Some("Les Hautes Terres"));
        let p = Path::new("D:/Séries/Rova/e04.mkv");
        assert_eq!(series_from_folder(p).as_deref(), Some("Rova"));
    }

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("mm-cinema-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn finds_local_artwork_and_plots() {
        let dir = scratch("art");
        let season = dir.join("Saison 1");
        fs::create_dir_all(&season).unwrap();
        fs::write(dir.join("poster.jpg"), b"x").unwrap();
        fs::write(dir.join("fanart.png"), b"x").unwrap();
        fs::write(
            dir.join("tvshow.nfo"),
            "<tvshow><title>T</title><plot>Une guide &amp; son p\u{e8}re.</plot><year>2023</year><genre>Drame</genre></tvshow>",
        )
        .unwrap();
        let episode = season.join("Show.S01E01.mkv");
        let folder = series_folder(&episode).unwrap();
        assert_eq!(folder, dir);
        assert!(series_poster(&folder).unwrap().ends_with("poster.jpg"));
        assert!(series_backdrop(&folder).unwrap().ends_with("fanart.png"));
        let nfo = read_nfo(&folder.join("tvshow.nfo")).unwrap();
        assert_eq!(nfo.plot.as_deref(), Some("Une guide & son p\u{e8}re."));
        assert_eq!(nfo.year, Some(2023));
        assert_eq!(nfo.genre.as_deref(), Some("Drame"));
        assert_eq!(read_nfo(&dir.join("missing.nfo")), None);

        let film = dir.join("Le Dernier Ferry.mkv");
        assert_eq!(film_poster(&film, false), None);
        fs::write(dir.join("Le Dernier Ferry-poster.jpg"), b"x").unwrap();
        assert!(
            film_poster(&film, false)
                .unwrap()
                .ends_with("Le Dernier Ferry-poster.jpg")
        );
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn lists_subtitles_named_after_the_video() {
        let dir = scratch("subs");
        for f in [
            "Film.fr.srt",
            "Film.en.forced.ass",
            "Film.srt",
            "Filmographie.srt",
            "Film.fr.txt",
        ] {
            fs::write(dir.join(f), b"x").unwrap();
        }
        let subs = sidecar_subtitles(&dir.join("Film.mkv"));
        let found: Vec<_> = subs
            .iter()
            .map(|s| (s.language.clone(), s.format.clone()))
            .collect();
        assert_eq!(
            found,
            vec![
                (Some("en.forced".into()), "ASS".into()),
                (Some("fr".into()), "SRT".into()),
                (None, "SRT".into()),
            ]
        );
        fs::remove_dir_all(&dir).unwrap();
    }
}

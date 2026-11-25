use std::path::Path;
use std::sync::Mutex;

use anyhow::{Result, anyhow};
use storage::{GroupBy, MediaKind, MediaQuery, MediaRecord, MediaSort, NewMedia, Storage};

pub struct LibraryItem {
    pub id: i64,
    pub title: String,
    pub path: String,
    pub is_video: bool,
    pub duration_secs: Option<f64>,
    pub artist: Option<String>,
    pub album: Option<String>,
    /// Short technical label (codec or container), e.g. "FLAC".
    pub format: Option<String>,
    pub missing: bool,
    pub favorite: bool,
    /// Absolute path of the cover / thumbnail JPEG, when one exists.
    pub thumbnail: Option<String>,
    pub track_no: Option<u32>,
    /// Plays noted by the player.
    pub plays: u32,
}

/// One album or artist of the music library.
pub struct LibraryGroup {
    pub name: String,
    /// Album artist (albums) or number of albums (artists).
    pub detail: Option<String>,
    pub count: u64,
    pub duration_secs: f64,
    pub year: Option<i32>,
    pub thumbnail: Option<String>,
    /// Newest entry, ms since the epoch ("Ajoutés récemment").
    pub added_at: i64,
    /// Plays of all its tracks ("écouté N fois", "Les plus écoutés").
    pub plays: u64,
    pub size_bytes: u64,
    /// Lossless or beyond 48 kHz audio ("FLAC / hi-res").
    pub lossless: bool,
    /// Downloaded with Miarina.
    pub downloaded: bool,
    /// Album of various artists.
    pub compilation: bool,
}

pub struct LibrarySummary {
    pub schema_version: i64,
    pub total: u64,
    pub audio_count: u64,
    pub video_count: u64,
    pub items: Vec<LibraryItem>,
}

pub struct LibraryPage {
    pub items: Vec<LibraryItem>,
    pub total: u64,
}

/// One open database at a time: opening runs the migration check, so the
/// connection is kept between calls for the same path.
static OPEN: Mutex<Option<(String, Storage)>> = Mutex::new(None);

pub(crate) fn with_db<R>(db_path: &str, f: impl FnOnce(&Storage) -> Result<R>) -> Result<R> {
    let mut guard = OPEN.lock().map_err(|_| anyhow!("library lock poisoned"))?;
    let reuse = matches!(guard.as_ref(), Some((path, _)) if path == db_path);
    if !reuse {
        *guard = None;
        let db = Storage::open(Path::new(db_path))?;
        *guard = Some((db_path.to_owned(), db));
    }
    let (_, db) = guard.as_ref().expect("opened above");
    f(db)
}

/// The Format column: "FLAC 24/96" (bits / kHz) for lossless audio,
/// "MP3 320" (kbit/s) for lossy audio, the codec or container otherwise.
fn format_label(m: &MediaRecord) -> Option<String> {
    let audio = m.kind == MediaKind::Audio;
    let base = m
        .audio_codec
        .as_deref()
        .filter(|_| audio)
        .or(m.container.as_deref())
        .map(|f| f.to_uppercase())?;
    if !audio {
        return Some(base);
    }
    Some(match (m.bit_depth, m.sample_rate, m.bit_rate) {
        (Some(bits), Some(rate), _) => format!("{base} {bits}/{}", rate / 1000),
        (None, _, Some(kbps)) => format!("{base} {kbps}"),
        _ => base,
    })
}

pub(crate) fn item(m: MediaRecord) -> LibraryItem {
    let format = format_label(&m);
    LibraryItem {
        id: m.id,
        title: m.title,
        path: m.path,
        is_video: m.kind == MediaKind::Video,
        duration_secs: m.duration_secs,
        artist: m.artist,
        album: m.album,
        format,
        missing: m.missing,
        favorite: m.favorite,
        thumbnail: m.thumbnail,
        track_no: m.track_no,
        plays: m.play_count,
    }
}

/// Opens the library database (running pending migrations, exactly like the
/// Tauri app) and returns its counters and the first `limit` entries.
pub fn library_summary(db_path: String, limit: u32) -> Result<LibrarySummary> {
    with_db(&db_path, |db| {
        let stats = db.media_stats()?;
        // A query limit of 0 means "the maximum page" to the core: counters
        // alone must not load any row.
        let items = if limit == 0 {
            Vec::new()
        } else {
            db.query_media(&MediaQuery {
                limit: limit.min(200),
                ..MediaQuery::default()
            })?
            .items
        };
        Ok(LibrarySummary {
            schema_version: db.schema_version()?,
            total: stats.count,
            audio_count: stats.audio_count,
            video_count: stats.video_count,
            items: items.into_iter().map(item).collect(),
        })
    })
}

/// A page of audio tracks. `sort`: title (default), artist, album, format,
/// duration or added (newest first); `reverse` flips it; by disc and track
/// within an album when sorted by title. `search` uses the library's
/// full-text index (accent-insensitive), empty = everything. `album` /
/// `artist` narrow to one group; `added_since` (ms since the epoch) to the
/// tracks added since then; `never_played` to those never played; `hi_res`
/// to those beyond CD quality (more than 16 bits or 48 kHz).
#[allow(clippy::too_many_arguments)]
pub fn library_tracks(
    db_path: String,
    search: String,
    favorites_only: bool,
    album: Option<String>,
    artist: Option<String>,
    sort: String,
    reverse: bool,
    added_since: Option<i64>,
    never_played: bool,
    hi_res: bool,
    offset: u32,
    limit: u32,
) -> Result<LibraryPage> {
    let sort = match sort.as_str() {
        "artist" => MediaSort::Artist,
        "album" => MediaSort::Album,
        "format" => MediaSort::Format,
        "duration" => MediaSort::Duration,
        "added" => MediaSort::Added,
        "plays" => MediaSort::Plays,
        _ => MediaSort::Title,
    };
    with_db(&db_path, |db| {
        let page = db.query_media(&MediaQuery {
            search,
            kind: Some(MediaKind::Audio),
            favorites: favorites_only,
            album,
            artist_group: artist,
            sort,
            reverse,
            added_since,
            never_played,
            hi_res,
            offset,
            limit: limit.clamp(1, 500),
            ..MediaQuery::default()
        })?;
        Ok(LibraryPage {
            items: page.items.into_iter().map(item).collect(),
            total: page.total,
        })
    })
}

/// Albums (`by` = "album") or artists ("artist") of the music library,
/// alphabetical; files reported missing are left out.
pub fn library_groups(db_path: String, by: String) -> Result<Vec<LibraryGroup>> {
    let by = match by.as_str() {
        "album" => GroupBy::Album,
        // W-M1b: grouped by album artist, featurings stay with the artist.
        "artist" => GroupBy::AlbumArtist,
        other => return Err(anyhow!("unknown grouping: {other}")),
    };
    with_db(&db_path, |db| {
        // Artists: their own picture from their folders, else the first
        // cover (handoff D5; nothing fetched online).
        let pictures = if by == GroupBy::AlbumArtist {
            crate::artist_image::artist_pictures(&db.artist_track_paths()?)
        } else {
            Default::default()
        };
        Ok(db
            .media_groups(by)?
            .into_iter()
            .map(|g| LibraryGroup {
                thumbnail: pictures
                    .get(&g.name.to_lowercase())
                    .cloned()
                    .or(g.thumbnail),
                name: g.name,
                detail: g.detail,
                count: g.count,
                duration_secs: g.duration_secs,
                year: g.year,
                added_at: g.added_at,
                plays: g.plays,
                size_bytes: g.size_bytes,
                lossless: g.lossless,
                downloaded: g.downloaded,
                compilation: g.compilation,
            })
            .collect())
    })
}

/// One library entry by id; None when it was removed.
pub fn library_item(db_path: String, media_id: i64) -> Result<Option<LibraryItem>> {
    with_db(&db_path, |db| match db.media(media_id) {
        Ok(m) => Ok(Some(item(m))),
        Err(storage::StorageError::NotFound(_)) => Ok(None),
        Err(e) => Err(e.into()),
    })
}

/// The library entry of a file ("Open with"), if the file is known.
pub fn library_item_by_path(db_path: String, path: String) -> Result<Option<LibraryItem>> {
    with_db(&db_path, |db| Ok(db.media_by_path(&path)?.map(item)))
}

/// Marks or unmarks a library entry as a favorite.
/// A play of a library entry, as the player notes it (once per play).
/// Tempo of a music file from its tags, if it has one (the seek bar's wave
/// moves on the beat).
pub fn library_bpm(path: String) -> Option<f64> {
    library::tags::read_bpm(Path::new(&path))
}

pub fn library_note_played(db_path: String, media_id: i64) -> Result<()> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    with_db(&db_path, |db| Ok(db.note_played(media_id, now)?))
}

pub fn library_set_favorite(db_path: String, media_id: i64, favorite: bool) -> Result<()> {
    with_db(&db_path, |db| Ok(db.set_favorite(media_id, favorite)?))
}

/// Adds one local file to the library and returns its id.
pub fn library_add_file(
    db_path: String,
    path: String,
    title: String,
    is_video: bool,
    size_bytes: u64,
) -> Result<i64> {
    with_db(&db_path, |db| {
        let record = db.upsert_media(&NewMedia {
            path,
            title,
            kind: if is_video {
                MediaKind::Video
            } else {
                MediaKind::Audio
            },
            source_host: None,
            source_url: None,
            task_id: None,
            size_bytes,
        })?;
        Ok(record.id)
    })
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;
    use storage::MediaProbe;

    #[test]
    fn the_format_column_names_the_quality() {
        let db = Storage::open_in_memory().unwrap();
        let add = |path: &str, probe: MediaProbe| {
            let m = db
                .upsert_media(&NewMedia {
                    path: path.into(),
                    title: path.into(),
                    kind: MediaKind::Audio,
                    source_host: None,
                    source_url: None,
                    task_id: None,
                    size_bytes: 1,
                })
                .unwrap();
            db.set_media_probe(m.id, &probe, None).unwrap();
            item(db.media(m.id).unwrap()).format
        };
        let flac = MediaProbe {
            audio_codec: Some("flac".into()),
            sample_rate: Some(96_000),
            bit_depth: Some(24),
            ..MediaProbe::default()
        };
        assert_eq!(add("C:/a.flac", flac).as_deref(), Some("FLAC 24/96"));
        let cd = MediaProbe {
            audio_codec: Some("flac".into()),
            sample_rate: Some(44_100),
            bit_depth: Some(16),
            ..MediaProbe::default()
        };
        assert_eq!(add("C:/b.flac", cd).as_deref(), Some("FLAC 16/44"));
        let mp3 = MediaProbe {
            audio_codec: Some("mp3".into()),
            sample_rate: Some(44_100),
            bit_rate: Some(320),
            ..MediaProbe::default()
        };
        assert_eq!(add("C:/c.mp3", mp3).as_deref(), Some("MP3 320"));
        let bare = MediaProbe {
            audio_codec: Some("opus".into()),
            ..MediaProbe::default()
        };
        assert_eq!(add("C:/d.opus", bare).as_deref(), Some("OPUS"));
    }
}

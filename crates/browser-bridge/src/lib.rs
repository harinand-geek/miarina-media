//! Bounded native-messaging frames from the browser extension: a link opened
//! in Miarina Media (0.2.3), or the durable local inbox of the 0.1.x app. No
//! network listener.
use serde::{Deserialize, Serialize};
use std::{
    fs,
    io::{self, Read, Write},
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

pub const HOST: &str = "org.miarina.media.bridge";
pub const MAX_FRAME: usize = 16 * 1024;
#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    pub url: String,
}
#[derive(Deserialize, Serialize)]
pub struct Entry {
    pub id: String,
    pub url: String,
}

/// What the extension sends (0.2.3): a link to open in the app, or a ping
/// (the connection test). Exactly one of the two.
#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Message {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub ping: bool,
}

fn read_frame(reader: &mut impl Read) -> io::Result<Vec<u8>> {
    let mut prefix = [0u8; 4];
    reader.read_exact(&mut prefix)?;
    let len = u32::from_ne_bytes(prefix) as usize;
    if len == 0 || len > MAX_FRAME {
        return Err(io::Error::other("Invalid message size"));
    }
    let mut bytes = vec![0; len];
    reader.read_exact(&mut bytes)?;
    Ok(bytes)
}

/// Reads one native-messaging frame from the extension (bounded, untrusted).
pub fn read_message(reader: &mut impl Read) -> io::Result<Message> {
    let message: Message =
        serde_json::from_slice(&read_frame(reader)?).map_err(io::Error::other)?;
    match (&message.url, message.ping) {
        (Some(url), false) => validate(url)?,
        (None, true) => {}
        _ => return Err(io::Error::other("Send a link or a ping")),
    }
    Ok(message)
}

/// The Miarina Media executable next to this bridge (installed together):
/// `miarina-media.exe`, a recette build's `miarina-media-….exe`, or the
/// development build's `miarina_media.exe`.
pub fn app_next_to(bridge: &Path) -> Option<PathBuf> {
    let dir = bridge.parent()?;
    let mut found: Vec<PathBuf> = fs::read_dir(dir)
        .ok()?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| {
            let name = p
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or_default()
                .to_ascii_lowercase();
            (name.starts_with("miarina-media") || name.starts_with("miarina_media"))
                && name.ends_with(".exe")
                && p.is_file()
        })
        .collect();
    found.sort();
    found.into_iter().next()
}

/// Opens `url` in Miarina Media: its analysis page, in the running window
/// (the app keeps one) or a new one. Nothing is downloaded without the
/// user's choice. The app outlives this process (the browser ends it).
#[cfg(windows)]
pub fn open_in_app(url: &str) -> io::Result<()> {
    use std::os::windows::process::CommandExt;
    use std::process::{Command, Stdio};
    validate(url)?;
    let app = app_next_to(&std::env::current_exe()?)
        .ok_or_else(|| io::Error::other("Miarina Media not found next to the bridge"))?;
    const DETACHED_PROCESS: u32 = 0x0000_0008;
    const CREATE_NEW_PROCESS_GROUP: u32 = 0x0000_0200;
    const CREATE_BREAKAWAY_FROM_JOB: u32 = 0x0100_0000;
    let spawn = |flags: u32| {
        Command::new(&app)
            .arg("--link")
            .arg(url)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .creation_flags(flags)
            .spawn()
    };
    // Out of the browser's job when it allows it, so closing the browser
    // does not close the app.
    spawn(DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_BREAKAWAY_FROM_JOB)
        .or_else(|_| spawn(DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP))
        .map(|_| ())
}

pub fn read_request(reader: &mut impl Read) -> io::Result<Request> {
    let request: Request =
        serde_json::from_slice(&read_frame(reader)?).map_err(io::Error::other)?;
    validate(&request.url)?;
    Ok(request)
}
fn validate(url: &str) -> io::Result<()> {
    media_core::validate_media_url(url)
        .map(|_| ())
        .map_err(|_| io::Error::other("Only HTTP(S) links without credentials are accepted"))
}
pub fn write_response(writer: &mut impl Write, ok: bool) -> io::Result<()> {
    let bytes = serde_json::to_vec(&serde_json::json!({ "ok": ok })).map_err(io::Error::other)?;
    writer.write_all(&(bytes.len() as u32).to_ne_bytes())?;
    writer.write_all(&bytes)?;
    writer.flush()
}
pub fn enqueue(dir: &Path, request: Request) -> io::Result<()> {
    validate(&request.url)?;
    fs::create_dir_all(dir)?;
    if fs::read_dir(dir)?.take(101).count() >= 100 {
        return Err(io::Error::other("Inbox full"));
    }
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(io::Error::other)?
        .as_nanos();
    let id = format!("{stamp}-{}", std::process::id());
    let tmp = dir.join(format!("{id}.tmp"));
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&tmp)?;
    let bytes = serde_json::to_vec(&Entry {
        id: id.clone(),
        url: request.url,
    })
    .map_err(io::Error::other)?;
    file.write_all(&bytes)?;
    file.sync_all()?;
    drop(file);
    fs::rename(tmp, dir.join(format!("{id}.json")))
}
pub fn inbox(dir: &Path) -> io::Result<Vec<Entry>> {
    if !dir.exists() {
        return Ok(Vec::new());
    }
    let mut entries = Vec::new();
    for file in fs::read_dir(dir)?.take(200) {
        let file = file?;
        if file.path().extension().is_none_or(|e| e != "json") {
            continue;
        }
        // One stale, unreadable or oversized entry must not hide the whole inbox.
        let Ok(input) = fs::File::open(file.path()) else {
            continue;
        };
        let Ok(metadata) = input.metadata() else {
            continue;
        };
        if !metadata.is_file() || metadata.len() > MAX_FRAME as u64 {
            continue;
        }
        let mut bytes = Vec::new();
        if input
            .take(MAX_FRAME as u64 + 1)
            .read_to_end(&mut bytes)
            .is_err()
            || bytes.len() > MAX_FRAME
        {
            continue;
        }
        let Ok(entry) = serde_json::from_slice::<Entry>(&bytes) else {
            continue;
        };
        if valid_id(&entry.id)
            && validate(&entry.url).is_ok()
            && file.file_name() == format!("{}.json", entry.id).as_str()
        {
            entries.push(entry);
        }
    }
    entries.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(entries)
}
fn valid_id(id: &str) -> bool {
    !id.is_empty() && id.len() < 80 && id.bytes().all(|b| b.is_ascii_digit() || b == b'-')
}
pub fn dismiss(dir: &Path, id: &str) -> io::Result<()> {
    if !valid_id(id) {
        return Err(io::Error::other("Invalid message ID"));
    }
    fs::remove_file(dir.join(format!("{id}.json")))
}
pub fn default_inbox() -> io::Result<PathBuf> {
    std::env::var_os("APPDATA")
        .map(|p| {
            PathBuf::from(p)
                .join("org.miarina.media")
                .join("browser-inbox")
        })
        .ok_or_else(|| io::Error::other("Application data folder unavailable"))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_oversized_and_truncated_frames() {
        assert!(read_request(&mut ((MAX_FRAME as u32 + 1).to_ne_bytes().as_slice())).is_err());
        assert!(read_request(&mut [10, 0, 0, 0, b'{'].as_slice()).is_err());
    }
    #[test]
    fn validates_links_and_preserves_unicode() {
        let bytes = serde_json::to_vec(&Request {
            url: "https://example.com/été".into(),
        })
        .unwrap();
        let mut frame = (bytes.len() as u32).to_ne_bytes().to_vec();
        frame.extend(bytes);
        assert_eq!(
            read_request(&mut frame.as_slice()).unwrap().url,
            "https://example.com/été"
        );
        assert!(validate("file:///c:/secret").is_err());
        assert!(validate("https://user:secret@example.com").is_err());
    }
    #[test]
    fn durable_inbox_and_safe_dismissal() {
        let dir = tempfile::tempdir().unwrap();
        enqueue(
            dir.path(),
            Request {
                url: "https://example.com/test.mp4".into(),
            },
        )
        .unwrap();
        let list = inbox(dir.path()).unwrap();
        assert_eq!(list.len(), 1);
        assert!(dismiss(dir.path(), "../other").is_err());
        dismiss(dir.path(), &list[0].id).unwrap();
        assert!(inbox(dir.path()).unwrap().is_empty());
    }
    #[test]
    fn response_is_exact_native_frame() {
        let mut out = Vec::new();
        write_response(&mut out, true).unwrap();
        assert_eq!(
            u32::from_ne_bytes(out[..4].try_into().unwrap()) as usize,
            out.len() - 4
        );
        assert_eq!(
            serde_json::from_slice::<serde_json::Value>(&out[4..]).unwrap()["ok"],
            true
        );
    }

    fn frame(body: &str) -> Vec<u8> {
        let mut out = (body.len() as u32).to_ne_bytes().to_vec();
        out.extend(body.as_bytes());
        out
    }

    #[test]
    fn messages_are_a_link_or_a_ping() {
        let m = read_message(&mut frame(r#"{"url":"https://example.com/v"}"#).as_slice()).unwrap();
        assert_eq!(m.url.as_deref(), Some("https://example.com/v"));
        assert!(
            read_message(&mut frame(r#"{"ping":true}"#).as_slice())
                .unwrap()
                .ping
        );
        for bad in [
            r#"{}"#,
            r#"{"ping":false}"#,
            r#"{"url":"https://example.com","ping":true}"#,
            r#"{"url":"file:///c:/secret"}"#,
            r#"{"url":"https://example.com","cookies":"x"}"#,
        ] {
            assert!(read_message(&mut frame(bad).as_slice()).is_err(), "{bad}");
        }
    }

    #[test]
    fn the_app_is_found_next_to_the_bridge() {
        let dir = tempfile::tempdir().unwrap();
        let bridge = dir.path().join("miarina-browser-bridge.exe");
        fs::write(&bridge, b"").unwrap();
        assert_eq!(app_next_to(&bridge), None);
        fs::write(dir.path().join("miarina-media.exe"), b"").unwrap();
        fs::write(dir.path().join("other.exe"), b"").unwrap();
        assert_eq!(
            app_next_to(&bridge).unwrap().file_name().unwrap(),
            "miarina-media.exe"
        );
    }

    #[test]
    fn malformed_entries_do_not_hide_valid_links() {
        let dir = tempfile::tempdir().unwrap();
        fs::create_dir(dir.path().join("1-1.json")).unwrap();
        fs::write(dir.path().join("2-2.json"), b"invalid json").unwrap();
        fs::write(dir.path().join("3-3.json"), vec![b' '; MAX_FRAME + 1]).unwrap();
        enqueue(
            dir.path(),
            Request {
                url: "https://example.com/valid".into(),
            },
        )
        .unwrap();
        let list = inbox(dir.path()).unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].url, "https://example.com/valid");
    }
}

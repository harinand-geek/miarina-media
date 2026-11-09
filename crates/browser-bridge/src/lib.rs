//! Bounded native-messaging frames and a durable local inbox. No network listener.
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

pub fn read_request(reader: &mut impl Read) -> io::Result<Request> {
    let mut prefix = [0u8; 4];
    reader.read_exact(&mut prefix)?;
    let len = u32::from_ne_bytes(prefix) as usize;
    if len == 0 || len > MAX_FRAME {
        return Err(io::Error::other("Invalid message size"));
    }
    let mut bytes = vec![0; len];
    reader.read_exact(&mut bytes)?;
    let request: Request = serde_json::from_slice(&bytes).map_err(io::Error::other)?;
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
        if file.path().extension().is_none_or(|e| e != "json")
            || file.metadata()?.len() > MAX_FRAME as u64
        {
            continue;
        }
        let Ok(entry) = serde_json::from_slice::<Entry>(&fs::read(file.path())?) else {
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
}

//! Signed release manifests. Only this server and its signed artifact may be installed.
use crate::commands::CommandError;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;
use tauri::{AppHandle, Manager, State};
use tokio::{io::AsyncWriteExt, sync::Mutex};
type Result<T> = std::result::Result<T, CommandError>;
const BASE: &str = "https://media.miarina.org";
#[derive(Default)]
pub struct Updates {
    downloaded: AtomicU64,
    lock: Mutex<()>,
    ready: Mutex<Option<Release>>,
}
#[derive(Clone, Deserialize, Serialize)]
pub struct Release {
    pub version: String,
    pub notes: String,
    pub url: String,
    pub sha256: String,
    pub size: u64,
}
#[derive(Deserialize)]
struct Envelope {
    payload: String,
    signature: String,
}
#[derive(Deserialize)]
struct Manifest {
    windows: Release,
    android: Release,
}
fn err(e: impl std::fmt::Display) -> CommandError {
    CommandError::new("update", e.to_string())
}
fn hex(s: &str) -> Result<Vec<u8>> {
    if s.len() % 2 != 0 || !s.is_ascii() {
        return Err(err("Invalid signature encoding"));
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).map_err(err))
        .collect()
}
fn version(s: &str) -> Result<[u64; 3]> {
    let v = s
        .split('.')
        .map(|x| x.parse::<u64>().map_err(err))
        .collect::<Result<Vec<_>>>()?;
    v.try_into().map_err(|_| err("Invalid release version"))
}
fn verify(raw: &[u8], android: bool) -> Result<Release> {
    verify_with_key(
        raw,
        android,
        include_bytes!("../resources/update-public-key.bin"),
    )
}
fn verify_with_key(raw: &[u8], android: bool, key: &[u8]) -> Result<Release> {
    let envelope: Envelope = serde_json::from_slice(raw).map_err(err)?;
    ring::signature::UnparsedPublicKey::new(&ring::signature::ED25519, key)
        .verify(envelope.payload.as_bytes(), &hex(&envelope.signature)?)
        .map_err(|_| err("Update signature is invalid"))?;
    let manifest: Manifest = serde_json::from_str(&envelope.payload).map_err(err)?;
    let r = if android {
        manifest.android
    } else {
        manifest.windows
    };
    version(&r.version)?;
    let suffix = if android { ".apk" } else { "-x64-setup.exe" };
    if r.url != format!("{BASE}/downloads/MiarinaMedia-{}{suffix}", r.version)
        || r.size == 0
        || r.size > 512 * 1024 * 1024
        || hex(&r.sha256)?.len() != 32
        || r.notes.len() > 16000
    {
        return Err(err("Invalid release metadata"));
    }
    Ok(r)
}
fn client() -> Result<reqwest::Client> {
    reqwest::Client::builder()
        .https_only(true)
        .redirect(reqwest::redirect::Policy::none())
        .connect_timeout(Duration::from_secs(20))
        .timeout(Duration::from_secs(1800))
        .build()
        .map_err(err)
}
#[tauri::command]
pub async fn app_update_check(app: AppHandle) -> Result<Option<Release>> {
    let mut response = client()?
        .get(format!(
            "{BASE}/updates/stable.json?t={}",
            storage::now_ms()
        ))
        .send()
        .await
        .map_err(err)?
        .error_for_status()
        .map_err(err)?;
    let mut bytes = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(err)? {
        if bytes.len() + chunk.len() > 65536 {
            return Err(err("Update manifest too large"));
        }
        bytes.extend_from_slice(&chunk);
    }
    let r = verify(&bytes, cfg!(target_os = "android"))?;
    Ok((version(&r.version)? > version(&app.package_info().version.to_string())?).then_some(r))
}
fn path(app: &AppHandle) -> Result<std::path::PathBuf> {
    Ok(app
        .path()
        .app_cache_dir()
        .map_err(err)?
        .join(if cfg!(target_os = "android") {
            "miarina-update.apk"
        } else {
            "miarina-update.exe"
        }))
}
#[tauri::command]
pub async fn app_update_download(app: AppHandle, state: State<'_, Updates>) -> Result<Release> {
    let _lock = state
        .lock
        .try_lock()
        .map_err(|_| err("An update operation is already running"))?;
    *state.ready.lock().await = None;
    state.downloaded.store(0, Ordering::Relaxed);
    let r = app_update_check(app.clone())
        .await?
        .ok_or_else(|| err("No newer release available"))?;
    let dest = path(&app)?;
    let part = dest.with_extension("part");
    tokio::fs::create_dir_all(dest.parent().unwrap())
        .await
        .map_err(err)?;
    let result = async {
        let mut response = client()?
            .get(&r.url)
            .send()
            .await
            .map_err(err)?
            .error_for_status()
            .map_err(err)?;
        let mut file = tokio::fs::File::create(&part).await.map_err(err)?;
        let mut hash = Sha256::new();
        let mut count = 0u64;
        while let Some(chunk) = response.chunk().await.map_err(err)? {
            count += chunk.len() as u64;
            if count > r.size {
                return Err(err("Update size mismatch"));
            }
            hash.update(&chunk);
            file.write_all(&chunk).await.map_err(err)?;
            state.downloaded.store(count, Ordering::Relaxed);
        }
        file.sync_all().await.map_err(err)?;
        drop(file);
        if count != r.size || hash.finalize().as_slice() != hex(&r.sha256)?.as_slice() {
            return Err(err("Update checksum mismatch"));
        }
        if tokio::fs::try_exists(&dest).await.map_err(err)? {
            tokio::fs::remove_file(&dest).await.map_err(err)?;
        }
        tokio::fs::rename(&part, &dest).await.map_err(err)?;
        Ok(())
    }
    .await;
    if result.is_err() {
        let _ = tokio::fs::remove_file(&part).await;
    }
    result?;
    *state.ready.lock().await = Some(r.clone());
    Ok(r)
}
#[tauri::command]
pub async fn app_update_install(app: AppHandle, state: State<'_, Updates>) -> Result<()> {
    let _lock = state
        .lock
        .try_lock()
        .map_err(|_| err("An update operation is already running"))?;
    let r = state
        .ready
        .lock()
        .await
        .clone()
        .ok_or_else(|| err("Download the update first"))?;
    let dest = path(&app)?;
    // Recheck immediately before execution; never accept a path from the webview.
    if tokio::fs::metadata(&dest).await.map_err(err)?.len() != r.size {
        return Err(err("Update file changed; download it again"));
    }
    let bytes = tokio::fs::read(&dest).await.map_err(err)?;
    if bytes.len() as u64 != r.size
        || Sha256::digest(&bytes).as_slice() != hex(&r.sha256)?.as_slice()
    {
        return Err(err("Update file changed; download it again"));
    }
    let data = app.state::<crate::state::AppState>();
    if data.manager.tasks()?.iter().any(|t| {
        matches!(
            t.state,
            media_core::TaskState::Downloading
                | media_core::TaskState::Processing
                | media_core::TaskState::Analyzing
                | media_core::TaskState::Waiting
                | media_core::TaskState::Queued
        )
    }) {
        return Err(err("Pause or finish your downloads before installing"));
    }
    #[cfg(windows)]
    {
        crate::torrents::torrents_disable(app.state()).await?;
        std::process::Command::new(&dest).spawn().map_err(err)?;
        app.exit(0);
    }
    #[cfg(target_os = "android")]
    crate::shell::install_update(&app, dest.to_string_lossy().into_owned()).await?;
    Ok(())
}
#[tauri::command]
pub fn app_update_progress(state: State<'_, Updates>) -> u64 {
    state.downloaded.load(Ordering::Relaxed)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn authenticated_manifest_and_tampering() {
        use ring::signature::KeyPair;
        let key = ring::signature::Ed25519KeyPair::from_seed_unchecked(&[7; 32]).unwrap();
        let release = serde_json::json!({"version":"0.1.7","notes":"Test","url":"https://media.miarina.org/downloads/MiarinaMedia-0.1.7.apk","size":100,"sha256":"00".repeat(32)});
        let payload = serde_json::json!({"windows":release,"android":release}).to_string();
        let signature = key
            .sign(payload.as_bytes())
            .as_ref()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>();
        let envelope = serde_json::json!({"payload":payload,"signature":signature});
        assert!(
            verify_with_key(
                envelope.to_string().as_bytes(),
                true,
                key.public_key().as_ref()
            )
            .is_ok()
        );
        assert!(
            verify_with_key(
                envelope.to_string().as_bytes(),
                false,
                key.public_key().as_ref()
            )
            .is_err()
        );
        let mut corrupt = envelope;
        corrupt["payload"] = serde_json::Value::String("{}".into());
        assert!(
            verify_with_key(
                corrupt.to_string().as_bytes(),
                true,
                key.public_key().as_ref()
            )
            .is_err()
        );
    }

    #[test]
    fn versions_are_numeric() {
        assert!(version("0.1.10").unwrap() > version("0.1.9").unwrap());
        assert!(version("../file").is_err());
        assert!(version("1.2").is_err());
    }
    #[test]
    fn unsigned_manifest_is_rejected() {
        assert!(verify(br#"{"payload":"{}","signature":"00"}"#, false).is_err());
    }
}

//! App updates (plan R3), ported from the 0.1.x app
//! (`apps/client/src-tauri/src/updates.rs`, UPD-01..08) with the same rules
//! and tests: only artifacts named by a manifest signed with a pinned key,
//! on the release server, are ever installed, and never without the user's
//! click. Same manifest, same key, same cache files as 0.1.x.
//!
//! The download survives cancellation, network loss and restarts: the
//! partial file is resumed with `If-Range` when the server still serves the
//! same bytes, and a finished download stays ready across launches. The
//! signed manifest is kept with it and verified again on every launch.
//!
//! Errors are `code: message`; codes as in 0.1.x (`update`,
//! `update_network`, `update_canceled`, `update_converting`).
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::PathBuf;
use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;

/// A failure with its stable code (0.1.x `CommandError`).
#[derive(Debug)]
pub struct CommandError {
    pub code: &'static str,
    pub message: String,
}

impl CommandError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl std::fmt::Display for CommandError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for CommandError {}

impl From<storage::StorageError> for CommandError {
    fn from(e: storage::StorageError) -> Self {
        err(e)
    }
}

type Outcome<T> = std::result::Result<T, CommandError>;

/// Runs an update operation on its own small runtime (downloads can last
/// minutes; the library's runtime is not needed).
pub fn run<T>(f: impl std::future::Future<Output = Outcome<T>>) -> anyhow::Result<T> {
    static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    let rt = RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(1)
            .thread_name("miarina-updates")
            .enable_all()
            .build()
            .expect("update runtime")
    });
    rt.block_on(f).map_err(|e| anyhow::anyhow!(e))
}

/// Release server. Recette builds (`update-test-channel`) use a loopback
/// server and a test key given at build time: never the public channel.
#[cfg(not(feature = "update-test-channel"))]
const BASE: &str = "https://media.miarina.org";
#[cfg(feature = "update-test-channel")]
const BASE: &str = env!("MIARINA_UPDATE_TEST_BASE");
/// Signed manifests are small; anything larger is refused unread.
const MANIFEST_MAX: usize = 64 * 1024;
const ARTIFACT_MAX: u64 = 512 * 1024 * 1024;
const KEY_CHANNEL: &str = "update_channel";
const KEY_AUTO: &str = "update_auto_download";
#[cfg(target_os = "android")]
const ANDROID: bool = true;
#[cfg(not(target_os = "android"))]
const ANDROID: bool = false;

/// Pinned Ed25519 public keys: a manifest signed by any of them is accepted.
/// Rotation (docs/app-updates.md): ship the next key here first, sign with
/// it only once that release is installed.
fn keys() -> Vec<Vec<u8>> {
    #[cfg(not(feature = "update-test-channel"))]
    {
        vec![include_bytes!("../../../client/src-tauri/resources/update-public-key.bin").to_vec()]
    }
    #[cfg(feature = "update-test-channel")]
    {
        vec![hex(env!("MIARINA_UPDATE_TEST_KEY")).expect("hexadecimal test key")]
    }
}

/// Where and what: the running version (`MM_VERSION`), the cache folder
/// (`%LOCALAPPDATA%\\org.miarina.media`, as 0.1.x) and the database.
pub struct Config {
    pub installed: String,
    pub cache_dir: PathBuf,
    pub db_path: String,
}

static CONFIG: OnceLock<Config> = OnceLock::new();
static STATE: OnceLock<Updates> = OnceLock::new();

pub fn configure(config: Config) -> Outcome<()> {
    version(&config.installed)?;
    CONFIG
        .set(config)
        .map_err(|_| err("Updates already configured"))
}

fn config() -> Outcome<&'static Config> {
    CONFIG.get().ok_or_else(|| err("Updates not configured"))
}

pub fn state() -> &'static Updates {
    STATE.get_or_init(Updates::default)
}

#[derive(Default)]
pub struct Updates {
    downloaded: AtomicU64,
    lock: Mutex<()>,
    cancel: std::sync::Mutex<Option<CancellationToken>>,
    ready: Mutex<Option<Release>>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct Release {
    pub version: String,
    pub notes: String,
    pub url: String,
    pub sha256: String,
    pub size: u64,
}

/// Release track. Beta also receives stable releases when they are newer.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Channel {
    #[default]
    Stable,
    Beta,
}

impl Channel {
    fn name(self) -> &'static str {
        match self {
            Self::Stable => "stable",
            Self::Beta => "beta",
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePrefs {
    pub channel: Channel,
    /// UPD-05: off by default; only on unmetered networks, never installs.
    pub auto_download: bool,
}

#[derive(Deserialize)]
struct Envelope {
    payload: String,
    signature: String,
}

#[derive(Deserialize)]
struct Manifest {
    /// Signed with the rest: a beta manifest replayed at the stable address
    /// is refused. Manifests before 0.1.8 have none and are stable.
    #[serde(default)]
    channel: Channel,
    windows: Release,
    android: Release,
}

/// Kept next to the download so a later launch can resume or install it.
#[derive(Deserialize, Serialize)]
struct Saved {
    /// Signed envelope the release came from, verified again when loaded.
    manifest: String,
    channel: Channel,
    /// `ETag` (strong) or `Last-Modified` of the artifact, for `If-Range`.
    validator: Option<String>,
    ready: bool,
}

/// What the settings screen shows after a launch.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStatus {
    /// Version actually running (shown in Settings).
    pub installed: String,
    pub release: Option<Release>,
    pub ready: bool,
    pub downloaded: u64,
    pub downloading: bool,
}

fn err(e: impl std::fmt::Display) -> CommandError {
    CommandError::new("update", e.to_string())
}

/// Network failures get their own code: the interface explains that the
/// download resumes, instead of showing the HTTP library's text.
fn network(e: reqwest::Error) -> CommandError {
    CommandError::new("update_network", e.to_string())
}

fn hex(s: &str) -> Outcome<Vec<u8>> {
    if !s.len().is_multiple_of(2) || !s.is_ascii() {
        return Err(err("Invalid signature encoding"));
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).map_err(err))
        .collect()
}

fn version(s: &str) -> Outcome<[u64; 3]> {
    let v = s
        .split('.')
        .map(|x| x.parse::<u64>().map_err(err))
        .collect::<Outcome<Vec<_>>>()?;
    v.try_into().map_err(|_| err("Invalid release version"))
}

fn verify(raw: &[u8], channel: Channel) -> Outcome<Release> {
    verify_with_keys(raw, ANDROID, channel, BASE, &keys())
}

/// UPD-02: signature by a pinned key, channel, server, artifact name, size
/// and digest format; the manifest itself is bounded.
fn verify_with_keys(
    raw: &[u8],
    android: bool,
    channel: Channel,
    base: &str,
    keys: &[Vec<u8>],
) -> Outcome<Release> {
    if raw.len() > MANIFEST_MAX {
        return Err(err("Update manifest too large"));
    }
    let envelope: Envelope = serde_json::from_slice(raw).map_err(err)?;
    let signature = hex(&envelope.signature)?;
    let signed = keys.iter().any(|key| {
        ring::signature::UnparsedPublicKey::new(&ring::signature::ED25519, key)
            .verify(envelope.payload.as_bytes(), &signature)
            .is_ok()
    });
    if !signed {
        return Err(err("Update signature is invalid"));
    }
    let manifest: Manifest = serde_json::from_str(&envelope.payload).map_err(err)?;
    if manifest.channel != channel {
        return Err(err("Update manifest belongs to another channel"));
    }
    let r = if android {
        manifest.android
    } else {
        manifest.windows
    };
    version(&r.version)?;
    let suffix = if android { ".apk" } else { "-x64-setup.exe" };
    if r.url != format!("{base}/downloads/MiarinaMedia-{}{suffix}", r.version)
        || r.size == 0
        || r.size > ARTIFACT_MAX
        || hex(&r.sha256)?.len() != 32
        || r.notes.len() > 16000
    {
        return Err(err("Invalid release metadata"));
    }
    Ok(r)
}

fn client() -> Outcome<reqwest::Client> {
    #[cfg(feature = "update-test-channel")]
    assert!(
        BASE.starts_with("http://127.0.0.1:"),
        "the test channel only uses a loopback server"
    );
    reqwest::Client::builder()
        .https_only(cfg!(not(feature = "update-test-channel")))
        .redirect(reqwest::redirect::Policy::none())
        .connect_timeout(Duration::from_secs(20))
        // Per read, not for the whole transfer: a stalled server fails, a
        // slow but moving one does not.
        .read_timeout(Duration::from_secs(60))
        .build()
        .map_err(err)
}

/// Reads at most `MANIFEST_MAX` bytes.
async fn read_bounded(mut response: reqwest::Response) -> Outcome<Vec<u8>> {
    if response
        .content_length()
        .is_some_and(|n| n > MANIFEST_MAX as u64)
    {
        return Err(err("Update manifest too large"));
    }
    let mut bytes = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(network)? {
        if bytes.len() + chunk.len() > MANIFEST_MAX {
            return Err(err("Update manifest too large"));
        }
        bytes.extend_from_slice(&chunk);
    }
    Ok(bytes)
}

async fn fetch_manifest(client: &reqwest::Client, channel: Channel) -> Outcome<Option<Vec<u8>>> {
    let response = client
        .get(format!(
            "{BASE}/updates/{}.json?t={}",
            channel.name(),
            storage::now_ms()
        ))
        .send()
        .await
        .map_err(network)?;
    // No beta published yet: nothing more than stable to offer.
    if channel == Channel::Beta && response.status() == reqwest::StatusCode::NOT_FOUND {
        return Ok(None);
    }
    read_bounded(response.error_for_status().map_err(err)?)
        .await
        .map(Some)
}

fn settings<R>(f: impl FnOnce(&storage::Storage) -> Outcome<R>) -> Outcome<R> {
    let db = &config()?.db_path;
    crate::api::library::with_db(db, |s| f(s).map_err(|e| anyhow::anyhow!(e))).map_err(err)
}

pub fn prefs() -> UpdatePrefs {
    settings(|s| {
        Ok(UpdatePrefs {
            channel: s.setting(KEY_CHANNEL).ok().flatten().unwrap_or_default(),
            auto_download: s.setting(KEY_AUTO).ok().flatten().unwrap_or(false),
        })
    })
    .unwrap_or_default()
}

fn installed() -> Outcome<[u64; 3]> {
    version(&config()?.installed)
}

/// Newest signed release above the installed version, with its manifest.
async fn newest() -> Outcome<Option<(Release, Vec<u8>, Channel)>> {
    let client = client()?;
    let mut channels = vec![Channel::Stable];
    if prefs().channel == Channel::Beta {
        channels.push(Channel::Beta);
    }
    let mut best: Option<(Release, Vec<u8>, Channel)> = None;
    for channel in channels {
        let Some(raw) = fetch_manifest(&client, channel).await? else {
            continue;
        };
        let r = verify(&raw, channel)?;
        let newer = match &best {
            Some((b, ..)) => version(&r.version)? > version(&b.version)?,
            None => true,
        };
        if newer {
            best = Some((r, raw, channel));
        }
    }
    let current = installed()?;
    Ok(match best {
        Some((r, ..)) if version(&r.version)? <= current => None,
        other => other,
    })
}

pub async fn check() -> Outcome<Option<Release>> {
    Ok(newest().await?.map(|(r, ..)| r))
}

pub fn set_prefs(prefs: UpdatePrefs) -> Outcome<UpdatePrefs> {
    settings(|s| {
        s.set_setting(KEY_CHANNEL, &prefs.channel)?;
        s.set_setting(KEY_AUTO, &prefs.auto_download)?;
        Ok(())
    })?;
    Ok(prefs)
}

/// Files of the update in the app cache (same names as 0.1.7 so Android's
/// file provider keeps serving the APK).
struct Files {
    dest: PathBuf,
    part: PathBuf,
    saved: PathBuf,
}

impl Files {
    fn of() -> Outcome<Self> {
        let dir = config()?.cache_dir.clone();
        let dest = dir.join(if ANDROID {
            "miarina-update.apk"
        } else {
            "miarina-update.exe"
        });
        Ok(Self {
            part: dest.with_extension("part"),
            saved: dest.with_extension("json"),
            dest,
        })
    }

    fn load(&self) -> Option<(Saved, Release)> {
        let saved: Saved = serde_json::from_slice(&std::fs::read(&self.saved).ok()?).ok()?;
        let release = verify(saved.manifest.as_bytes(), saved.channel).ok()?;
        Some((saved, release))
    }

    fn store(&self, saved: &Saved) -> Outcome<()> {
        let tmp = self.saved.with_extension("json.tmp");
        std::fs::write(&tmp, serde_json::to_vec(saved).map_err(err)?).map_err(err)?;
        std::fs::rename(&tmp, &self.saved).map_err(err)
    }

    fn clear(&self) {
        for path in [&self.dest, &self.part, &self.saved] {
            let _ = std::fs::remove_file(path);
        }
    }
}

fn len(path: &std::path::Path) -> u64 {
    std::fs::metadata(path).map_or(0, |m| m.len())
}

/// UPD-03, at launch: drops what an installed or abandoned update left
/// behind and restores a finished download as ready.
pub fn restore() {
    let Ok(files) = Files::of() else { return };
    let Ok(current) = installed() else { return };
    let Some((saved, release)) = files.load() else {
        files.clear();
        return;
    };
    let newer = version(&release.version).is_ok_and(|v| v > current);
    if !newer {
        files.clear();
    } else if saved.ready
        && len(&files.dest) == release.size
        && let Ok(mut ready) = state().ready.try_lock()
    {
        *ready = Some(release);
    }
}

pub async fn status() -> Outcome<UpdateStatus> {
    let state = state();
    let downloading = state.lock.try_lock().is_err();
    let running = config()?.installed.clone();
    if let Some(r) = state.ready.lock().await.clone() {
        return Ok(UpdateStatus {
            installed: running,
            downloaded: r.size,
            release: Some(r),
            ready: true,
            downloading,
        });
    }
    let files = Files::of()?;
    let current = installed()?;
    let pending = files
        .load()
        .filter(|(_, r)| version(&r.version).is_ok_and(|v| v > current));
    Ok(match pending {
        Some((saved, r)) => UpdateStatus {
            installed: running,
            downloaded: if downloading {
                state.downloaded.load(Ordering::Relaxed)
            } else if saved.validator.is_some() {
                len(&files.part).min(r.size)
            } else {
                // Without a validator the next download starts over.
                0
            },
            release: Some(r),
            ready: false,
            downloading,
        },
        None => UpdateStatus {
            installed: running,
            release: None,
            ready: false,
            downloaded: 0,
            downloading,
        },
    })
}

/// Size and SHA-256 of a download, checked as bytes arrive.
struct Digesting {
    hash: Sha256,
    count: u64,
    size: u64,
}

impl Digesting {
    fn new(size: u64) -> Self {
        Self {
            hash: Sha256::new(),
            count: 0,
            size,
        }
    }

    fn push(&mut self, chunk: &[u8]) -> Outcome<()> {
        self.count += chunk.len() as u64;
        if self.count > self.size {
            return Err(err("Update size mismatch"));
        }
        self.hash.update(chunk);
        Ok(())
    }

    /// Refuses truncated, oversized or altered files.
    fn finish(self, sha256: &str) -> Outcome<()> {
        if self.count != self.size || self.hash.finalize().as_slice() != hex(sha256)?.as_slice() {
            return Err(err("Update checksum mismatch"));
        }
        Ok(())
    }
}

/// Hashes a file on disk without reading it whole into memory.
async fn digest_file(path: &std::path::Path, into: &mut Digesting) -> Outcome<()> {
    let mut file = tokio::fs::File::open(path).await.map_err(err)?;
    let mut buf = vec![0u8; 1 << 20];
    loop {
        let n = file.read(&mut buf).await.map_err(err)?;
        if n == 0 {
            return Ok(());
        }
        into.push(&buf[..n])?;
    }
}

/// Validator for `If-Range`: a strong ETag, else `Last-Modified`.
fn validator_of(headers: &reqwest::header::HeaderMap) -> Option<String> {
    let etag = headers
        .get(reqwest::header::ETAG)
        .and_then(|v| v.to_str().ok())
        .filter(|v| !v.starts_with("W/"));
    etag.or_else(|| {
        headers
            .get(reqwest::header::LAST_MODIFIED)
            .and_then(|v| v.to_str().ok())
    })
    .map(str::to_owned)
}

/// First byte of a `206` answer (`Content-Range: bytes START-END/TOTAL`).
fn range_start(headers: &reqwest::header::HeaderMap) -> Option<u64> {
    let value = headers.get(reqwest::header::CONTENT_RANGE)?.to_str().ok()?;
    let range = value.strip_prefix("bytes ")?;
    range.split('-').next()?.parse().ok()
}

enum Stop {
    /// Partial file kept for a later resume.
    Kept(CommandError),
    /// Partial file was wrong and is deleted.
    Dropped(CommandError),
}

impl From<CommandError> for Stop {
    fn from(e: CommandError) -> Self {
        Self::Kept(e)
    }
}

async fn transfer(
    files: &Files,
    r: &Release,
    mut saved: Saved,
    state: &Updates,
    token: &CancellationToken,
) -> std::result::Result<(), Stop> {
    let mut digest = Digesting::new(r.size);
    let mut have = if saved.validator.is_some() {
        len(&files.part)
    } else {
        0
    };
    if have >= r.size {
        have = 0;
    }
    if have > 0 {
        digest_file(&files.part, &mut digest).await?;
    }
    let mut request = client()?.get(&r.url);
    if let (true, Some(validator)) = (have > 0, saved.validator.as_deref()) {
        request = request
            .header(reqwest::header::RANGE, format!("bytes={have}-"))
            .header(reqwest::header::IF_RANGE, validator);
    }
    let mut response = request.send().await.map_err(network)?;
    if !response.status().is_success() {
        let e = err(format!("Update server answered {}", response.status()));
        // A refused range (416) would fail again: start over next time.
        return Err(if have > 0 {
            Stop::Dropped(e)
        } else {
            Stop::Kept(e)
        });
    }
    let resumed = have > 0
        && response.status() == reqwest::StatusCode::PARTIAL_CONTENT
        && range_start(response.headers()) == Some(have);
    if !resumed {
        if response.status() != reqwest::StatusCode::OK {
            return Err(Stop::Dropped(err(
                "Unexpected answer from the update server",
            )));
        }
        // The artifact changed or the server ignores ranges: start over.
        digest = Digesting::new(r.size);
    }
    saved.validator = validator_of(response.headers());
    saved.ready = false;
    files.store(&saved)?;
    let mut file = tokio::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .append(resumed)
        .truncate(!resumed)
        .open(&files.part)
        .await
        .map_err(err)?;
    state.downloaded.store(digest.count, Ordering::Relaxed);
    let received = async {
        loop {
            let chunk = tokio::select! {
                chunk = response.chunk() => chunk.map_err(network)?,
                () = token.cancelled() => {
                    return Err(Stop::Kept(CommandError::new(
                        "update_canceled",
                        "Update download canceled",
                    )));
                }
            };
            let Some(chunk) = chunk else { return Ok(()) };
            digest.push(&chunk).map_err(Stop::Dropped)?;
            file.write_all(&chunk).await.map_err(err)?;
            state.downloaded.store(digest.count, Ordering::Relaxed);
        }
    }
    .await;
    // On every path (cancel, network loss included): what was received is
    // on disk before the length is used for a resume.
    let flushed = file.flush().await;
    received?;
    flushed.map_err(err)?;
    file.sync_all().await.map_err(err)?;
    drop(file);
    if let Err(e) = digest.finish(&r.sha256) {
        return Err(Stop::Dropped(e));
    }
    if files.dest.exists() {
        std::fs::remove_file(&files.dest).map_err(err)?;
    }
    std::fs::rename(&files.part, &files.dest).map_err(err)?;
    saved.ready = true;
    files.store(&saved)?;
    Ok(())
}

pub async fn download() -> Outcome<Release> {
    let state = state();
    let _lock = state
        .lock
        .try_lock()
        .map_err(|_| err("An update operation is already running"))?;
    let token = CancellationToken::new();
    *state.cancel.lock().unwrap_or_else(|p| p.into_inner()) = Some(token.clone());
    *state.ready.lock().await = None;
    state.downloaded.store(0, Ordering::Relaxed);
    let (r, raw, channel) = newest()
        .await?
        .ok_or_else(|| err("No newer release available"))?;
    let files = Files::of()?;
    std::fs::create_dir_all(files.dest.parent().expect("cache folder")).map_err(err)?;
    let previous = files.load().filter(|(_, p)| *p == r);
    // Finished in an earlier session: check it again rather than download.
    if let Some((saved, _)) = &previous
        && saved.ready
        && len(&files.dest) == r.size
    {
        let mut digest = Digesting::new(r.size);
        if digest_file(&files.dest, &mut digest).await.is_ok() && digest.finish(&r.sha256).is_ok() {
            state.downloaded.store(r.size, Ordering::Relaxed);
            *state.ready.lock().await = Some(r.clone());
            return Ok(r);
        }
    }
    if previous.is_none() {
        files.clear();
    }
    let saved = Saved {
        manifest: String::from_utf8(raw).map_err(err)?,
        channel,
        validator: previous.and_then(|(s, _)| s.validator),
        ready: false,
    };
    match transfer(&files, &r, saved, state, &token).await {
        Ok(()) => {
            *state.ready.lock().await = Some(r.clone());
            Ok(r)
        }
        Err(Stop::Kept(e)) => Err(e),
        Err(Stop::Dropped(e)) => {
            let _ = std::fs::remove_file(&files.part);
            Err(e)
        }
    }
}

/// Stops the running download; its partial file is kept for a resume.
pub fn cancel() {
    if let Some(token) = state()
        .cancel
        .lock()
        .unwrap_or_else(|p| p.into_inner())
        .take()
    {
        token.cancel();
    }
}

/// Checks the downloaded installer again and starts it; the app then
/// closes through its normal exit path (torrents stopped, downloads
/// flushed), as 0.1.x.
pub async fn install(converting: bool) -> Outcome<()> {
    let state = state();
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
    // UPD-04: a conversion would be lost; running downloads are stopped by
    // the normal exit path and come back paused (or queued) after the update.
    if converting {
        return Err(CommandError::new(
            "update_converting",
            "A conversion is running; install once it is finished",
        ));
    }
    let files = Files::of()?;
    // Recheck immediately before execution; never accept a path from the
    // interface. Streamed: the installer is not read whole into memory.
    let mut digest = Digesting::new(r.size);
    let checked = digest_file(&files.dest, &mut digest).await;
    if checked.is_err() || digest.finish(&r.sha256).is_err() {
        *state.ready.lock().await = None;
        files.clear();
        return Err(err("Update file changed; download it again"));
    }
    #[cfg(windows)]
    std::process::Command::new(&files.dest)
        .spawn()
        .map_err(err)?;
    // Android: the APK checked just above stays in the app cache; the
    // interface hands it to the system installer (AppUpdateChannel.kt),
    // which asks the user.
    #[cfg(not(any(windows, target_os = "android")))]
    return Err(err(
        "Installing updates is not available on this platform yet",
    ));
    #[cfg(any(windows, target_os = "android"))]
    Ok(())
}

/// UPD-05: automatic downloads only when enabled, on an unmetered network
/// and outside battery saver. Installing still waits for the user.
pub fn auto_allowed() -> bool {
    prefs().auto_download && network_allows_auto()
}

#[cfg(windows)]
fn network_allows_auto() -> bool {
    use windows::Win32::Networking::NetworkListManager::{
        INetworkCostManager, NLM_CONNECTION_COST_APPROACHINGDATALIMIT,
        NLM_CONNECTION_COST_OVERDATALIMIT, NLM_CONNECTION_COST_ROAMING,
        NLM_CONNECTION_COST_UNRESTRICTED, NetworkListManager,
    };
    use windows::Win32::System::Com::{
        CLSCTX_ALL, COINIT_MULTITHREADED, CoCreateInstance, CoInitializeEx, CoUninitialize,
    };
    use windows::Win32::System::Power::{GetSystemPowerStatus, SYSTEM_POWER_STATUS};
    // SAFETY: out-parameters owned here; COM is initialized and released on
    // this thread, after the manager object is dropped.
    unsafe {
        let mut power = SYSTEM_POWER_STATUS::default();
        if GetSystemPowerStatus(&mut power).is_ok() && power.SystemStatusFlag == 1 {
            return false;
        }
        let init = CoInitializeEx(None, COINIT_MULTITHREADED);
        let cost = (|| -> windows::core::Result<u32> {
            let manager: INetworkCostManager =
                CoCreateInstance(&NetworkListManager, None, CLSCTX_ALL)?;
            let mut cost = 0u32;
            manager.GetCost(&mut cost, std::ptr::null())?;
            Ok(cost)
        })();
        if init.is_ok() {
            CoUninitialize();
        }
        let Ok(cost) = cost else { return false };
        let limited = (NLM_CONNECTION_COST_OVERDATALIMIT.0
            | NLM_CONNECTION_COST_ROAMING.0
            | NLM_CONNECTION_COST_APPROACHINGDATALIMIT.0) as u32;
        cost & NLM_CONNECTION_COST_UNRESTRICTED.0 as u32 != 0 && cost & limited == 0
    }
}

/// Android (UPD-06): background rules are not implemented yet.
#[cfg(not(windows))]
fn network_allows_auto() -> bool {
    false
}

pub fn progress() -> u64 {
    state().downloaded.load(Ordering::Relaxed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ring::signature::{Ed25519KeyPair, KeyPair};

    const BASE_TEST: &str = "https://media.miarina.org";

    fn key(seed: u8) -> Ed25519KeyPair {
        Ed25519KeyPair::from_seed_unchecked(&[seed; 32]).unwrap()
    }

    fn release(version: &str, suffix: &str) -> serde_json::Value {
        serde_json::json!({
            "version": version,
            "notes": "Test",
            "url": format!("{BASE_TEST}/downloads/MiarinaMedia-{version}{suffix}"),
            "size": 100,
            "sha256": "00".repeat(32)
        })
    }

    fn signed(payload: &str, signer: &Ed25519KeyPair) -> Vec<u8> {
        let signature: String = signer
            .sign(payload.as_bytes())
            .as_ref()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();
        serde_json::json!({ "payload": payload, "signature": signature })
            .to_string()
            .into_bytes()
    }

    fn payload(channel: Option<&str>, windows: serde_json::Value) -> String {
        let mut p = serde_json::json!({ "windows": windows, "android": release("0.1.8", ".apk") });
        if let Some(c) = channel {
            p["channel"] = serde_json::Value::String(c.into());
        }
        p.to_string()
    }

    fn check(raw: &[u8], channel: Channel) -> Outcome<Release> {
        verify_with_keys(
            raw,
            false,
            channel,
            BASE_TEST,
            &[key(7).public_key().as_ref().to_vec()],
        )
    }

    #[test]
    fn a_signed_manifest_is_accepted_for_its_platform() {
        let raw = signed(&payload(None, release("0.1.8", "-x64-setup.exe")), &key(7));
        assert_eq!(check(&raw, Channel::Stable).unwrap().version, "0.1.8");
        // The Android record of the same manifest is checked separately.
        let android = verify_with_keys(
            &raw,
            true,
            Channel::Stable,
            BASE_TEST,
            &[key(7).public_key().as_ref().to_vec()],
        );
        assert_eq!(
            android.unwrap().url,
            format!("{BASE_TEST}/downloads/MiarinaMedia-0.1.8.apk")
        );
    }

    #[test]
    fn forged_or_altered_manifests_are_refused() {
        let good = payload(None, release("0.1.8", "-x64-setup.exe"));
        // Signed by another key.
        assert!(check(&signed(&good, &key(8)), Channel::Stable).is_err());
        // Payload altered after signing.
        let raw = signed(&good, &key(7));
        let mut envelope: serde_json::Value = serde_json::from_slice(&raw).unwrap();
        envelope["payload"] = good.replace("0.1.8", "0.1.9").into();
        assert!(check(envelope.to_string().as_bytes(), Channel::Stable).is_err());
        // Signature not hexadecimal / truncated.
        envelope["payload"] = good.clone().into();
        envelope["signature"] = "zz".into();
        assert!(check(envelope.to_string().as_bytes(), Channel::Stable).is_err());
        // Unsigned against the pinned release key.
        assert!(verify(br#"{"payload":"{}","signature":"00"}"#, Channel::Stable).is_err());
    }

    #[test]
    fn an_oversized_manifest_is_refused_unread() {
        let mut big = release("0.1.8", "-x64-setup.exe");
        big["notes"] = "x".repeat(MANIFEST_MAX).into();
        let raw = signed(&payload(None, big), &key(7));
        assert!(raw.len() > MANIFEST_MAX);
        assert!(
            check(&raw, Channel::Stable)
                .err()
                .unwrap()
                .message
                .contains("too large")
        );
    }

    #[test]
    fn foreign_or_mismatched_urls_are_refused() {
        for url in [
            "http://media.miarina.org/downloads/MiarinaMedia-0.1.8-x64-setup.exe",
            "https://evil.example/downloads/MiarinaMedia-0.1.8-x64-setup.exe",
            "https://media.miarina.org.evil.example/downloads/MiarinaMedia-0.1.8-x64-setup.exe",
            "https://media.miarina.org/downloads/MiarinaMedia-0.1.7-x64-setup.exe",
            "https://media.miarina.org/downloads/../MiarinaMedia-0.1.8-x64-setup.exe",
            "https://media.miarina.org/downloads/MiarinaMedia-0.1.8.apk",
        ] {
            let mut r = release("0.1.8", "-x64-setup.exe");
            r["url"] = url.into();
            let raw = signed(&payload(None, r), &key(7));
            assert!(check(&raw, Channel::Stable).is_err(), "{url}");
        }
        for (field, value) in [
            ("size", serde_json::json!(0)),
            ("size", serde_json::json!(ARTIFACT_MAX + 1)),
            ("sha256", serde_json::json!("00".repeat(31))),
            ("version", serde_json::json!("0.1.8-beta")),
        ] {
            let mut r = release("0.1.8", "-x64-setup.exe");
            r[field] = value;
            let raw = signed(&payload(None, r), &key(7));
            assert!(check(&raw, Channel::Stable).is_err(), "{field}");
        }
    }

    #[test]
    fn channels_cannot_be_swapped() {
        let beta = signed(
            &payload(Some("beta"), release("0.1.9", "-x64-setup.exe")),
            &key(7),
        );
        assert!(check(&beta, Channel::Beta).is_ok());
        assert!(
            check(&beta, Channel::Stable).is_err(),
            "beta served as stable"
        );
        let stable = signed(&payload(None, release("0.1.8", "-x64-setup.exe")), &key(7));
        assert!(
            check(&stable, Channel::Beta).is_err(),
            "stable served as beta"
        );
    }

    #[test]
    fn downloads_must_match_size_and_digest() {
        let data = b"installer bytes";
        let sha: String = Sha256::digest(data)
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();
        let size = data.len() as u64;
        // Whole file in two chunks: accepted.
        let mut ok = Digesting::new(size);
        ok.push(&data[..4]).unwrap();
        ok.push(&data[4..]).unwrap();
        assert!(ok.finish(&sha).is_ok());
        // Truncated.
        let mut short = Digesting::new(size);
        short.push(&data[..size as usize - 1]).unwrap();
        assert!(short.finish(&sha).is_err());
        // Longer than announced: refused as soon as it overflows.
        let mut long = Digesting::new(size);
        long.push(data).unwrap();
        assert!(long.push(b"!").is_err());
        // Same size, other bytes.
        let mut altered = Digesting::new(size);
        altered.push(b"installer bytez").unwrap();
        assert!(altered.finish(&sha).is_err());
    }

    #[test]
    fn resume_uses_validators_and_ranges() {
        use reqwest::header::{CONTENT_RANGE, ETAG, HeaderMap, HeaderValue, LAST_MODIFIED};
        let mut h = HeaderMap::new();
        h.insert(
            LAST_MODIFIED,
            HeaderValue::from_static("Wed, 12 Nov 2026 10:00:00 GMT"),
        );
        assert_eq!(
            validator_of(&h).as_deref(),
            Some("Wed, 12 Nov 2026 10:00:00 GMT")
        );
        h.insert(ETAG, HeaderValue::from_static("\"abc\""));
        assert_eq!(validator_of(&h).as_deref(), Some("\"abc\""));
        // A weak ETag cannot be used with If-Range.
        h.insert(ETAG, HeaderValue::from_static("W/\"abc\""));
        assert_eq!(
            validator_of(&h).as_deref(),
            Some("Wed, 12 Nov 2026 10:00:00 GMT")
        );
        h.insert(
            CONTENT_RANGE,
            HeaderValue::from_static("bytes 1000-1999/2000"),
        );
        assert_eq!(range_start(&h), Some(1000));
        h.insert(CONTENT_RANGE, HeaderValue::from_static("bytes */2000"));
        assert_eq!(range_start(&h), None);
    }

    #[test]
    fn versions_are_numeric() {
        assert!(version("0.1.10").unwrap() > version("0.1.9").unwrap());
        assert!(version("../file").is_err());
        assert!(version("1.2").is_err());
    }
}

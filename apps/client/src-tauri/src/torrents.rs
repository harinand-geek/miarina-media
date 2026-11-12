//! Windows torrent commands. No session/network activity until Enable is pressed.
use crate::{commands::CommandError, state::AppState};
use mdm_torrent::{Config, Meta, Source, Torrents};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, path::PathBuf, sync::Arc, time::Duration};
use tauri::{AppHandle, Manager, State};
use tauri_plugin_dialog::DialogExt;
use tauri_plugin_opener::OpenerExt;
use tokio::sync::Mutex;

type Result<T> = std::result::Result<T, CommandError>;
const RECORDS: &str = "torrent_records_v1";
const LIMITS: &str = "torrent_limits_v1";

#[derive(Default)]
pub struct TorrentState {
    engine: Mutex<Option<Arc<Torrents>>>,
    pending: Mutex<HashMap<String, Meta>>,
    actions: Mutex<()>,
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Record {
    hash: String,
    name: String,
    folder: PathBuf,
    #[serde(default)]
    sequential: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileDto {
    index: usize,
    path: String,
    size: u64,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Preview {
    hash: String,
    name: String,
    files: Vec<FileDto>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Row {
    hash: String,
    name: String,
    folder: PathBuf,
    phase: String,
    done: u64,
    total: u64,
    uploaded: u64,
    down_speed: f64,
    up_speed: f64,
    peers: usize,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    enabled: bool,
    rows: Vec<Row>,
    download_limit: u64,
    upload_limit: u64,
}

fn error(_: impl std::fmt::Display) -> CommandError {
    CommandError::new(
        "torrent",
        "Torrent operation failed. Check the file, peers and available disk space.",
    )
}
fn records(app: &AppState) -> Result<Vec<Record>> {
    Ok(app.storage().setting(RECORDS)?.unwrap_or_default())
}
impl TorrentState {
    async fn engine(&self) -> Result<Arc<Torrents>> {
        self.engine.lock().await.clone().ok_or_else(|| {
            CommandError::new("torrent_disabled", "Enable the torrent session first.")
        })
    }
    pub async fn shutdown(&self) {
        if let Some(engine) = self.engine.lock().await.take() {
            engine.stop().await;
        }
    }
}

#[tauri::command]
pub async fn torrents_enable(
    app: AppHandle,
    state: State<'_, TorrentState>,
    data: State<'_, AppState>,
) -> Result<()> {
    let _action = state.actions.lock().await;
    let mut engine = state.engine.lock().await;
    if engine.is_none() {
        let mut config = Config::new(app.path().app_data_dir().map_err(error)?.join("torrents"));
        // Outgoing peer connections and DHT suffice; no router changes or LAN announcements.
        config.upnp = false;
        config.lsd = false;
        config.listen = false;
        // Read persisted configuration before starting any background workers.
        let saved_records = records(&data)?;
        let limits: (u64, u64) = data.storage().setting(LIMITS)?.unwrap_or((0, 0));
        let session = Torrents::start(config).await.map_err(error)?;
        for record in saved_records {
            if record.sequential
                && session.has(&record.hash)
                && let Err(e) = session.set_order(
                    &record.hash,
                    mdm_torrent::PieceOrder::InOrder {
                        first_and_last_first: false,
                    },
                )
            {
                session.stop().await;
                return Err(error(e));
            }
        }
        session.set_download_limit(Some(limits.0));
        session.set_upload_limit(Some(limits.1));
        *engine = Some(Arc::new(session));
    }
    Ok(())
}

#[tauri::command]
pub async fn torrents_disable(state: State<'_, TorrentState>) -> Result<()> {
    let _action = state.actions.lock().await;
    state.shutdown().await;
    state.pending.lock().await.clear();
    Ok(())
}

#[tauri::command]
pub async fn torrents_list(
    state: State<'_, TorrentState>,
    data: State<'_, AppState>,
) -> Result<Snapshot> {
    let engine = state.engine.lock().await.clone();
    let rows = records(&data)?
        .into_iter()
        .map(|r| {
            let stats = engine.as_ref().and_then(|e| e.stats(&r.hash).ok());
            Row {
                hash: r.hash,
                name: r.name,
                folder: r.folder,
                phase: stats
                    .as_ref()
                    .map(|s| format!("{:?}", s.phase).to_lowercase())
                    .unwrap_or("inactive".into()),
                done: stats.as_ref().map_or(0, |s| s.done),
                total: stats.as_ref().map_or(0, |s| s.total),
                uploaded: stats.as_ref().map_or(0, |s| s.uploaded),
                down_speed: stats.as_ref().map_or(0., |s| s.down_speed),
                up_speed: stats.as_ref().map_or(0., |s| s.up_speed),
                peers: stats.as_ref().map_or(0, |s| s.peers_live),
            }
        })
        .collect();
    Ok(Snapshot {
        enabled: engine.is_some(),
        rows,
        download_limit: engine
            .as_ref()
            .and_then(|e| e.download_limit())
            .unwrap_or(0),
        upload_limit: engine.as_ref().and_then(|e| e.upload_limit()).unwrap_or(0),
    })
}

#[tauri::command]
pub async fn torrents_preview(
    app: AppHandle,
    state: State<'_, TorrentState>,
    magnet: Option<String>,
) -> Result<Option<Preview>> {
    let engine = state.engine().await?;
    let source = if let Some(text) = magnet {
        if text.len() > 16_384 {
            return Err(error("link too long"));
        }
        Source::magnet(&text).ok_or_else(|| error("invalid magnet"))?
    } else {
        let picked = tauri::async_runtime::spawn_blocking(move || {
            app.dialog()
                .file()
                .add_filter("Torrent", &["torrent"])
                .blocking_pick_file()
        })
        .await
        .map_err(error)?;
        let Some(file) = picked else { return Ok(None) };
        let path = file.into_path().map_err(error)?;
        let bytes = tauri::async_runtime::spawn_blocking(move || mdm_torrent::read_file(&path))
            .await
            .map_err(error)?
            .map_err(error)?;
        Source::File(bytes)
    };
    let meta = engine
        .metadata(&source, Duration::from_secs(60), None)
        .await
        .map_err(error)?;
    let preview = Preview {
        hash: meta.info_hash.clone(),
        name: meta.name.clone(),
        files: meta
            .files
            .iter()
            .enumerate()
            .filter(|(_, f)| !f.padding)
            .map(|(index, f)| FileDto {
                index,
                path: f.path.to_string_lossy().into_owned(),
                size: f.size,
            })
            .collect(),
    };
    // Do not revive a preview from a session stopped/replaced during lookup.
    let _action = state.actions.lock().await;
    let current = state.engine().await?;
    if !Arc::ptr_eq(&current, &engine) {
        return Err(CommandError::new(
            "torrent_session_changed",
            "The torrent session changed. Inspect the link again.",
        ));
    }
    let mut pending = state.pending.lock().await;
    if pending.len() >= 8 {
        pending.clear();
    }
    pending.insert(meta.info_hash.clone(), meta);
    Ok(Some(preview))
}

fn validate_selection(meta: &Meta, files: &[usize]) -> Result<()> {
    let unique: std::collections::HashSet<_> = files.iter().copied().collect();
    if files.is_empty()
        || unique.len() != files.len()
        || files
            .iter()
            .any(|&i| meta.files.get(i).is_none_or(|f| f.padding))
    {
        return Err(CommandError::new(
            "torrent_selection",
            "Select at least one valid file.",
        ));
    }
    Ok(())
}

#[tauri::command]
pub async fn torrents_start(
    state: State<'_, TorrentState>,
    data: State<'_, AppState>,
    hash: String,
    files: Vec<usize>,
    sequential: bool,
) -> Result<()> {
    let _action = state.actions.lock().await;
    let engine = state.engine().await?;
    let meta = state
        .pending
        .lock()
        .await
        .get(&hash)
        .cloned()
        .ok_or_else(|| error("preview expired"))?;
    validate_selection(&meta, &files)?;
    let mut rows = records(&data)?;
    if rows.iter().any(|r| r.hash == hash) {
        return Err(CommandError::new(
            "torrent_duplicate",
            "This torrent is already in the list.",
        ));
    }
    let base = PathBuf::from(data.settings().download_dir).join("Torrents");
    std::fs::create_dir_all(&base).map_err(error)?;
    // An exclusive fresh directory: upstream's overwrite=true only ever sees our own files.
    let folder = (0..1000)
        .map(|n| base.join(format!("{}-{n}", meta.info_hash)))
        .find(|dir| std::fs::create_dir(dir).is_ok())
        .ok_or_else(|| error("cannot reserve destination"))?;
    let id = engine
        .add(&meta.torrent, &folder, Some(files), meta.peers, true)
        .await
        .map_err(error)?;
    rows.push(Record {
        hash: id.clone(),
        name: meta.name,
        folder,
        sequential,
    });
    let saved = data.storage().set_setting(RECORDS, &rows);
    if let Err(e) = saved {
        let _ = engine.remove(&id, false).await;
        return Err(e.into());
    }
    if sequential {
        engine
            .set_order(
                &id,
                mdm_torrent::PieceOrder::InOrder {
                    first_and_last_first: false,
                },
            )
            .map_err(error)?;
    }
    engine.resume(&id).await.map_err(error)?;
    state.pending.lock().await.remove(&hash);
    Ok(())
}

#[tauri::command]
pub async fn torrents_action(
    app: AppHandle,
    state: State<'_, TorrentState>,
    data: State<'_, AppState>,
    hash: String,
    action: String,
) -> Result<()> {
    let _action = state.actions.lock().await;
    let mut rows = records(&data)?;
    let row = rows
        .iter()
        .find(|r| r.hash == hash)
        .ok_or_else(|| error("unknown torrent"))?;
    if action == "reveal" {
        return app
            .opener()
            .open_path(row.folder.to_string_lossy(), None::<&str>)
            .map_err(error);
    }
    let engine = state.engine().await?;
    match action.as_str() {
        "pause" => engine.pause(&hash).await.map_err(error)?,
        "resume" => engine.resume(&hash).await.map_err(error)?,
        "remove" => {
            if engine.has(&hash) {
                engine.remove(&hash, false).await.map_err(error)?;
            }
            rows.retain(|r| r.hash != hash);
            data.storage().set_setting(RECORDS, &rows)?;
        }
        _ => return Err(error("invalid action")),
    }
    Ok(())
}

#[tauri::command]
pub async fn torrents_limits(
    state: State<'_, TorrentState>,
    data: State<'_, AppState>,
    download: u64,
    upload: u64,
) -> Result<()> {
    let _action = state.actions.lock().await;
    if download > u32::MAX as u64 || upload > u32::MAX as u64 {
        return Err(error("invalid limit"));
    }
    let engine = state.engine().await?;
    data.storage().set_setting(LIMITS, &(download, upload))?;
    engine.set_download_limit(Some(download));
    engine.set_upload_limit(Some(upload));
    Ok(())
}

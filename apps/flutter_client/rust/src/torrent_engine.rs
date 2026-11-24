//! Torrent session behind `api::torrents` (kept outside `api` so the
//! bridge generator does not expose it).

#[cfg(windows)]
mod platform {
    use std::collections::HashMap;
    use std::path::PathBuf;
    use std::sync::{Arc, LazyLock};
    use std::time::Duration;

    use anyhow::{Result, anyhow};
    use mdm_torrent::{Config, Meta, PieceOrder, Source, Torrents};
    use serde::{Deserialize, Serialize};
    use tokio::sync::Mutex;

    use crate::api::indexer::shared;
    use crate::api::torrents::{TorrentFile, TorrentPreview, TorrentRow, TorrentSnapshot};

    const RECORDS: &str = "torrent_records_v1";
    const LIMITS: &str = "torrent_limits_v1";
    const SHARING: &str = "torrent_sharing_v1";
    /// How often the sharing rules are checked.
    const SHARING_CHECK: Duration = Duration::from_secs(30);

    /// When finished torrents stop sharing: uploaded at least `ratio` times
    /// their size, or shared for `hours` since they finished; 0 = no rule.
    #[derive(Clone, Copy, Default, Serialize, Deserialize)]
    struct Sharing {
        ratio: f64,
        hours: u32,
    }

    fn sharing() -> Sharing {
        shared()
            .ok()
            .and_then(|parts| {
                parts
                    .storage
                    .lock()
                    .ok()?
                    .setting::<Sharing>(SHARING)
                    .ok()
                    .flatten()
            })
            .unwrap_or_default()
    }

    fn now_secs() -> i64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_secs() as i64)
    }

    /// Whether a finished torrent has shared enough under `rules`.
    fn shared_enough(rules: Sharing, uploaded: u64, total: u64, seeding_secs: i64) -> bool {
        let ratio = rules.ratio > 0.0 && total > 0 && uploaded as f64 >= rules.ratio * total as f64;
        let time = rules.hours > 0 && seeding_secs >= i64::from(rules.hours) * 3600;
        ratio || time
    }

    #[cfg(test)]
    pub fn shared_enough_for_test(
        ratio: f64,
        hours: u32,
        uploaded: u64,
        total: u64,
        seeding_secs: i64,
    ) -> bool {
        shared_enough(Sharing { ratio, hours }, uploaded, total, seeding_secs)
    }

    /// Notes when torrents finish and stops the sharing of those that
    /// reached a rule (as "Arrêter le partage" does).
    async fn enforce(engine: &Torrents) -> Result<()> {
        let _action = STATE.actions.lock().await;
        let rules = sharing();
        let now = now_secs();
        let mut rows = records()?;
        let mut changed = false;
        for r in &mut rows {
            let Ok(stats) = engine.stats(&r.hash) else {
                continue;
            };
            if format!("{:?}", stats.phase).to_lowercase() != "finished" {
                continue;
            }
            let since = match r.finished_at {
                Some(t) => t,
                None => {
                    r.finished_at = Some(now);
                    changed = true;
                    now
                }
            };
            if shared_enough(rules, stats.uploaded, stats.total, now - since) {
                engine.pause(&r.hash).await.map_err(failed)?;
            }
        }
        if changed {
            save_records(&rows)?;
        }
        Ok(())
    }

    pub fn set_sharing(ratio: f64, hours: u32) -> Result<()> {
        if !ratio.is_finite() || !(0.0..=100.0).contains(&ratio) || hours > 24 * 365 {
            return Err(failed("invalid sharing rule"));
        }
        let parts = shared()?;
        parts
            .storage
            .lock()
            .map_err(|_| anyhow!("storage lock poisoned"))?
            .set_setting(SHARING, &Sharing { ratio, hours })?;
        Ok(())
    }

    #[derive(Default)]
    struct TorrentState {
        engine: Mutex<Option<Arc<Torrents>>>,
        pending: Mutex<HashMap<String, Meta>>,
        actions: Mutex<()>,
    }

    static STATE: LazyLock<TorrentState> = LazyLock::new(TorrentState::default);

    /// Same records as the Tauri app (torrents listed even while off).
    #[derive(Clone, Serialize, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Record {
        hash: String,
        name: String,
        folder: PathBuf,
        #[serde(default)]
        sequential: bool,
        /// When the download finished (seconds since 1970), for the
        /// seeding time rule.
        #[serde(default)]
        finished_at: Option<i64>,
    }

    /// Any engine failure: the detail stays out of the UI.
    fn failed(_: impl std::fmt::Display) -> anyhow::Error {
        anyhow!("torrent")
    }

    fn records() -> Result<Vec<Record>> {
        let parts = shared()?;
        let records = parts
            .storage
            .lock()
            .map_err(|_| anyhow!("storage lock poisoned"))?
            .setting(RECORDS)?
            .unwrap_or_default();
        Ok(records)
    }

    fn save_records(rows: &[Record]) -> Result<()> {
        let parts = shared()?;
        parts
            .storage
            .lock()
            .map_err(|_| anyhow!("storage lock poisoned"))?
            .set_setting(RECORDS, &rows)?;
        Ok(())
    }

    /// Runs on the shared runtime (these functions are called from the
    /// bridge's worker threads, outside it).
    fn run<T>(f: impl std::future::Future<Output = Result<T>>) -> Result<T> {
        shared()?.runtime.block_on(f)
    }

    async fn current_engine() -> Result<Arc<Torrents>> {
        STATE
            .engine
            .lock()
            .await
            .clone()
            .ok_or_else(|| anyhow!("torrent_disabled"))
    }

    pub fn enable(data_dir: &str) -> Result<()> {
        let dir = PathBuf::from(data_dir).join("torrents");
        run(async move {
            let _action = STATE.actions.lock().await;
            let mut engine = STATE.engine.lock().await;
            if engine.is_none() {
                let mut config = Config::new(dir);
                // Outgoing peer connections and DHT suffice: no router
                // changes, no LAN announcements, no listening port.
                config.upnp = false;
                config.lsd = false;
                config.listen = false;
                let saved = records()?;
                let limits: (u64, u64) = {
                    let parts = shared()?;
                    let db = parts
                        .storage
                        .lock()
                        .map_err(|_| anyhow!("storage lock poisoned"))?;
                    db.setting(LIMITS)?.unwrap_or((0, 0))
                };
                let session = Torrents::start(config).await.map_err(failed)?;
                for record in saved {
                    if record.sequential
                        && session.has(&record.hash)
                        && let Err(e) = session.set_order(
                            &record.hash,
                            PieceOrder::InOrder {
                                first_and_last_first: false,
                            },
                        )
                    {
                        session.stop().await;
                        return Err(failed(e));
                    }
                }
                session.set_download_limit(Some(limits.0));
                session.set_upload_limit(Some(limits.1));
                let session = Arc::new(session);
                *engine = Some(session.clone());
                // The sharing rules, while this session lives.
                tokio::spawn(async move {
                    loop {
                        tokio::time::sleep(SHARING_CHECK).await;
                        let current = STATE.engine.lock().await.clone();
                        match current {
                            Some(e) if Arc::ptr_eq(&e, &session) => {
                                let _ = enforce(&e).await;
                            }
                            _ => break,
                        }
                    }
                });
            }
            Ok(())
        })
    }

    pub fn disable() -> Result<()> {
        run(async {
            let _action = STATE.actions.lock().await;
            if let Some(engine) = STATE.engine.lock().await.take() {
                engine.stop().await;
            }
            STATE.pending.lock().await.clear();
            Ok(())
        })
    }

    pub fn list() -> Result<TorrentSnapshot> {
        run(async {
            let engine = STATE.engine.lock().await.clone();
            let rows = records()?
                .into_iter()
                .map(|r| {
                    let stats = engine.as_ref().and_then(|e| e.stats(&r.hash).ok());
                    TorrentRow {
                        hash: r.hash,
                        name: r.name,
                        folder: r.folder.to_string_lossy().into_owned(),
                        phase: stats
                            .as_ref()
                            .map(|s| format!("{:?}", s.phase).to_lowercase())
                            .unwrap_or_else(|| "inactive".into()),
                        done: stats.as_ref().map_or(0, |s| s.done),
                        total: stats.as_ref().map_or(0, |s| s.total),
                        uploaded: stats.as_ref().map_or(0, |s| s.uploaded),
                        down_speed: stats.as_ref().map_or(0., |s| s.down_speed),
                        up_speed: stats.as_ref().map_or(0., |s| s.up_speed),
                        peers: stats.as_ref().map_or(0, |s| s.peers_live as u32),
                    }
                })
                .collect();
            let rules = sharing();
            Ok(TorrentSnapshot {
                enabled: engine.is_some(),
                target_ratio: rules.ratio,
                seed_hours: rules.hours,
                rows,
                download_limit: engine
                    .as_ref()
                    .and_then(|e| e.download_limit())
                    .unwrap_or(0),
                upload_limit: engine.as_ref().and_then(|e| e.upload_limit()).unwrap_or(0),
            })
        })
    }

    pub fn preview(magnet: Option<String>, file: Option<String>) -> Result<TorrentPreview> {
        run(async move {
            let engine = current_engine().await?;
            let source = match (magnet, file) {
                (Some(text), _) => {
                    if text.len() > 16_384 {
                        return Err(anyhow!("torrent_link"));
                    }
                    Source::magnet(text.trim()).ok_or_else(|| anyhow!("torrent_link"))?
                }
                (None, Some(path)) => {
                    let bytes = tokio::task::spawn_blocking(move || {
                        mdm_torrent::read_file(std::path::Path::new(&path))
                    })
                    .await
                    .map_err(failed)?
                    .map_err(failed)?;
                    Source::File(bytes)
                }
                (None, None) => return Err(anyhow!("torrent_link")),
            };
            let meta = engine
                .metadata(&source, Duration::from_secs(60), None)
                .await
                .map_err(failed)?;
            let preview = TorrentPreview {
                hash: meta.info_hash.clone(),
                name: meta.name.clone(),
                files: meta
                    .files
                    .iter()
                    .enumerate()
                    .filter(|(_, f)| !f.padding)
                    .map(|(index, f)| TorrentFile {
                        index: index as u32,
                        path: f.path.to_string_lossy().into_owned(),
                        size: f.size,
                    })
                    .collect(),
            };
            // Do not revive a preview from a session stopped or replaced
            // during the lookup.
            let _action = STATE.actions.lock().await;
            let current = current_engine().await?;
            if !Arc::ptr_eq(&current, &engine) {
                return Err(anyhow!("torrent_session_changed"));
            }
            let mut pending = STATE.pending.lock().await;
            if pending.len() >= 8 {
                pending.clear();
            }
            pending.insert(meta.info_hash.clone(), meta);
            Ok(preview)
        })
    }

    fn validate_selection(meta: &Meta, files: &[usize]) -> Result<()> {
        let unique: std::collections::HashSet<_> = files.iter().copied().collect();
        if files.is_empty()
            || unique.len() != files.len()
            || files
                .iter()
                .any(|&i| meta.files.get(i).is_none_or(|f| f.padding))
        {
            return Err(anyhow!("torrent_selection"));
        }
        Ok(())
    }

    pub fn start(hash: String, files: Vec<u32>, sequential: bool) -> Result<()> {
        let files: Vec<usize> = files.into_iter().map(|i| i as usize).collect();
        let download_dir = crate::api::get::get_settings()?.download_dir;
        run(async move {
            let _action = STATE.actions.lock().await;
            let engine = current_engine().await?;
            let meta = STATE
                .pending
                .lock()
                .await
                .get(&hash)
                .cloned()
                .ok_or_else(|| anyhow!("torrent_expired"))?;
            validate_selection(&meta, &files)?;
            let mut rows = records()?;
            if rows.iter().any(|r| r.hash == hash) {
                return Err(anyhow!("torrent_duplicate"));
            }
            let base = PathBuf::from(download_dir).join("Torrents");
            std::fs::create_dir_all(&base).map_err(failed)?;
            // An exclusive fresh folder: the engine only ever writes there.
            let folder = (0..1000)
                .map(|n| base.join(format!("{}-{n}", meta.info_hash)))
                .find(|dir| std::fs::create_dir(dir).is_ok())
                .ok_or_else(|| failed("cannot reserve destination"))?;
            let id = engine
                .add(&meta.torrent, &folder, Some(files), meta.peers, true)
                .await
                .map_err(failed)?;
            rows.push(Record {
                hash: id.clone(),
                name: meta.name,
                folder,
                sequential,
                finished_at: None,
            });
            if let Err(e) = save_records(&rows) {
                let _ = engine.remove(&id, false).await;
                return Err(e);
            }
            if sequential {
                engine
                    .set_order(
                        &id,
                        PieceOrder::InOrder {
                            first_and_last_first: false,
                        },
                    )
                    .map_err(failed)?;
            }
            engine.resume(&id).await.map_err(failed)?;
            STATE.pending.lock().await.remove(&hash);
            Ok(())
        })
    }

    pub fn action(hash: String, action: String) -> Result<()> {
        run(async move {
            let _action = STATE.actions.lock().await;
            let mut rows = records()?;
            if !rows.iter().any(|r| r.hash == hash) {
                return Err(failed("unknown torrent"));
            }
            let engine = current_engine().await?;
            match action.as_str() {
                "pause" => engine.pause(&hash).await.map_err(failed)?,
                "resume" => engine.resume(&hash).await.map_err(failed)?,
                "remove" => {
                    // The downloaded files stay on disk.
                    if engine.has(&hash) {
                        engine.remove(&hash, false).await.map_err(failed)?;
                    }
                    rows.retain(|r| r.hash != hash);
                    save_records(&rows)?;
                }
                _ => return Err(failed("invalid action")),
            }
            Ok(())
        })
    }

    pub fn limits(download: u64, upload: u64) -> Result<()> {
        if download > u32::MAX as u64 || upload > u32::MAX as u64 {
            return Err(failed("invalid limit"));
        }
        run(async move {
            let _action = STATE.actions.lock().await;
            let engine = current_engine().await?;
            {
                let parts = shared()?;
                parts
                    .storage
                    .lock()
                    .map_err(|_| anyhow!("storage lock poisoned"))?
                    .set_setting(LIMITS, &(download, upload))?;
            }
            engine.set_download_limit(Some(download));
            engine.set_upload_limit(Some(upload));
            Ok(())
        })
    }
}

#[cfg(not(windows))]
mod platform {
    use crate::api::torrents::{TorrentPreview, TorrentSnapshot};
    use anyhow::{Result, bail};

    pub fn enable(_: &str) -> Result<()> {
        bail!("unsupported_platform")
    }
    pub fn disable() -> Result<()> {
        Ok(())
    }
    pub fn list() -> Result<TorrentSnapshot> {
        Ok(TorrentSnapshot {
            enabled: false,
            rows: Vec::new(),
            download_limit: 0,
            upload_limit: 0,
            target_ratio: 0.0,
            seed_hours: 0,
        })
    }
    pub fn set_sharing(_: f64, _: u32) -> Result<()> {
        bail!("unsupported_platform")
    }
    pub fn preview(_: Option<String>, _: Option<String>) -> Result<TorrentPreview> {
        bail!("unsupported_platform")
    }
    pub fn start(_: String, _: Vec<u32>, _: bool) -> Result<()> {
        bail!("unsupported_platform")
    }
    pub fn action(_: String, _: String) -> Result<()> {
        bail!("unsupported_platform")
    }
    pub fn limits(_: u64, _: u64) -> Result<()> {
        bail!("unsupported_platform")
    }
}

pub use platform::*;

#[cfg(all(test, windows))]
mod tests {
    #[test]
    fn sharing_stops_at_the_ratio_or_the_time() {
        use super::platform::shared_enough_for_test as enough;
        let gib = 1u64 << 30;
        // No rule: sharing goes on.
        assert!(!enough(0.0, 0, 5 * gib, gib, 999_999));
        // Ratio 1.0: once as much was sent as received.
        assert!(!enough(1.0, 0, gib / 2, gib, 0));
        assert!(enough(1.0, 0, gib, gib, 0));
        // 24 h, counted from the end of the download.
        assert!(!enough(0.0, 24, 0, gib, 23 * 3600));
        assert!(enough(0.0, 24, 0, gib, 24 * 3600));
    }
}

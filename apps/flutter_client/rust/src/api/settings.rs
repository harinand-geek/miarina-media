use anyhow::Result;
use serde_json::Value;

use super::library::with_db;

/// A setting of the shared `settings` table, as JSON text (None when unset).
pub fn settings_get(db_path: String, key: String) -> Result<Option<String>> {
    with_db(&db_path, |db| {
        Ok(db.setting::<Value>(&key)?.map(|v| v.to_string()))
    })
}

/// Stores `json` (any JSON value) under `key`.
pub fn settings_set(db_path: String, key: String, json: String) -> Result<()> {
    let value: Value = serde_json::from_str(&json)?;
    with_db(&db_path, |db| Ok(db.set_setting(&key, &value)?))
}

/// A playback-state value (resume positions `mm:position:<id>`, play
/// history `mm:playHistory:v1`…), same keys as the Tauri app.
pub fn playback_get(db_path: String, key: String) -> Result<Option<String>> {
    with_db(&db_path, |db| Ok(db.playback_value(&key)?))
}

/// Sets (or removes, with None) playback-state values in one transaction;
/// unknown keys are refused by the core.
pub fn playback_set(db_path: String, changes: Vec<(String, Option<String>)>) -> Result<()> {
    with_db(&db_path, |db| Ok(db.write_playback(&changes)?))
}

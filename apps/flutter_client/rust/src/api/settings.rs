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

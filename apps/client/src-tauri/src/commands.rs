//! Narrow, validated commands exposed to the frontend.

use media_core::{UrlError, validate_media_url as validate};
use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ValidatedLink {
    pub url: String,
    pub host: String,
}

/// Validates a pasted link before analysis. Errors are returned as stable
/// codes so the UI can show the message defined by the design.
#[tauri::command]
pub fn validate_media_url(url: String) -> Result<ValidatedLink, UrlError> {
    let valid = validate(&url)?;
    Ok(ValidatedLink {
        url: valid.as_str().to_owned(),
        host: valid.host().to_owned(),
    })
}

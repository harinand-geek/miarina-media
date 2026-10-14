//! Validation of user-supplied media URLs.

use serde::Serialize;
use thiserror::Error;
use url::Url;

pub const MAX_URL_LEN: usize = 2_048;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Error, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum UrlError {
    #[error("the link is empty")]
    Empty,
    #[error("the link is too long")]
    TooLong,
    #[error("this doesn't look like a complete link")]
    Malformed,
    #[error("only http and https links are supported")]
    UnsupportedScheme,
    #[error("the link has no host")]
    MissingHost,
    #[error("links containing a user name or password are not accepted")]
    ContainsCredentials,
}

/// A URL that passed [`validate_media_url`]. Only this type is accepted by
/// download engines.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidatedUrl(Url);

impl ValidatedUrl {
    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }

    pub fn host(&self) -> &str {
        self.0.host_str().unwrap_or_default()
    }

    /// Form safe for logs and history: scheme and host only, because paths
    /// and query strings may carry tokens.
    pub fn redacted(&self) -> String {
        format!("{}://{}", self.0.scheme(), self.host())
    }
}

pub fn validate_media_url(input: &str) -> Result<ValidatedUrl, UrlError> {
    let input = input.trim();
    if input.is_empty() {
        return Err(UrlError::Empty);
    }
    if input.len() > MAX_URL_LEN {
        return Err(UrlError::TooLong);
    }
    let url = Url::parse(input).map_err(|_| UrlError::Malformed)?;
    if !matches!(url.scheme(), "http" | "https") {
        return Err(UrlError::UnsupportedScheme);
    }
    if url.host_str().is_none_or(str::is_empty) {
        return Err(UrlError::MissingHost);
    }
    if !url.username().is_empty() || url.password().is_some() {
        return Err(UrlError::ContainsCredentials);
    }
    Ok(ValidatedUrl(url))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_http_and_https() {
        let url = validate_media_url("  https://mango.blender.org/download/  ").unwrap();
        assert_eq!(url.as_str(), "https://mango.blender.org/download/");
        assert_eq!(url.host(), "mango.blender.org");
        assert!(validate_media_url("http://example.org/a.mp4").is_ok());
    }

    #[test]
    fn rejects_missing_scheme() {
        assert_eq!(
            validate_media_url("mango.blender"),
            Err(UrlError::Malformed)
        );
    }

    #[test]
    fn rejects_other_schemes() {
        for input in [
            "file:///C:/Windows/win.ini",
            "javascript:alert(1)",
            "ftp://example.org/a",
            "data:text/plain,hi",
        ] {
            assert_eq!(
                validate_media_url(input),
                Err(UrlError::UnsupportedScheme),
                "{input}"
            );
        }
    }

    #[test]
    fn rejects_credentials() {
        assert_eq!(
            validate_media_url("https://user:pass@example.org/"),
            Err(UrlError::ContainsCredentials)
        );
    }

    #[test]
    fn rejects_empty_and_oversized_input() {
        assert_eq!(validate_media_url("   "), Err(UrlError::Empty));
        let long = format!("https://example.org/{}", "a".repeat(MAX_URL_LEN));
        assert_eq!(validate_media_url(&long), Err(UrlError::TooLong));
    }

    #[test]
    fn rejects_argument_injection_shapes() {
        assert!(validate_media_url("--exec calc.exe").is_err());
        assert!(validate_media_url("-o C:/x").is_err());
    }

    #[test]
    fn redacts_path_and_query() {
        let url = validate_media_url("https://cdn.example.org/v.mp4?token=secret").unwrap();
        assert_eq!(url.redacted(), "https://cdn.example.org");
    }
}

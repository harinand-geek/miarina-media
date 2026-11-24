//! Untrusted `yt-dlp --dump-single-json` output, parsed leniently: every
//! field is optional and unknown fields are ignored.

use std::collections::BTreeMap;

use serde::Deserialize;

/// A value of the wrong type or out of range (a negative size, a text
/// where a number is expected) is dropped instead of failing the whole
/// analysis: the extractor's output is untrusted and varies by site.
fn lenient<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: serde::de::DeserializeOwned,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(serde_json::from_value(value).ok())
}

/// Upper bound accepted for the JSON document.
pub const MAX_JSON_BYTES: usize = 32 * 1024 * 1024;

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawFormat {
    pub format_id: Option<String>,
    pub ext: Option<String>,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub height: Option<u32>,
    #[serde(default, deserialize_with = "lenient")]
    pub fps: Option<f64>,
    #[serde(default, deserialize_with = "lenient")]
    pub abr: Option<f64>,
    #[serde(default, deserialize_with = "lenient")]
    pub tbr: Option<f64>,
    #[serde(default, deserialize_with = "lenient")]
    pub filesize: Option<u64>,
    #[serde(default, deserialize_with = "lenient")]
    pub filesize_approx: Option<u64>,
    pub protocol: Option<String>,
    pub has_drm: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawInfo {
    #[serde(rename = "_type")]
    pub kind: Option<String>,
    pub title: Option<String>,
    pub uploader: Option<String>,
    pub channel: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub duration: Option<f64>,
    pub upload_date: Option<String>,
    pub release_date: Option<String>,
    /// Picture published by the site (untrusted URL).
    pub thumbnail: Option<String>,
    pub license: Option<String>,
    pub webpage_url: Option<String>,
    pub extractor_key: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub is_live: Option<bool>,
    pub live_status: Option<String>,
    pub formats: Option<Vec<RawFormat>>,
    /// Single-format results expose their format fields at the top level.
    pub format_id: Option<String>,
    pub ext: Option<String>,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub height: Option<u32>,
    #[serde(default, deserialize_with = "lenient")]
    pub filesize: Option<u64>,
    #[serde(default, deserialize_with = "lenient")]
    pub filesize_approx: Option<u64>,
    /// Playlist (`_type: playlist`): its entries, listed flat (bounded by
    /// `--playlist-items`), and the source's total when it gives one.
    pub entries: Option<Vec<RawEntry>>,
    /// Subtitles published by the source, by language (not the automatic
    /// captions).
    pub subtitles: Option<BTreeMap<String, Vec<RawSubtitle>>>,
    #[serde(default, deserialize_with = "lenient")]
    pub playlist_count: Option<u64>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawSubtitle {
    pub ext: Option<String>,
    pub name: Option<String>,
}

/// One playlist entry as listed by `--flat-playlist` (untrusted).
#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawEntry {
    #[serde(rename = "_type")]
    pub kind: Option<String>,
    pub url: Option<String>,
    pub webpage_url: Option<String>,
    pub title: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub duration: Option<f64>,
    pub ie_key: Option<String>,
    pub thumbnail: Option<String>,
    pub thumbnails: Option<Vec<RawThumbnail>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawThumbnail {
    pub url: Option<String>,
    #[serde(default, deserialize_with = "lenient")]
    pub width: Option<u32>,
}

impl RawFormat {
    pub fn id(&self) -> Option<&str> {
        self.format_id.as_deref()
    }

    pub fn size(&self) -> Option<u64> {
        self.filesize.or(self.filesize_approx)
    }

    /// `true`/"maybe" both count: protected formats are never offered.
    pub fn drm(&self) -> bool {
        match &self.has_drm {
            Some(serde_json::Value::Bool(b)) => *b,
            Some(serde_json::Value::String(s)) => s != "false",
            _ => false,
        }
    }

    fn codec(value: &Option<String>) -> Option<&str> {
        value.as_deref().filter(|c| *c != "none" && !c.is_empty())
    }

    pub fn video_codec(&self) -> Option<&str> {
        Self::codec(&self.vcodec)
    }

    pub fn audio_codec(&self) -> Option<&str> {
        Self::codec(&self.acodec)
    }

    pub fn has_video(&self) -> bool {
        self.video_codec().is_some()
            || (self.vcodec.is_none()
                && self.height.is_some()
                && self.protocol.as_deref() != Some("mhtml"))
    }

    pub fn is_audio_only(&self) -> bool {
        self.vcodec.as_deref() == Some("none") && self.audio_codec().is_some()
    }

    /// Video with its own audio track (or unknown codecs: a complete file).
    pub fn is_progressive(&self) -> bool {
        (self.has_video() && self.audio_codec().is_some())
            || (self.vcodec.is_none() && self.acodec.is_none())
    }
}

impl RawInfo {
    pub fn parse(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() > MAX_JSON_BYTES {
            return Err("extractor output too large".into());
        }
        serde_json::from_slice(bytes).map_err(|e| format!("unreadable extractor output: {e}"))
    }

    pub fn is_live(&self) -> bool {
        self.is_live == Some(true)
            || matches!(
                self.live_status.as_deref(),
                Some("is_live" | "is_upcoming" | "post_live")
            )
    }

    /// Formats offered by the source, including the single-format case.
    pub fn formats(&self) -> Vec<RawFormat> {
        match &self.formats {
            Some(formats) if !formats.is_empty() => formats.clone(),
            _ => self
                .format_id
                .as_ref()
                .map(|id| {
                    vec![RawFormat {
                        format_id: Some(id.clone()),
                        ext: self.ext.clone(),
                        vcodec: self.vcodec.clone(),
                        acodec: self.acodec.clone(),
                        height: self.height,
                        filesize: self.filesize,
                        filesize_approx: self.filesize_approx,
                        ..Default::default()
                    }]
                })
                .unwrap_or_default(),
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn a_bad_number_is_dropped_not_fatal() {
        let info = super::RawInfo::parse(
            br#"{"title":"T","duration":"n/a","formats":[{"format_id":"1","filesize":-111004,"height":720}]}"#,
        )
        .unwrap();
        assert_eq!(info.duration, None);
        assert_eq!(info.formats()[0].filesize, None);
        assert_eq!(info.formats()[0].height, Some(720));
    }
}

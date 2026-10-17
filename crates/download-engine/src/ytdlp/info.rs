//! Untrusted `yt-dlp --dump-single-json` output, parsed leniently: every
//! field is optional and unknown fields are ignored.

use serde::Deserialize;

/// Upper bound accepted for the JSON document.
pub const MAX_JSON_BYTES: usize = 32 * 1024 * 1024;

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RawFormat {
    pub format_id: Option<String>,
    pub ext: Option<String>,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    pub height: Option<u32>,
    pub fps: Option<f64>,
    pub abr: Option<f64>,
    pub tbr: Option<f64>,
    pub filesize: Option<u64>,
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
    pub duration: Option<f64>,
    pub upload_date: Option<String>,
    pub release_date: Option<String>,
    /// Picture published by the site (untrusted URL).
    pub thumbnail: Option<String>,
    pub license: Option<String>,
    pub webpage_url: Option<String>,
    pub extractor_key: Option<String>,
    pub is_live: Option<bool>,
    pub live_status: Option<String>,
    pub formats: Option<Vec<RawFormat>>,
    /// Single-format results expose their format fields at the top level.
    pub format_id: Option<String>,
    pub ext: Option<String>,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    pub height: Option<u32>,
    pub filesize: Option<u64>,
    pub filesize_approx: Option<u64>,
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
        self.video_codec().is_some() || self.height.is_some()
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

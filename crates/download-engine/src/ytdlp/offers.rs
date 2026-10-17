//! Turns the formats a source provides into the choices shown by the
//! design (Video / Audio only), without inventing qualities.

use serde::{Deserialize, Serialize};

use super::info::{RawFormat, RawInfo};

/// What the engine runs for a choice. Serialized as the task's `format_id`;
/// it comes back from the UI, so it is validated before use.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FormatSpec {
    /// yt-dlp `-f` selector, built from source format ids.
    #[serde(rename = "s")]
    pub selector: String,
    /// `--merge-output-format` when video and audio are separate streams.
    #[serde(rename = "m", default, skip_serializing_if = "Option::is_none")]
    pub merge: Option<String>,
    /// `--audio-format` for audio extraction/conversion.
    #[serde(rename = "x", default, skip_serializing_if = "Option::is_none")]
    pub extract_audio: Option<String>,
    /// Constant bitrate of the conversion in kbps (`--audio-quality <n>K`);
    /// `None` keeps yt-dlp's best VBR. Lossy formats only.
    #[serde(rename = "b", default, skip_serializing_if = "Option::is_none")]
    pub audio_kbps: Option<u32>,
}

const MERGE_FORMATS: [&str; 3] = ["mp4", "webm", "mkv"];
const AUDIO_FORMATS: [&str; 4] = ["mp3", "m4a", "flac", "opus"];
/// Bitrates offered for MP3 conversion, highest first.
pub const AUDIO_BITRATES: [u32; 4] = [320, 256, 192, 128];
const MAX_SELECTOR_LEN: usize = 200;

impl FormatSpec {
    pub fn encode(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }

    /// Parses and validates a spec received from the UI.
    pub fn decode(raw: &str) -> Result<Self, String> {
        let spec: Self = serde_json::from_str(raw).map_err(|_| "invalid format".to_owned())?;
        let selector_ok = !spec.selector.is_empty()
            && spec.selector.len() <= MAX_SELECTOR_LEN
            && !spec.selector.starts_with('-')
            && spec
                .selector
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || "+-_/[]=<>.*:".contains(c));
        let merge_ok = spec
            .merge
            .as_deref()
            .is_none_or(|m| MERGE_FORMATS.contains(&m));
        let audio_ok = spec
            .extract_audio
            .as_deref()
            .is_none_or(|a| AUDIO_FORMATS.contains(&a));
        let bitrate_ok = spec.audio_kbps.is_none_or(|kbps| {
            AUDIO_BITRATES.contains(&kbps)
                && spec.extract_audio.as_deref().is_some_and(|a| a != "flac")
        });
        if selector_ok && merge_ok && audio_ok && bitrate_ok {
            Ok(spec)
        } else {
            Err("invalid format".to_owned())
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Offer {
    pub spec: FormatSpec,
    pub quality: String,
    pub detail: String,
    pub size_bytes: Option<u64>,
    pub extension: String,
    pub tag: Option<&'static str>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct Offers {
    pub video: Vec<Offer>,
    pub audio: Vec<Offer>,
}

const MAX_VIDEO_OFFERS: usize = 8;

type FormatFilter<'a> = &'a dyn Fn(&RawFormat) -> bool;

fn codec_name(codec: &str) -> &'static str {
    let c = codec.to_ascii_lowercase();
    if c.starts_with("avc") || c.starts_with("h264") {
        "H.264"
    } else if c.starts_with("vp9") || c.starts_with("vp09") {
        "VP9"
    } else if c.starts_with("av01") || c.starts_with("av1") {
        "AV1"
    } else if c.starts_with("hev") || c.starts_with("hvc") || c.starts_with("h265") {
        "HEVC"
    } else if c.starts_with("vp8") {
        "VP8"
    } else if c.starts_with("mp4a") || c.starts_with("aac") {
        "AAC"
    } else if c.starts_with("opus") {
        "Opus"
    } else if c.starts_with("vorbis") {
        "Vorbis"
    } else if c.starts_with("mp3") {
        "MP3"
    } else if c.starts_with("flac") {
        "FLAC"
    } else {
        "Other codec"
    }
}

fn is_mp4_h264(f: &RawFormat) -> bool {
    f.ext.as_deref() == Some("mp4") && f.video_codec().is_some_and(|c| codec_name(c) == "H.264")
}

fn ext_label(ext: &str) -> String {
    match ext {
        "webm" => "WebM".into(),
        other => other.to_ascii_uppercase(),
    }
}

/// Best audio-only stream to pair with a video container.
fn best_audio<'a>(formats: &'a [RawFormat], for_ext: &str) -> Option<&'a RawFormat> {
    let audio = formats.iter().filter(|f| f.is_audio_only() && !f.drm());
    let score = |f: &&RawFormat| f.abr.or(f.tbr).unwrap_or(0.0);
    let compatible = |f: &&RawFormat| match for_ext {
        "mp4" => f.ext.as_deref() == Some("m4a"),
        "webm" => f.ext.as_deref() == Some("webm"),
        _ => true,
    };
    audio
        .clone()
        .filter(compatible)
        .max_by(|a, b| score(a).total_cmp(&score(b)))
        .or_else(|| audio.max_by(|a, b| score(a).total_cmp(&score(b))))
}

fn sum(a: Option<u64>, b: Option<u64>) -> Option<u64> {
    Some(a? + b?)
}

/// Builds the offers. Without FFmpeg only complete files (progressive
/// video, original audio tracks) are offered, because merging and
/// converting need it.
pub fn build_offers(info: &RawInfo, ffmpeg: bool) -> Offers {
    let formats: Vec<RawFormat> = info
        .formats()
        .into_iter()
        .filter(|f| !f.drm() && f.id().is_some())
        .collect();
    let mut offers = Offers::default();

    // ---- video: one entry per height, preferring broadly playable MP4/H.264.
    let mut heights: Vec<u32> = formats
        .iter()
        .filter(|f| f.has_video())
        .filter_map(|f| f.height)
        .collect();
    heights.sort_unstable_by(|a, b| b.cmp(a));
    heights.dedup();
    for height in heights {
        let candidates: Vec<&RawFormat> = formats
            .iter()
            .filter(|f| f.has_video() && f.height == Some(height))
            .filter(|f| ffmpeg || f.is_progressive())
            .collect();
        let Some(video) = candidates.iter().copied().max_by(|a, b| {
            (is_mp4_h264(a), a.is_progressive(), a.tbr.unwrap_or(0.0))
                .partial_cmp(&(is_mp4_h264(b), b.is_progressive(), b.tbr.unwrap_or(0.0)))
                .unwrap_or(std::cmp::Ordering::Equal)
        }) else {
            continue;
        };
        let ext = video.ext.clone().unwrap_or_else(|| "mp4".into());
        let vid = video.id().unwrap_or_default();
        let (spec, size, audio_codec) = if video.is_progressive() {
            (
                FormatSpec {
                    selector: vid.to_owned(),
                    merge: None,
                    extract_audio: None,
                    audio_kbps: None,
                },
                video.size(),
                video.audio_codec().map(codec_name),
            )
        } else {
            let Some(audio) = best_audio(&formats, &ext) else {
                continue;
            };
            let merge = if MERGE_FORMATS.contains(&ext.as_str()) {
                ext.clone()
            } else {
                "mkv".into()
            };
            (
                FormatSpec {
                    selector: format!("{vid}+{}", audio.id().unwrap_or_default()),
                    merge: Some(merge),
                    extract_audio: None,
                    audio_kbps: None,
                },
                sum(video.size(), audio.size()),
                audio.audio_codec().map(codec_name),
            )
        };
        let final_ext = spec.merge.clone().unwrap_or(ext);
        let mut detail = vec![ext_label(&final_ext)];
        if let Some(v) = video.video_codec() {
            detail.push(codec_name(v).into());
        }
        if let Some(fps) = video.fps.filter(|f| *f > 0.0) {
            detail.push(format!("{} fps", fps.round()));
        }
        if audio_codec.is_none() {
            detail.push("no audio".into());
        }
        let quality = if height >= 2160 {
            format!("{height}p · 4K")
        } else {
            format!("{height}p")
        };
        offers.video.push(Offer {
            spec,
            quality,
            detail: detail.join(" · "),
            size_bytes: size,
            extension: final_ext,
            tag: None,
        });
        if offers.video.len() == MAX_VIDEO_OFFERS {
            break;
        }
    }
    // Formats without a known height (generic sites): offer the complete file.
    if offers.video.is_empty()
        && let Some(f) = formats.iter().find(|f| f.is_progressive())
    {
        let ext = f.ext.clone().unwrap_or_else(|| "mp4".into());
        offers.video.push(Offer {
            spec: FormatSpec {
                selector: f.id().unwrap_or_default().to_owned(),
                merge: None,
                extract_audio: None,
                audio_kbps: None,
            },
            quality: format!("{} · best available", ext_label(&ext)),
            detail: "Complete file provided by the source".into(),
            size_bytes: f.size(),
            extension: ext,
            tag: None,
        });
    }
    if let Some(first) = offers.video.first_mut() {
        first.tag = Some("Best quality");
    }
    if let Some(rec) = offers
        .video
        .iter_mut()
        .filter(|o| o.extension == "mp4" && o.detail.contains("H.264"))
        .find(|o| {
            o.quality
                .split('p')
                .next()
                .and_then(|h| h.parse::<u32>().ok())
                .is_some_and(|h| h <= 1080)
        })
        && rec.tag.is_none()
    {
        rec.tag = Some("Recommended");
    }

    // ---- audio
    let audio_only: Vec<&RawFormat> = formats.iter().filter(|f| f.is_audio_only()).collect();
    let best = |pred: &dyn Fn(&RawFormat) -> bool| {
        audio_only
            .iter()
            .copied()
            .filter(|f| pred(f))
            .max_by(|a, b| {
                a.abr
                    .or(a.tbr)
                    .unwrap_or(0.0)
                    .total_cmp(&b.abr.or(b.tbr).unwrap_or(0.0))
            })
    };
    // Conversions need FFmpeg. Without a separate audio stream, the audio is
    // extracted from the smallest video that carries one.
    let conversion_source = if !audio_only.is_empty() {
        let kbps = best(&|_| true).and_then(|f| f.abr.or(f.tbr));
        Some(("ba".to_owned(), "Converted", kbps))
    } else {
        formats
            .iter()
            .filter(|f| f.has_video() && f.audio_codec().is_some())
            .min_by_key(|f| f.size().unwrap_or(u64::MAX))
            .and_then(|f| f.id().map(|id| (id, f.abr)))
            .map(|(id, abr)| (id.to_owned(), "Extracted from the video", abr))
    };
    if ffmpeg && let Some((selector, how, source_kbps)) = conversion_source {
        // Converting never adds quality: say what the source carries.
        let source = source_kbps
            .filter(|k| *k > 0.0)
            .map(|k| format!(" · source ≈ {} kbps", k.round()))
            .unwrap_or_default();
        for kbps in AUDIO_BITRATES {
            offers.audio.push(Offer {
                spec: FormatSpec {
                    selector: selector.clone(),
                    merge: None,
                    extract_audio: Some("mp3".into()),
                    audio_kbps: Some(kbps),
                },
                quality: format!("MP3 · {kbps} kbps"),
                detail: format!("{how} with FFmpeg{source}"),
                // Constant bitrate: duration × bitrate is a close estimate.
                size_bytes: info
                    .duration
                    .filter(|d| d.is_finite() && *d > 0.0)
                    .map(|d| (d * f64::from(kbps) * 1000.0 / 8.0) as u64),
                extension: "mp3".into(),
                tag: (kbps == AUDIO_BITRATES[0]).then_some("Recommended"),
            });
        }
        offers.audio.push(Offer {
            spec: FormatSpec {
                selector,
                merge: None,
                extract_audio: Some("flac".into()),
                audio_kbps: None,
            },
            quality: "FLAC · Lossless".into(),
            detail: format!("{how} with FFmpeg{source} · large file"),
            size_bytes: None,
            extension: "flac".into(),
            tag: None,
        });
    }
    let originals: [(&str, FormatFilter); 2] = [
        ("m4a", &|f: &RawFormat| f.ext.as_deref() == Some("m4a")),
        ("webm", &|f: &RawFormat| f.ext.as_deref() == Some("webm")),
    ];
    for (ext, pred) in originals {
        if let Some(f) = best(pred) {
            let codec = f.audio_codec().map(codec_name).unwrap_or("Audio");
            let kbps = f
                .abr
                .or(f.tbr)
                .map(|r| format!(" · {} kbps", r.round()))
                .unwrap_or_default();
            offers.audio.push(Offer {
                spec: FormatSpec {
                    selector: f.id().unwrap_or_default().to_owned(),
                    merge: None,
                    extract_audio: None,
                    audio_kbps: None,
                },
                quality: format!(
                    "{}{kbps}",
                    if ext == "m4a" {
                        "M4A".to_owned()
                    } else {
                        codec.to_owned()
                    }
                ),
                detail: format!("{codec} · original track"),
                size_bytes: f.size(),
                extension: ext.into(),
                tag: if !ffmpeg && offers.audio.is_empty() {
                    Some("Recommended")
                } else {
                    None
                },
            });
        }
    }
    offers
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fmt(
        id: &str,
        ext: &str,
        vcodec: &str,
        acodec: &str,
        height: Option<u32>,
        size: u64,
    ) -> RawFormat {
        RawFormat {
            format_id: Some(id.into()),
            ext: Some(ext.into()),
            vcodec: Some(vcodec.into()),
            acodec: Some(acodec.into()),
            height,
            filesize: Some(size),
            tbr: Some(size as f64 / 1000.0),
            // Audio streams: 20 → 130 kbps, 18 → 117 kbps.
            abr: (vcodec == "none").then_some(size as f64 * 6.5),
            ..Default::default()
        }
    }

    fn info(formats: Vec<RawFormat>) -> RawInfo {
        RawInfo {
            formats: Some(formats),
            ..Default::default()
        }
    }

    fn dash() -> RawInfo {
        info(vec![
            fmt("137", "mp4", "avc1.640028", "none", Some(1080), 300),
            fmt("248", "webm", "vp9", "none", Some(1080), 250),
            fmt("313", "webm", "vp9", "none", Some(2160), 1000),
            fmt("22", "mp4", "avc1.64001F", "mp4a.40.2", Some(720), 150),
            fmt("140", "m4a", "none", "mp4a.40.2", None, 20),
            fmt("251", "webm", "none", "opus", None, 18),
            RawFormat {
                has_drm: Some(serde_json::Value::Bool(true)),
                ..fmt("999", "mp4", "avc1", "mp4a", Some(1440), 500)
            },
        ])
    }

    #[test]
    fn video_offers_follow_the_source_and_skip_drm() {
        let offers = build_offers(&dash(), true);
        let qualities: Vec<_> = offers.video.iter().map(|o| o.quality.as_str()).collect();
        assert_eq!(
            qualities,
            ["2160p · 4K", "1080p", "720p"],
            "no 1440p: it is DRM-protected"
        );
        assert_eq!(offers.video[0].tag, Some("Best quality"));
        // 1080p prefers MP4/H.264 and merges with the M4A track.
        let hd = &offers.video[1];
        assert_eq!(hd.spec.selector, "137+140");
        assert_eq!(hd.spec.merge.as_deref(), Some("mp4"));
        assert_eq!(hd.size_bytes, Some(320));
        assert_eq!(hd.tag, Some("Recommended"));
        // 4K VP9 merges with Opus into WebM.
        assert_eq!(offers.video[0].spec.selector, "313+251");
        assert_eq!(offers.video[0].extension, "webm");
        // 720p is a complete file.
        assert_eq!(
            offers.video[2].spec,
            FormatSpec {
                selector: "22".into(),
                merge: None,
                extract_audio: None,
                audio_kbps: None
            }
        );
    }

    #[test]
    fn without_ffmpeg_only_complete_files_are_offered() {
        let offers = build_offers(&dash(), false);
        assert_eq!(offers.video.len(), 1);
        assert_eq!(offers.video[0].spec.selector, "22");
        assert!(offers.audio.iter().all(|o| o.spec.extract_audio.is_none()));
        assert_eq!(offers.audio[0].tag, Some("Recommended"));
    }

    #[test]
    fn audio_offers_include_conversion_and_originals() {
        let offers = build_offers(
            &RawInfo {
                duration: Some(100.0),
                ..dash()
            },
            true,
        );
        let labels: Vec<_> = offers
            .audio
            .iter()
            .map(|o| (o.quality.as_str(), o.spec.selector.as_str()))
            .collect();
        assert_eq!(
            labels,
            [
                ("MP3 · 320 kbps", "ba"),
                ("MP3 · 256 kbps", "ba"),
                ("MP3 · 192 kbps", "ba"),
                ("MP3 · 128 kbps", "ba"),
                ("FLAC · Lossless", "ba"),
                ("M4A · 130 kbps", "140"),
                ("Opus · 117 kbps", "251"),
            ]
        );
        let best = &offers.audio[0];
        assert_eq!(best.tag, Some("Recommended"));
        assert_eq!(best.spec.audio_kbps, Some(320));
        // 100 s at 320 kbps.
        assert_eq!(best.size_bytes, Some(4_000_000));
        assert_eq!(best.detail, "Converted with FFmpeg · source ≈ 130 kbps");
        assert_eq!(offers.audio[4].spec.audio_kbps, None);
        assert_eq!(offers.audio[4].size_bytes, None);
    }

    #[test]
    fn mp3_is_extracted_from_video_when_no_audio_stream_exists() {
        let progressive_only = info(vec![
            fmt("4", "webm", "vp8", "vorbis", Some(2160), 3000),
            fmt("0", "webm", "vp9", "opus", Some(240), 30),
        ]);
        let offers = build_offers(&progressive_only, true);
        assert_eq!(offers.audio.len(), AUDIO_BITRATES.len() + 1);
        assert!(
            offers.audio.iter().all(|o| o.spec.selector == "0"),
            "smallest video with audio"
        );
        assert_eq!(offers.audio[0].spec.extract_audio.as_deref(), Some("mp3"));
        assert_eq!(offers.audio[0].size_bytes, None, "unknown duration");
        assert!(build_offers(&progressive_only, false).audio.is_empty());
    }

    #[test]
    fn single_format_results_are_supported() {
        let raw = RawInfo {
            format_id: Some("0".into()),
            ext: Some("mp4".into()),
            ..Default::default()
        };
        let offers = build_offers(&raw, false);
        assert_eq!(offers.video.len(), 1);
        assert_eq!(offers.video[0].quality, "MP4 · best available");
    }

    #[test]
    fn specs_round_trip_and_reject_injection() {
        let spec = FormatSpec {
            selector: "137+140".into(),
            merge: Some("mp4".into()),
            extract_audio: None,
            audio_kbps: None,
        };
        assert_eq!(FormatSpec::decode(&spec.encode()).unwrap(), spec);
        let mp3 = r#"{"s":"ba","x":"mp3","b":320}"#;
        assert_eq!(FormatSpec::decode(mp3).unwrap().audio_kbps, Some(320));
        for bad in [
            r#"{"s":"ba","x":"mp3","b":321}"#,
            r#"{"s":"ba","x":"flac","b":320}"#,
            r#"{"s":"ba","b":320}"#,
            r#"{"s":"--exec calc"}"#,
            r#"{"s":"137 --exec calc"}"#,
            r#"{"s":"137;rm"}"#,
            r#"{"s":""}"#,
            r#"{"s":"137","m":"exe"}"#,
            r#"{"s":"ba","x":"sh"}"#,
            "not json",
        ] {
            assert!(FormatSpec::decode(bad).is_err(), "{bad}");
        }
    }
}

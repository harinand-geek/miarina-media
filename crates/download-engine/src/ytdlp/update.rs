//! Verified yt-dlp updates (Windows). Sites change often and an outdated
//! extractor stops working, so yt-dlp alone is updated between app
//! releases; FFmpeg and QuickJS-NG only change with the app.
//!
//! A release is accepted only if its `SHA2-256SUMS` carries a valid OpenPGP
//! signature by the yt-dlp signing key pinned below (fingerprint checked),
//! and `yt-dlp.exe` matches the signed digest. The new executable must then
//! report the expected version before it replaces the active one. The
//! bundled pinned version always remains as a fallback.

use std::path::{Path, PathBuf};
use std::time::Duration;

use pgp::composed::{Deserializable, DetachedSignature, SignedPublicKey};
use pgp::types::KeyDetails;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tokio::io::AsyncWriteExt;
use tokio_util::sync::CancellationToken;

use crate::EngineError;
use crate::components::{Components, YTDLP, hex};

/// yt-dlp's release signing key (`public.key` in the yt-dlp repository).
const SIGNING_KEY: &str = include_str!("../../keys/yt-dlp-signing-key.asc");
/// "Simon Sawicki (yt-dlp signing key)", RSA 4096, created 2023-02-26.
pub const SIGNING_KEY_FINGERPRINT: &str = "ac0cbbe6848d6a873464af4e57cf65933b5a7581";

const LATEST_RELEASE_API: &str = "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest";
const RELEASE_DOWNLOAD: &str = "https://github.com/yt-dlp/yt-dlp/releases/download";
const EXECUTABLE: &str = "yt-dlp.exe";

/// Bounds on downloaded documents (the real ones are a few KB / ~18 MB).
const MAX_JSON_BYTES: usize = 1024 * 1024;
const MAX_SUMS_BYTES: usize = 64 * 1024;
const MAX_SIG_BYTES: usize = 16 * 1024;
const MAX_EXECUTABLE_BYTES: u64 = 128 * 1024 * 1024;
/// A PyInstaller executable can be slow to start the first time.
const VERSION_CHECK_TIMEOUT: Duration = Duration::from_secs(60);

/// File recording which updated yt-dlp is active.
const ACTIVE_FILE: &str = "active.json";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActiveYtDlp {
    pub version: String,
    pub sha256: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum UpdateOutcome {
    UpToDate { version: String },
    Updated { version: String },
}

/// `2026.08.19`, `2026.08.19.1` → comparable numbers; `None` if malformed
/// (the tag comes from the network and is used in URLs and paths).
pub fn parse_version(tag: &str) -> Option<Vec<u32>> {
    let parts: Vec<u32> = tag
        .split('.')
        .map(|p| {
            (!p.is_empty() && p.len() <= 8 && p.bytes().all(|b| b.is_ascii_digit()))
                .then(|| p.parse().ok())
                .flatten()
        })
        .collect::<Option<_>>()?;
    (parts.len() >= 3 && parts.len() <= 4 && parts[0] >= 2023).then_some(parts)
}

/// Checks the OpenPGP signature of a `SHA2-256SUMS` file against the
/// pinned yt-dlp key.
pub fn verify_sums(sums: &[u8], signature: &[u8]) -> Result<(), EngineError> {
    let invalid = |why: &str| EngineError::Unsupported {
        reason: format!("the yt-dlp update was rejected: {why}"),
    };
    let (key, _) = SignedPublicKey::from_armor_single(SIGNING_KEY.as_bytes())
        .map_err(|_| invalid("signing key unreadable"))?;
    if hex(key.fingerprint().as_bytes()) != SIGNING_KEY_FINGERPRINT {
        return Err(invalid("unexpected signing key"));
    }
    let signature =
        DetachedSignature::from_bytes(signature).map_err(|_| invalid("signature unreadable"))?;
    signature
        .verify(&key.primary_key, sums)
        .map_err(|_| invalid("bad signature"))
}

/// The digest listed for `file` in a (verified) `SHA2-256SUMS`.
pub fn digest_for(sums: &str, file: &str) -> Option<String> {
    sums.lines().find_map(|line| {
        let (digest, name) = line.split_once(char::is_whitespace)?;
        let name = name.trim_start().trim_start_matches('*');
        (name == file && digest.len() == 64 && digest.bytes().all(|b| b.is_ascii_hexdigit()))
            .then(|| digest.to_ascii_lowercase())
    })
}

impl Components {
    fn ytdlp_dir(&self) -> PathBuf {
        self.root().join("yt-dlp")
    }

    /// The updated yt-dlp recorded as active, if its file is still there.
    pub fn active_ytdlp(&self) -> Option<(ActiveYtDlp, PathBuf)> {
        let raw = std::fs::read(self.ytdlp_dir().join(ACTIVE_FILE)).ok()?;
        let active: ActiveYtDlp = serde_json::from_slice(&raw).ok()?;
        parse_version(&active.version)?;
        if active.sha256.len() != 64 || !active.sha256.bytes().all(|b| b.is_ascii_hexdigit()) {
            return None;
        }
        let path = self.ytdlp_dir().join(&active.sha256[..16]).join(EXECUTABLE);
        path.is_file().then_some((active, path))
    }

    /// Version of the yt-dlp that runs: the update if newer, else the pinned one.
    pub fn ytdlp_version(&self) -> String {
        self.updated_ytdlp()
            .map_or_else(|| YTDLP.version.to_owned(), |(a, _)| a.version)
    }

    /// The active update when it is newer than the pinned version.
    pub(crate) fn updated_ytdlp(&self) -> Option<(ActiveYtDlp, PathBuf)> {
        let (active, path) = self.active_ytdlp()?;
        let pinned = parse_version(YTDLP.version)?;
        (parse_version(&active.version)? > pinned).then_some((active, path))
    }

    /// Looks for a newer yt-dlp release and installs it when verified.
    pub async fn update_ytdlp(
        &self,
        cancel: &CancellationToken,
    ) -> Result<UpdateOutcome, EngineError> {
        let current = self.ytdlp_version();
        let latest = self.latest_tag().await?;
        let (Some(latest_v), Some(current_v)) = (parse_version(&latest), parse_version(&current))
        else {
            return Err(EngineError::Unsupported {
                reason: "the yt-dlp release name is not a version".into(),
            });
        };
        if latest_v <= current_v {
            return Ok(UpdateOutcome::UpToDate { version: current });
        }

        self.install_release(&latest, cancel).await?;
        Ok(UpdateOutcome::Updated { version: latest })
    }

    /// Downloads, verifies, checks and activates release `tag`.
    pub async fn install_release(
        &self,
        tag: &str,
        cancel: &CancellationToken,
    ) -> Result<(), EngineError> {
        if parse_version(tag).is_none() {
            return Err(rejected("not a release version"));
        }
        let base = format!("{RELEASE_DOWNLOAD}/{tag}");
        let sums = self
            .fetch_small(&format!("{base}/SHA2-256SUMS"), MAX_SUMS_BYTES)
            .await?;
        let signature = self
            .fetch_small(&format!("{base}/SHA2-256SUMS.sig"), MAX_SIG_BYTES)
            .await?;
        verify_sums(&sums, &signature)?;
        let digest = digest_for(&String::from_utf8_lossy(&sums), EXECUTABLE)
            .ok_or_else(|| rejected("the release has no Windows executable"))?;

        let dir = self.ytdlp_dir().join(&digest[..16]);
        let target = dir.join(EXECUTABLE);
        if !target.is_file() {
            self.fetch_executable(&format!("{base}/{EXECUTABLE}"), &digest, &dir, cancel)
                .await?;
        }
        check_version(&target, tag).await?;

        let active = ActiveYtDlp {
            version: tag.to_owned(),
            sha256: digest,
        };
        write_atomically(
            &self.ytdlp_dir().join(ACTIVE_FILE),
            &serde_json::to_vec(&active).unwrap_or_default(),
        )
    }

    async fn latest_tag(&self) -> Result<String, EngineError> {
        #[derive(Deserialize)]
        struct Release {
            tag_name: String,
        }
        let body = self.fetch_small(LATEST_RELEASE_API, MAX_JSON_BYTES).await?;
        let release: Release =
            serde_json::from_slice(&body).map_err(|_| EngineError::Unsupported {
                reason: "unexpected answer from GitHub".into(),
            })?;
        Ok(release.tag_name)
    }

    async fn fetch_small(&self, url: &str, max: usize) -> Result<Vec<u8>, EngineError> {
        let mut response = self
            .client()
            .get(url)
            .header("Accept", "application/vnd.github+json")
            .send()
            .await
            .map_err(EngineError::from_reqwest)?;
        if !response.status().is_success() {
            return Err(EngineError::Http {
                status: response.status().as_u16(),
            });
        }
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(EngineError::from_reqwest)? {
            if body.len() + chunk.len() > max {
                return Err(EngineError::Unsupported {
                    reason: "the yt-dlp release file is too large".into(),
                });
            }
            body.extend_from_slice(&chunk);
        }
        Ok(body)
    }

    /// Streams the executable to disk, checking size and the signed digest,
    /// then publishes its folder atomically.
    async fn fetch_executable(
        &self,
        url: &str,
        digest: &str,
        dir: &Path,
        cancel: &CancellationToken,
    ) -> Result<(), EngineError> {
        let staging = self.ytdlp_dir().join(format!(".{}.part", &digest[..16]));
        let _ = tokio::fs::remove_dir_all(&staging).await;
        tokio::fs::create_dir_all(&staging)
            .await
            .map_err(EngineError::from_io)?;
        let result = async {
            let mut response = self
                .client()
                .get(url)
                .send()
                .await
                .map_err(EngineError::from_reqwest)?;
            if !response.status().is_success() {
                return Err(EngineError::Http {
                    status: response.status().as_u16(),
                });
            }
            let mut file = tokio::fs::File::create(staging.join(EXECUTABLE))
                .await
                .map_err(EngineError::from_io)?;
            let mut hasher = Sha256::new();
            let mut size = 0u64;
            loop {
                let chunk = tokio::select! {
                    _ = cancel.cancelled() => return Err(EngineError::Canceled),
                    c = response.chunk() => c.map_err(EngineError::from_reqwest)?,
                };
                let Some(chunk) = chunk else { break };
                size += chunk.len() as u64;
                if size > MAX_EXECUTABLE_BYTES {
                    return Err(rejected("the executable is too large"));
                }
                hasher.update(&chunk);
                file.write_all(&chunk).await.map_err(EngineError::from_io)?;
            }
            file.flush().await.map_err(EngineError::from_io)?;
            file.sync_all().await.map_err(EngineError::from_io)?;
            if hex(&hasher.finalize()) != digest {
                return Err(rejected("the executable does not match the signed digest"));
            }
            Ok(())
        }
        .await;
        if let Err(err) = result {
            let _ = tokio::fs::remove_dir_all(&staging).await;
            return Err(err);
        }
        let _ = tokio::fs::remove_dir_all(dir).await;
        tokio::fs::rename(&staging, dir)
            .await
            .map_err(EngineError::from_io)
    }
}

fn rejected(why: &str) -> EngineError {
    EngineError::Unsupported {
        reason: format!("the yt-dlp update was rejected: {why}"),
    }
}

/// The new executable must start and report the release it came from.
async fn check_version(exe: &Path, expected: &str) -> Result<(), EngineError> {
    let mut command = tokio::process::Command::new(exe);
    command
        .args(["--ignore-config", "--version"])
        .stdin(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .kill_on_drop(true);
    crate::process::configure(&mut command, true);
    let output = tokio::time::timeout(VERSION_CHECK_TIMEOUT, command.output())
        .await
        .map_err(|_| rejected("the new version did not start"))?
        .map_err(EngineError::from_io)?;
    let reported = String::from_utf8_lossy(&output.stdout);
    if output.status.success() && reported.trim() == expected {
        Ok(())
    } else {
        Err(rejected("the new version did not start correctly"))
    }
}

fn write_atomically(path: &Path, data: &[u8]) -> Result<(), EngineError> {
    let staging = path.with_extension("json.part");
    std::fs::write(&staging, data).map_err(EngineError::from_io)?;
    std::fs::rename(&staging, path).map_err(EngineError::from_io)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SUMS: &[u8] = include_bytes!("../../tests/fixtures/yt-dlp-2026.08.19/SHA2-256SUMS");
    const SIG: &[u8] = include_bytes!("../../tests/fixtures/yt-dlp-2026.08.19/SHA2-256SUMS.sig");

    #[test]
    fn the_real_release_signature_verifies() {
        verify_sums(SUMS, SIG).expect("yt-dlp 2026.08.19 is signed by the pinned key");
        // The signed digest is the one pinned for the bundled executable.
        assert_eq!(
            digest_for(&String::from_utf8_lossy(SUMS), "yt-dlp.exe").as_deref(),
            Some("66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a")
        );
    }

    #[test]
    fn tampered_sums_or_signatures_are_rejected() {
        let mut tampered = SUMS.to_vec();
        let at = tampered.iter().position(|b| *b == b'6').unwrap();
        tampered[at] = b'7';
        assert!(verify_sums(&tampered, SIG).is_err());
        assert!(verify_sums(SUMS, &SIG[..SIG.len() - 1]).is_err());
        assert!(verify_sums(SUMS, b"").is_err());
    }

    #[test]
    fn digests_are_matched_by_exact_name() {
        let sums = "aa  yt-dlp.exe\n\
                    1111111111111111111111111111111111111111111111111111111111111111  yt-dlp_x86.exe\n\
                    2222222222222222222222222222222222222222222222222222222222222222 *yt-dlp.exe\n";
        assert_eq!(
            digest_for(sums, "yt-dlp.exe").as_deref(),
            Some("2222222222222222222222222222222222222222222222222222222222222222")
        );
        assert_eq!(digest_for(sums, "yt-dlp"), None);
    }

    #[test]
    fn versions_are_validated_and_ordered() {
        assert!(parse_version("2026.09.02") > parse_version("2026.08.19"));
        assert!(parse_version("2026.08.19.1") > parse_version("2026.08.19"));
        for bad in [
            "",
            "latest",
            "2026.08",
            "2026.08.19/../x",
            "-1.2.3",
            "2026.08.19.1.2",
            "1999.01.01",
        ] {
            assert_eq!(parse_version(bad), None, "{bad}");
        }
    }

    #[test]
    fn an_older_or_broken_record_does_not_replace_the_pinned_version() {
        let dir = tempfile::tempdir().unwrap();
        let components = Components::new(dir.path().to_path_buf()).unwrap();
        let ytdlp = dir.path().join("yt-dlp");
        std::fs::create_dir_all(ytdlp.join("aaaaaaaaaaaaaaaa")).unwrap();
        std::fs::write(ytdlp.join("aaaaaaaaaaaaaaaa").join("yt-dlp.exe"), b"exe").unwrap();
        let record = |version: &str| {
            let active = ActiveYtDlp {
                version: version.into(),
                sha256: "a".repeat(64),
            };
            std::fs::write(
                ytdlp.join(ACTIVE_FILE),
                serde_json::to_vec(&active).unwrap(),
            )
            .unwrap();
        };
        record("2025.01.01");
        assert_eq!(
            components.ytdlp_version(),
            YTDLP.version,
            "older than pinned"
        );
        record("2099.01.01");
        assert_eq!(components.ytdlp_version(), "2099.01.01");
        assert!(
            components
                .ytdlp()
                .unwrap()
                .ends_with("aaaaaaaaaaaaaaaa/yt-dlp.exe")
        );
        std::fs::write(ytdlp.join(ACTIVE_FILE), b"{not json").unwrap();
        assert_eq!(
            components.ytdlp_version(),
            YTDLP.version,
            "broken record ignored"
        );
    }
}

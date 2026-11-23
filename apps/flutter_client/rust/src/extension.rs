//! Native messaging registration of the browser extension, behind
//! `api::extension` (Windows only; elsewhere: not available).

use std::path::{Path, PathBuf};

use crate::api::extension::ExtensionStatus;

/// Native messaging host name (the extension's `HOST`).
pub const HOST: &str = "org.miarina.media.bridge";
/// The extension's fixed ID (from the public `key` of its manifest).
pub const EXTENSION_ID: &str = "dlfhnodjkhddcjeeoaeminkboapodnoa";
const BRIDGE_EXE: &str = "miarina-browser-bridge.exe";

/// Registry keys under HKCU, per browser.
const KEYS: [(&str, &str); 2] = [
    (
        "chrome",
        r"Software\Google\Chrome\NativeMessagingHosts\org.miarina.media.bridge",
    ),
    (
        "edge",
        r"Software\Microsoft\Edge\NativeMessagingHosts\org.miarina.media.bridge",
    ),
];

fn manifest_path(data_dir: &str) -> PathBuf {
    Path::new(data_dir)
        .join("browser-bridge")
        .join(format!("{HOST}.json"))
}

fn app_dir() -> Option<PathBuf> {
    std::env::current_exe()
        .ok()?
        .parent()
        .map(Path::to_path_buf)
}

fn bridge_path() -> Option<PathBuf> {
    app_dir()
        .map(|d| d.join(BRIDGE_EXE))
        .filter(|p| p.is_file())
}

fn folder() -> Option<String> {
    app_dir()
        .map(|d| d.join("browser-extension"))
        .filter(|p| p.join("manifest.json").is_file())
        .map(|p| p.to_string_lossy().into_owned())
}

/// The manifest Chrome and Edge read: this bridge, this extension only.
fn manifest_json(bridge: &Path) -> String {
    serde_json::to_string_pretty(&serde_json::json!({
        "name": HOST,
        "description": "Miarina Media browser connection",
        "path": bridge,
        "type": "stdio",
        "allowed_origins": [format!("chrome-extension://{EXTENSION_ID}/")],
    }))
    .unwrap_or_default()
}

/// Writes the manifest atomically.
#[cfg_attr(not(windows), allow(dead_code))]
fn write_manifest(manifest: &Path, bridge: &Path) -> std::io::Result<()> {
    if let Some(dir) = manifest.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let tmp = manifest.with_extension("json.tmp");
    std::fs::write(&tmp, manifest_json(bridge))?;
    std::fs::rename(&tmp, manifest)
}

/// Whether the manifest on disk is ours and points at this bridge.
fn manifest_current(manifest: &Path, bridge: &Path) -> bool {
    std::fs::read_to_string(manifest).is_ok_and(|text| text == manifest_json(bridge))
}

#[cfg(windows)]
mod registry {
    use windows::Win32::Foundation::ERROR_SUCCESS;
    use windows::Win32::System::Registry::{
        HKEY, HKEY_CURRENT_USER, KEY_WRITE, REG_OPTION_NON_VOLATILE, REG_SZ, RRF_RT_REG_SZ,
        RegCloseKey, RegCreateKeyExW, RegDeleteTreeW, RegGetValueW, RegSetValueExW,
    };
    use windows::core::{HSTRING, PCWSTR};

    /// The default value of `HKCU\key`, when it is a string.
    pub fn read(key: &str) -> Option<String> {
        let key = HSTRING::from(key);
        let mut buf = vec![0u16; 2048];
        let mut size = (buf.len() * 2) as u32;
        let status = unsafe {
            RegGetValueW(
                HKEY_CURRENT_USER,
                &key,
                PCWSTR::null(),
                RRF_RT_REG_SZ,
                None,
                Some(buf.as_mut_ptr().cast()),
                Some(&mut size),
            )
        };
        if status != ERROR_SUCCESS {
            return None;
        }
        let len = (size as usize / 2).saturating_sub(1);
        Some(String::from_utf16_lossy(&buf[..len.min(buf.len())]))
    }

    pub fn write(key: &str, value: &str) -> anyhow::Result<()> {
        let mut handle = HKEY::default();
        let status = unsafe {
            RegCreateKeyExW(
                HKEY_CURRENT_USER,
                &HSTRING::from(key),
                None,
                PCWSTR::null(),
                REG_OPTION_NON_VOLATILE,
                KEY_WRITE,
                None,
                &mut handle,
                None,
            )
        };
        status.ok()?;
        let data: Vec<u16> = value.encode_utf16().chain(std::iter::once(0)).collect();
        let bytes =
            unsafe { std::slice::from_raw_parts(data.as_ptr().cast::<u8>(), data.len() * 2) };
        let status = unsafe { RegSetValueExW(handle, PCWSTR::null(), None, REG_SZ, Some(bytes)) };
        let _ = unsafe { RegCloseKey(handle) };
        status.ok()?;
        Ok(())
    }

    pub fn delete(key: &str) {
        let _ = unsafe { RegDeleteTreeW(HKEY_CURRENT_USER, &HSTRING::from(key)) };
    }
}

#[cfg(windows)]
pub fn status(data_dir: &str) -> ExtensionStatus {
    let manifest = manifest_path(data_dir);
    let ours = manifest.to_string_lossy().into_owned();
    let bridge = bridge_path();
    let registered = KEYS
        .iter()
        .any(|(_, key)| registry::read(key).is_some_and(|v| v.eq_ignore_ascii_case(&ours)));
    // Connected, then the app moved or was reinstalled: the manifest follows
    // the bridge.
    if let Some(b) = bridge.as_deref()
        && registered
        && !manifest_current(&manifest, b)
    {
        let _ = write_manifest(&manifest, b);
    }
    let current = bridge
        .as_deref()
        .is_some_and(|b| manifest_current(&manifest, b));
    let mut on = [false; 2];
    let mut other = false;
    for (i, (_, key)) in KEYS.iter().enumerate() {
        match registry::read(key) {
            Some(value) if value.eq_ignore_ascii_case(&ours) => on[i] = current,
            Some(_) => other = true,
            None => {}
        }
    }
    ExtensionStatus {
        bridge: bridge.is_some(),
        chrome: on[0],
        edge: on[1],
        other,
        folder: folder(),
    }
}

#[cfg(windows)]
pub fn set_enabled(data_dir: &str, enabled: bool) -> anyhow::Result<()> {
    let manifest = manifest_path(data_dir);
    let ours = manifest.to_string_lossy().into_owned();
    if !enabled {
        // Only this copy's registrations: another install's stay.
        for (_, key) in KEYS {
            if registry::read(key).is_some_and(|v| v.eq_ignore_ascii_case(&ours)) {
                registry::delete(key);
            }
        }
        let _ = std::fs::remove_file(&manifest);
        return Ok(());
    }
    let bridge = bridge_path().ok_or_else(|| anyhow::anyhow!("bridge_missing"))?;
    write_manifest(&manifest, &bridge)?;
    for (_, key) in KEYS {
        registry::write(key, &ours)?;
    }
    Ok(())
}

/// The bridge answers a ping as it would for the browser (5 s at most).
#[cfg(windows)]
pub fn test(data_dir: &str) -> bool {
    use std::io::{Read, Write};
    use std::os::windows::process::CommandExt;
    use std::process::{Command, Stdio};
    let s = status(data_dir);
    let Some(bridge) = bridge_path() else {
        return false;
    };
    if !(s.chrome || s.edge) {
        return false;
    }
    let Ok(mut child) = Command::new(bridge)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .creation_flags(0x0800_0000) // CREATE_NO_WINDOW
        .spawn()
    else {
        return false;
    };
    let body = br#"{"ping":true}"#;
    if let Some(mut input) = child.stdin.take() {
        let _ = input.write_all(&(body.len() as u32).to_ne_bytes());
        let _ = input.write_all(body);
    }
    let (tx, rx) = std::sync::mpsc::channel();
    let mut output = child.stdout.take();
    std::thread::spawn(move || {
        let mut bytes = Vec::new();
        if let Some(out) = output.as_mut() {
            let _ = out.take(1024).read_to_end(&mut bytes);
        }
        let _ = tx.send(bytes);
    });
    let reply = rx.recv_timeout(std::time::Duration::from_secs(5));
    let _ = child.kill();
    let _ = child.wait();
    let Ok(bytes) = reply else { return false };
    bytes.len() > 4
        && serde_json::from_slice::<serde_json::Value>(&bytes[4..])
            .is_ok_and(|v| v["ok"] == serde_json::Value::Bool(true))
}

#[cfg(not(windows))]
pub fn status(_: &str) -> ExtensionStatus {
    ExtensionStatus {
        bridge: false,
        chrome: false,
        edge: false,
        other: false,
        folder: None,
    }
}

#[cfg(not(windows))]
pub fn set_enabled(_: &str, _: bool) -> anyhow::Result<()> {
    anyhow::bail!("bridge_missing")
}

#[cfg(not(windows))]
pub fn test(_: &str) -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_manifest_allows_only_this_extension_and_bridge() {
        let json: serde_json::Value = serde_json::from_str(&manifest_json(Path::new(
            r"C:\App\miarina-browser-bridge.exe",
        )))
        .unwrap();
        assert_eq!(json["name"], HOST);
        assert_eq!(json["type"], "stdio");
        assert_eq!(json["path"], r"C:\App\miarina-browser-bridge.exe");
        assert_eq!(
            json["allowed_origins"],
            serde_json::json!([format!("chrome-extension://{EXTENSION_ID}/")])
        );
        assert_eq!(EXTENSION_ID.len(), 32);
        assert!(EXTENSION_ID.bytes().all(|b| (b'a'..=b'p').contains(&b)));
    }

    #[test]
    fn a_manifest_for_another_bridge_is_not_current() {
        let manifest = std::env::temp_dir().join(format!(
            "miarina-extension-test-{}.json",
            std::process::id()
        ));
        std::fs::write(&manifest, manifest_json(Path::new(r"C:\Old\bridge.exe"))).unwrap();
        assert!(!manifest_current(
            &manifest,
            Path::new(r"C:\New\bridge.exe")
        ));
        assert!(manifest_current(&manifest, Path::new(r"C:\Old\bridge.exe")));
        let _ = std::fs::remove_file(&manifest);
    }

    /// A real HKCU round trip on a throwaway key this test creates and
    /// removes (never the browsers' keys).
    #[cfg(windows)]
    #[test]
    fn registry_values_round_trip() {
        let key = format!(
            r"Software\org.miarina.media.test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );
        assert_eq!(registry::read(&key), None);
        let value = r"C:\Users\Zoé\AppData\Roaming\org.miarina.media\browser-bridge\x.json";
        registry::write(&key, value).unwrap();
        assert_eq!(registry::read(&key).as_deref(), Some(value));
        registry::delete(&key);
        assert_eq!(registry::read(&key), None);
    }
}

//! Android shared storage. From Android 11 (API 30) an app may create files
//! in the shared `Movies/` and `Music/` folders through plain file paths,
//! without any permission, and rename or delete its own files there; the
//! system indexes them for the gallery and keeps them after uninstall.
//! Older versions would need the storage permission: files stay in the
//! app's own folder there.

// Pure path logic is compiled everywhere so it is unit-tested on desktop.
#![cfg_attr(not(target_os = "android"), allow(dead_code))]

use std::path::{Component, Path, PathBuf};

/// First Android version where apps write shared media without permission.
pub const SHARED_MEDIA_SDK: u32 = 30;

/// Download folders in shared storage.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SharedDirs {
    pub video: PathBuf,
    pub audio: PathBuf,
}

/// Root of the user's shared storage, derived from an app-specific folder:
/// `/storage/emulated/0/Android/data/<pkg>/files/Movies` → `/storage/emulated/0`
/// (keeps the right user id for work profiles and secondary users).
pub fn storage_root(app_dir: &Path) -> Option<PathBuf> {
    let parts: Vec<Component<'_>> = app_dir.components().collect();
    let at = parts
        .windows(2)
        .position(|w| w[0].as_os_str() == "Android" && w[1].as_os_str() == "data")?;
    (at > 1).then(|| parts[..at].iter().collect())
}

/// `Movies/Miarina` and `Music/Miarina` when the device allows it.
pub fn shared_dirs(app_dir: &Path, sdk: u32) -> Option<SharedDirs> {
    if sdk < SHARED_MEDIA_SDK {
        return None;
    }
    let root = storage_root(app_dir)?;
    Some(SharedDirs {
        video: root.join("Movies").join("Miarina"),
        audio: root.join("Music").join("Miarina"),
    })
}

/// Android API level (`ro.build.version.sdk`), 0 when unknown.
#[cfg(target_os = "android")]
pub fn sdk_level() -> u32 {
    use std::ffi::{c_char, c_int};
    unsafe extern "C" {
        // Bionic, available on every Android version.
        fn __system_property_get(name: *const c_char, value: *mut c_char) -> c_int;
    }
    // PROP_VALUE_MAX is 92 bytes, terminator included.
    let mut value = [0 as c_char; 92];
    // SAFETY: the name is NUL-terminated and the buffer has PROP_VALUE_MAX bytes.
    let len =
        unsafe { __system_property_get(c"ro.build.version.sdk".as_ptr(), value.as_mut_ptr()) };
    let len = usize::try_from(len).unwrap_or(0).min(value.len());
    let bytes: Vec<u8> = value[..len].iter().map(|&c| c as u8).collect();
    std::str::from_utf8(&bytes)
        .ok()
        .and_then(|s| s.trim().parse().ok())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_shared_root_comes_from_the_app_folder() {
        let app = Path::new("/storage/emulated/10/Android/data/org.miarina.media/files/Movies");
        assert_eq!(
            storage_root(app),
            Some(PathBuf::from("/storage/emulated/10"))
        );
        assert_eq!(
            storage_root(Path::new("/data/user/0/org.miarina.media")),
            None
        );
        assert_eq!(storage_root(Path::new("/Android/data/x")), None);
    }

    #[test]
    fn shared_folders_need_android_11() {
        let app = Path::new("/storage/emulated/0/Android/data/org.miarina.media/files/Movies");
        assert_eq!(shared_dirs(app, 29), None);
        assert_eq!(
            shared_dirs(app, 35),
            Some(SharedDirs {
                video: PathBuf::from("/storage/emulated/0/Movies/Miarina"),
                audio: PathBuf::from("/storage/emulated/0/Music/Miarina"),
            })
        );
    }
}

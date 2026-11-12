//! UPD-10: the app database is copied before its schema changes and never
//! opened by a build older than its schema. When it cannot be opened, the
//! user is told why (Windows message box) instead of the window silently
//! never appearing.
//!
//! On Windows the database is opened before the Tauri app is built: a
//! message box shown from inside `setup` runs a modal loop that makes Tauri
//! handle window events before its state exists (seen in the L09 recette:
//! the app aborted instead of showing the message).
use std::path::{Path, PathBuf};

use storage::{Storage, StorageError, Upgrade};

/// Database opened before the app is built, with the folder it lives in.
pub struct Opened {
    pub dir: PathBuf,
    pub storage: Storage,
    pub upgrade: Upgrade,
}

/// Windows: opens `%APPDATA%\<identifier>\miarina.db` before any window
/// exists; a refused database is reported and the process ends. `None`
/// when the folder cannot be determined (setup opens it instead).
#[cfg(windows)]
pub fn open_early(identifier: &str, version: &str) -> Option<Opened> {
    let dir = PathBuf::from(std::env::var_os("APPDATA")?).join(identifier);
    std::fs::create_dir_all(&dir).ok()?;
    match open_in(&dir) {
        Ok((storage, upgrade)) => Some(Opened {
            dir,
            storage,
            upgrade,
        }),
        Err(e) => {
            show(&message(&e, &dir.join(DB_NAME), version, french_ui()));
            std::process::exit(1);
        }
    }
}

const DB_NAME: &str = "miarina.db";

fn open_in(data_dir: &Path) -> Result<(Storage, Upgrade), StorageError> {
    Storage::open_upgrading(&data_dir.join(DB_NAME), &data_dir.join("backups"))
}

/// Opens `miarina.db` in `data_dir` from `setup` (Android, or Windows when
/// the early open did not apply); copies go to `data_dir/backups`.
pub fn open(data_dir: &Path, version: &str) -> Result<(Storage, Upgrade), StorageError> {
    let result = open_in(data_dir);
    #[cfg(windows)]
    if let Err(e) = &result {
        let text = message(e, &data_dir.join(DB_NAME), version, french_ui());
        // On its own thread: the main thread must not run a modal loop
        // inside `setup` (see the module comment).
        let _ = std::thread::spawn(move || show(&text)).join();
        std::process::exit(1);
    }
    #[cfg(not(windows))]
    let _ = version;
    result
}

/// Text shown when the database cannot be opened (Windows message box).
#[cfg_attr(not(windows), allow(dead_code))]
pub fn message(e: &StorageError, db: &Path, version: &str, french: bool) -> String {
    let db = db.display();
    match (e, french) {
        (StorageError::TooNew { found, supported }, true) => format!(
            "Cette bibliothèque a été mise à jour par une version plus récente de Miarina Media : \
             la version {version} ne peut pas l'ouvrir sans risque (schéma {found}, cette version \
             s'arrête au schéma {supported}).\n\nVos données n'ont pas été modifiées. Installez la \
             version la plus récente de Miarina Media."
        ),
        (StorageError::TooNew { found, supported }, false) => format!(
            "This library was updated by a newer version of Miarina Media: version {version} \
             cannot open it safely (schema {found}, this version supports up to schema \
             {supported}).\n\nYour data was not changed. Install the latest version of Miarina \
             Media."
        ),
        (StorageError::UpgradeFailed { backup, reason, .. }, true) => format!(
            "La mise à jour de votre bibliothèque a échoué. Elle a été annulée : vos données n'ont \
             pas été modifiées.\n\nCopie de sauvegarde : {}\nDétail : {reason}\n\nRéinstallez la \
             version précédente de Miarina Media pour continuer à utiliser cette bibliothèque.",
            backup
                .as_deref()
                .map_or_else(|| "aucune".into(), |p| p.display().to_string())
        ),
        (StorageError::UpgradeFailed { backup, reason, .. }, false) => format!(
            "Updating your library failed. The update was rolled back: your data was not \
             changed.\n\nBackup copy: {}\nDetails: {reason}\n\nReinstall the previous version of \
             Miarina Media to keep using this library.",
            backup
                .as_deref()
                .map_or_else(|| "none".into(), |p| p.display().to_string())
        ),
        (StorageError::Backup(reason), true) => format!(
            "Miarina Media n'a pas pu copier votre bibliothèque avant de la mettre à jour : la mise \
             à jour n'a pas été faite et vos données n'ont pas été modifiées.\n\nVérifiez l'espace \
             libre sur le disque puis relancez Miarina Media.\nDétail : {reason}"
        ),
        (StorageError::Backup(reason), false) => format!(
            "Miarina Media could not copy your library before updating it: the update was not \
             applied and your data was not changed.\n\nCheck the free disk space, then start \
             Miarina Media again.\nDetails: {reason}"
        ),
        (e, true) => format!(
            "La bibliothèque de Miarina Media n'a pas pu être ouverte.\n\nFichier : {db}\nDétail : {e}"
        ),
        (e, false) => {
            format!("The Miarina Media library could not be opened.\n\nFile: {db}\nDetails: {e}")
        }
    }
}

#[cfg(windows)]
fn french_ui() -> bool {
    // Primary language identifier of the Windows display language.
    const LANG_FRENCH: u16 = 0x0c;
    // SAFETY: no arguments, reads the user's UI language.
    unsafe { windows::Win32::Globalization::GetUserDefaultUILanguage() & 0x3ff == LANG_FRENCH }
}

#[cfg(windows)]
fn show(text: &str) {
    use windows::Win32::UI::WindowsAndMessaging::{MB_ICONERROR, MB_OK, MessageBoxW};
    use windows::core::HSTRING;
    // SAFETY: both strings outlive the modal call; no owner window.
    unsafe {
        MessageBoxW(
            None,
            &HSTRING::from(text),
            &HSTRING::from("Miarina Media"),
            MB_OK | MB_ICONERROR,
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn messages_explain_what_happened_to_the_data() {
        let db = Path::new("C:/data/miarina.db");
        let too_new = StorageError::TooNew {
            found: 12,
            supported: 9,
        };
        let fr = message(&too_new, db, "0.1.8", true);
        assert!(fr.contains("0.1.8") && fr.contains("12") && fr.contains('9'));
        assert!(fr.contains("pas été modifiées"));
        assert!(message(&too_new, db, "0.1.8", false).contains("was not changed"));

        let failed = StorageError::UpgradeFailed {
            from: 8,
            to: 9,
            backup: Some(PathBuf::from("C:/data/backups/miarina-schema8-1.db")),
            reason: "table exists".into(),
        };
        let text = message(&failed, db, "0.1.8", true);
        assert!(text.contains("miarina-schema8-1.db") && text.contains("table exists"));
        assert!(message(&failed, db, "0.1.8", false).contains("rolled back"));

        let other = StorageError::Corrupted("tasks.state");
        assert!(message(&other, db, "0.1.8", false).contains("miarina.db"));
    }
}

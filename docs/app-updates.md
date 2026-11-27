# Application updates

Since 0.1.7, Windows and Android check for a newer release after startup and every six hours while the UI is visible. Settings provides a manual check, download progress, cancel/resume and a separate installation action. Installation never starts automatically. The behaviour below is the one implemented for the next release (lot L09, 2026-11-12); 0.1.7 has the first version of it (no channel, no resume, no backup before migration).

## Flutter app (0.2.x, Windows)

The same mechanism, ported with its tests (plan R3, 2026-11-21): `apps/flutter_client/rust/src/update_engine.rs` (rules, files and tests of `updates.rs`; same manifest addresses, same pinned key file `apps/client/src-tauri/resources/update-public-key.bin`, same cache folder `%LOCALAPPDATA%\org.miarina.media`, same settings keys `update_channel` / `update_auto_download`), `api/updates.rs` (bridge), `features/updates/` (Settings › Updates with the 0.1.x texts, check 15 s after launch and every six hours while the app is in front). Only release builds (`MM_VERSION` given) check; a development build says updates are off. Installing starts the verified installer, then the app closes through its exit path (torrent session stopped, downloads flushed). The test channel is the cargo feature `update-test-channel` of `miarina_bridge`, with the same build-time variables.

## Manifest and authenticity (UPD-02)

The manifest is an envelope with a UTF-8 `payload` JSON string and a hexadecimal Ed25519 signature over the exact payload bytes. Public keys are pinned in the application (`apps/client/src-tauri/resources/update-public-key.bin`; the code accepts a list of keys for rotation). The payload carries `channel` (`stable` or `beta`; absent means stable, as in 0.1.7 manifests) and one record per platform: numeric three-part version, release notes, URL, byte size and SHA-256.

The app refuses, before downloading anything:

- a manifest over 64 KiB (checked on `Content-Length` and while reading);
- a signature from any other key, an altered payload or a malformed signature;
- a manifest whose signed channel differs from the address it was fetched from (a beta manifest served as `stable.json`);
- a URL other than `https://media.miarina.org/downloads/MiarinaMedia-VERSION-x64-setup.exe` (or `.apk`) for that exact version, a size of 0 or over 512 MiB, a digest that is not 32 bytes, notes over 16 000 bytes;
- redirects (none followed) and plain HTTP.

The artifact is streamed to disk and refused when it is longer than announced (as soon as it overflows), shorter (truncated), or has another SHA-256. Installation hashes the file again, streamed, immediately before running it; a mismatch deletes it. These cases are covered by Rust unit tests in `updates.rs`.

## Channels (UPD-07)

Settings › Updates › Channel: Stable (default) or Beta. Stable reads `/updates/stable.json`. Beta reads `/updates/beta.json` **and** `stable.json` and offers the higher version, so a beta user never misses a stable release. A missing `beta.json` (404) simply means no beta. A beta becomes stable by publishing the same artifacts (same version, same bytes) in `stable.json`: a version number is never reused for different bytes.

## Download, cancel, resume (UPD-03, UPD-05)

- Files live in the app cache: `miarina-update.part` while downloading, `miarina-update.exe` (`.apk`) once verified, and `miarina-update.json`, which stores the signed manifest, the channel and the server validator. The manifest is verified again whenever this file is read.
- **Cancel** keeps the partial file. **Network loss** keeps it too. The next download resumes with `Range` + `If-Range` (strong `ETag`, else `Last-Modified`); if the server answers 200 (file changed or ranges unsupported) the download restarts from zero; a refused range (416) deletes the partial file. The partial bytes are re-hashed before resuming so the final digest covers the whole file.
- **After a restart**, a verified download is offered as ready without downloading again, and a partial one as "resume".
- **Cleanup**: at launch, files for a version that is not newer than the running one (the update was installed, or abandoned) are deleted, as are 0.1.7 leftovers. A download for another version replaces the previous files.
- **Automatic download** (Settings, off by default): only when Windows reports an unrestricted network cost (not roaming, not over or near a data limit) and battery saver is off. It never installs. Android: not implemented (UPD-06).

## Installation (UPD-04)

- Refused while a conversion is running (the button is disabled and the reason shown).
- Running downloads are stopped by the normal exit path and come back after the update (resumable ones paused, others queued); the card says so before the click, and also says when playback or torrent sharing will stop.
- Windows closes Miarina and starts the NSIS installer from the cache; Android requests permission to install packages if needed, validates the APK package name and signing certificate, then opens the system installer through a content URI. No uninstall is performed. Android installation always requires the user's system confirmation.

## Database across versions (UPD-10)

- Before migrating an existing database to a newer schema, the app copies it with `VACUUM INTO` to `%APPDATA%\org.miarina.media\backups\miarina-schemaN-TIME.db` (Android: the app data folder). Without a copy the migration does not run. The three newest copies are kept.
- Migrations run in a single transaction: if one fails, the database keeps its previous schema.
- A database whose schema is **newer** than the running build (an older version reinstalled over a newer one) is not opened and not modified.
- In these cases Windows shows a message (French or English, from the Windows display language) saying what happened, that the data was not changed and where the copy is, then exits. On Windows the database is opened before the Tauri app is built (`data_guard::open_early`), so the message appears without a window: a message box shown inside Tauri's `setup` made the app abort during the L09 recette. Android: the start fails (no dedicated screen yet; the Android splash/migration design is in `design/design_handoff_splash`).
- The Flutter app (0.2.x, Windows) uses the same folder and the same rules: `app_open_database` (`apps/flutter_client/rust/src/api/app.rs`) opens the database once at launch with `open_upgrading`, before anything else reads it, and `app/database_problem.dart` shows the same messages in a window instead of a message box.
- Manual recovery: close the app, rename `miarina.db` (and its `-wal`/`-shm` files), copy the chosen backup to `miarina.db`, then start the version that matches the copy's schema (the file name says it) or a newer one.

## Keys (UPD-07)

The private Ed25519 release key is local in ignored `builds/update-signing-private.pem`; never put it in Git, archives or on the public server. Keep a protected offline backup: losing it prevents updates accepted by installed clients. Rotation: add the new public key next to the current one in the app and release that version; once it is installed widely, sign with the new key; remove the old key from a later release. If the private key leaks, ship a release (signed with the old key) that pins only a new key. APK signing uses its own, separate certificate; Windows Authenticode signing (UPD-09) is separate and not done.

## Publication (UPD-08)

1. Build and verify Windows and Android artifacts with matching version metadata.
2. `node apps/flutter_client/tool/sign-app-update.mjs VERSION KEY WINDOWS_EXE ANDROID_APK OUTPUT NOTES_FILE [stable|beta]`.
3. Upload the versioned artifacts first; previous versions stay on the server. Then check the local signed manifest against what the server serves: `node apps/flutter_client/tool/verify-app-update.mjs OUTPUT [channel]` (downloads both artifacts and compares size and SHA-256).
4. Publish the manifest last at `/updates/CHANNEL.json` (atomic rename), served with revalidation/no-cache; the client adds a cache-busting query.
5. Run `verify-app-update.mjs https://media.miarina.org/updates/CHANNEL.json CHANNEL` against the public URL.

## Test channel (UPD-01, T-06)

Never test by inventing a version on the public channel. The cargo feature `update-test-channel` builds a client that reads a **loopback** server (`MIARINA_UPDATE_TEST_BASE`, must start with `http://127.0.0.1:`) and trusts only a test key (`MIARINA_UPDATE_TEST_KEY`, 64 hex characters), both given at build time. It is only for recette builds with their own identifier, product name and executable name, so they install and keep data apart from the real application. The recette of lot L09 (two installed versions) is described in `docs/lots/LOT-L09-mises-a-jour.md`.

## Limits

- 0.1.6 cannot discover updates; 0.1.7 must be installed manually once.
- Android: background download (foreground service), metered-network rules and the migration screen are not implemented (UPD-06).
- Windows installers are not Authenticode-signed (UPD-09).

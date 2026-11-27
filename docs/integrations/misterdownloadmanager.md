# Mister Download Manager integration

Upstream: https://github.com/anefzaoui/misterdownloadmanager
Pinned revision: `46bb3bcd316a540a05fc18feff40707afe5a4dee` (0.5.1).
License: GPL-3.0-or-later; retain upstream notices. Miarina source is
GPL-3.0-only, with Windows authorization recorded on 2026-11-09.

Initialize the source dependency before building:

```sh
git submodule update --init vendor/misterdownloadmanager-source
cargo build -p miarina-browser-bridge
```

`apps/flutter_client/tool/stage_windows.ps1` builds the bridge in release mode and copies it next to the app. The former `mdm-adapter` crate (HTTP downloads through MDM, Tauri app only) was removed with that app (decision 0012).

Windows development builds can select `--features mdm-http` to use the adapter
for direct HTTP transfers. Default builds and Android keep the existing engine.
The upstream repository is included as a submodule, not a replacement for
Miarina's React/Tauri interface. Inclusion of code does not make a feature
available in Miarina. Upstream's desktop engine has not been validated on Android.

## Feature inventory

| Upstream capability | Miarina integration status |
| --- | --- |
| Segmented HTTP(S), resumable state | Adapter in development; not enabled in released applications |
| FTP(S) | Pending URL validation, credentials handling and UI |
| Checksums, speed limits | Pending settings and task API wiring |
| Browser extension/native messaging | Chrome/Edge explicit link sender, per-user registration, local inbox and build packaging implemented; browser end-to-end and store publication pending; full upstream traffic/media capture not ported |
| Video/audio extraction, playlists, subtitles | Existing Miarina yt-dlp implementation; upstream parity not established |
| Gallery extraction | Pending gallery-dl packaging and task model |
| Torrents/magnets, selection, RSS, seeding | Windows torrent screen and native commands implemented: metadata preview, selection, pause/resume, rate limits, sequential order, sharing and stop-session; RSS and ratio/time seeding limits pending |
| Link grabber and packages | Pending import/selection UI and persistent grouping |
| Archive extraction | Pending extraction UI, paths validation and tool packaging |
| Debrid providers | Pending opt-in account storage and provider integration |
| Scheduling, wake/shutdown actions | Pending scheduler persistence and explicit action settings |
| Proxy/PAC, DNS, VPN binding/kill switch | Pending network settings and failure-mode tests |
| LAN remote control/pairing, headless mode | Pending opt-in server and authentication; no server started |
| CLI, local API, MCP | Pending application lifecycle and permission boundaries |
| Translations, themes, portable/accessibility | Existing Miarina UI retained; parity requires a separate audit |

## Transfer adapter boundaries

`crates/mdm-adapter` implements the existing HTTP engine interface. Existing
sequential partial files stay with the old engine; MDM's sparse segments and
resume metadata stay in each task's work directory. The final move uses
Miarina's no-overwrite naming. Cancellation joins upstream workers before
the manager can remove staging files. Raw upstream error messages are not
persisted, because they can contain signed URLs or response bodies.

Activation requires passing transfer, cancellation, resume and no-overwrite
checks. Crash recovery after upstream completion but before Miarina finalization
still needs a durable completion record. Do not deploy this adapter yet.

## Validation (Windows, 2026-11-09)

- `cargo check -p miarina-media --features mdm-http`: passed.
- `cargo test -p miarina-mdm-adapter --locked`: five tests passed using generated
  bytes and a local HTTP server: segmented transfer/no overwrite, cancellation
  then exact-byte resume, pre-cancel without writes, legacy partial resume,
  mismatched saved state rejection.
- `cargo test -p download-engine --lib --locked`: 46 tests passed, including
  release-signature verification after the SHA-256 dependency patch update.
- Native UI, Android portability and production binaries not validated for MDM.

## Windows torrent and extension slice

Torrents have their own screen (Ctrl+8). The session starts only through Enable;
UPnP and LAN discovery are disabled. Enable restores persisted transfers and may
resume sharing completed files. Stop all torrents and sharing shuts down the
session. Files are placed in an exclusively created hash-based directory under
the configured download directory/Torrents. Remove keeps files on disk.
The session persists piece state separately from Miarina's SQLite records.
Torrent files are not yet indexed automatically into Miarina's media library.

The extension in apps/browser-extension sends only explicit HTTP(S) links.
Settings → Browser extension opens the unpacked extension folder, registers its
exact Chrome/Edge ID under HKCU, and shows received links for manual analysis.
The Rust native host stores bounded requests in APPDATA/org.miarina.media/browser-inbox;
it does not launch a local HTTP server or automatically start downloads.
Native messaging uses the documented length-prefixed UTF-8 protocol:
https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging

Windows development/release hooks prepare and bundle the bridge. A raw cargo
check needs the bridge preparation commands above first. The extension remains
a developer-mode package until browser-store distribution is arranged.
No installer or APK containing these changes has been published.

Validation of this slice (2026-11-09):

- Native application `cargo check --locked --offline`: passed.
- Local BitTorrent seed-to-receiver transfer: passed, exact generated file bytes,
  initial pause/resume and removal keeping the file; DHT and external trackers off.
- Existing frontend suite: 70 tests passed; four new torrent/extension UI tests passed.
- Frontend typecheck, lint and production build: passed.
- Native bridge: four Rust protocol/inbox tests passed; real executable round-trip
  with isolated APPDATA passed.
- Extension worker: three tests passed (explicit sending, rejected input/origins,
  missing native host). Browser installation/registration has not been tested
  end-to-end in a real browser, and no public torrent swarm was used.

# Pre-build audit — 2026-11-09

Scope: recent Windows torrent/browser-extension integration, shared download
and storage paths, frontend regression suite. No release installer or APK was
generated or deployed during this audit. Test executables were built as needed.

## Corrections

- Editing one torrent rate limit preserves the other persisted limit; empty
  inputs are rejected instead of silently removing a limit.
- Errored torrents offer Resume; inactive/checking rows do not offer invalid
  pause actions.
- A metadata lookup finishing after its session was stopped/replaced cannot
  repopulate pending previews. Rate changes serialize with session lifecycle.
- A malformed, oversized or unreadable browser-inbox entry no longer hides valid
  links. Reads remain bounded even if a file grows after its metadata was read.
- Temporary-file cleanup fails closed when task metadata cannot be read.
  Size calculation does not follow symbolic links.
- Download-folder write checks create an exclusive unique probe rather than
  overwriting/deleting a user file named `.miarina-write-test`.

## Verification

- Frontend: 76 tests passed; TypeScript and ESLint passed.
- Core Rust libraries (download-engine, media-core, storage, resource-manager,
  library and browser bridge): unit suites passed.
- Application Rust: 29 tests passed, including filesystem regression tests.
- HTTP transfer: 9 integration tests passed.
- Download manager: 10 integration tests passed.
- Optional MDM HTTP adapter: 5 integration tests passed.
- Torrent loopback transfer: passed, including exact bytes, pause, session restart
  preserving pause and removal preserving downloaded files.
- Extension worker: 3 tests passed.

## Remaining release validation

This is not a guarantee that no bugs remain. Native browser extension installation
and messaging in Chrome/Edge, Windows installer appearance, real-phone Android
downloads/background lifecycle and native fullscreen playback still need device
validation. Public provider behavior (including YouTube) is not covered by local
fixtures. Android does not expose the new Windows-only torrent screen.

MDM HTTP remains opt-in: its crash window after staging completion and before
final placement is documented in the integration inventory. Do not enable it
by default until recovery is implemented and tested. The full upstream feature
set is not integrated. No release version has been bumped by this audit.

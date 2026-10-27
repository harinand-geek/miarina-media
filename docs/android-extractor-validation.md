# Android extractor integration — 2026-10-27

Development build based on 0.1.3; not a new published release.
Product direction: Android follows the SnapTube functional workflow; Windows
follows Televzr. Both retain Miarina's branding and approved visual system.

## Implemented

- Packaged Python/yt-dlp/QuickJS/FFmpeg, initialized by `ExtractorPlugin`.
- Shared Rust extraction, format selection, conversion and persistent queue.
- YouTube watch/shorts and page players offered for analysis in the browser.
- HLS playlists routed to extraction instead of being treated as audio files.
- Actual network/HTTP errors retained for direct links, without exposing URLs.
- Cancel action and confirmation on mobile active/queued downloads.
- APK updates replace the packaged extractor; no remote code updater enabled.
- Owner-approved GPL-compatible Android source grant and packaged notices.

## Checks completed

- Frontend: 64 tests passed (12 files), typecheck, eslint and formatting passed.
- Rust: 26 app tests, 44 engine unit tests, 9 HTTP tests and 10 queue tests passed.
- Windows clippy for app and download-engine, all targets, warnings denied: passed.
- Real Windows YouTube analysis and thumbnail cache test (Blender Sintel): passed.
- First x86_64 signed release-mode APK compiled and installed: 69,468,168 bytes.
  This is an emulator APK, not an ARM64 phone artifact.

An initial frontend parallel run timed out during heavy compilation/emulator
load; the two-worker rerun passed. An HTTP cancellation timing assertion also
failed under load; the serial integration rerun passed without relaxing it.

## Device findings

Android 15 emulator `voakajy_test`, no physical device. Cold boot was needed
after system UI/launcher ANRs. The first APK exposed a real R8 release crash:
Commons Compress ZIP extra-field classes used by reflection had been optimized
away. Added a targeted keep rule for `ZipExtraField` implementations and a
controlled error for native tool linkage failures. The corrected x86_64 APK
(69,476,804 bytes) installed and initialized the runtime without that crash.
The packaged Python extractor listed real video and audio formats for Blender's
Big Buck Bunny (`aqz-KE-bpKQ`) on the emulator, exiting successfully. This was a
native runtime diagnostic, not a completed in-app download.

The app's generic HTTP probe failed before reaching extraction on this network.
Known YouTube hosts now route directly to the extractor. A further APK build
includes this correction and the checksum-verified yt-dlp 2026.08.19 archive.
The rebuilt APK (72,549,432 bytes, SHA-256
`e878362dabec06297436a044cea97c3a27c2dbbf9d37b6740beab0bc06ba2f2c`)
completed the actual in-app flow on Android 15 x86_64: shared YouTube link,
metadata/thumbnail and format sheet, selected 360p, download progress, completion
in Done, and local playback advancing to 0:09 of 10:35. The resulting MP4 in
`Movies/Miarina` is 28,983,576 bytes. Audio output was not audibly checked on the
headless emulator.

This test also exposed storyboard images appearing as a bogus 180p offer.
The shared format classifier now respects an explicit `vcodec: none` instead
of treating image height as video. All seven format-offer tests pass, including
the new storyboard regression. This final classifier change is not included
in the APK hash above and needs the next build.

## Release gate

Verify Android analysis, completed video+audio download, MP3 conversion,
cancellation and library playback. Build ARM64, measure size, inspect dependency
licenses/source availability for the exact artifacts, then publish a distinct
version with corresponding sources. Multiple tabs/history are not implemented
by this slice. Physical-device verification remains outstanding.

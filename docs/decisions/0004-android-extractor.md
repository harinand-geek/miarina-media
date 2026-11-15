# Android extraction — 2026-10-27

## Product decision

The owner confirmed Android should follow SnapTube's functional workflow and
desktop should follow Televzr's. Preserve Miarina branding and the approved
design. The immediate gap is Android URL analysis and downloading, not a new
visual redesign. Multiple tabs and browser history remain separate work.

## Runtime

Pin `io.github.junkfood02.youtubedl-android:library:0.18.1` and `ffmpeg:0.18.1`,
as documented in the upstream README. These package Python, yt-dlp, QuickJS,
and FFmpeg for Android. Native binaries are extracted by the package manager;
the plugin initializes packaged resources off the UI thread. No new Android
permissions, remote extraction service or user credentials are introduced.

The Python extractor is separately pinned to yt-dlp 2026.08.19, matching the
existing Windows pin, instead of the library's bundled 2025.11.12. Its release
archive is stored at `app/src/main/res/raw/ytdlp` in the Android project (named
`miarina_ytdlp` until 2026-11-15; the shared name now overrides the library's own
copy, so the APK carries one yt-dlp instead of two, about 3 MB less).
SHA-256 `1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6`
matches the repository's signed release checksum fixture. APK initialization
atomically replaces the installed script with this bundled version.

Rust retains ownership of commands, bounded analysis output, format validation,
progress, queue persistence, staging and finalization. The Kotlin bridge only
returns trusted runtime paths, never accepts an executable from the frontend.
Those paths depend on the pinned upstream layout and must be rechecked when
updating it. Cancellation kills the Unix process group, including FFmpeg.
The existing shared-storage publishing path is retained.

Analysis treats page players and manifests as candidates; the extractor must
still reject DRM, unavailable formats, live streams and playlists. YouTube
watch/shorts URLs can expose the button before playback. No cookies or account
access are imported. Requests refused by the source remain errors.

## Licensing and updates

The owner explicitly approved GPL-compatible open source Android distribution
on 2026-10-27. See LICENSE-ANDROID.md and packaged notices. Windows remains a
separate distribution. Before a public APK release, provide corresponding
sources and license notices for the exact native dependency artifacts as well
as the application. No runtime code download/update is enabled; ship updated
tools in signed APK releases.

## Required validation

- Host Rust tests and lint, frontend typecheck/lint/tests.
- Android Kotlin/Rust build, native binary loading and initialization.
- Authorized YouTube sample: analysis, audio+video download, MP3 conversion,
  cancellation/retry, gallery and library playback.
- APK size, source availability and a physical-device follow-up.

Compilation alone does not establish YouTube support. Record real results in
the implementation report before advertising or publishing the feature.

## Sources

- https://github.com/yausername/youtubedl-android/tree/0.18.1
- https://github.com/yausername/youtubedl-android/blob/0.18.1/LICENSE

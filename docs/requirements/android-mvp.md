# MIARINA MEDIA — Android MVP Features (exigences produit, reçues le 2026-10-14)

> Source : message du propriétaire du produit. Conservé tel quel ; les écarts avec le design approuvé sont listés en fin de document.

**Product:** MIARINA MEDIA · **Platform:** Android · **Experience:** Inspired by SnapTube · **Technology:** Tauri 2 + React + TypeScript + Rust + Kotlin

## 1. Built-in Browser (Core Feature)
- Integrated mobile browser using Android WebView.
- URL bar with search functionality.
- Back, forward, refresh and home navigation.
- Multiple browser tabs.
- Browsing history and bookmarks.
- Automatic detection of supported downloadable media.
- Floating download button when downloadable media is detected.
- Support for authorized media sources without bypassing DRM or protected streams.

## 2. Smart Media Detection
- Detect supported video and audio resources while browsing.
- Analyze pasted URLs.
- Display media title, thumbnail and available formats.
- Offer available resolutions: 360p, 480p, 720p, 1080p or higher when supported.
- Display estimated file size when available.
- Handle unsupported and protected content gracefully.
- Do not claim universal media detection.

## 3. Download Manager
- Download videos and audio directly to Android storage.
- Download multiple files with configurable concurrency.
- Real-time progress, speed and estimated remaining time.
- Pause and resume when supported.
- Cancel, retry and delete downloads.
- Persistent download queue.
- Background downloading using Android-compliant services.
- Download notifications.
- Handle network interruptions and insufficient storage.

## 4. Video and Audio Downloads
- Support MP4, WebM, MP3 and M4A where technically available.
- Allow users to select video quality and audio formats.
- Extract audio from supported media using a compatible processing engine.
- Clearly distinguish direct downloads from conversions.
- Avoid unnecessary transcoding to reduce CPU, battery usage and processing time.

## 5. Media Library
- Organize downloaded videos and audio. Grid and list views. Search, sort and filter media.
- Display thumbnails, file sizes and durations.
- Rename, share and delete files. Open downloaded media with external applications.

## 6. Integrated Media Player
- Built-in video and audio playback. Play, pause, seek and volume controls. Full-screen video playback.
- Background audio playback. Playback speed selection. Resume playback from the last position.
- Support Android-compatible media formats.

## 7. Mobile UI/UX
- Original MIARINA MEDIA branding. Premium, modern interface inspired by SnapTube's usability.
- Dark and light themes.
- Bottom navigation: **Home, Browser, Downloads, Library**.
- Floating contextual download button. Responsive layouts for Android phones.
- Smooth transitions and lightweight animations. Clear loading, empty, success and error states.

## 8. Settings and Performance
- Download folder selection. Wi-Fi-only download option. Configurable simultaneous downloads.
- Download quality preferences. Dark/light/system theme. Language-ready architecture.
- Eco, Balanced and Performance modes. Optimized memory, CPU, storage and battery usage.

## 9. Security and Privacy
- Local-first architecture. No mandatory user account. No remote server required for standard supported downloads.
- Minimal Android permissions. Android scoped storage support. Secure WebView configuration.
- No DRM circumvention, paywall bypass or unauthorized access. No unnecessary tracking or analytics.

## 10. MVP Acceptance Criteria
The Android MVP is complete when a user can:
1. Open MIARINA MEDIA and browse a supported website.
2. Play or open an authorized video.
3. See a download button when a downloadable resource is successfully detected.
4. Select an available format and quality.
5. Start a download and monitor its progress.
6. Continue the download while the application is in the background, subject to Android restrictions.
7. Find the completed file in the media library.
8. Play the downloaded video or audio offline.
9. Manage downloaded files without requiring an account.

## Development Priority
- **P0 — Essential:** Built-in browser, supported media detection, contextual download button, format selection, download manager, local library and basic playback.
- **P1 — Important:** Background downloads, notifications, pause/resume, audio extraction, bookmarks and performance settings.
- **P2 — Post-MVP:** Playlists, batch downloads, advanced browser features, subtitle management, picture-in-picture and optional device synchronization.

## Implementation instructions
Use the approved Claude Design interface as the visual source of truth. Prioritize real working functionality over visual demonstrations. Validate media detection and downloading on representative authorized sources before the full engine. Use Android-native APIs where Tauri abstractions are insufficient. Do not assume desktop yt-dlp or FFmpeg binaries run on Android. Implement incrementally, test on real Android devices, document limitations.

---

## Écarts avec le design approuvé et `CLAUDE.md`

Arbitrés le 2026-10-14 : voir `docs/decisions/0001-embedded-browser-p0.md`.

| Exigence | Design / CLAUDE.md | Décision nécessaire |
|---|---|---|
| Navigateur intégré = P0 (Android et Windows) | `CLAUDE.md` : « Later, not MVP » ; design : écran Browser **PLANNED** (Windows), **absent** sur Android | Valider le changement de priorité et mettre `CLAUDE.md` à jour |
| Bottom nav Home / Browser / Downloads / Library | Design Android : Home / Downloads / Library / **Settings** | Où va Settings (icône dans l'en-tête Home ?) — maquette ou accord |
| Écrans navigateur (onglets, historique, favoris, bouton flottant) | Non maquettés | Maquettes Claude Design, ou accord pour les composer avec le design system |
| Multi-webview sous Tauri | Feature `unstable` sur desktop, non supportée sur mobile (risque R3) | Spike : Android = WebView natif via plugin Kotlin ; Windows = webview enfant `unstable` ou fenêtre dédiée |

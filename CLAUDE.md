# MIARINA MEDIA — Claude Code Project Instructions

## Project identity
- **Product:** Miarina Media
- **Company:** MIARINA
- **Company domain:** https://miarina.org
- **Proposed product site:** https://media.miarina.org
- **Repository:** `miarina-media`
- **Target platforms:** Windows and Android (no browser-based downloader in MVP)
- **Mission:** Build an original, lightweight, local-first multimedia downloader, library and player. Televzr and SnapTube are functional references only; never copy their branding, assets or proprietary UI.

## Non-negotiable principles
1. **Design fidelity:** The approved Claude Design handoff is the source of truth for visual decisions. Inspect `design/` and `docs/design-system.md` before implementing UI. Do not invent a new design or replace supplied assets.
2. **Performance first:** Stream to disk; do not buffer entire media files in memory. Limit parallel downloads and conversions, throttle UI progress events, and measure rather than assume resource savings.
3. **Local-first:** Downloads, conversion, history and library operate on-device. Do not add a remote backend, telemetry, accounts or cloud sync without approval.
4. **Cross-platform honesty:** Share UI and domain code when practical, but use platform-specific adapters. Never assume Windows binaries work on Android.
5. **Security and legality:** Support authorized media only. Do not bypass DRM, paywalls, authentication or access controls. Treat URLs, metadata, output paths and subprocess output as untrusted.
6. **Incremental delivery:** Build working vertical slices, test them, and report actual results. Do not claim tests/builds passed unless run.

## Preferred technology
- **Shell:** Tauri 2
- **Frontend:** React + TypeScript + Vite + Tailwind CSS
- **UI state:** Zustand when justified; keep state local otherwise
- **Core:** Rust with typed Tauri commands and events
- **Persistence:** SQLite with versioned migrations
- **Windows media extraction:** evaluate yt-dlp and FFmpeg as external managed tools, including licensing, distribution and update strategy
- **Android integration:** Kotlin and Android APIs for storage, notifications, lifecycle and background work; validate extractor/FFmpeg feasibility before committing
- **Website:** optional separate Next.js marketing site, outside the app MVP

Confirm current stable compatible versions against official documentation before pinning dependencies. Prefer small, maintained libraries and avoid unnecessary frameworks.

## Target repository structure
```text
miarina-media/
├── CLAUDE.md
├── design/                     # Approved Claude Design handoff
├── docs/
│   ├── architecture.md
│   ├── design-system.md
│   ├── design-implementation-map.md
│   ├── android-feasibility.md
│   └── decisions/
├── apps/
│   └── client/
│       ├── src/
│       │   ├── components/
│       │   ├── features/{home,analysis,downloads,library,player,history,settings}/
│       │   ├── hooks/
│       │   ├── services/
│       │   └── styles/
│       └── src-tauri/
│           ├── src/
│           └── capabilities/
├── crates/
│   ├── media-core/
│   ├── download-engine/
│   ├── storage/
│   └── resource-manager/
├── plugins/
│   └── android-download/
└── packages/
    ├── ui/
    └── shared-types/
```
This is a target layout, not a requirement to create empty packages. Introduce modules when needed, and document justified deviations.

## Product scope
### MVP (Windows first)
- Paste a supported media URL and analyze available metadata and formats.
- Choose video/audio format and quality when available.
- Start, cancel and monitor downloads; resume only when technically supported.
- Persist download tasks and history in SQLite; recover safely after restart.
- Browse and search locally downloaded media.
- Play supported local media using an appropriate platform playback implementation.
- Configure destination, concurrency and resource mode (Eco / Balanced / Performance).
- Provide useful errors, empty states and accessible keyboard navigation.

### Android phase
- Reuse the approved mobile design and shared core where viable.
- Validate extractor packaging, APK/AAB size, media conversion, scoped storage, content URIs, permissions, notifications and background task behavior on physical devices.
- Implement a native Android adapter with lifecycle-aware work; do not promise feature parity before validation.

### Later, not MVP
- Embedded browser and media detection
- Playlist/batch downloads
- Optional synchronization or cloud services

## Architecture rules
- Keep React components presentation-oriented. No direct arbitrary filesystem or shell access from the frontend.
- Expose narrow, validated Tauri commands and typed progress/status events.
- Define a platform-independent download interface: `analyze`, `formats`, `start`, `cancel`, `status`, and conditional `pause`/`resume`.
- Model task states explicitly (e.g. queued, analyzing, downloading, processing, completed, failed, canceled); enforce valid transitions.
- Store metadata and task status in SQLite with migrations; do not store entire media blobs in the database.
- Stream network responses to temporary files; use atomic finalization where feasible.
- Sanitize filenames, reject traversal, validate destination permissions, and safely handle duplicates.
- Run subprocesses with argument arrays, never interpolated shell strings. Limit execution and clean up child processes on cancellation.
- Keep secrets out of source control and logs. Do not log tokens, cookies or sensitive URLs.
- Restrict Tauri capabilities and Android permissions to the minimum necessary.

## Resource and reliability requirements
- Download concurrency configurable, default conservative; conversions separately bounded.
- No unbounded queues, event storms or whole-file memory reads.
- Progress UI should update at a controlled rate rather than for every downloaded chunk.
- Provide cancellation, timeout and bounded retries with backoff.
- Handle low disk space, network loss, invalid URLs, unsupported sources and interrupted shutdowns.
- Eco / Balanced / Performance must change actual concurrency or processing behavior, not just labels.
- Benchmark cold start, idle RAM, active-download RAM/CPU, conversion CPU and package size on representative devices; record measurements and environment in `docs/performance.md`. Do not invent numeric targets or results.

## Design handoff contract
Before implementing any screen:
1. Inspect files in `design/` (screenshots, exported assets, components, tokens and interaction notes).
2. Extract and document tokens, responsive breakpoints, screen states and component variants in `docs/design-system.md`.
3. Map each screen to code modules in `docs/design-implementation-map.md`.
4. Ask for missing essential design inputs; otherwise make only minimal, documented accessibility/technical adaptations.
5. Compare screenshots at representative Windows and Android sizes and fix meaningful mismatches.

If no approved handoff exists, implement only a minimal functional scaffold and request the design before polishing UI. Suggested visual direction (not a substitute for approved design): dark-first, accent `#35C9BD`, backgrounds `#101820` / `#182530`, text `#F5F7FA` / `#94A3B8`, accessible light theme.

## Testing and release discipline
- Add Rust unit/integration tests for task state transitions, path validation and queue behavior.
- Add frontend component tests for core user flows and error states.
- Test SQLite migrations and restart recovery.
- Run formatting, linting, type checks and relevant tests before reporting a phase complete.
- Verify Windows builds on Windows and Android builds with the required Android toolchain; clearly disclose environments not tested.
- Review licensing and redistribution obligations for yt-dlp, FFmpeg, codecs and other dependencies before bundling.
- Document signing, release artifacts, versioning and update strategy before production release.

## Claude Code working protocol
For each phase:
1. Read `CLAUDE.md`, relevant docs and existing code.
2. State scope, assumptions, dependencies, risks and acceptance criteria.
3. Make a small implementation plan and implement one working slice at a time.
4. Run available checks and inspect output; fix failures within scope.
5. Summarize changed files, verified behavior, tests actually run, limitations and next step.
6. Do not silently add dependencies, services, permissions or major architecture changes.

### Phase sequence
- **Phase 0:** Audit design handoff, confirm platform feasibility and write architecture/risks.
- **Phase 1:** Scaffold Tauri + React and implement approved design shell/screens.
- **Phase 2:** Working Windows URL-to-download vertical slice, queue and SQLite.
- **Phase 3:** Local library, playback, conversion and reliability.
- **Phase 4:** Android feasibility spike, then native implementation.
- **Phase 5:** Profiling, accessibility, hardening and release preparation.

## First instruction to Claude Code
**Start with Phase 0 only.** Inspect the repository and `design/`, identify missing inputs, propose module boundaries and an actionable implementation plan. Explicitly assess Android extractor feasibility, FFmpeg packaging, background downloads, application size and the future embedded browser. Do not scaffold the entire application or claim cross-platform compatibility before this review is approved.


## Windows playback interruption — 2026-10-31

User screenshot: white playback surface, generic unsupported-format message at 3:04 of a 5:22 H.264/AAC MP4. Read the matching library record without modifying the database. FFmpeg decoded the 175–200 second interval and the entire local file with exit 0 and no errors. This does not reproduce or diagnose the WebView2 decoder failure.

Desktop player now records the HTML media error code, distinguishes unsupported source from read/decode/interruption failures, and offers an explicit reload at the interrupted position. Failed video surfaces and animated backdrops are hidden against the existing dark player background. Regression tests cover retry position, reset of the error state, and repeated unsupported-source failures. No dependency or native Android player change.

Native Windows reproduction and installer verification remain pending; this change is not a claim that the underlying WebView2 failure is eliminated.

Verification: 69 frontend tests passed across 14 files; TypeScript/Vite production build and ESLint passed. FFmpeg checks passed as described above. jsdom emitted its existing canvas-not-implemented warning. No native installer built or published.

Fullscreen checks: client production build, TypeScript and ESLint passed; 70 frontend tests passed including entering fullscreen, restoring sidebar with Escape, and resetting fullscreen on navigation. Native Windows fullscreen rendering is not yet manually rechecked; no new installer published.

## Windows 0.1.5 release — 2026-10-31

Native Tauri/NSIS build succeeded from application revision 0fab9e2. Product and file version 0.1.5; installer 72496005 bytes, SHA-256 97dd9247170f05f8358f10bf55012f5232d1b6c2498e71a7697a2144606e0cf6. Authenticode status NotSigned, consistent with existing test releases. Contains fullscreen shell correction and explicit playback recovery; underlying WebView2 interruption has not been reproduced. The 70 frontend tests, TypeScript and lint passed before this release; website production/prerender build passed. Native visual playback and installer interaction have not been rechecked for this build.

Publication verified: server installer SHA-256 matched; public Windows download HTTP 200 with Content-Length 72496005. Live site HTTP 200 contains the hash-qualified Windows 0.1.5 link and preserves Android 0.1.5. Site backup /root/miarina-before-windows-0.1.5-site.tar.gz.

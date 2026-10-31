
## Windows playback interruption — 2026-10-31

User screenshot: white playback surface, generic unsupported-format message at 3:04 of a 5:22 H.264/AAC MP4. Read the matching library record without modifying the database. FFmpeg decoded the 175–200 second interval and the entire local file with exit 0 and no errors. This does not reproduce or diagnose the WebView2 decoder failure.

Desktop player now records the HTML media error code, distinguishes unsupported source from read/decode/interruption failures, and offers an explicit reload at the interrupted position. Failed video surfaces and animated backdrops are hidden against the existing dark player background. Regression tests cover retry position, reset of the error state, and repeated unsupported-source failures. No dependency or native Android player change.

Native Windows reproduction and installer verification remain pending; this change is not a claim that the underlying WebView2 failure is eliminated.

Verification: 69 frontend tests passed across 14 files; TypeScript/Vite production build and ESLint passed. FFmpeg checks passed as described above. jsdom emitted its existing canvas-not-implemented warning. No native installer built or published.

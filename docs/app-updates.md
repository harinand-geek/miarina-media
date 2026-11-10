# Application updates (0.1.7)

Windows and Android check `/updates/stable.json` after startup and every six hours while the UI is visible. Settings provides a manual check, download progress and a separate installation action. Downloads do not start without a click. Installation never starts automatically.

The manifest is an envelope with a UTF-8 `payload` JSON string and a hexadecimal Ed25519 signature over the exact payload bytes. The public key is pinned in the application. Each platform record contains a numeric three-part version, release notes, HTTPS URL, byte size and SHA-256. Only versioned download URLs on media.miarina.org are allowed. Redirects are refused, metadata reads are bounded, artifacts are streamed with size and hash checks. Installation rechecks the file. Active media downloads must first finish or be paused; Windows stops the torrent session before exiting.

Windows starts the packaged NSIS installer from the app cache. Android requests permission to install packages if needed, validates the APK package name and existing signing certificate, then opens Android's installer via a content URI. No uninstall is performed. Android installation always requires the user's system confirmation.

The private Ed25519 release key is local in ignored `builds/update-signing-private.pem`; never put it in Git, archives or on the public server. Keep a protected backup: losing it prevents updates accepted by installed clients. APK signing continues to use its existing, separate certificate. Windows Authenticode signing remains separate.

Publication:

1. Build and verify Windows and Android artifacts with matching version metadata.
2. Run `node apps/client/scripts/sign-app-update.mjs VERSION KEY WINDOWS_EXE ANDROID_APK OUTPUT NOTES_FILE`.
3. Upload and verify the versioned artifacts first. Publish the signed manifest last at `/updates/stable.json` (atomic rename). Serve with revalidation/no-cache; the client adds a cache-busting query.
4. Verify the public manifest signature with the pinned public key and check both download hashes.

0.1.6 cannot discover updates: one manual installation of 0.1.7 is required. The new mechanism applies to subsequent releases. An interrupted update download can be retried from Settings; byte-range resume and automatic Wi-Fi-only downloading are not implemented. The app must stay running during the update download; Android foreground-service integration for this download is not yet implemented.

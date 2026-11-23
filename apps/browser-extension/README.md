# Miarina Media browser extension (Chrome, Edge)

Sends the current page, or a link chosen from the context menu, to Miarina
Media on the same PC. Nothing is read from pages and nothing is sent anywhere
else. Decision: `docs/decisions/0009-browser-extension-flutter.md`.

## Install (until the store publication)

1. In Miarina Media: Settings › Browser extension › **Connect** (writes the
   native messaging manifest in the app's data folder and one HKCU value per
   browser; no administrator rights).
2. In Chrome or Edge, open the Extensions page, enable Developer mode, choose
   **Load unpacked** and select the `browser-extension` folder next to the app
   (step 1 in Settings opens it).
3. Use **Test the connection** in the popup, or **Test** in Settings.

The manifest's `key` fixes the extension ID (`dlfhnodjkhddcjeeoaeminkboapodnoa`),
which is the only origin the native host accepts. The private key is kept out
of the repository.

## How a link travels

Popup or context menu → `chrome.runtime.sendNativeMessage("org.miarina.media.bridge",
{url})` → `miarina-browser-bridge.exe` (validates: http(s), no credentials,
at most 2048 characters) → `miarina-media.exe --link <url>` → the running
window opens the analysis in Obtenir. Nothing downloads without the user's
choice. `{ping: true}` is the connection test.

## Checks

    node --test apps/browser-extension/background.test.mjs
    cargo test -p miarina-browser-bridge

Firefox is not supported (no Mozilla ID or signing). No Chrome/Edge store
publication has been performed.

Source license: GPL-3.0-only, see the repository root LICENSE.
Protocol reference: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging

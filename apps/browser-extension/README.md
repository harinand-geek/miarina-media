# Miarina browser extension

Development distribution for Chrome/Edge. In the browser's Extensions page,
enable Developer mode and load this folder with **Load unpacked**. Open its
popup to copy its ID, then in Miarina Settings → Browser extension select the
browser, paste the ID and choose Connect. The application build must include
the native bridge. Registration is per Windows user and requires no administrator.

Use the toolbar button or a page/link/media context menu to send a link.
Requests are stored locally even when Miarina is closed. Review them in
Settings → Browser extension → Received links before starting downloads.

This extension currently handles explicit HTTP(S) links. It does not intercept
all downloads, collect cookies, scan page traffic, or provide the upstream
extension's complete feature set. Firefox packaging/signing is not yet shipped.
No Chrome/Edge store publication has been performed.

Source license: GPL-3.0-only, see the repository root LICENSE.
Protocol reference: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging

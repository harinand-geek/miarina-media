/* Miarina Media — GPL-3.0-only. Explicit user actions only; no page monitoring. */
const HOST = 'org.miarina.media.bridge';
function valid(url) {
  try {
    const u = new URL(url);
    return (
      ['http:', 'https:'].includes(u.protocol) && !u.username && !u.password && url.length <= 2048
    );
  } catch {
    return false;
  }
}
function send(url) {
  return new Promise((resolve) => {
    if (!valid(url)) {
      resolve({ ok: false, message: 'Choose an HTTP or HTTPS link.' });
      return;
    }
    chrome.runtime.sendNativeMessage(HOST, { url }, (reply) => {
      const failed = chrome.runtime.lastError;
      resolve(
        failed
          ? {
              ok: false,
              message: 'Connect this extension in Miarina Settings → Browser extension.',
            }
          : reply?.ok
            ? {
                ok: true,
                message: 'Saved in Miarina Settings → Browser extension → Received links.',
              }
            : { ok: false, message: 'Miarina could not save this link. The inbox may be full.' },
      );
    });
  });
}
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'miarina-send',
      title: 'Send to Miarina Media',
      contexts: ['page', 'link', 'video', 'audio'],
    });
  });
});
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== 'miarina-send') return;
  const result = await send(info.linkUrl || info.srcUrl || info.pageUrl || tab?.url);
  await chrome.storage.local.set({ lastResult: result });
  await chrome.action.setBadgeText({ text: result.ok ? '✓' : '!' });
});
chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (sender.id !== chrome.runtime.id || message?.type !== 'send') return false;
  void send(message.url).then(reply);
  return true;
});

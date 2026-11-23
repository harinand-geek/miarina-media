/* Miarina Media — GPL-3.0-only.
 * Explicit user actions only: nothing is read from pages. The link the user
 * sends (toolbar button or context menu) goes to the native host
 * org.miarina.media.bridge, which opens its analysis in Miarina Media. */
const HOST = 'org.miarina.media.bridge';
const text = (key) => chrome.i18n.getMessage(key) || key;

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

/** One message to the native host: its reply, or `missing` when the app
 * has not connected this browser. */
function native(body) {
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(HOST, body, (reply) => {
      resolve(chrome.runtime.lastError ? { missing: true } : { ok: reply?.ok === true });
    });
  });
}

async function send(url) {
  if (!valid(url)) return { ok: false, message: text('notWeb') };
  const r = await native({ url });
  if (r.missing) return { ok: false, message: text('notConnected') };
  return r.ok ? { ok: true, message: text('sent') } : { ok: false, message: text('failed') };
}

async function test() {
  const r = await native({ ping: true });
  if (r.missing) return { ok: false, message: text('notConnected') };
  return r.ok ? { ok: true, message: text('connected') } : { ok: false, message: text('failed') };
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'miarina-send',
      title: text('menuSend'),
      contexts: ['page', 'link', 'video', 'audio'],
    });
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== 'miarina-send') return;
  const result = await send(info.linkUrl || info.srcUrl || info.pageUrl || tab?.url);
  await chrome.storage.local.set({ lastResult: result });
  await chrome.action.setBadgeText({ text: result.ok ? '' : '!' });
});

chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (sender.id !== chrome.runtime.id) return false;
  if (message?.type === 'send') {
    void send(message.url).then(reply);
    return true;
  }
  if (message?.type === 'test') {
    void test().then(reply);
    return true;
  }
  return false;
});

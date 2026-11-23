/* Miarina Media — GPL-3.0-only. */
for (const el of document.querySelectorAll('[data-i18n]')) {
  el.textContent = chrome.i18n.getMessage(el.dataset.i18n);
}
document.documentElement.lang = chrome.i18n.getUILanguage();
const status = document.getElementById('status');
const buttons = [document.getElementById('send'), document.getElementById('test')];

function show(result) {
  status.textContent = result?.message || '';
  status.className = result ? (result.ok ? 'ok' : 'warn') : '';
}

chrome.storage.local.get('lastResult').then((r) => show(r.lastResult));
chrome.action.setBadgeText({ text: '' });

async function run(message) {
  buttons.forEach((b) => (b.disabled = true));
  try {
    const reply = await chrome.runtime.sendMessage(message);
    show(reply);
    await chrome.storage.local.set({ lastResult: reply });
  } catch {
    show({ ok: false, message: chrome.i18n.getMessage('failed') });
  } finally {
    buttons.forEach((b) => (b.disabled = false));
  }
}

buttons[0].addEventListener('click', async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  await run({ type: 'send', url: tab?.url });
});
buttons[1].addEventListener('click', () => run({ type: 'test' }));

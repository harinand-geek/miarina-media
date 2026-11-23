import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';
const source = await readFile(new URL('./background.js', import.meta.url), 'utf8');
function setup({ missing = false, ok = true } = {}) {
  let receive;
  const sent = [];
  const chrome = {
    i18n: { getMessage: (key) => key },
    runtime: {
      id: 'test-extension',
      lastError: missing ? { message: 'missing host' } : undefined,
      onInstalled: { addListener() {} },
      onMessage: { addListener(fn) { receive = fn; } },
      sendNativeMessage(host, body, callback) { sent.push({ host, body }); callback({ ok }); },
    },
    contextMenus: { onClicked: { addListener() {} } },
  };
  vm.runInNewContext(source, { URL, chrome });
  const ask = (message) =>
    new Promise((resolve) => receive(message, { id: 'test-extension' }, (r) => resolve(JSON.parse(JSON.stringify(r)))));
  return { sent, receive, send: (url) => ask({ type: 'send', url }), test: () => ask({ type: 'test' }) };
}
test('a sent link reaches the native host, nothing else', async () => {
  const s = setup();
  assert.deepEqual(await s.send('https://example.com/video'), { ok: true, message: 'sent' });
  assert.deepEqual(JSON.parse(JSON.stringify(s.sent)), [
    { host: 'org.miarina.media.bridge', body: { url: 'https://example.com/video' } },
  ]);
});
test('rejects file URLs, credentials and messages from another extension', async () => {
  const s = setup();
  for (const link of ['file:///C:/secret', 'https://user:pass@example.com', 'javascript:alert(1)']) {
    assert.equal((await s.send(link)).ok, false);
  }
  assert.equal(s.receive({ type: 'send', url: 'https://example.com' }, { id: 'someone-else' }, () => {}), false);
  assert.equal(s.sent.length, 0);
});
test('not connected yet, or refused by the app', async () => {
  assert.deepEqual(await setup({ missing: true }).send('https://example.com'), { ok: false, message: 'notConnected' });
  assert.deepEqual(await setup({ ok: false }).send('https://example.com'), { ok: false, message: 'failed' });
});
test('the connection test only pings', async () => {
  const s = setup();
  assert.deepEqual(await s.test(), { ok: true, message: 'connected' });
  assert.deepEqual(JSON.parse(JSON.stringify(s.sent))[0].body, { ping: true });
});

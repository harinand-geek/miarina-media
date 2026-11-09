import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import { test } from 'node:test';
import assert from 'node:assert/strict';
const source = await readFile(new URL('./background.js', import.meta.url), 'utf8');
function setup(failure = false) {
  let receive;
  const sent = [];
  const chrome = {
    runtime: {
      id:'test-extension', lastError:failure ? {message:'missing host'} : undefined,
      onInstalled:{addListener() {}},
      onMessage:{addListener(fn) {receive = fn;}},
      sendNativeMessage(host, body, callback) { sent.push({host,body}); callback({ok:true}); },
    },
    contextMenus:{onClicked:{addListener() {}}},
  };
  vm.runInNewContext(source, {URL, chrome});
  return {sent, send: url => new Promise(resolve => receive({type:'send',url},{id:'test-extension'},resolve)), receive};
}
test('explicit links reach the native host without extra page information', async () => {
  const s = setup(); assert.equal((await s.send('https://example.com/video')).ok, true);
  assert.deepEqual(s.sent.map(x => JSON.parse(JSON.stringify(x))), [{host:'org.miarina.media.bridge',body:{url:'https://example.com/video'}}]);
});
test('rejects file URLs, credentials and messages from another extension', async () => {
  const s = setup();
  for (const link of ['file:///C:/secret','https://user:pass@example.com','javascript:alert(1)']) assert.equal((await s.send(link)).ok, false);
  assert.equal(s.receive({type:'send',url:'https://example.com'},{id:'someone-else'},()=>{}), false);
  assert.equal(s.sent.length,0);
});
test('a missing native host is reported as failure', async () => {
  assert.equal((await setup(true).send('https://example.com')).ok, false);
});

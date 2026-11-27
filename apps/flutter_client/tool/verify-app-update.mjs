// UPD-08: checks a release before (or after) publication, read-only.
// Usage: node apps/client/scripts/verify-app-update.mjs MANIFEST [CHANNEL]
//   MANIFEST: a local file (signed, not yet published) or an https URL.
// Verifies the signature with the key pinned in the app, the channel, the
// artifact names and that each artifact URL serves exactly the signed size
// and SHA-256 (downloaded and hashed, streamed). Exits non-zero on any error.
import fs from 'node:fs';
import crypto from 'node:crypto';

const [source, channel = 'stable'] = process.argv.slice(2);
if (!source || !['stable', 'beta'].includes(channel))
  throw Error('Expected MANIFEST [stable|beta]');
const BASE = 'https://media.miarina.org';
const raw = /^https:\/\//.test(source)
  ? Buffer.from(
      await (await fetch(`${source}?t=${Date.now()}`, { redirect: 'error' })).arrayBuffer(),
    )
  : fs.readFileSync(source);
if (raw.length > 64 * 1024) throw Error('Manifest larger than the 64 KiB the app accepts');
const { payload, signature } = JSON.parse(raw);
const pinned = fs.readFileSync(
  new URL('../rust/update-public-key.bin', import.meta.url),
);
const key = crypto.createPublicKey({
  key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), pinned]),
  format: 'der',
  type: 'spki',
});
if (!crypto.verify(null, Buffer.from(payload), key, Buffer.from(signature, 'hex')))
  throw Error('Signature does not match the pinned release key');
const manifest = JSON.parse(payload);
if ((manifest.channel ?? 'stable') !== channel)
  throw Error(`Manifest is for channel ${manifest.channel ?? 'stable'}, not ${channel}`);

let failed = false;
for (const [platform, suffix] of [
  ['windows', '-x64-setup.exe'],
  ['android', '.apk'],
]) {
  const r = manifest[platform];
  const expected = `${BASE}/downloads/MiarinaMedia-${r.version}${suffix}`;
  if (!/^\d+\.\d+\.\d+$/.test(r.version) || r.url !== expected) {
    console.error(`${platform}: unexpected version or URL ${r.url}`);
    failed = true;
    continue;
  }
  const response = await fetch(r.url, { redirect: 'error' });
  if (!response.ok) {
    console.error(`${platform}: ${r.url} answered ${response.status}`);
    failed = true;
    continue;
  }
  const hash = crypto.createHash('sha256');
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    hash.update(chunk);
  }
  const sha = hash.digest('hex');
  const ok = size === r.size && sha === r.sha256;
  console.log(`${platform} ${r.version}: ${size} bytes, sha256 ${sha} ${ok ? 'OK' : 'MISMATCH'}`);
  failed ||= !ok;
}
if (failed) process.exit(1);
console.log(`Manifest verified for channel ${channel}.`);

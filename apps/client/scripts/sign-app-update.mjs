// Usage: node apps/client/scripts/sign-app-update.mjs VERSION PRIVATE_KEY WINDOWS_EXE ANDROID_APK OUTPUT NOTES_FILE [CHANNEL] [ANDROID_VERSION]
// CHANNEL: stable (default) or beta. The channel is signed with the rest, so a
// beta manifest served at the stable address is refused by the app.
// ANDROID_VERSION: when only Windows is released, the Android record keeps the
// already published APK (its version, unchanged file): Android finds nothing newer.
import fs from 'node:fs';
import crypto from 'node:crypto';
const [version,keyPath,windowsPath,androidPath,output,notesPath,channel='stable',androidVersion=version]=process.argv.slice(2);
if(!/^\d+\.\d+\.\d+$/.test(version??'')||!/^\d+\.\d+\.\d+$/.test(androidVersion)||!notesPath)throw Error('Expected VERSION PRIVATE_KEY WINDOWS_EXE ANDROID_APK OUTPUT NOTES_FILE [CHANNEL] [ANDROID_VERSION]');
if(!['stable','beta'].includes(channel))throw Error('CHANNEL must be stable or beta');
const key=crypto.createPrivateKey(fs.readFileSync(keyPath));
const publicKey=crypto.createPublicKey(key);
const raw=publicKey.export({format:'der',type:'spki'}).subarray(-32);
const pinned=fs.readFileSync(new URL('../src-tauri/resources/update-public-key.bin',import.meta.url));
if(key.asymmetricKeyType!=='ed25519'||!raw.equals(pinned))throw Error('Wrong release signing key');
const notes=fs.readFileSync(notesPath,'utf8');
function artifact(path,suffix,v){const bytes=fs.readFileSync(path);return {version:v,notes,url:`https://media.miarina.org/downloads/MiarinaMedia-${v}${suffix}`,size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};}
const payload=JSON.stringify({channel,windows:artifact(windowsPath,'-x64-setup.exe',version),android:artifact(androidPath,'.apk',androidVersion)});
if(Buffer.byteLength(payload)>60000)throw Error('Manifest too large for the app (64 KiB limit)');
const signature=crypto.sign(null,Buffer.from(payload),key);
if(!crypto.verify(null,Buffer.from(payload),publicKey,signature))throw Error('Signature self-check failed');
fs.writeFileSync(output,JSON.stringify({payload,signature:signature.toString('hex')})+'\n');
console.log(`Signed ${channel} manifest written. Publish it at /updates/${channel}.json only after both artifacts are uploaded and verified (verify-app-update.mjs).`);

// Usage: node apps/client/scripts/sign-app-update.mjs VERSION PRIVATE_KEY WINDOWS_EXE ANDROID_APK OUTPUT NOTES_FILE
import fs from 'node:fs';
import crypto from 'node:crypto';
const [version,keyPath,windowsPath,androidPath,output,notesPath]=process.argv.slice(2);
if(!/^\d+\.\d+\.\d+$/.test(version??'')||!notesPath)throw Error('Expected VERSION PRIVATE_KEY WINDOWS_EXE ANDROID_APK OUTPUT NOTES_FILE');
const key=crypto.createPrivateKey(fs.readFileSync(keyPath));
const publicKey=crypto.createPublicKey(key);
const raw=publicKey.export({format:'der',type:'spki'}).subarray(-32);
const pinned=fs.readFileSync(new URL('../src-tauri/resources/update-public-key.bin',import.meta.url));
if(key.asymmetricKeyType!=='ed25519'||!raw.equals(pinned))throw Error('Wrong release signing key');
const notes=fs.readFileSync(notesPath,'utf8');
function artifact(path,suffix){const bytes=fs.readFileSync(path);return {version,notes,url:`https://media.miarina.org/downloads/MiarinaMedia-${version}${suffix}`,size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};}
const payload=JSON.stringify({windows:artifact(windowsPath,'-x64-setup.exe'),android:artifact(androidPath,'.apk')});
const signature=crypto.sign(null,Buffer.from(payload),key);
if(!crypto.verify(null,Buffer.from(payload),publicKey,signature))throw Error('Signature self-check failed');
fs.writeFileSync(output,JSON.stringify({payload,signature:signature.toString('hex')})+'\n');
console.log('Signed manifest written; publish only after both artifacts are uploaded and verified.');

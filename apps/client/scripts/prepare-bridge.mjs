import { mkdir, copyFile } from 'node:fs/promises';
const destination = new URL('../src-tauri/tools/bridge/', import.meta.url);
const profile = process.argv.includes('--debug') ? 'debug' : 'release';
await mkdir(destination, { recursive: true });
await copyFile(
  new URL(`../../../target/${profile}/miarina-browser-bridge.exe`, import.meta.url),
  new URL('miarina-browser-bridge.exe', destination),
);

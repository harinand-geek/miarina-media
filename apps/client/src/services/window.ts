import { getCurrentWindow } from '@tauri-apps/api/window';
import { inTauri } from './platform';

// Window controls for the custom title bar. Outside Tauri (browser preview,
// tests) they are no-ops.

export async function minimizeWindow() {
  if (inTauri()) await getCurrentWindow().minimize();
}

export async function toggleMaximizeWindow() {
  if (inTauri()) await getCurrentWindow().toggleMaximize();
}

export async function closeWindow() {
  if (inTauri()) await getCurrentWindow().close();
}

export async function setFullscreen(on: boolean) {
  if (inTauri()) await getCurrentWindow().setFullscreen(on);
}

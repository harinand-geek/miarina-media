import { getCurrentWindow } from '@tauri-apps/api/window';
import { detectPlatform, inTauri } from './platform';

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

/**
 * Windows: the app's theme for the window, so the built-in browser pages
 * (WebView2, which takes the window theme) follow Miarina's Light / Dark
 * instead of the system one; `null` = follow the system.
 */
export async function setWindowTheme(theme: 'light' | 'dark' | null) {
  if (inTauri() && detectPlatform() !== 'android') await getCurrentWindow().setTheme(theme);
}

export async function setFullscreen(on: boolean) {
  if (inTauri()) await getCurrentWindow().setFullscreen(on);
}

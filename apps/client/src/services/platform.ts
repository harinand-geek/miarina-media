import { isTauri } from '@tauri-apps/api/core';

export type Platform = 'windows' | 'android';

/**
 * The shell is chosen by platform, not by window width, so Android never
 * gets desktop navigation. `?platform=android` previews the mobile shell in
 * a desktop browser during development.
 */
export function detectPlatform(): Platform {
  if (import.meta.env.DEV) {
    const forced = new URLSearchParams(window.location.search).get('platform');
    if (forced === 'android' || forced === 'windows') return forced;
  }
  return /android/i.test(navigator.userAgent) ? 'android' : 'windows';
}

export const inTauri = (): boolean => isTauri();

import { useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { detectPlatform, inTauri } from '../services/platform';

/**
 * Android "Share → Miarina Media": takes the link shared by another app
 * when the app starts and whenever it comes back to the foreground, and
 * hands it to `onLink` (already extracted and validated in Rust).
 */
export function useSharedLinks(onLink: (url: string) => void) {
  useEffect(() => {
    if (!inTauri() || detectPlatform() !== 'android') return;
    const take = () => {
      if (document.hidden) return;
      void invoke<string | null>('app_take_shared_link')
        .then((url) => url && onLink(url))
        .catch(() => {});
    };
    take();
    document.addEventListener('visibilitychange', take);
    return () => document.removeEventListener('visibilitychange', take);
  }, [onLink]);
}

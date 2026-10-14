import { onBackButtonPress } from '@tauri-apps/api/app';
import type { PluginListener } from '@tauri-apps/api/core';
import { useEffect, useRef } from 'react';
import { detectPlatform, inTauri } from '../services/platform';

const android = detectPlatform() === 'android';

/**
 * While `active`, Android's back button runs `handler` (close a panel,
 * return Home). Otherwise the system default applies (leave the app).
 */
export function useAndroidBack(active: boolean, handler: () => void) {
  const latest = useRef(handler);
  useEffect(() => {
    latest.current = handler;
  });
  useEffect(() => {
    if (!active || !android || !inTauri()) return;
    let listener: PluginListener | undefined;
    let closed = false;
    void onBackButtonPress(() => latest.current()).then((l) => {
      if (closed) void l.unregister();
      else listener = l;
    });
    return () => {
      closed = true;
      void listener?.unregister();
    };
  }, [active]);
}

import { useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { detectPlatform, inTauri } from '../services/platform';

/** `shell::LaunchRequest` (Rust). */
interface LaunchRequest {
  link: string | null;
  playTask: string | null;
}

/**
 * Android asks the app to open something: a link shared from another app
 * ("Share → Miarina Media", already extracted and validated in Rust) or a
 * finished download whose notification was tapped. Taken when the app
 * starts and whenever it comes back to the foreground.
 */
export function useLaunchRequests(handlers: {
  onLink: (url: string) => void;
  onPlayTask: (taskId: string) => void;
}) {
  const { onLink, onPlayTask } = handlers;
  useEffect(() => {
    if (!inTauri() || detectPlatform() !== 'android') return;
    const take = () => {
      if (document.hidden) return;
      void invoke<LaunchRequest>('app_take_launch')
        .then((request) => {
          if (request.link) onLink(request.link);
          else if (request.playTask) onPlayTask(request.playTask);
        })
        .catch(() => {});
    };
    take();
    document.addEventListener('visibilitychange', take);
    return () => document.removeEventListener('visibilitychange', take);
  }, [onLink, onPlayTask]);
}

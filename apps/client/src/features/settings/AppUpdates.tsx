import { useEffect } from 'react';
import { useUpdates } from './useUpdates';

/**
 * Looks for an update 15 s after launch and every six hours while the window
 * is visible. Downloading and installing always wait for the user (UPD-04);
 * the panels live in Settings › Updates (Windows) and Settings (Android).
 */
export function UpdateMonitor() {
  useEffect(() => {
    const check = () => {
      if (document.visibilityState === 'visible') void useUpdates.getState().check(true);
    };
    const timer = setTimeout(check, 15000);
    const interval = setInterval(check, 6 * 60 * 60 * 1000);
    return () => {
      clearTimeout(timer);
      clearInterval(interval);
    };
  }, []);
  return null;
}

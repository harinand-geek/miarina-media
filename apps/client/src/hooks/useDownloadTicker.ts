import { useEffect } from 'react';
import { isRunning, useDownloads } from '../stores/downloads';
import { RESOURCE_PROFILES, effectiveConcurrency, useSettings } from '../stores/settings';

/**
 * Drives the simulated download progress. The timer only exists while
 * something can move (no idle polling) and its period follows the resource
 * mode (Eco refreshes every 2 s).
 */
export function useDownloadTicker() {
  const intervalMs = useSettings((s) => RESOURCE_PROFILES[s.resourceMode].progressIntervalMs);
  const maxActive = useSettings(effectiveConcurrency);
  const needsTick = useDownloads((s) => {
    const running = s.tasks.filter(isRunning).length;
    return running > 0 || (s.queue.length > 0 && running < maxActive);
  });

  useEffect(() => {
    if (!needsTick) return;
    const timer = setInterval(
      () => useDownloads.getState().tick(intervalMs / 1000, maxActive),
      intervalMs,
    );
    return () => clearInterval(timer);
  }, [needsTick, intervalMs, maxActive]);
}

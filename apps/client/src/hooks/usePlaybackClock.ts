import { useCallback, useEffect, useState } from 'react';

/**
 * Simulated playback position for the Phase 1 player UI. Phase 3 replaces
 * it with the real media element (Windows) or Media3 session (Android).
 */
export function usePlaybackClock(durationSec: number, startAt = 0) {
  const [time, setTime] = useState(startAt);
  const [playing, setPlaying] = useState(true);

  useEffect(() => {
    if (!playing || durationSec <= 0) return;
    const timer = setInterval(() => setTime((t) => (t + 1) % durationSec), 1000);
    return () => clearInterval(timer);
  }, [playing, durationSec]);

  const seek = useCallback(
    (sec: number) => setTime(Math.min(Math.max(0, Math.round(sec)), Math.max(0, durationSec - 1))),
    [durationSec],
  );
  const skip = useCallback(
    (delta: number) =>
      setTime((t) => Math.min(Math.max(0, t + delta), Math.max(0, durationSec - 1))),
    [durationSec],
  );
  const toggle = useCallback(() => setPlaying((p) => !p), []);

  return { time, playing, toggle, seek, skip };
}

export function formatClock(totalSec: number, padMinutes = true) {
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = Math.floor(totalSec % 60);
  const ss = String(s).padStart(2, '0');
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${ss}`;
  return `${padMinutes ? String(m).padStart(2, '0') : m}:${ss}`;
}

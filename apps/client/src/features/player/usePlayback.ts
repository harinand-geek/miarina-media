import { useCallback, useEffect, useRef, useState } from 'react';
import { usePlaybackClock } from '../../hooks/usePlaybackClock';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';

const POSITION_KEY = (id: number) => `mm:position:${id}`;
/** Positions this close to the start or the end are not worth resuming. */
const RESUME_MARGIN_SECS = 5;

function savedPosition(id: number): number {
  try {
    return Number(localStorage.getItem(POSITION_KEY(id))) || 0;
  } catch {
    return 0;
  }
}

function savePosition(id: number, time: number, duration: number) {
  try {
    if (time < RESUME_MARGIN_SECS || duration - time < RESUME_MARGIN_SECS) {
      localStorage.removeItem(POSITION_KEY(id));
    } else {
      localStorage.setItem(POSITION_KEY(id), String(Math.floor(time)));
    }
  } catch {
    // Storage unavailable: resuming is a convenience only.
  }
}

export interface Playback {
  /** Present when the file can be streamed (desktop app). */
  src: string;
  attachMedia: (el: HTMLMediaElement | null) => void;
  time: number;
  duration: number;
  buffered: number;
  playing: boolean;
  volume: number;
  rate: number;
  /** The WebView could not decode this file. */
  error: boolean;
  toggle: () => void;
  seek: (sec: number) => void;
  skip: (delta: number) => void;
  setVolume: (v: number) => void;
  setRate: (r: number) => void;
}

/**
 * Drives a real <video>/<audio> element streamed through the asset
 * protocol (range requests, nothing loaded in memory). In the browser
 * preview there is no file: a simulated clock keeps the UI usable.
 */
export function usePlayback(media: MediaRecord): Playback {
  const src = backend.mediaUrl(media.path);
  const duration = media.durationSecs ?? 0;
  const simulated = usePlaybackClock(src ? 0 : duration, src ? 0 : savedPosition(media.id));
  const element = useRef<HTMLMediaElement | null>(null);
  const [state, setState] = useState({
    time: 0,
    duration,
    buffered: 0,
    playing: false,
    volume: 0.8,
    rate: 1,
    error: false,
  });

  const attachMedia = useCallback(
    (el: HTMLMediaElement | null) => {
      element.current = el;
      if (!el) return;
      const sync = () =>
        setState((s) => ({
          ...s,
          time: el.currentTime,
          duration: Number.isFinite(el.duration) ? el.duration : s.duration,
          buffered: el.buffered.length ? el.buffered.end(el.buffered.length - 1) : 0,
          playing: !el.paused && !el.ended,
          volume: el.volume,
          rate: el.playbackRate,
        }));
      const start = () => {
        const resume = savedPosition(media.id);
        if (resume > 0 && resume < el.duration - RESUME_MARGIN_SECS) el.currentTime = resume;
        void el.play().catch(() => sync());
        sync();
      };
      el.onloadedmetadata = start;
      el.ontimeupdate = sync;
      el.onprogress = sync;
      el.onplay = sync;
      el.onpause = () => {
        savePosition(media.id, el.currentTime, el.duration);
        sync();
      };
      el.onended = () => {
        savePosition(media.id, 0, el.duration);
        sync();
      };
      el.onvolumechange = sync;
      el.onratechange = sync;
      el.onerror = () => setState((s) => ({ ...s, error: true, playing: false }));
      // React creates the element during render: it may have loaded its
      // metadata before this ref ran (e.g. while the lazy screen committed).
      if (el.readyState >= HTMLMediaElement.HAVE_METADATA) start();
    },
    [media.id],
  );

  // Remember the position when leaving the player.
  useEffect(
    () => () => {
      const el = element.current;
      if (el && Number.isFinite(el.duration)) savePosition(media.id, el.currentTime, el.duration);
    },
    [media.id],
  );

  if (!src) {
    return {
      src,
      attachMedia: () => {},
      time: simulated.time,
      duration,
      buffered: Math.min(duration, simulated.time + duration * 0.18),
      playing: simulated.playing,
      volume: state.volume,
      rate: state.rate,
      error: false,
      toggle: simulated.toggle,
      seek: simulated.seek,
      skip: simulated.skip,
      setVolume: (volume) => setState((s) => ({ ...s, volume })),
      setRate: (rate) => setState((s) => ({ ...s, rate })),
    };
  }

  // Actions read the element when they run, never during render.
  const current = () => element.current;
  return {
    src,
    attachMedia,
    ...state,
    toggle: () => {
      const el = current();
      if (!el) return;
      if (el.paused) void el.play().catch(() => {});
      else el.pause();
    },
    seek: (sec) => {
      const el = current();
      if (el) el.currentTime = Math.min(Math.max(0, sec), state.duration || sec);
    },
    skip: (delta) => {
      const el = current();
      if (el) el.currentTime = Math.min(Math.max(0, el.currentTime + delta), state.duration);
    },
    setVolume: (v) => {
      const el = current();
      if (el) el.volume = Math.min(1, Math.max(0, v));
    },
    setRate: (r) => {
      const el = current();
      if (el) el.playbackRate = r;
    },
  };
}

import { useCallback, useEffect, useRef, useState } from 'react';
import { nativePlayer, type NativePlayerStatus } from '../../services/nativePlayer';
import type { MediaRecord } from '../../services/types';
import { RESUME_MARGIN_SECS, savePosition, savedPosition, type Playback } from './usePlayback';

/** How often the screen reads the native position (only while open and visible). */
const POLL_MS = 250;

export type NativePlayback = Playback & {
  /** The element whose box the native video is drawn into. */
  attachSurface: (el: HTMLElement | null) => void;
};

/**
 * Android: same contract as `usePlayback`, backed by Media3 through Rust.
 * The screen keeps its approved React controls; the native player decodes
 * and, for video, draws into the area of the element given to
 * `attachSurface`.
 */
export function useNativePlayback(media: MediaRecord): NativePlayback {
  const [state, setState] = useState({
    time: 0,
    duration: media.durationSecs ?? 0,
    buffered: 0,
    playing: false,
    rate: 1,
    error: false,
  });
  const ready = useRef(false);
  const video = useRef(false);
  const surface = useRef<HTMLElement | null>(null);
  const last = useRef<NativePlayerStatus | null>(null);

  /** Sends the current box of the surface element to the native view. */
  const pushSurface = useCallback(() => {
    if (!ready.current || !video.current) return;
    const el = surface.current;
    const box = el?.getBoundingClientRect();
    void nativePlayer
      .setSurface({
        x: box?.left ?? 0,
        y: box?.top ?? 0,
        width: box?.width ?? 0,
        height: box?.height ?? 0,
        visible: !!el && !document.hidden,
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    let closed = false;
    let timer: ReturnType<typeof setInterval> | undefined;
    let inFlight = false;

    const apply = (s: NativePlayerStatus) => {
      last.current = s;
      setState((prev) => ({
        ...prev,
        time: s.positionMs / 1000,
        duration: s.durationMs > 0 ? s.durationMs / 1000 : prev.duration,
        buffered: s.bufferedMs / 1000,
        playing: s.playing,
        rate: s.rate || prev.rate,
        error: prev.error || !!s.error,
      }));
    };

    const poll = () => {
      if (inFlight || document.hidden) return;
      inFlight = true;
      nativePlayer
        .status()
        .then((s) => {
          if (!closed && s.open) apply(s);
        })
        .catch(() => {})
        .finally(() => {
          inFlight = false;
        });
    };

    const saved = savedPosition(media.id);
    const duration = media.durationSecs ?? 0;
    const resume = saved > 0 && (!duration || saved < duration - RESUME_MARGIN_SECS) ? saved : 0;
    nativePlayer
      .open(media.id, resume)
      .then((isVideo) => {
        if (closed) {
          void nativePlayer.close().catch(() => {});
          return;
        }
        ready.current = true;
        video.current = isVideo;
        pushSurface();
        timer = setInterval(poll, POLL_MS);
      })
      .catch(() => setState((s) => ({ ...s, error: true })));

    const onVisibility = () => pushSurface();
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('resize', pushSurface);
    // The player slides in (CSS transform): a box measured mid-animation is
    // offset, and transforms do not trigger ResizeObserver.
    document.addEventListener('animationend', pushSurface, true);
    document.addEventListener('transitionend', pushSurface, true);

    return () => {
      closed = true;
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('resize', pushSurface);
      document.removeEventListener('animationend', pushSurface, true);
      document.removeEventListener('transitionend', pushSurface, true);
      if (!ready.current) return;
      ready.current = false;
      nativePlayer
        .close()
        .then((s) => {
          if (s.durationMs > 0) savePosition(media.id, s.positionMs / 1000, s.durationMs / 1000);
        })
        .catch(() => {});
    };
  }, [media.id, media.durationSecs, pushSurface]);

  const attachSurface = useCallback(
    (el: HTMLElement | null) => {
      surface.current = el;
      pushSurface();
      if (!el || typeof ResizeObserver === 'undefined') return;
      const observer = new ResizeObserver(() => pushSurface());
      observer.observe(el);
      return () => observer.disconnect();
    },
    [pushSurface],
  );

  const seek = (sec: number) => {
    const target = Math.max(0, state.duration ? Math.min(sec, state.duration) : sec);
    setState((s) => ({ ...s, time: target }));
    void nativePlayer.seek(target).catch(() => {});
  };

  return {
    src: 'native',
    attachMedia: () => {},
    attachSurface,
    ...state,
    volume: 1,
    toggle: () => {
      if (state.playing) {
        setState((s) => ({ ...s, playing: false }));
        void nativePlayer.pause().catch(() => {});
        if (state.duration) savePosition(media.id, state.time, state.duration);
      } else {
        setState((s) => ({ ...s, playing: true }));
        void nativePlayer.play().catch(() => {});
      }
    },
    seek,
    skip: (delta) => seek(state.time + delta),
    // Volume follows the device buttons on Android.
    setVolume: () => {},
    setRate: (rate) => {
      setState((s) => ({ ...s, rate }));
      void nativePlayer.setRate(rate).catch(() => {});
    },
  };
}

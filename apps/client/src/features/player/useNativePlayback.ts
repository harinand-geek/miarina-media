import { useCallback, useEffect, useRef, useState } from 'react';
import { nativePlayer, type NativePlayerStatus } from '../../services/nativePlayer';
import type { MediaRecord } from '../../services/types';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import { useUi } from '../../stores/ui';
import { t } from '../../i18n';
import { RESUME_MARGIN_SECS, savePosition, savedPosition, type Playback } from './usePlayback';

/** How often the screen reads the native position (only while visible). */
const POLL_MS = 250;
/** How long a UI skip may wait for the service to confirm it. */
const PENDING_MS = 2000;

export type NativePlayback = Playback & {
  /** The element whose box the native video is drawn into. */
  attachSurface: (el: HTMLElement | null) => void;
};

const kindOf = (id: number) =>
  useMobilePlayback.getState().queue.find((m) => m.id === id)?.kind ?? null;

/**
 * Android (CDC L03): one native session per play queue. The queue is handed
 * to the Media3 MediaSessionService, which keeps playing with the screen off
 * and moves to the next track by itself; this hook follows it (the current
 * item comes back through the status) and forwards what the UI changes:
 * track, queue order, repeat mode. Same contract as `usePlayback` otherwise.
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
  const video = useRef(media.kind === 'video');
  const surface = useRef<HTMLElement | null>(null);
  const last = useRef<NativePlayerStatus | null>(null);
  /** Item the native player is on, as far as this screen knows. */
  const currentId = useRef(media.id);
  /** UI-requested track not yet confirmed by the service, and since when. */
  const pending = useRef<{ id: number; at: number } | null>(null);
  const first = useRef(media);

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

  // The session: opened once for the queue, closed when the player closes.
  useEffect(() => {
    let closed = false;
    let timer: ReturnType<typeof setInterval> | undefined;
    let inFlight = false;

    const apply = (s: NativePlayerStatus) => {
      last.current = s;
      // A status read before a UI skip still names the previous track.
      if (pending.current) {
        if (s.mediaId === pending.current.id || Date.now() - pending.current.at > PENDING_MS) {
          pending.current = null;
        } else {
          return;
        }
      }
      if (s.mediaId != null && s.mediaId !== currentId.current) {
        // The service moved on (end of track, lock screen, Bluetooth button).
        savePosition(currentId.current, 0, 0);
        currentId.current = s.mediaId;
        video.current = kindOf(s.mediaId) === 'video';
        const store = useMobilePlayback.getState();
        store.syncFromNative(s.mediaId);
        if (store.sleep.mode === 'end') {
          void nativePlayer.pause().catch(() => {});
          store.setSleep('off');
          useUi.getState().pushToast({ tone: 'success', message: t('sleepStopped') });
        }
      }
      setState((prev) => ({
        ...prev,
        time: s.positionMs / 1000,
        duration: s.durationMs > 0 ? s.durationMs / 1000 : prev.duration,
        buffered: s.bufferedMs / 1000,
        playing: s.playing,
        rate: s.rate || prev.rate,
        error: !!s.error,
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

    const start = first.current;
    const store = useMobilePlayback.getState();
    const ids = store.queue.some((m) => m.id === start.id) ? store.queue.map((m) => m.id) : [start.id];
    const saved = savedPosition(start.id);
    const duration = start.durationSecs ?? 0;
    const resume = saved > 0 && (!duration || saved < duration - RESUME_MARGIN_SECS) ? saved : 0;
    nativePlayer
      .open(ids, Math.max(0, ids.indexOf(start.id)), resume)
      .then((isVideo) => {
        if (closed) {
          void nativePlayer.close().catch(() => {});
          return;
        }
        ready.current = true;
        video.current = isVideo;
        void nativePlayer.setRepeat(useMobilePlayback.getState().repeat).catch(() => {});
        pushSurface();
        timer = setInterval(poll, POLL_MS);
      })
      .catch(() => setState((s) => ({ ...s, error: true })));

    // Queue order and repeat mode follow the UI (same session only).
    const stop = useMobilePlayback.subscribe((s, prev) => {
      if (!ready.current || s.session !== prev.session) return;
      if (s.queue !== prev.queue) {
        const at = s.queue.findIndex((m) => m.id === currentId.current);
        if (at >= 0) void nativePlayer.setQueue(s.queue.map((m) => m.id), at).catch(() => {});
      }
      if (s.repeat !== prev.repeat) void nativePlayer.setRepeat(s.repeat).catch(() => {});
    });

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
      stop();
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('resize', pushSurface);
      document.removeEventListener('animationend', pushSurface, true);
      document.removeEventListener('transitionend', pushSurface, true);
      if (!ready.current) return;
      ready.current = false;
      const id = currentId.current;
      nativePlayer
        .close()
        .then((s) => {
          if (s.durationMs > 0) savePosition(id, s.positionMs / 1000, s.durationMs / 1000);
        })
        .catch(() => {});
    };
  }, [pushSurface]);

  // The UI picked another track of the queue (next, previous, queue sheet).
  useEffect(() => {
    if (!ready.current || media.id === currentId.current) return;
    const at = useMobilePlayback.getState().queue.findIndex((m) => m.id === media.id);
    if (at < 0) return;
    const s = last.current;
    if (s && s.durationMs > 0) savePosition(currentId.current, s.positionMs / 1000, s.durationMs / 1000);
    currentId.current = media.id;
    pending.current = { id: media.id, at: Date.now() };
    video.current = media.kind === 'video';
    void nativePlayer.skip(at).catch(() => {});
  }, [media.id, media.kind]);

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
        if (state.duration) savePosition(currentId.current, state.time, state.duration);
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

import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react';
import { backend } from '../../services/backend';
import {
  bindEngine,
  reportEnded,
  reportEngine,
  swapEngine,
  usePlayer,
  type EngineReport,
  type PlayerEngine,
  type PlayerError,
} from '../../stores/player';
import { useUi } from '../../stores/ui';
import { useEqualizer } from './equalizer';
import { createNativeEngine } from './nativeEngine';
import { RESUME_MARGIN_SECS, savePosition } from './usePlayback';

/** Kept in the DOM but out of sight while no screen shows the picture. */
const HIDDEN: CSSProperties = {
  position: 'absolute',
  left: 0,
  top: 0,
  width: 1,
  height: 1,
  opacity: 0,
  pointerEvents: 'none',
};

function errorKind(code: number | undefined): PlayerError['kind'] {
  switch (code) {
    case 1:
      return 'aborted';
    case 2:
      return 'read';
    case 3:
      return 'decode';
    case 4:
      return 'unsupported';
    default:
      return 'unknown';
  }
}

/**
 * The desktop playback engine, mounted once by the shell so playback
 * continues across screens without restart or double sound (COM-05). The
 * video screen registers a surface element; the picture is placed over it.
 *
 * Windows with libVLC shipped (decision 0005): libVLC plays, its picture is
 * a native window placed over the surface (hidden while a dialog covers
 * it). Otherwise a single media element streams through the asset protocol
 * (range requests, nothing buffered in memory); without a file (browser
 * preview) a simulated clock keeps the UI usable.
 */
export function PlayerHost() {
  const ref = useRef<HTMLVideoElement>(null);
  const kind = usePlayer((s) => s.media?.kind);
  const surface = usePlayer((s) => s.surface);
  const nativeVideo = usePlayer((s) => s.nativeVideo);
  const failed = usePlayer((s) => s.state === 'error');
  const covered = useUi((s) => !!s.confirm || !!s.tagEditor || !!s.removal || !!s.playlistDialog);
  const [box, setBox] = useState<CSSProperties | null>(null);
  const showPicture = !!surface && kind === 'video';

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let instance = 0;
    /** Set between `load` and `loadedmetadata`. */
    let pending: { startAt: number; autoplay: boolean } | null = null;
    let simulated = false;
    let simTimer: ReturnType<typeof setInterval> | undefined;
    let simPos = 0;
    let simDur = 0;
    let simRate = 1;

    const report = (r: EngineReport) => reportEngine(instance, r);
    const finite = (n: number) => (Number.isFinite(n) ? n : null);

    const simHalt = () => {
      clearInterval(simTimer);
      simTimer = undefined;
    };
    const simPlay = () => {
      simHalt();
      simTimer = setInterval(() => {
        simPos = Math.min(simDur, simPos + simRate);
        report({ position: simPos });
        if (simDur > 0 && simPos >= simDur) {
          simHalt();
          reportEnded(instance);
        }
      }, 1000);
      report({ state: 'playing' });
    };

    const onMetadata = () => {
      const duration = finite(el.duration);
      if (duration != null) report({ duration });
      if (!pending) return;
      const { startAt, autoplay } = pending;
      pending = null;
      if (startAt > 0 && (duration == null || startAt < duration - RESUME_MARGIN_SECS)) {
        el.currentTime = startAt;
      }
      if (autoplay) void el.play().catch(() => report({ state: 'paused' }));
      else report({ state: 'ready' });
    };
    const onTime = () => report({ position: el.currentTime });
    const onProgress = () =>
      report({ buffered: el.buffered.length ? el.buffered.end(el.buffered.length - 1) : 0 });
    const onPlaying = () => report({ state: 'playing', error: null });
    const onWaiting = () => {
      if (!pending) report({ state: 'buffering' });
    };
    const onPause = () => {
      // Changing the source pauses the previous media: not a user pause.
      if (!pending && !el.ended) report({ state: 'paused', position: el.currentTime });
    };
    const onEnded = () => reportEnded(instance);
    const onError = () => {
      if (!el.getAttribute('src')) return;
      pending = null;
      report({ state: 'error', error: { kind: errorKind(el.error?.code) } });
    };

    el.addEventListener('loadedmetadata', onMetadata);
    el.addEventListener('timeupdate', onTime);
    el.addEventListener('progress', onProgress);
    el.addEventListener('playing', onPlaying);
    el.addEventListener('waiting', onWaiting);
    el.addEventListener('pause', onPause);
    el.addEventListener('ended', onEnded);
    el.addEventListener('error', onError);

    const engine: PlayerEngine = {
      load: (media, inst, startAt, autoplay) => {
        instance = inst;
        simHalt();
        const src = backend.mediaUrl(media.path);
        simulated = !src;
        if (simulated) {
          pending = null;
          el.removeAttribute('src');
          simDur = media.durationSecs ?? 0;
          simPos = startAt;
          report({ duration: simDur, position: simPos });
          if (autoplay) simPlay();
          else report({ state: 'ready' });
          return;
        }
        pending = { startAt, autoplay };
        el.src = src;
        el.load();
      },
      play: () => {
        if (simulated) simPlay();
        else void el.play().catch(() => report({ state: 'paused' }));
      },
      pause: () => {
        if (simulated) {
          simHalt();
          report({ state: 'paused', position: simPos });
        } else el.pause();
      },
      seek: (secs) => {
        if (simulated) {
          simPos = secs;
          report({ position: secs });
        } else el.currentTime = secs;
      },
      setVolume: (volume, muted) => {
        el.volume = volume;
        el.muted = muted;
      },
      setRate: (rate) => {
        simRate = rate;
        el.defaultPlaybackRate = rate;
        el.playbackRate = rate;
      },
      stop: () => {
        simHalt();
        pending = null;
        // Late events of the released file must not reach the store.
        instance = -1;
        el.pause();
        el.removeAttribute('src');
        el.load();
      },
    };
    let unbind = bindEngine(engine);
    // libVLC when shipped (Windows); it takes over a file already loaded.
    let native: ReturnType<typeof createNativeEngine> | null = null;
    let alive = true;
    void backend
      .nativePlayerStatus()
      .then((status) => {
        if (!alive || !status.available) return;
        native = createNativeEngine();
        unbind();
        unbind = swapEngine(engine, native.engine);
        useEqualizer.getState().push();
      })
      .catch(() => {});

    const keep = () => {
      const s = usePlayer.getState();
      if (s.media && s.duration > 0 && s.state !== 'idle') {
        savePosition(s.media.id, s.position, s.duration);
      }
    };
    window.addEventListener('pagehide', keep);

    return () => {
      alive = false;
      keep();
      unbind();
      native?.engine.stop();
      native?.dispose();
      simHalt();
      window.removeEventListener('pagehide', keep);
      el.removeEventListener('loadedmetadata', onMetadata);
      el.removeEventListener('timeupdate', onTime);
      el.removeEventListener('progress', onProgress);
      el.removeEventListener('playing', onPlaying);
      el.removeEventListener('waiting', onWaiting);
      el.removeEventListener('pause', onPause);
      el.removeEventListener('ended', onEnded);
      el.removeEventListener('error', onError);
      el.pause();
    };
  }, []);

  // Native picture: a window placed over the surface (window coordinates).
  useLayoutEffect(() => {
    if (!nativeVideo) return;
    const visible = showPicture && !covered && !failed;
    if (!visible || !surface) {
      void backend.nativePlayerFrame({ x: 0, y: 0, width: 0, height: 0 }, false).catch(() => {});
      return;
    }
    const place = () => {
      const r = surface.getBoundingClientRect();
      void backend
        .nativePlayerFrame({ x: r.left, y: r.top, width: r.width, height: r.height }, true)
        .catch(() => {});
    };
    place();
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(place);
    observer?.observe(surface);
    window.addEventListener('resize', place);
    document.addEventListener('animationend', place, true);
    return () => {
      observer?.disconnect();
      window.removeEventListener('resize', place);
      document.removeEventListener('animationend', place, true);
    };
  }, [nativeVideo, showPicture, surface, covered, failed]);

  // Place the picture over the video screen's surface.
  useLayoutEffect(() => {
    const el = ref.current;
    const parent = el?.parentElement;
    if (nativeVideo || !showPicture || !surface || !el || !parent) {
      setBox(null);
      return;
    }
    const measure = () => {
      const p = parent.getBoundingClientRect();
      const r = surface.getBoundingClientRect();
      setBox({
        position: 'absolute',
        left: r.left - p.left,
        top: r.top - p.top,
        width: r.width,
        height: r.height,
      });
    };
    measure();
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(measure);
    observer?.observe(surface);
    observer?.observe(parent);
    window.addEventListener('resize', measure);
    // The screen enters with an 8 px rise: measure again once it settles.
    document.addEventListener('animationend', measure, true);
    return () => {
      observer?.disconnect();
      window.removeEventListener('resize', measure);
      document.removeEventListener('animationend', measure, true);
    };
  }, [showPicture, surface, nativeVideo]);

  return (
    <video
      ref={ref}
      preload="metadata"
      playsInline
      aria-hidden="true"
      tabIndex={-1}
      data-testid="player-engine"
      className="bg-player object-contain"
      style={box ? { ...box, pointerEvents: 'none' } : HIDDEN}
    />
  );
}

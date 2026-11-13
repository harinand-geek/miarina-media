import { useCallback, useEffect, useRef, useState, type PointerEvent } from 'react';
import { createPortal } from 'react-dom';
import { Icon } from '../../components/Icon';
import { useAndroidBack } from '../../hooks/useAndroidBack';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useT } from '../../i18n';
import { nativePlayer, type NativeTracks } from '../../services/nativePlayer';
import type { MediaRecord } from '../../services/types';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { durationLabel, formatLabel } from '../library/format';
import { rateLabel } from './playbackRate';
import { SeekBar } from './SeekBar';

const RATES = [0.5, 0.75, 1, 1.25, 1.5, 2];

/** Label, else language ("und" = undetermined in Media3), else `fallback`. */
const trackName = (track: { label: string | null; language: string | null }, fallback: string) =>
  track.label ?? (track.language && track.language !== 'und' ? track.language : fallback);
const HIDE_AFTER_MS = 3000;
const DOUBLE_TAP_MS = 300;

/** Controls of the native player, as given by `useNativePlayback`. */
interface Controls {
  time: number;
  duration: number;
  playing: boolean;
  rate: number;
  toggle: () => void;
  seek: (secs: number) => void;
}

type Gesture = {
  kind: 'brightness' | 'volume';
  x: number;
  y: number;
  base: number | null;
  dragging: boolean;
};

/**
 * Android v2 screen 13 (AND-07/08/13/14): the picture fills the screen in
 * landscape, drawn natively behind the transparent page; these controls sit
 * over it. Tap shows / hides them, left / right vertical drags set the
 * brightness / volume, a double tap seeks ±10 s, the lock leaves only its
 * own button.
 */
export function MobileVideoFullscreen({
  item,
  p,
  onExit,
}: {
  item: MediaRecord;
  p: Controls;
  onExit: () => void;
}) {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const gesturesOn = useSettings((s) => s.videoGestures);
  const [visible, setVisible] = useState(true);
  const [locked, setLocked] = useState(false);
  const [panel, setPanel] = useState(false);
  const [landscape, setLandscape] = useState(true);
  const [pip, setPip] = useState(false);
  const [pipSupported, setPipSupported] = useState(false);
  const [tracks, setTracks] = useState<NativeTracks | null>(null);
  const [indicator, setIndicator] = useState<{ kind: Gesture['kind']; value: number } | null>(null);
  const [skipHint, setSkipHint] = useState<'back' | 'forward' | null>(null);
  const gesture = useRef<Gesture | null>(null);
  const lastTap = useRef<{ at: number; side: 'back' | 'forward' } | null>(null);
  const latest = useRef(p);
  useEffect(() => {
    latest.current = p;
  });

  // Native fullscreen for the life of this screen; the page becomes
  // transparent so the picture behind it shows (index.css).
  useEffect(() => {
    document.documentElement.dataset.videoFullscreen = '';
    return () => {
      delete document.documentElement.dataset.videoFullscreen;
      void nativePlayer.fullscreen(false).catch(() => {});
      // The portrait surface box is measured again.
      setTimeout(() => window.dispatchEvent(new Event('resize')), 300);
    };
  }, []);
  useEffect(() => {
    void nativePlayer.fullscreen(true, landscape).catch(() => {});
  }, [landscape]);

  useEffect(() => {
    void nativePlayer
      .pip(false)
      .then(setPipSupported)
      .catch(() => {});
    let listener: { unregister: () => Promise<void> } | undefined;
    let closed = false;
    void nativePlayer
      .onPip(setPip)
      .then((l) => {
        if (closed) void l.unregister();
        else listener = l;
      })
      .catch(() => {});
    return () => {
      closed = true;
      void listener?.unregister();
    };
  }, []);

  const loadTracks = useCallback(() => {
    void nativePlayer
      .tracks()
      .then(setTracks)
      .catch(() => {});
  }, []);
  // Tracks are known once the file is prepared.
  const known = (tracks?.audio.length ?? 0) > 0;
  useEffect(() => {
    if (known) return;
    loadTracks();
    const timer = setInterval(loadTracks, 1000);
    return () => clearInterval(timer);
  }, [known, loadTracks]);

  // Controls hide after a while during playback.
  useEffect(() => {
    if (!visible || panel || !p.playing) return;
    const timer = setTimeout(() => setVisible(false), HIDE_AFTER_MS);
    return () => clearTimeout(timer);
  }, [visible, panel, p.playing, p.time]);

  useAndroidBack(true, () => {
    if (panel) setPanel(false);
    else onExit();
  });

  const skip = (side: 'back' | 'forward') => {
    const { time, duration, seek } = latest.current;
    seek(Math.max(0, Math.min(duration || Infinity, time + (side === 'back' ? -10 : 10))));
    setSkipHint(side);
    setTimeout(() => setSkipHint(null), 600);
  };

  const onPointerDown = (e: PointerEvent<HTMLDivElement>) => {
    if (locked) return;
    const box = e.currentTarget.getBoundingClientRect();
    const kind = e.clientX - box.left < box.width / 2 ? 'brightness' : 'volume';
    const g: Gesture = { kind, x: e.clientX, y: e.clientY, base: null, dragging: false };
    gesture.current = g;
    if (gesturesOn) {
      void nativePlayer
        .level(kind)
        .then((v) => {
          if (gesture.current === g) g.base = v;
        })
        .catch(() => {});
    }
  };
  const onPointerMove = (e: PointerEvent<HTMLDivElement>) => {
    const g = gesture.current;
    if (!g || !gesturesOn || g.base == null) return;
    const dy = e.clientY - g.y;
    if (!g.dragging && Math.abs(dy) < 12) return;
    g.dragging = true;
    const height = e.currentTarget.getBoundingClientRect().height || 1;
    const value = Math.max(0, Math.min(1, g.base - dy / (height * 0.8)));
    setIndicator({ kind: g.kind, value });
    void nativePlayer.level(g.kind, value).catch(() => {});
  };
  const onPointerUp = (e: PointerEvent<HTMLDivElement>) => {
    const g = gesture.current;
    gesture.current = null;
    if (g?.dragging) {
      setTimeout(() => setIndicator(null), 600);
      return;
    }
    if (locked) {
      setVisible((v) => !v);
      return;
    }
    const box = e.currentTarget.getBoundingClientRect();
    const side = e.clientX - box.left < box.width / 2 ? 'back' : 'forward';
    const now = Date.now();
    if (gesturesOn && lastTap.current && now - lastTap.current.at < DOUBLE_TAP_MS) {
      lastTap.current = null;
      skip(side);
      return;
    }
    lastTap.current = { at: now, side };
    setVisible((v) => !v);
  };

  const selectTrack = (kind: 'audio' | 'text', id: string | null) => {
    void nativePlayer
      .selectTrack(kind, id)
      .then(() => setTimeout(loadTracks, 300))
      .catch(() => {});
  };
  const addSubtitle = () => {
    void nativePlayer
      .pickSubtitle()
      .then((r) => {
        if (r.added) {
          useUi.getState().pushToast({ tone: 'success', message: t('subtitleAdded') });
          setTimeout(loadTracks, 800);
        }
      })
      .catch(() =>
        useUi.getState().pushToast({ tone: 'error', message: t('subtitleUnsupported') }),
      );
  };
  const cycleRate = () => {
    const at = RATES.indexOf(p.rate);
    const next = RATES[(at + 1) % RATES.length] ?? 1;
    useMobilePlayback.getState().setRate(next);
  };

  const subtitle = tracks?.text.find((x) => x.selected);
  const info = [
    // Container only: the codecs come from the tracks below.
    formatLabel(item).split(' · ')[0],
    tracks?.video,
    tracks?.sound,
    tracks && tracks.audio.length > 1 ? t('fsAudioCount', { n: tracks.audio.length }) : null,
    tracks?.text.length ? t('fsSubtitleCount', { n: tracks.text.length }) : null,
  ]
    .filter(Boolean)
    .join(' · ');
  const show = visible && !pip;

  return createPortal(
    <div
      className="fixed inset-0 z-[60] select-none overflow-hidden text-[#F5F7FA]"
      data-testid="video-fullscreen"
    >
      {/* Gesture layer, under the controls. */}
      <div
        className="absolute inset-0 touch-none"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={() => (gesture.current = null)}
        aria-hidden="true"
      />

      {indicator && !pip && (
        <div
          className={`pointer-events-none absolute top-1/2 flex -translate-y-1/2 flex-col items-center gap-2 ${
            indicator.kind === 'brightness' ? 'left-8' : 'right-8'
          }`}
          role="status"
          aria-label={`${indicator.kind === 'brightness' ? t('fsBrightness') : t('volume')} ${Math.round(indicator.value * 100)} %`}
        >
          <Icon name={indicator.kind === 'brightness' ? 'light_mode' : 'volume_up'} size={22} />
          <span className="relative h-24 w-1 overflow-hidden rounded-full bg-white/25">
            <span
              className="absolute inset-x-0 bottom-0 bg-[#F5F7FA]"
              style={{ height: `${indicator.value * 100}%` }}
            />
          </span>
          <span className="font-mono text-[12px]">{Math.round(indicator.value * 100)}</span>
        </div>
      )}
      {skipHint && !pip && (
        <span
          className={`pointer-events-none absolute top-1/2 -translate-y-1/2 rounded-full bg-black/55 px-3 py-2 font-mono text-[13px] font-bold ${
            skipHint === 'back' ? 'left-[22%]' : 'right-[22%]'
          }`}
        >
          {skipHint === 'back' ? '−10 s' : '+10 s'}
        </span>
      )}

      {show && locked && (
        <button
          type="button"
          aria-label={t('fsUnlock')}
          onClick={() => setLocked(false)}
          className="absolute bottom-5 left-1/2 grid h-12 w-12 -translate-x-1/2 place-items-center rounded-full bg-black/55"
        >
          <Icon name="lock" size={24} />
        </button>
      )}

      {show && !locked && (
        <>
          <header className="absolute inset-x-0 top-0 flex h-24 items-start gap-2 bg-gradient-to-b from-black/75 to-transparent px-3 pt-3">
            <button
              type="button"
              aria-label={t('fsExit')}
              onClick={onExit}
              className="grid h-11 w-11 shrink-0 place-items-center"
            >
              <Icon name="arrow_back" size={24} />
            </button>
            <div className="flex min-w-0 flex-1 flex-col gap-0.5 pt-1.5">
              <span className="truncate text-[16px] font-bold">{item.title}</span>
              {info && (
                <span className="truncate font-mono text-[11px] text-[#CBD5E1]">{info}</span>
              )}
            </div>
            {pipSupported && (
              <button
                type="button"
                aria-label={t('pip')}
                onClick={() => void nativePlayer.pip(true).catch(() => {})}
                className="grid h-11 w-11 shrink-0 place-items-center"
              >
                <Icon name="picture_in_picture_alt" size={24} />
              </button>
            )}
            <button
              type="button"
              aria-label={t('fsRotate')}
              onClick={() => setLandscape((l) => !l)}
              className="grid h-11 w-11 shrink-0 place-items-center"
            >
              <Icon name="screen_rotation" size={24} />
            </button>
          </header>

          <div className="pointer-events-none absolute inset-0 flex items-center justify-center gap-12">
            <button
              type="button"
              aria-label={t('back10')}
              onClick={() => skip('back')}
              className="pointer-events-auto grid h-14 w-14 place-items-center rounded-full bg-black/35"
            >
              <Icon name="replay_10" size={32} />
            </button>
            <button
              type="button"
              aria-label={p.playing ? t('pause') : t('play')}
              onClick={p.toggle}
              className="pointer-events-auto grid h-[68px] w-[68px] place-items-center rounded-full bg-coral text-coral-ink"
            >
              <Icon name={p.playing ? 'pause' : 'play_arrow'} size={38} fill />
            </button>
            <button
              type="button"
              aria-label={t('forward10')}
              onClick={() => skip('forward')}
              className="pointer-events-auto grid h-14 w-14 place-items-center rounded-full bg-black/35"
            >
              <Icon name="forward_10" size={32} />
            </button>
          </div>

          <footer className="absolute inset-x-0 bottom-0 flex flex-col gap-1 bg-gradient-to-t from-black/75 to-transparent px-4 pb-2 pt-8">
            <div className="flex items-center gap-3">
              <span className="w-14 shrink-0 font-mono text-[12px] tabular">
                {formatClock(p.time, false)}
              </span>
              <div className="min-w-0 flex-1">
                <SeekBar
                  time={p.time}
                  duration={p.duration}
                  onSeek={p.seek}
                  thumbSize={12}
                  hitHeight={24}
                  halo={false}
                  tone="coral"
                  label={t('seek')}
                />
              </div>
              <span className="w-14 shrink-0 text-right font-mono text-[12px] tabular">
                {durationLabel(p.duration || null)}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                aria-label={t('fsLock')}
                onClick={() => setLocked(true)}
                className="grid h-10 w-10 place-items-center"
              >
                <Icon name="lock_open" size={22} />
              </button>
              <span className="flex-1" />
              <button
                type="button"
                aria-label={t('tracksTitle')}
                aria-expanded={panel}
                onClick={() => setPanel(true)}
                className={`flex h-8 items-center gap-1 rounded-full px-3 font-mono text-[12px] font-bold ${
                  subtitle ? 'bg-coral/20 text-coral-strong' : 'bg-white/10'
                }`}
              >
                <Icon name="closed_caption" size={18} />
                {(subtitle?.language && subtitle.language !== 'und'
                  ? subtitle.language.slice(0, 2).toUpperCase()
                  : null) ?? (subtitle ? 'CC' : t('subtitlesOff'))}
              </button>
              <button
                type="button"
                aria-label={`${t('speed')} ${rateLabel(p.rate, lang)}`}
                onClick={cycleRate}
                className="h-8 rounded-full bg-white/10 px-3 font-mono text-[12px] font-bold"
              >
                {rateLabel(p.rate, lang)}
              </button>
            </div>
          </footer>
        </>
      )}

      {panel && !pip && (
        <aside
          aria-label={t('tracksTitle')}
          className="absolute inset-y-0 right-0 flex w-[340px] max-w-[80vw] flex-col gap-1 overflow-auto bg-[rgba(24,37,48,0.96)] px-5 py-4"
        >
          <div className="flex items-center justify-between pb-2">
            <span className="text-[15px] font-bold">{t('tracksTitle')}</span>
            <button
              type="button"
              aria-label={t('close')}
              onClick={() => setPanel(false)}
              className="grid h-10 w-10 place-items-center"
            >
              <Icon name="close" size={22} />
            </button>
          </div>
          <span className="pt-1 text-[11px] font-bold tracking-[0.06em] text-[#94A3B8]">
            {t('audioTracks').toUpperCase()}
          </span>
          {(tracks?.audio ?? []).map((a) => (
            <button
              key={a.id}
              type="button"
              aria-pressed={a.selected}
              onClick={() => selectTrack('audio', a.id)}
              className="flex h-12 items-center gap-3 text-left text-[14px]"
            >
              <Icon
                name="check"
                size={20}
                className={a.selected ? 'text-accent' : 'text-transparent'}
              />
              <span className="min-w-0 flex-1 truncate">{trackName(a, t('trackUnnamed'))}</span>
              {a.codec && <span className="font-mono text-[12px] text-[#94A3B8]">{a.codec}</span>}
            </button>
          ))}
          {tracks && tracks.audio.length === 0 && (
            <span className="py-2 text-[13px] text-[#94A3B8]">{t('noAudioTrack')}</span>
          )}
          <span className="pt-4 text-[11px] font-bold tracking-[0.06em] text-[#94A3B8]">
            {t('subtitles').toUpperCase()}
          </span>
          <button
            type="button"
            aria-pressed={!subtitle}
            onClick={() => selectTrack('text', null)}
            className="flex h-12 items-center gap-3 text-left text-[14px]"
          >
            <Icon
              name="check"
              size={20}
              className={!subtitle ? 'text-accent' : 'text-transparent'}
            />
            {t('subtitlesOff')}
          </button>
          {(tracks?.text ?? []).map((s) => (
            <button
              key={s.id}
              type="button"
              aria-pressed={s.selected}
              onClick={() => selectTrack('text', s.id)}
              className="flex h-12 items-center gap-3 text-left text-[14px]"
            >
              <Icon
                name="check"
                size={20}
                className={s.selected ? 'text-accent' : 'text-transparent'}
              />
              <span className="min-w-0 flex-1 truncate">{trackName(s, t('trackUnnamed'))}</span>
              {s.codec && <span className="font-mono text-[12px] text-[#94A3B8]">{s.codec}</span>}
            </button>
          ))}
          <button
            type="button"
            onClick={addSubtitle}
            className="flex h-12 items-center gap-3 text-left text-[14px] font-semibold text-accent"
          >
            <Icon name="add" size={20} />
            {t('fsLoadSubtitle')}
          </button>
          <div className="flex items-center justify-between pt-3 text-[13px] text-[#94A3B8]">
            <span>{t('subtitleDelay')}</span>
            <span className="rounded-xs bg-planned-ink px-1.5 py-px font-mono text-[10px] font-bold text-planned">
              {t('planned')}
            </span>
          </div>
        </aside>
      )}
    </div>,
    document.body,
  );
}

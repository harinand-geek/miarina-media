import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useT } from '../../i18n';
import { nativePlayback } from '../../services/nativePlayer';
import type { MediaRecord } from '../../services/types';
import { MOBILE_RESTART_SECS, useMobilePlayback } from '../../stores/mobilePlayback';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { durationLabel, formatLabel, qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { useMobileMediaSheet } from '../library/useMobileMediaSheet';
import { useNow } from '../downloads/useNow';
import { mediaByline } from './byline';
import { MobileMiniPlayer } from './MobileMiniPlayer';
import { MobileVideoFullscreen } from './MobileVideoFullscreen';
import { LyricsSheet, QueueSheet, SoundSheet } from './MobilePlayerSheets';
import { rateLabel } from './playbackRate';
import { notePlayed, noteStopped } from './recentPlays';
import { SeekBar } from './SeekBar';
import { useNativePlayback, type NativePlayback } from './useNativePlayback';
import { usePlayback, type Playback } from './usePlayback';

const ROUND = 'grid place-items-center text-[#F5F7FA]';

/**
 * The Android WebView cannot stream local files (asset protocol, measured on
 * the emulator): in the app, Media3 decodes and draws the video into the
 * "video surface" area while these controls drive it.
 */
const NATIVE = nativePlayback();
const usePlayer: (media: MediaRecord) => Playback | NativePlayback = NATIVE
  ? useNativePlayback
  : usePlayback;

type Sheet = 'queue' | 'sound' | 'lyrics' | null;

/**
 * Android player (Android v2 screen 07 for audio). Minimizing keeps it
 * mounted, so the engine keeps playing; the mini-player is portalled into
 * `miniSlot` (absent on screens that hide it: browser, settings).
 */
export function MobilePlayer({
  item,
  miniSlot,
}: {
  item: MediaRecord;
  miniSlot: HTMLElement | null;
}) {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const { attachMedia, ...p } = usePlayer(item);
  const attachSurface = 'attachSurface' in p ? p.attachSurface : undefined;
  const expanded = useUi((s) => s.mobilePlayerExpanded);
  const setExpanded = (mobilePlayerExpanded: boolean) => useUi.setState({ mobilePlayerExpanded });
  const audio = item.kind === 'audio';
  const actionsSheet = useMobileMediaSheet({ inPlayer: true });
  const [sheet, setSheet] = useState<Sheet>(null);
  /** Screen 13: native landscape fullscreen (Android app only). */
  const [fullscreen, setFullscreen] = useState(false);
  const { queue, source, shuffle, repeat, rate, sleep, setShuffle, cycleRepeat } =
    useMobilePlayback();
  const at = queue.findIndex((m) => m.id === item.id);
  const hasNext = (at >= 0 && at + 1 < queue.length) || (repeat === 'all' && queue.length > 1);
  const now = useNow(sleep.mode === 'minutes' ? 30_000 : null);

  // Latest playback controls for timers and effects.
  const latest = useRef(p);
  useEffect(() => {
    latest.current = p;
  });

  // Play history (COM-13): Music › Recent / Most played, Home "Continue".
  const playing = p.playing;
  const wasPlaying = useRef(false);
  useEffect(() => {
    if (playing) notePlayed(item);
    else if (wasPlaying.current) noteStopped(item.id, latest.current.time);
    wasPlaying.current = playing;
  }, [playing, item]);

  // Persisted speed (AND-09), applied once the engine knows the media.
  const ready = p.duration > 0;
  useEffect(() => {
    if (ready && latest.current.rate !== rate) latest.current.setRate(rate);
  }, [ready, rate]);

  // End of the media: repeat, stop for the sleep timer, or continue with the
  // queue (foreground; lot L03 moves this to the MediaSession service).
  const handled = useRef(false);
  const ended = !p.playing && p.duration > 0 && p.time >= p.duration - 1;
  useEffect(() => {
    // Android app: the MediaSession service chains tracks and repeats itself.
    if (NATIVE) return;
    if (!ended) {
      handled.current = false;
      return;
    }
    if (handled.current) return;
    handled.current = true;
    const store = useMobilePlayback.getState();
    if (store.sleep.mode === 'end') {
      store.setSleep('off');
      useUi.getState().pushToast({ tone: 'success', message: t('sleepStopped') });
    } else if (store.repeat === 'one') {
      latest.current.seek(0);
      latest.current.toggle();
    } else {
      store.next();
    }
  }, [ended, t]);

  // Sleep timer in minutes: pauses, the app stays open (AND-11).
  useEffect(() => {
    if (sleep.mode !== 'minutes') return;
    const timer = setTimeout(
      () => {
        if (latest.current.playing) latest.current.toggle();
        useMobilePlayback.getState().setSleep('off');
        useUi.getState().pushToast({ tone: 'success', message: t('sleepStopped') });
      },
      Math.max(0, sleep.endsAt - Date.now()),
    );
    return () => clearTimeout(timer);
  }, [sleep, t]);

  const previous = () => {
    if (p.time > MOBILE_RESTART_SECS || !useMobilePlayback.getState().previous()) p.seek(0);
  };
  const next = () => useMobilePlayback.getState().next(true);

  const sleepLabel =
    sleep.mode === 'minutes'
      ? t('sleepMinutes', {
          n: Math.min(sleep.minutes, Math.max(1, Math.ceil((sleep.endsAt - now) / 60_000))),
        })
      : sleep.mode === 'end'
        ? t('sleepEnd')
        : t('timer');
  const repeatLabel =
    repeat === 'off' ? t('repeatOff') : repeat === 'all' ? t('repeatAll') : t('repeatOne');

  const accessItems = [
    {
      id: 'speed',
      label: t('speed'),
      on: rate !== 1,
      icon: null,
      value: rateLabel(rate, lang),
      run: () => setSheet('sound'),
    },
    { id: 'eq', label: t('eq'), on: false, icon: 'graphic_eq', run: () => setSheet('sound') },
    {
      id: 'sleep',
      label: sleepLabel,
      on: sleep.mode !== 'off',
      icon: 'bedtime',
      run: () => setSheet('sound'),
    },
    { id: 'lyrics', label: t('lyrics'), on: false, icon: 'lyrics', run: () => setSheet('lyrics') },
    {
      id: 'queue',
      label: t('queueCount', { n: queue.length }),
      on: false,
      icon: 'queue_music',
      run: () => setSheet('queue'),
    },
  ];
  // Lyrics and the equalizer are music settings.
  const access = audio
    ? accessItems
    : accessItems.filter((a) => a.id !== 'eq' && a.id !== 'lyrics');

  return (
    <>
      {!expanded &&
        miniSlot &&
        createPortal(
          <MobileMiniPlayer
            media={item}
            playing={p.playing}
            time={p.time}
            duration={p.duration}
            onToggle={p.toggle}
            onExpand={() => setExpanded(true)}
            onNext={hasNext ? next : undefined}
          />,
          miniSlot,
        )}
      <div
        role="dialog"
        aria-modal="true"
        aria-label={`Now playing: ${item.title}`}
        hidden={!expanded}
        className={`absolute inset-0 z-40 flex animate-sheet-in flex-col text-[#F5F7FA] [--mm-border:245_247_250_/_0.18] ${
          audio
            ? item.thumbnail
              ? 'bg-[linear-gradient(180deg,#2A2320_0%,#141C24_45%,#0A0F14_100%)]'
              : 'bg-[linear-gradient(180deg,#1B252F_0%,#121A21_45%,#0A0F14_100%)]'
            : 'bg-[#0A0F14]'
        }`}
      >
        <div className="flex h-14 shrink-0 items-center px-1">
          <button
            type="button"
            aria-label={t('minimizePlayer')}
            onClick={() => setExpanded(false)}
            className={`${ROUND} h-12 w-12`}
          >
            <Icon name="keyboard_arrow_down" size={28} />
          </button>
          <span className="flex min-w-0 flex-1 flex-col items-center">
            <span className="text-[11px] font-bold tracking-[0.06em] text-[#94A3B8]">
              {t('playingFrom')}
            </span>
            <span className="max-w-full truncate text-[13px] font-bold">
              {source ?? t('libraryFallback')}
            </span>
          </span>
          <button
            type="button"
            aria-label={t('moreActions')}
            onClick={() => actionsSheet.open(item)}
            className={`${ROUND} h-12 w-12`}
          >
            <Icon name="more_vert" size={24} />
          </button>
        </div>

        {audio ? (
          <>
            <MediaThumb
              media={item}
              className="mx-9 mt-5 aspect-square shrink-0 rounded-[20px] shadow-dialog"
            />
            <div className="flex flex-col gap-1 px-6 pt-7">
              <span className="truncate text-[24px] font-extrabold tracking-[-0.01em]">
                {item.title}
              </span>
              <span className="truncate text-[15px] text-[#94A3B8]">{mediaByline(item, t)}</span>
            </div>
          </>
        ) : (
          <div className="relative grid aspect-video place-items-center bg-black font-mono text-[11px] text-[#64748B]">
            {NATIVE ? (
              // Minimized: no surface, the native picture is hidden (sound goes on).
              expanded && (
                <>
                  <div ref={attachSurface} className="absolute inset-0 bg-black" />
                  <button
                    type="button"
                    aria-label={t('fsEnter')}
                    onClick={() => setFullscreen(true)}
                    className="absolute bottom-2 right-2 z-10 grid h-11 w-11 place-items-center rounded-full bg-black/55 text-[#F5F7FA]"
                  >
                    <Icon name="fullscreen" size={24} />
                  </button>
                </>
              )
            ) : p.src ? (
              <video
                ref={attachMedia}
                src={p.src}
                preload="metadata"
                playsInline
                className="absolute inset-0 h-full w-full bg-black object-contain"
              />
            ) : (
              'video surface'
            )}
          </div>
        )}
        {audio && p.src && !NATIVE && <audio ref={attachMedia} src={p.src} preload="metadata" />}

        {!audio && (
          <div className="flex flex-col gap-1 px-6 pt-6">
            <span className="text-[20px] font-bold tracking-[-0.01em]">{item.title}</span>
            <span className="text-[14px] text-[#94A3B8]">
              {[item.sourceHost, qualityLabel(item)].filter(Boolean).join(' · ')}
            </span>
          </div>
        )}
        {p.error && (
          <div
            role="alert"
            className="mx-4 mt-4 flex items-center gap-3 rounded-[14px] border border-[#2F4558] bg-[#1F2F3B] px-4 py-3 text-[14px]"
          >
            <Icon name="error" fill className="shrink-0 text-[#F07070]" />
            <span className="flex-1">{t('errUnsupported', { format: formatLabel(item) })}</span>
          </div>
        )}

        <div className="flex flex-col gap-2 px-6 pt-5">
          <SeekBar
            time={p.time}
            duration={p.duration}
            onSeek={p.seek}
            thumbSize={16}
            hitHeight={24}
            halo={false}
            tone="coral"
            label={t('seek')}
          />
          <div className="flex justify-between font-mono text-[12px] font-medium text-[#94A3B8] tabular">
            <span>{formatClock(p.time, false)}</span>
            {/* Unknown duration (metadata not read yet): a dash, not 0:00. */}
            <span>{durationLabel(p.duration || null)}</span>
          </div>
        </div>

        <div className="flex items-center justify-between px-5 pt-3">
          <button
            type="button"
            aria-label={t('shuffle')}
            aria-pressed={shuffle}
            onClick={() => setShuffle(!shuffle)}
            className={`relative grid h-12 w-12 place-items-center ${shuffle ? 'text-coral-strong' : 'text-[#94A3B8]'}`}
          >
            <Icon name="shuffle" size={24} />
            {shuffle && (
              <span className="absolute bottom-1.5 h-1 w-1 rounded-full bg-coral-strong" />
            )}
          </button>
          <button
            type="button"
            aria-label={t('previous')}
            onClick={previous}
            className={`${ROUND} h-14 w-14`}
          >
            <Icon name="skip_previous" size={38} fill />
          </button>
          <button
            type="button"
            aria-label={p.playing ? t('pause') : t('play')}
            onClick={p.toggle}
            className="grid h-[76px] w-[76px] place-items-center rounded-full bg-coral text-coral-ink active:bg-coral-press"
          >
            <Icon name={p.playing ? 'pause' : 'play_arrow'} size={42} fill />
          </button>
          <button
            type="button"
            aria-label={t('next')}
            disabled={!hasNext}
            onClick={next}
            className={`${ROUND} h-14 w-14 disabled:opacity-40`}
          >
            <Icon name="skip_next" size={38} fill />
          </button>
          <button
            type="button"
            aria-label={repeatLabel}
            aria-pressed={repeat !== 'off'}
            onClick={cycleRepeat}
            className={`relative grid h-12 w-12 place-items-center ${repeat !== 'off' ? 'text-coral-strong' : 'text-[#94A3B8]'}`}
          >
            <Icon name={repeat === 'one' ? 'repeat_one' : 'repeat'} size={24} />
            {repeat !== 'off' && (
              <span className="absolute bottom-1.5 h-1 w-1 rounded-full bg-coral-strong" />
            )}
          </button>
        </div>

        <div className="flex-1" />
        <div className="flex justify-around px-3 pb-3">
          {access.map((a) => (
            <button
              key={a.id}
              type="button"
              onClick={a.run}
              aria-label={a.id === 'speed' ? `${a.label} ${a.value}` : a.label}
              className={`flex w-16 flex-col items-center gap-1 text-[11.5px] font-semibold ${
                a.on ? 'text-coral-strong' : 'text-[#94A3B8]'
              }`}
            >
              {a.icon ? (
                <Icon name={a.icon} size={26} />
              ) : (
                <span className="grid h-7 place-items-center font-mono text-[14px] font-bold text-[#F5F7FA]">
                  {a.value}
                </span>
              )}
              <span className="max-w-full truncate">{a.label}</span>
            </button>
          ))}
        </div>
        {actionsSheet.sheet}
        {NATIVE && !audio && expanded && fullscreen && (
          <MobileVideoFullscreen item={item} p={p} onExit={() => setFullscreen(false)} />
        )}
        {sheet === 'queue' && (
          <QueueSheet onClose={() => setSheet(null)} time={p.time} duration={p.duration} />
        )}
        {sheet === 'sound' && <SoundSheet media={item} onClose={() => setSheet(null)} />}
        {sheet === 'lyrics' && <LyricsSheet media={item} onClose={() => setSheet(null)} />}
      </div>
    </>
  );
}

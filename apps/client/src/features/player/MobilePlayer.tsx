import { useState } from 'react';
import { createPortal } from 'react-dom';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { nativePlayback } from '../../services/nativePlayer';
import type { MediaRecord } from '../../services/types';
import { useT } from '../../i18n';
import { useUi } from '../../stores/ui';
import { MobileMiniPlayer } from './MobileMiniPlayer';
import { durationLabel, formatLabel, qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { ThumbBackdrop } from './Backdrop';
import { SeekBar } from './SeekBar';
import { nextRate } from './playbackRate';
import { useNativePlayback, type NativePlayback } from './useNativePlayback';
import { usePlayback, type Playback } from './usePlayback';
import { useMobileMediaSheet } from '../library/useMobileMediaSheet';

const ROUND = 'grid place-items-center text-[#F5F7FA]';

/**
 * The Android WebView cannot stream local files (asset protocol, measured on
 * the emulator): in the app, Media3 decodes and draws the video into the
 * "video surface" area while these approved controls drive it.
 */
const NATIVE = nativePlayback();
const usePlayer: (media: MediaRecord) => Playback | NativePlayback = NATIVE
  ? useNativePlayback
  : usePlayback;

/**
 * Android full-screen player (design M-player). Minimizing keeps it mounted,
 * so the engine keeps playing; the mini-player is portalled into `miniSlot`
 * (absent on screens that hide it: browser, settings).
 */
export function MobilePlayer({
  item,
  miniSlot,
}: {
  item: MediaRecord;
  miniSlot: HTMLElement | null;
}) {
  const t = useT();
  const { attachMedia, ...p } = usePlayer(item);
  const attachSurface = 'attachSurface' in p ? p.attachSurface : undefined;
  const expanded = useUi((s) => s.mobilePlayerExpanded);
  const setExpanded = (mobilePlayerExpanded: boolean) => useUi.setState({ mobilePlayerExpanded });
  const [subtitles, setSubtitles] = useState(false);
  const audio = item.kind === 'audio';
  const actionsSheet = useMobileMediaSheet({ inPlayer: true });

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
        />,
        miniSlot,
      )}
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Now playing: ${item.title}`}
      hidden={!expanded}
      className="absolute inset-0 z-40 flex animate-sheet-in flex-col bg-[#0A0F14] text-[#F5F7FA] [--mm-border:36_53_69]"
    >
      <div className="flex h-14 items-center px-1">
        <button
          type="button"
          aria-label={t('minimizePlayer')}
          onClick={() => setExpanded(false)}
          className={`${ROUND} h-12 w-12`}
        >
          <Icon name="keyboard_arrow_down" size={26} />
        </button>
        <span className="flex-1 text-center text-[13px] font-semibold text-[#94A3B8]">
          {audio ? 'Now playing' : 'Video'}
        </span>
        <button
          type="button"
          aria-label="More actions"
          onClick={() => actionsSheet.open(item)}
          className={`${ROUND} h-12 w-12`}
        >
          <Icon name="more_vert" size={24} />
        </button>
      </div>
      {audio ? (
        <div className="relative mx-8 mt-4">
          {/* Blurred cover behind the cover (no placeholder stripes). */}
          <div className="pointer-events-none absolute -inset-8 overflow-hidden">
            <ThumbBackdrop path={item.thumbnail} />
          </div>
          {item.thumbnail ? (
            <MediaThumb
              media={item}
              className="relative aspect-square rounded-[20px] shadow-menu"
            />
          ) : (
            <div className="relative grid aspect-square place-items-center rounded-[20px] bg-[#182530]">
              <Icon name="music_note" size={64} className="text-[#8FB3D9]" />
            </div>
          )}
          {p.src && !NATIVE && <audio ref={attachMedia} src={p.src} preload="metadata" />}
        </div>
      ) : (
        <div className="relative grid aspect-video place-items-center bg-black font-mono text-[11px] text-[#64748B]">
          {NATIVE ? (
            // Minimized: no surface, the native picture is hidden (sound goes on).
            expanded && <div ref={attachSurface} className="absolute inset-0 bg-black" />
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
      {p.error && (
        <div
          role="alert"
          className="mx-4 mt-4 flex items-center gap-3 rounded-[14px] border border-[#2F4558] bg-[#1F2F3B] px-4 py-3 text-[14px]"
        >
          <Icon name="error" fill className="shrink-0 text-[#F07070]" />
          <span className="flex-1">This file cannot be played here ({formatLabel(item)}).</span>
        </div>
      )}
      <div className="flex flex-col gap-1 px-6 pt-6">
        <span className="text-[20px] font-bold tracking-[-0.01em]">{item.title}</span>
        <span className="text-[14px] text-[#94A3B8]">
          {[item.sourceHost, qualityLabel(item)].filter(Boolean).join(' · ')}
        </span>
      </div>
      <div className="flex flex-col gap-2 px-6 pt-5">
        <SeekBar
          time={p.time}
          duration={p.duration}
          onSeek={p.seek}
          thumbSize={16}
          hitHeight={24}
          halo={false}
        />
        <div className="flex justify-between font-mono text-[12px] font-medium text-[#94A3B8] tabular">
          <span>{formatClock(p.time, false)}</span>
          {/* Unknown duration (metadata not read yet): show a dash, not 0:00. */}
          <span>{durationLabel(p.duration || null)}</span>
        </div>
      </div>
      <div className="flex items-center justify-center gap-4 py-4">
        <button
          type="button"
          aria-label="Back 10 seconds"
          onClick={() => p.skip(-10)}
          className={`${ROUND} h-[52px] w-[52px]`}
        >
          <Icon name="replay_10" size={30} />
        </button>
        <button
          type="button"
          aria-label={p.playing ? 'Pause' : 'Play'}
          onClick={p.toggle}
          className="grid h-[76px] w-[76px] place-items-center rounded-full bg-coral text-coral-ink"
        >
          <Icon name={p.playing ? 'pause' : 'play_arrow'} size={40} fill />
        </button>
        <button
          type="button"
          aria-label="Forward 10 seconds"
          onClick={() => p.skip(10)}
          className={`${ROUND} h-[52px] w-[52px]`}
        >
          <Icon name="forward_10" size={30} />
        </button>
      </div>
      <div className="flex justify-around px-6 text-[#94A3B8]">
        <button
          type="button"
          aria-label={`Playback speed ${p.rate}×`}
          onClick={() => p.setRate(nextRate(p.rate))}
          className="relative grid h-12 w-12 place-items-center"
        >
          <Icon name="speed" size={24} />
          {p.rate !== 1 && (
            <span className="absolute bottom-0 font-mono text-[10px] text-accent">{p.rate}×</span>
          )}
        </button>
        <button
          type="button"
          aria-label="Subtitles (no subtitle track in this file)"
          aria-pressed={subtitles}
          disabled
          onClick={() => setSubtitles((s) => !s)}
          className="grid h-12 w-12 place-items-center opacity-50"
        >
          <Icon name="closed_caption" size={24} />
        </button>
        <button
          type="button"
          aria-label="Rotate (not available yet)"
          disabled
          className="grid h-12 w-12 place-items-center opacity-50"
        >
          <Icon name="screen_rotation" size={24} />
        </button>
        <button
          type="button"
          aria-label="Picture in picture (not available yet)"
          disabled
          className="grid h-12 w-12 place-items-center opacity-50"
        >
          <Icon name="picture_in_picture_alt" size={24} />
        </button>
      </div>
      {actionsSheet.sheet}
    </div>
    </>
  );
}

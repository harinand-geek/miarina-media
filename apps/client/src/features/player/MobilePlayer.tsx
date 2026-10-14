import { useState } from 'react';
import { Icon } from '../../components/Icon';
import { formatClock, usePlaybackClock } from '../../hooks/usePlaybackClock';
import type { LibraryItem } from '../../services/types';
import { useUi } from '../../stores/ui';
import { SeekBar } from './SeekBar';
import { nextRate } from './playbackRate';

const ROUND = 'grid place-items-center text-[#F5F7FA]';

/** Android full-screen player (Phase 4: native Media3 session). */
export function MobilePlayer({ item }: { item: LibraryItem }) {
  const { time, playing, toggle, seek, skip } = usePlaybackClock(
    item.durationSec,
    Math.floor(item.durationSec * 0.3),
  );
  const close = useUi((s) => s.play);
  const [rate, setRate] = useState(1);
  const [subtitles, setSubtitles] = useState(false);
  const audio = item.kind === 'audio';

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Now playing: ${item.title}`}
      className="absolute inset-0 z-40 flex animate-sheet-in flex-col bg-[#0A0F14] text-[#F5F7FA] [--mm-border:36_53_69]"
    >
      <div className="flex h-14 items-center px-1">
        <button
          type="button"
          aria-label="Close player"
          onClick={() => close(null)}
          className={`${ROUND} h-12 w-12`}
        >
          <Icon name="keyboard_arrow_down" size={26} />
        </button>
        <span className="flex-1 text-center text-[13px] font-semibold text-[#94A3B8]">
          {audio ? 'Now playing' : 'Video'}
        </span>
        <button
          type="button"
          aria-label="More actions (not designed yet)"
          disabled
          className={`${ROUND} h-12 w-12 opacity-50`}
        >
          <Icon name="more_vert" size={24} />
        </button>
      </div>
      {audio ? (
        <div className="mx-8 mt-4 grid aspect-square place-items-center rounded-[20px] bg-[repeating-linear-gradient(135deg,#1C2C37_0_8px,#18262F_8px_16px)] font-mono text-[11px] text-[#64748B]">
          cover art
        </div>
      ) : (
        <div className="grid aspect-video place-items-center bg-[repeating-linear-gradient(135deg,#131D25_0_8px,#0F171E_8px_16px)] font-mono text-[11px] text-[#64748B]">
          video surface
        </div>
      )}
      <div className="flex flex-col gap-1 px-6 pt-6">
        <span className="text-[20px] font-bold tracking-[-0.01em]">{item.title}</span>
        <span className="text-[14px] text-[#94A3B8]">
          {item.source} · {item.quality}
        </span>
      </div>
      <div className="flex flex-col gap-2 px-6 pt-5">
        <SeekBar
          time={time}
          duration={item.durationSec}
          onSeek={seek}
          thumbSize={16}
          hitHeight={24}
          halo={false}
        />
        <div className="flex justify-between font-mono text-[12px] font-medium text-[#94A3B8] tabular">
          <span>{formatClock(time, false)}</span>
          <span>{item.duration}</span>
        </div>
      </div>
      <div className="flex items-center justify-center gap-4 py-4">
        <button
          type="button"
          aria-label="Back 10 seconds"
          onClick={() => skip(-10)}
          className={`${ROUND} h-[52px] w-[52px]`}
        >
          <Icon name="replay_10" size={30} />
        </button>
        <button
          type="button"
          aria-label={playing ? 'Pause' : 'Play'}
          onClick={toggle}
          className="grid h-[76px] w-[76px] place-items-center rounded-full bg-accent text-accent-ink"
        >
          <Icon name={playing ? 'pause' : 'play_arrow'} size={40} fill />
        </button>
        <button
          type="button"
          aria-label="Forward 10 seconds"
          onClick={() => skip(10)}
          className={`${ROUND} h-[52px] w-[52px]`}
        >
          <Icon name="forward_10" size={30} />
        </button>
      </div>
      <div className="flex justify-around px-6 text-[#94A3B8]">
        <button
          type="button"
          aria-label={`Playback speed ${rate}×`}
          onClick={() => setRate(nextRate(rate))}
          className="relative grid h-12 w-12 place-items-center"
        >
          <Icon name="speed" size={24} />
          {rate !== 1 && (
            <span className="absolute bottom-0 font-mono text-[10px] text-accent">{rate}×</span>
          )}
        </button>
        <button
          type="button"
          aria-label="Subtitles"
          aria-pressed={subtitles}
          onClick={() => setSubtitles((s) => !s)}
          className={`grid h-12 w-12 place-items-center ${subtitles ? 'text-accent' : ''}`}
        >
          <Icon name="closed_caption" size={24} fill={subtitles} />
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
    </div>
  );
}

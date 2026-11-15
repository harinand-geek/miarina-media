import { useRef } from 'react';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { MediaThumb } from '../library/MediaThumb';
import { mediaByline } from './byline';

/** Upward movement (px) that opens the full player. */
const SWIPE_UP = 24;

/**
 * Android v2 mini-player (COM-05): 64 dp card above the bottom bar. It shows
 * the playback of the minimized full player, which keeps the engine alive.
 */
export function MobileMiniPlayer({
  media,
  playing,
  time,
  duration,
  onToggle,
  onExpand,
  onNext,
}: {
  media: MediaRecord;
  playing: boolean;
  time: number;
  duration: number;
  onToggle: () => void;
  onExpand: () => void;
  /** Absent when nothing follows in the queue. */
  onNext?: () => void;
}) {
  const t = useT();
  const pct = duration > 0 ? Math.min(100, (time / duration) * 100) : 0;
  // Vice versa of the full player's drag down: swipe the card up to open it.
  const swipe = useRef<{ y: number; id: number } | null>(null);
  return (
    <section
      onPointerDown={(e) => {
        if (e.button === 0) swipe.current = { y: e.clientY, id: e.pointerId };
      }}
      onPointerMove={(e) => {
        const s = swipe.current;
        if (s && s.id === e.pointerId && s.y - e.clientY > SWIPE_UP) {
          swipe.current = null;
          onExpand();
        }
      }}
      onPointerUp={() => (swipe.current = null)}
      onPointerCancel={() => (swipe.current = null)}
      style={{ touchAction: 'pan-x' }}
      aria-label={t('nowPlaying')}
      className="relative mx-2 mb-2 flex h-[76px] animate-sheet-in items-center gap-3 overflow-hidden rounded-[22px] bg-surface2 pl-2.5 pr-2 shadow-[0_6px_24px_rgb(0_0_0/0.28)]"
    >
      <button
        type="button"
        onClick={onExpand}
        aria-label={`${t('openPlayer')}: ${media.title}`}
        className="flex min-w-0 flex-1 items-center gap-3 text-left"
      >
        <MediaThumb media={media} className="h-14 w-14 rounded-[14px]" />
        <span className="flex min-w-0 flex-col gap-0.5">
          <span className="truncate text-[15px] font-bold">{media.title}</span>
          <span className="truncate text-[12.5px] text-muted">{mediaByline(media, t)}</span>
        </span>
      </button>
      <button
        type="button"
        disabled={!onNext}
        onClick={onNext}
        aria-label={t('next')}
        className="grid h-11 w-11 place-items-center text-fg disabled:opacity-40"
      >
        <Icon name="skip_next" size={28} fill />
      </button>
      <button
        type="button"
        onClick={onToggle}
        aria-label={playing ? t('pause') : t('play')}
        className="grid h-12 w-12 place-items-center rounded-full border-2 border-coral-strong text-coral-strong"
      >
        <Icon name={playing ? 'pause' : 'play_arrow'} size={28} fill />
      </button>
      <div
        className="absolute inset-x-5 bottom-0 h-[3px] rounded-full bg-line-strong"
        aria-hidden="true"
      >
        <div className="h-full rounded-full bg-coral" style={{ width: `${pct}%` }} />
      </div>
    </section>
  );
}

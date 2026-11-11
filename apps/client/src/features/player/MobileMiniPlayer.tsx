import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { MediaThumb } from '../library/MediaThumb';
import { mediaByline } from './byline';

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
  return (
    <section
      aria-label={t('nowPlaying')}
      className="relative mx-2 mb-2 flex h-16 animate-sheet-in items-center gap-3 overflow-hidden rounded-[14px] bg-surface2 pl-2.5 pr-1.5"
    >
      <button
        type="button"
        onClick={onExpand}
        aria-label={`${t('openPlayer')}: ${media.title}`}
        className="flex min-w-0 flex-1 items-center gap-3 text-left"
      >
        <MediaThumb media={media} className="h-11 w-11 rounded-md" />
        <span className="flex min-w-0 flex-col">
          <span className="truncate text-[14px] font-bold">{media.title}</span>
          <span className="truncate text-[12px] text-muted">{mediaByline(media, t)}</span>
        </span>
      </button>
      <button
        type="button"
        onClick={onToggle}
        aria-label={playing ? t('pause') : t('play')}
        className="grid h-12 w-12 place-items-center text-coral-strong"
      >
        <Icon name={playing ? 'pause_circle' : 'play_circle'} size={32} fill />
      </button>
      <button
        type="button"
        disabled={!onNext}
        onClick={onNext}
        aria-label={t('next')}
        className="grid h-12 w-12 place-items-center text-fg disabled:opacity-40"
      >
        <Icon name="skip_next" size={28} fill />
      </button>
      <div className="absolute inset-x-0 bottom-0 h-0.5 bg-line-strong" aria-hidden="true">
        <div className="h-full bg-coral" style={{ width: `${pct}%` }} />
      </div>
    </section>
  );
}

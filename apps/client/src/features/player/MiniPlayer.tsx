import { IconButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useT } from '../../i18n';
import { isActive, usePlayer } from '../../stores/player';
import { useUi } from '../../stores/ui';
import { playerScreenFor } from '../../app/navigation';
import { durationLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { mediaByline } from './byline';
import { PlayButton, VolumeControl } from './parts';

/**
 * 68 px bar under the content (Windows v2, COM-05). It drives the same
 * engine as the full player: expanding never restarts the media.
 */
export function MiniPlayer() {
  const t = useT();
  const media = usePlayer((s) => s.media);
  const position = usePlayer((s) => s.position);
  const duration = usePlayer((s) => s.duration);
  const playing = usePlayer((s) => isActive(s.state));
  const failed = usePlayer((s) => s.state === 'error');
  const hasPrev = usePlayer((s) => s.queue.length > 0);
  const hasNext = usePlayer((s) => s.index + 1 < s.queue.length || (s.repeat === 'all' && s.queue.length > 1));
  const go = useUi((s) => s.go);
  if (!media) return null;

  const { toggle, previous, next } = usePlayer.getState();
  const pct = duration > 0 ? Math.min(100, (position / duration) * 100) : 0;
  const expand = () => go(playerScreenFor(media));

  return (
    <section
      aria-label={t('nowPlaying')}
      className="relative flex h-[68px] shrink-0 items-center gap-4 border-t border-divider bg-sidebar px-5"
    >
      <div className="absolute inset-x-0 -top-px h-0.5 bg-line" aria-hidden="true">
        <div className="h-full bg-coral" style={{ width: `${pct}%` }} />
      </div>
      <button
        type="button"
        onClick={expand}
        title={t('expand')}
        className="flex w-[300px] min-w-0 items-center gap-3 rounded-sm text-left"
      >
        <MediaThumb media={media} className="h-11 w-11 shrink-0 rounded-sm" />
        <span className="flex min-w-0 flex-col">
          <span className="truncate text-[13.5px] font-bold">{media.title}</span>
          <span className="flex items-center gap-1 truncate text-[12px] text-muted">
            {failed && <Icon name="error" size={14} className="text-danger" />}
            {mediaByline(media, t)}
          </span>
        </span>
      </button>
      <div className="flex flex-1 items-center justify-center gap-2">
        <IconButton
          icon="skip_previous"
          label={t('previous')}
          fill
          iconSize={24}
          disabled={!hasPrev}
          onClick={previous}
          className="!rounded-full"
        />
        <PlayButton size={42} iconSize={26} playing={playing} onClick={toggle} t={t} />
        <IconButton
          icon="skip_next"
          label={t('next')}
          fill
          iconSize={24}
          disabled={!hasNext}
          onClick={next}
          className="!rounded-full"
        />
        <span className="ml-2.5 font-mono text-[12px] text-muted tabular">
          {formatClock(position)} / {durationLabel(duration)}
        </span>
      </div>
      <div className="flex w-[300px] items-center justify-end gap-1">
        <VolumeControl t={t} />
        <IconButton
          icon="queue_music"
          label={t('queue')}
          onClick={() => {
            useUi.setState({ nowPanel: 'queue' });
            go('now');
          }}
        />
        <IconButton icon="open_in_full" label={t('expand')} onClick={expand} />
      </div>
    </section>
  );
}

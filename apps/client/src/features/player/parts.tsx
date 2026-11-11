import { Icon } from '../../components/Icon';
import type { Translate } from '../../i18n';
import { usePlayer } from '../../stores/player';

/** Play/pause button in the coral "play" accent. */
export function PlayButton({
  size,
  iconSize,
  playing,
  onClick,
  t,
  className = '',
}: {
  size: number;
  iconSize: number;
  playing: boolean;
  onClick: () => void;
  t: Translate;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={playing ? t('pause') : t('play')}
      title={`${playing ? t('pause') : t('play')} (Space)`}
      className={`grid shrink-0 place-items-center rounded-full bg-coral text-coral-ink transition-colors duration-[80ms] hover:bg-coral-hover active:bg-coral-press ${className}`}
      style={{ width: size, height: size }}
    >
      <Icon name={playing ? 'pause' : 'play_arrow'} size={iconSize} fill />
    </button>
  );
}

/** Mute toggle + 0–100 % slider bound to the player store. */
export function VolumeControl({
  t,
  width = 80,
  dark = false,
}: {
  t: Translate;
  width?: number;
  /** Fixed light-on-dark colors (video chrome). */
  dark?: boolean;
}) {
  const volume = usePlayer((s) => s.volume);
  const muted = usePlayer((s) => s.muted);
  const { setVolume, toggleMute } = usePlayer.getState();
  const level = muted ? 0 : volume;
  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        aria-label={muted || volume === 0 ? t('unmute') : t('mute')}
        onClick={toggleMute}
        className={`grid h-9 w-9 place-items-center rounded-sm ${dark ? 'text-[#94A3B8] hover:bg-[#243545] hover:text-[#F5F7FA]' : 'text-muted hover:bg-line hover:text-fg'}`}
      >
        <Icon name={level === 0 ? 'volume_off' : 'volume_up'} />
      </button>
      <div
        role="slider"
        tabIndex={0}
        aria-label={t('volume')}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(level * 100)}
        onClick={(e) => {
          const r = e.currentTarget.getBoundingClientRect();
          setVolume((e.clientX - r.left) / r.width);
        }}
        onKeyDown={(e) => {
          if (e.key === 'ArrowUp' || e.key === 'ArrowRight') setVolume(level + 0.1);
          else if (e.key === 'ArrowDown' || e.key === 'ArrowLeft') setVolume(level - 0.1);
          else return;
          e.preventDefault();
          e.stopPropagation();
        }}
        className="flex h-3.5 cursor-pointer items-center"
        style={{ width }}
      >
        <div className={`h-1 w-full rounded-full ${dark ? 'bg-[#243545]' : 'bg-line'}`}>
          <div
            className={`h-full rounded-full ${dark ? 'bg-[#F5F7FA]' : 'bg-fg'}`}
            style={{ width: `${level * 100}%` }}
          />
        </div>
      </div>
    </div>
  );
}

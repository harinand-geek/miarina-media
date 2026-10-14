import { formatClock } from '../../hooks/usePlaybackClock';

interface SeekBarProps {
  time: number;
  duration: number;
  onSeek: (sec: number) => void;
  /** Buffered position in seconds (desktop only). */
  buffered?: number;
  thumbSize?: 12 | 16;
  hitHeight?: number;
  halo?: boolean;
}

/** Accessible seek slider: click to seek, ←/→ ±10 s, Home/End. */
export function SeekBar({
  time,
  duration,
  onSeek,
  buffered,
  thumbSize = 12,
  hitHeight = 14,
  halo = true,
}: SeekBarProps) {
  const pct = duration > 0 ? (time / duration) * 100 : 0;
  const bufPct =
    buffered !== undefined && duration > 0 ? Math.min(100, (buffered / duration) * 100) : 0;

  return (
    <div
      role="slider"
      tabIndex={0}
      aria-label="Seek"
      aria-valuemin={0}
      aria-valuemax={duration}
      aria-valuenow={Math.round(time)}
      aria-valuetext={`${formatClock(time)} of ${formatClock(duration)}`}
      onClick={(e) => {
        const r = e.currentTarget.getBoundingClientRect();
        onSeek(((e.clientX - r.left) / r.width) * duration);
      }}
      onKeyDown={(e) => {
        const step = { ArrowLeft: -10, ArrowRight: 10 }[e.key];
        if (step !== undefined) {
          e.preventDefault();
          e.stopPropagation();
          onSeek(time + step);
        } else if (e.key === 'Home') onSeek(0);
        else if (e.key === 'End') onSeek(duration - 1);
      }}
      className="relative flex cursor-pointer items-center"
      style={{ height: hitHeight }}
    >
      <div className="absolute inset-x-0 h-1 rounded-full bg-line" />
      {buffered !== undefined && (
        <div
          className="absolute left-0 h-1 rounded-full bg-faint-icon"
          style={{ width: `${bufPct}%` }}
        />
      )}
      <div className="absolute left-0 h-1 rounded-full bg-accent" style={{ width: `${pct}%` }} />
      <div
        className={`absolute rounded-full bg-[#F5F7FA] ${halo ? 'shadow-[0_0_0_3px_rgba(53,201,189,.3)]' : ''}`}
        style={{ left: `${pct}%`, width: thumbSize, height: thumbSize, marginLeft: -thumbSize / 2 }}
      />
    </div>
  );
}

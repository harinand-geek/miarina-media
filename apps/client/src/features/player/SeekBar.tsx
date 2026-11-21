import { useRef, useState } from 'react';
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
  /** Windows v2: coral is the playback accent. */
  tone?: 'accent' | 'coral';
  label?: string;
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
  tone = 'accent',
  label = 'Seek',
}: SeekBarProps) {
  const [preview, setPreview] = useState<number | null>(null);
  const pointer = useRef<number | null>(null);
  const shown = preview ?? time;
  const clamp = (value: number) => Math.max(0, Math.min(duration, value));
  const coral = tone === 'coral';
  const pct = duration > 0 ? (shown / duration) * 100 : 0;
  const bufPct =
    buffered !== undefined && duration > 0 ? Math.min(100, (buffered / duration) * 100) : 0;

  return (
    <div
      role="slider"
      tabIndex={0}
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={duration}
      aria-valuenow={Math.round(shown)}
      aria-valuetext={`${formatClock(shown)} of ${formatClock(duration)}`}
      aria-disabled={duration <= 0}
      onPointerDown={(e) => {
        if (e.button !== 0 || duration <= 0) return;
        e.preventDefault();
        e.currentTarget.focus();
        pointer.current = e.pointerId;
        e.currentTarget.setPointerCapture(e.pointerId);
        const r = e.currentTarget.getBoundingClientRect();
        if (r.width > 0) setPreview(clamp(((e.clientX - r.left) / r.width) * duration));
      }}
      onPointerMove={(e) => {
        if (pointer.current !== e.pointerId) return;
        const r = e.currentTarget.getBoundingClientRect();
        if (r.width > 0) setPreview(clamp(((e.clientX - r.left) / r.width) * duration));
      }}
      onPointerUp={(e) => {
        if (pointer.current !== e.pointerId) return;
        const r = e.currentTarget.getBoundingClientRect();
        pointer.current = null;
        setPreview(null);
        e.currentTarget.releasePointerCapture(e.pointerId);
        if (r.width > 0) onSeek(clamp(((e.clientX - r.left) / r.width) * duration));
      }}
      onPointerCancel={() => {
        pointer.current = null;
        setPreview(null);
      }}
      onLostPointerCapture={() => {
        pointer.current = null;
        setPreview(null);
      }}
      onKeyDown={(e) => {
        if (duration <= 0) return;
        const step = { ArrowLeft: -10, ArrowRight: 10 }[e.key];
        if (step !== undefined) {
          e.preventDefault();
          e.stopPropagation();
          onSeek(clamp(shown + step));
        } else if (e.key === 'Home' || e.key === 'End') {
          e.preventDefault();
          e.stopPropagation();
          onSeek(e.key === 'Home' ? 0 : duration);
        }
      }}
      className="relative flex cursor-pointer items-center"
      style={{ height: Math.max(24, hitHeight), touchAction: 'none' }}
    >
      <div className="absolute inset-x-0 h-1 rounded-full bg-line" />
      {buffered !== undefined && (
        <div
          className="absolute left-0 h-1 rounded-full bg-faint-icon"
          style={{ width: `${bufPct}%` }}
        />
      )}
      <div
        className={`absolute left-0 h-1 rounded-full ${coral ? 'bg-coral' : 'bg-accent'}`}
        style={{ width: `${pct}%` }}
      />
      <div
        className={`absolute rounded-full ${coral ? 'bg-coral' : 'bg-[#F5F7FA]'} ${halo && !coral ? 'shadow-[0_0_0_3px_rgba(53,201,189,.3)]' : ''}`}
        style={{ left: `${pct}%`, width: thumbSize, height: thumbSize, marginLeft: -thumbSize / 2 }}
      />
    </div>
  );
}

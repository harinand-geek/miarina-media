type Tone = 'active' | 'paused' | 'error' | 'complete';

interface ProgressBarProps {
  /** 0–100; `null` renders the indeterminate variant. */
  value: number | null;
  tone?: Tone;
  label: string;
  /** Track height: 4 px desktop, 6 px Android, 3 px sidebar card. */
  height?: 3 | 4 | 6;
  className?: string;
}

const FILL: Record<Tone, string> = {
  active: 'bg-accent',
  complete: 'bg-accent',
  paused: 'bg-paused',
  error: 'bg-danger',
};

/**
 * Progress track (design system §5). Width tweens linearly over 900 ms
 * between 1 s updates.
 */
export function ProgressBar({
  value,
  tone = 'active',
  label,
  height = 4,
  className = '',
}: ProgressBarProps) {
  const rounded = value === null ? undefined : Math.floor(value);
  return (
    <div
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={rounded}
      className={`overflow-hidden rounded-full bg-line ${className}`}
      style={{ height }}
    >
      {value === null ? (
        <div className="animate-indeterminate h-full w-[30%] rounded-full bg-accent" />
      ) : (
        <div
          className={`h-full rounded-full transition-[width] duration-[900ms] ease-linear ${FILL[tone]}`}
          style={{ width: `${Math.min(100, Math.max(0, value))}%` }}
        />
      )}
    </div>
  );
}

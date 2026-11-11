import type { ReactNode } from 'react';

interface Option<T extends string> {
  value: T;
  label: ReactNode;
}

interface SegmentedProps<T extends string> {
  options: Option<T>[];
  value: T;
  onChange: (value: T) => void;
  label: string;
  /** `mobile` = Android pill segmented (radius 24, 40 dp segments). */
  variant?: 'desktop' | 'mobile' | 'mobile-sunken';
  className?: string;
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
  label,
  variant = 'desktop',
  className = '',
}: SegmentedProps<T>) {
  const mobile = variant !== 'desktop';
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className={
        mobile
          ? `flex rounded-[24px] p-1 ${variant === 'mobile-sunken' ? 'bg-bg' : 'bg-surface'} ${className}`
          : `flex self-start rounded-[7px] border border-line-strong bg-bg p-[3px] ${className}`
      }
    >
      {options.map((o) => {
        const on = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={on}
            onClick={() => onChange(o.value)}
            className={
              mobile
                ? `h-10 flex-1 rounded-[20px] text-[13px] font-bold transition-colors duration-150 ${on ? 'bg-line-strong text-fg' : 'text-muted'}`
                : `h-7 rounded-[5px] px-3 text-[12.5px] font-semibold transition-colors duration-150 ${on ? 'bg-line-strong text-fg' : 'text-muted hover:text-fg'}`
            }
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

interface TabsProps<T extends string> {
  options: Option<T>[];
  value: T;
  onChange: (value: T) => void;
  label: string;
}

/** Underlined tabs (design system §5). */
export function Tabs<T extends string>({ options, value, onChange, label }: TabsProps<T>) {
  return (
    <div role="tablist" aria-label={label} className="flex gap-1 border-b border-surface2">
      {options.map((o) => {
        const on = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="tab"
            aria-selected={on}
            onClick={() => onChange(o.value)}
            className={`-mb-px h-[38px] border-b-2 px-3.5 text-[13.5px] font-semibold transition-colors duration-150 ${
              on ? 'border-accent text-fg' : 'border-transparent text-muted hover:text-fg'
            }`}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

interface ChipProps {
  selected: boolean;
  onClick: () => void;
  children: ReactNode;
  count?: number;
  size?: 'desktop' | 'mobile';
}

export function Chip({ selected, onClick, children, count, size = 'desktop' }: ChipProps) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onClick}
      className={`shrink-0 whitespace-nowrap border font-semibold transition-colors duration-150 ${
        size === 'mobile'
          ? 'h-9 rounded-[18px] px-4 text-[13px]'
          : 'h-[30px] rounded-[15px] px-3 text-[12.5px]'
      } ${selected ? 'border-chip-border bg-accent-subtle text-chip-text' : 'border-line-strong text-muted hover:text-fg'}`}
    >
      {children}
      {count !== undefined && <span className="ml-1 font-medium opacity-70">{count}</span>}
    </button>
  );
}

interface ToggleProps {
  checked: boolean;
  onChange: () => void;
  label: string;
  size?: 'desktop' | 'mobile';
}

/** Switch: 38×22 desktop, 52×32 Android. */
export function Toggle({ checked, onChange, label, size = 'desktop' }: ToggleProps) {
  const mobile = size === 'mobile';
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={onChange}
      className={`relative shrink-0 rounded-full transition-colors duration-150 ${checked ? 'bg-accent' : 'bg-line-strong'} ${
        mobile ? 'h-8 w-[52px]' : 'h-[22px] w-[38px]'
      }`}
    >
      <span
        className={`absolute rounded-full transition-[left] duration-150 ease-standard ${checked ? 'bg-accent-ink' : 'bg-muted'} ${
          mobile ? 'top-1 h-6 w-6' : 'top-[3px] h-4 w-4'
        }`}
        style={{ left: mobile ? (checked ? 24 : 4) : checked ? 19 : 3 }}
      />
    </button>
  );
}

interface RadioDotProps {
  checked: boolean;
  size?: 16 | 20;
  /** Destructive choice (e.g. delete a file). */
  tone?: 'accent' | 'danger';
}

/** Visual radio indicator used inside selectable rows. */
export function RadioDot({ checked, size = 16, tone = 'accent' }: RadioDotProps) {
  const on = tone === 'danger' ? 'danger' : 'accent';
  return (
    <span
      aria-hidden="true"
      className={`grid shrink-0 place-items-center rounded-full border-2 ${checked ? (on === 'danger' ? 'border-danger' : 'border-accent') : 'border-faint-icon'}`}
      style={{ width: size, height: size }}
    >
      <span
        className={`rounded-full ${checked ? (on === 'danger' ? 'bg-danger' : 'bg-accent') : 'bg-transparent'}`}
        style={{ width: size === 16 ? 6 : 10, height: size === 16 ? 6 : 10 }}
      />
    </span>
  );
}

interface StepperProps {
  value: number;
  min: number;
  max: number;
  onChange: (value: number) => void;
  label: string;
}

export function Stepper({ value, min, max, onChange, label }: StepperProps) {
  const btn =
    'h-8 w-8 bg-surface2 text-[16px] text-fg hover:bg-secondary-hover disabled:text-faint';
  return (
    <div
      role="group"
      aria-label={label}
      className="flex items-center overflow-hidden rounded-sm border border-line-strong"
    >
      <button
        type="button"
        aria-label={`Decrease ${label}`}
        className={btn}
        disabled={value <= min}
        onClick={() => onChange(value - 1)}
      >
        −
      </button>
      <output
        aria-live="polite"
        className="w-10 text-center font-mono text-[13px] font-medium tabular"
      >
        {value}
      </output>
      <button
        type="button"
        aria-label={`Increase ${label}`}
        className={btn}
        disabled={value >= max}
        onClick={() => onChange(value + 1)}
      >
        +
      </button>
    </div>
  );
}

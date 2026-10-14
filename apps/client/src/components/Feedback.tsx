import { useEffect, useState, type ReactNode } from 'react';
import { Icon } from './Icon';

export function PlannedBadge({ label = 'PLANNED' }: { label?: string }) {
  return (
    <span className="rounded-xs bg-planned px-1.5 py-0.5 font-mono text-[10.5px] font-bold text-planned-ink">
      {label}
    </span>
  );
}

export function Kbd({ children }: { children: ReactNode }) {
  return (
    <kbd className="rounded-xs border border-line-strong px-1.5 py-px font-mono text-[11px] font-medium text-muted">
      {children}
    </kbd>
  );
}

/** Placeholder artwork from the design until real thumbnails exist (Phase 3). */
export function Thumbnail({
  className = '',
  label,
  children,
}: {
  className?: string;
  label?: string;
  children?: ReactNode;
}) {
  return (
    <div
      className={`hatch relative grid shrink-0 place-items-center font-mono text-[9px] font-medium text-faint ${className}`}
    >
      {label}
      {children}
    </div>
  );
}

/** Small overlay label on thumbnails (duration, quality). */
export function ThumbBadge({ children, position }: { children: ReactNode; position: 'br' | 'tl' }) {
  return (
    <span
      className={`absolute rounded-[3px] bg-[rgb(10_16_22/0.85)] px-[5px] py-px font-mono text-[11px] text-[#F5F7FA] ${
        position === 'br' ? 'bottom-1.5 right-1.5' : 'left-1.5 top-1.5 text-[10.5px]'
      }`}
    >
      {children}
    </span>
  );
}

/** Skeleton block: shown only after 200 ms, pulse .6↔1 over 1.2 s. */
export function Skeleton({ className = '' }: { className?: string }) {
  return <div className={`animate-skeleton rounded-xs bg-surface2 ${className}`} />;
}

export function DelayedSkeletons({ children }: { children: ReactNode }) {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setVisible(true), 200);
    return () => clearTimeout(t);
  }, []);
  return visible ? <>{children}</> : null;
}

interface EmptyStateProps {
  icon?: string;
  title?: string;
  children: ReactNode;
  action?: ReactNode;
  variant?: 'dashed' | 'plain';
}

export function EmptyState({ icon, title, children, action, variant = 'dashed' }: EmptyStateProps) {
  return (
    <div
      className={`flex flex-col items-center gap-2.5 text-center ${
        variant === 'dashed'
          ? 'rounded-lg border border-dashed border-line-strong px-6 py-10'
          : 'px-6 py-12'
      }`}
    >
      {icon && <Icon name={icon} size={40} className="text-faint-icon" />}
      {title && <span className="text-[15px] font-bold">{title}</span>}
      <span className="text-[13.5px] leading-normal text-muted">{children}</span>
      {action && <div className="mt-1.5">{action}</div>}
    </div>
  );
}

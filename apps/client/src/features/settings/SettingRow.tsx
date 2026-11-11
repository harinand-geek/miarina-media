import type { ReactNode } from 'react';
import { Icon } from '../../components/Icon';

export function SettingRow({
  label,
  description,
  children,
}: {
  label: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-[64px] items-center gap-5 border-b border-line py-3.5">
      <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
        <span className="text-[14px] font-bold">{label}</span>
        {description && <span className="text-[12.5px] text-muted">{description}</span>}
      </div>
      {children}
    </div>
  );
}

interface SelectProps {
  label: string;
  value: string;
  options: string[];
  onChange?: (value: string) => void;
  disabled?: boolean;
}

/** Design select field; the native popup keeps OS accessibility (options are not designed yet). */
export function Select({ label, value, options, onChange, disabled }: SelectProps) {
  return (
    <div className="relative min-w-[200px]">
      <select
        aria-label={label}
        value={value}
        disabled={disabled}
        onChange={(e) => onChange?.(e.target.value)}
        className="h-9 w-full appearance-none rounded-sm border border-line-strong bg-bg pl-3 pr-9 text-[13px] text-fg disabled:text-muted"
      >
        {options.map((o) => (
          <option key={o}>{o}</option>
        ))}
      </select>
      <Icon
        name="expand_more"
        size={18}
        className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-muted"
      />
    </div>
  );
}

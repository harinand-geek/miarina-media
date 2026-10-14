import type { ComponentPropsWithRef, ReactNode } from 'react';
import { Icon } from './Icon';

type Variant = 'primary' | 'secondary' | 'destructive' | 'link';
type Size = 'sm' | 'md' | 'lg';

interface ButtonProps extends ComponentPropsWithRef<'button'> {
  variant?: Variant;
  size?: Size;
  icon?: string;
  /** Android pill shape (52 dp primary, radius 26). */
  pill?: boolean;
  children: ReactNode;
}

const VARIANTS: Record<Variant, string> = {
  primary:
    'bg-accent text-accent-ink font-bold hover:bg-accent-hover active:bg-accent-press disabled:bg-line disabled:text-faint',
  secondary:
    'bg-surface2 border border-line-strong text-fg font-semibold hover:bg-secondary-hover active:bg-line-strong active:border-overlay-border disabled:bg-surface disabled:border-line disabled:text-faint',
  destructive:
    'bg-destructive text-white font-bold hover:bg-destructive-hover active:bg-destructive-press focus-visible:outline-danger disabled:bg-line disabled:text-faint',
  link: 'text-accent-strong font-semibold hover:bg-accent-subtle disabled:text-faint',
};

const SIZES: Record<Size, string> = {
  sm: 'h-8 px-3 text-[12.5px]',
  md: 'h-10 px-4 text-[13.5px]',
  lg: 'h-12 px-5 text-[14px]',
};

export function Button({
  variant = 'secondary',
  size = 'md',
  icon,
  pill = false,
  className = '',
  children,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      className={`inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap transition-colors duration-[80ms] ${
        pill ? 'rounded-[26px]' : 'rounded-sm'
      } ${VARIANTS[variant]} ${SIZES[size]} ${className}`}
      {...rest}
    >
      {icon && <Icon name={icon} size={18} />}
      {children}
    </button>
  );
}

interface IconButtonProps extends ComponentPropsWithRef<'button'> {
  icon: string;
  label: string;
  size?: number;
  iconSize?: number;
  fill?: boolean;
  tone?: 'default' | 'muted' | 'danger-hover' | 'accent-hover';
}

const TONES = {
  default: 'text-fg hover:bg-line',
  muted: 'text-muted hover:bg-line hover:text-fg',
  'danger-hover': 'text-muted hover:bg-line hover:text-danger',
  'accent-hover': 'text-muted hover:bg-line hover:text-accent-strong',
};

/** Ghost icon button: 36×36, radius 6, icon 20 (design system §5). */
export function IconButton({
  icon,
  label,
  size = 36,
  iconSize = 20,
  fill = false,
  tone = 'muted',
  className = '',
  type = 'button',
  ...rest
}: IconButtonProps) {
  return (
    <button
      type={type}
      aria-label={label}
      title={rest.title ?? label}
      className={`grid shrink-0 place-items-center rounded-sm transition-colors duration-[80ms] active:bg-line-strong disabled:text-faint-icon ${TONES[tone]} ${className}`}
      style={{ width: size, height: size }}
      {...rest}
    >
      <Icon name={icon} size={iconSize} fill={fill} />
    </button>
  );
}

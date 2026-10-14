import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Icon } from './Icon';

export interface MenuItem {
  label: string;
  icon?: string;
  shortcut?: string;
  danger?: boolean;
  selected?: boolean;
  onSelect: () => void;
}

interface MenuProps {
  trigger: (props: { open: boolean; toggle: () => void; id: string }) => ReactNode;
  items: MenuItem[];
  label: string;
  align?: 'left' | 'right';
}

let menuSeq = 0;

/** Menu (design system §5): 240 px, surface-2, items 34 px, Esc closes. */
export function Menu({ trigger, items, label, align = 'right' }: MenuProps) {
  const [open, setOpen] = useState(false);
  const [id] = useState(() => `menu-${++menuSeq}`);
  const rootRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    listRef.current?.querySelector<HTMLButtonElement>('[role="menuitem"]')?.focus();
    const onPointer = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    window.addEventListener('pointerdown', onPointer);
    return () => window.removeEventListener('pointerdown', onPointer);
  }, [open]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    const buttons = [
      ...(listRef.current?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? []),
    ];
    const index = buttons.indexOf(document.activeElement as HTMLButtonElement);
    if (e.key === 'Escape') {
      e.stopPropagation();
      setOpen(false);
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      buttons[(index + 1) % buttons.length]?.focus();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      buttons[(index - 1 + buttons.length) % buttons.length]?.focus();
    }
  };

  return (
    <div ref={rootRef} className="relative" onKeyDown={onKeyDown}>
      {trigger({ open, toggle: () => setOpen((o) => !o), id })}
      {open && (
        <div
          ref={listRef}
          id={id}
          role="menu"
          aria-label={label}
          className={`absolute top-full z-20 mt-1 flex w-60 animate-fade-in flex-col rounded-lg border border-overlay-border bg-surface2 p-1.5 shadow-menu ${
            align === 'right' ? 'right-0' : 'left-0'
          }`}
        >
          {items.map((item) => (
            <button
              key={item.label}
              type="button"
              role="menuitem"
              onClick={() => {
                item.onSelect();
                setOpen(false);
              }}
              className={`flex h-[34px] items-center gap-2.5 rounded-sm px-2.5 text-left text-[13px] hover:bg-secondary-hover focus-visible:bg-secondary-hover ${
                item.danger ? 'text-danger' : 'text-fg'
              }`}
            >
              {item.icon && <Icon name={item.icon} size={18} />}
              <span className="flex-1">{item.label}</span>
              {item.selected && <Icon name="check" size={18} className="text-accent-strong" />}
              {item.shortcut && (
                <span className="font-mono text-[11px] text-muted">{item.shortcut}</span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

import { useEffect, useId, useRef, useState } from 'react';
import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';
import type { MediaRecord } from '../../services/types';
import { useT } from '../../i18n';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { useMediaActions } from './useMediaActions';

export interface MenuTarget {
  media: MediaRecord;
  x: number;
  y: number;
}

/** Positioned context menu (design system §5, items 34 px, shortcuts). */
export function MediaContextMenu({
  target,
  onClose,
  onRename,
}: {
  target: MenuTarget;
  onClose: () => void;
  onRename: (media: MediaRecord) => void;
}) {
  const t = useT();
  const actions = useMediaActions();
  const ref = useRef<HTMLDivElement>(null);
  const { media } = target;
  const items = [
    { icon: 'play_arrow', label: 'Play', key: 'Enter', run: () => actions.open(media) },
    {
      icon: 'folder_open',
      label: 'Show in folder',
      key: 'Ctrl E',
      run: () => actions.reveal(media),
    },
    {
      icon: 'content_copy',
      label: 'Copy source link',
      key: 'Ctrl C',
      run: () => actions.copyLink(media),
      disabled: !media.sourceUrl,
    },
    { icon: 'drive_file_rename_outline', label: 'Rename', key: 'F2', run: () => onRename(media) },
    {
      icon: 'edit_note',
      label: t('editTags'),
      key: '',
      run: () => useUi.setState({ tagEditor: media }),
    },
    {
      icon: 'delete',
      label: t('removeOrDelete'),
      key: 'Del',
      run: () => actions.askDelete(media),
      danger: true,
    },
  ];

  useEffect(() => {
    ref.current?.querySelector<HTMLButtonElement>('button:not(:disabled)')?.focus();
    const close = (e: PointerEvent) => {
      if (!ref.current?.contains(e.target as Node)) onClose();
    };
    window.addEventListener('pointerdown', close);
    return () => window.removeEventListener('pointerdown', close);
  }, [onClose]);

  // Keep the menu inside the window.
  const left = Math.min(target.x, window.innerWidth - 250);
  const top = Math.min(target.y, window.innerHeight - 200);

  return (
    <div
      ref={ref}
      role="menu"
      aria-label={`Actions for ${media.title}`}
      onKeyDown={(e) => {
        const buttons = [
          ...(ref.current?.querySelectorAll<HTMLButtonElement>('button:not(:disabled)') ?? []),
        ];
        const index = buttons.indexOf(document.activeElement as HTMLButtonElement);
        if (e.key === 'Escape') onClose();
        if (e.key === 'ArrowDown') buttons[(index + 1) % buttons.length]?.focus();
        if (e.key === 'ArrowUp') buttons[(index - 1 + buttons.length) % buttons.length]?.focus();
      }}
      className="fixed z-50 flex w-60 animate-fade-in flex-col rounded-lg border border-overlay-border bg-surface2 p-1.5 shadow-menu"
      style={{ left, top }}
    >
      {items.map((item) => (
        <button
          key={item.label}
          type="button"
          role="menuitem"
          disabled={item.disabled}
          onClick={() => {
            onClose();
            item.run();
          }}
          className={`flex h-[34px] items-center gap-2.5 rounded-sm px-2.5 text-left text-[13px] hover:bg-secondary-hover focus-visible:bg-secondary-hover disabled:text-faint ${
            item.danger ? 'text-danger' : 'text-fg'
          }`}
        >
          <Icon name={item.icon} size={18} />
          <span className="flex-1">{item.label}</span>
          <span className="font-mono text-[11px] text-muted">{item.key}</span>
        </button>
      ))}
    </div>
  );
}

/**
 * Rename dialog. Not in the design handoff: built from the confirmation
 * dialog layout and the input component.
 */
export function RenameDialog({ media, onClose }: { media: MediaRecord; onClose: () => void }) {
  const [title, setTitle] = useState(media.title);
  const [saving, setSaving] = useState(false);
  const rename = useLibrary((s) => s.rename);
  const inputRef = useRef<HTMLInputElement>(null);
  const titleId = useId();

  useEffect(() => {
    inputRef.current?.select();
  }, []);

  const submit = async () => {
    const value = title.trim();
    if (!value || value === media.title) return onClose();
    setSaving(true);
    if (await rename(media.id, value)) onClose();
    setSaving(false);
  };

  return (
    <div
      className="fixed inset-0 z-40 grid animate-fade-in place-items-center bg-scrim"
      onMouseDown={onClose}
    >
      <form
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onMouseDown={(e) => e.stopPropagation()}
        onKeyDown={(e) => e.key === 'Escape' && onClose()}
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
        className="flex w-[420px] max-w-[calc(100%-32px)] animate-dialog-in flex-col gap-3 rounded-xl border border-line-strong bg-surface p-6 shadow-dialog"
      >
        <h2 id={titleId} className="m-0 text-[17px] font-bold">
          Rename file
        </h2>
        <input
          ref={inputRef}
          value={title}
          maxLength={200}
          onChange={(e) => setTitle(e.target.value)}
          aria-label="New name"
          className="h-11 rounded-sm border border-line-strong bg-bg px-3 text-[13.5px] text-fg outline-none focus:border-accent focus:shadow-[0_0_0_3px_rgba(53,201,189,.18)]"
        />
        <p className="m-0 text-[12.5px] text-muted">
          The extension is kept. Unsafe characters are replaced and an existing file is never
          overwritten.
        </p>
        <div className="mt-1 flex justify-end gap-2">
          <Button type="button" onClick={onClose} className="h-[38px] text-[13px]">
            Cancel
          </Button>
          <Button
            type="submit"
            variant="primary"
            disabled={saving}
            className="h-[38px] text-[13px]"
          >
            Rename
          </Button>
        </div>
      </form>
    </div>
  );
}

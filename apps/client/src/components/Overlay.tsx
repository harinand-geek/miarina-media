import { useEffect, useId, useRef, type ReactNode } from 'react';
import { useUi } from '../stores/ui';
import { Button } from './Button';

/**
 * Confirmation dialog (design system §5): width 420, radius 14, scrim 62 %.
 * Esc and scrim choose the safe action; focus starts on the safe button.
 */
export function ConfirmDialog() {
  const confirm = useUi((s) => s.confirm);
  const close = useUi((s) => s.closeConfirm);
  const safeRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const titleId = useId();
  const bodyId = useId();

  useEffect(() => {
    if (!confirm) return;
    const previous = document.activeElement as HTMLElement | null;
    safeRef.current?.focus();
    return () => previous?.focus();
  }, [confirm]);

  if (!confirm) return null;

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      close();
    }
    if (e.key === 'Tab') {
      // Keep focus inside the dialog.
      const buttons = dialogRef.current?.querySelectorAll('button');
      if (!buttons?.length) return;
      const first = buttons[0]!;
      const last = buttons[buttons.length - 1]!;
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
  };

  return (
    <div
      className="absolute inset-0 z-40 grid animate-fade-in place-items-center bg-scrim"
      onMouseDown={close}
    >
      <div
        ref={dialogRef}
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={bodyId}
        onKeyDown={onKeyDown}
        onMouseDown={(e) => e.stopPropagation()}
        className="flex w-[420px] max-w-[calc(100%-32px)] animate-dialog-in flex-col gap-2.5 rounded-xl border border-line-strong bg-surface p-6 shadow-dialog"
      >
        <h2 id={titleId} className="m-0 text-[17px] font-bold">
          {confirm.title}
        </h2>
        <p id={bodyId} className="m-0 text-[13.5px] leading-normal text-muted">
          {confirm.body}
        </p>
        <div className="mt-3 flex justify-end gap-2">
          <Button ref={safeRef} onClick={close} className="h-[38px] text-[13px]">
            Keep
          </Button>
          <Button
            variant="destructive"
            className="h-[38px] text-[13px]"
            onClick={() => {
              confirm.onConfirm();
              close();
            }}
          >
            {confirm.confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}

interface BottomSheetProps {
  open: boolean;
  onClose: () => void;
  label: string;
  children: ReactNode;
  elevated?: boolean;
}

/** Android bottom sheet: drag handle, scrim tap dismisses, radius 24. */
export function BottomSheet({
  open,
  onClose,
  label,
  children,
  elevated = false,
}: BottomSheetProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <>
      <div
        className="absolute inset-0 z-30 animate-fade-in bg-[rgb(5_9_13/0.6)]"
        onClick={onClose}
        aria-hidden="true"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={label}
        className={`absolute inset-x-0 bottom-0 z-30 flex max-h-[88%] animate-sheet-in flex-col gap-3.5 overflow-auto rounded-t-2xl px-4 pb-5 pt-2.5 ${
          elevated ? 'bg-surface2' : 'bg-surface'
        }`}
      >
        <div className="h-1 w-9 self-center rounded-full bg-faint-icon" aria-hidden="true" />
        {children}
      </div>
    </>
  );
}

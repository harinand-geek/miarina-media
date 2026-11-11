import { useEffect, useRef } from 'react';
import { useUi, type Toast } from '../stores/ui';
import { Icon } from './Icon';

const TOAST_MS = 4000;

const PLACES = {
  desktop: 'bottom-5 right-5',
  // Windows v2: toasts clear the 68 px mini-player.
  aboveMiniPlayer: 'bottom-[84px] right-5',
  mobile: 'inset-x-4 bottom-24',
  // Browser: the page is a native view drawn above the app, so the toast
  // goes over the browser bar, one at a time.
  browser: 'inset-x-2 bottom-2 sm:left-auto',
};

/** Bottom-right, 4 s, max 2 stacked, paused on hover; errors persist. */
export function ToastHost({ position = 'desktop' }: { position?: keyof typeof PLACES }) {
  const all = useUi((s) => s.toasts);
  const toasts = position === 'browser' ? all.slice(-1) : all;
  return (
    <div
      aria-live="polite"
      className={`pointer-events-none absolute z-50 flex flex-col gap-2 ${PLACES[position]}`}
    >
      {toasts.map((t) => (
        <ToastItem key={t.id} toast={t} />
      ))}
    </div>
  );
}

function ToastItem({ toast }: { toast: Toast }) {
  const dismiss = useUi((s) => s.dismissToast);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const persistent = toast.tone === 'error';

  const arm = () => {
    if (persistent) return;
    timer.current = setTimeout(() => dismiss(toast.id), TOAST_MS);
  };
  const disarm = () => clearTimeout(timer.current);

  useEffect(() => {
    arm();
    return disarm;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div
      role={persistent ? 'alert' : 'status'}
      onMouseEnter={disarm}
      onMouseLeave={arm}
      className="pointer-events-auto flex min-w-[280px] animate-toast-in items-center gap-3 rounded-md border border-overlay-border bg-surface2 px-3.5 py-3 text-[13px] shadow-menu"
    >
      <Icon
        name={persistent ? 'error' : 'check_circle'}
        fill
        className={persistent ? 'text-danger' : 'text-accent-strong'}
      />
      <span className="flex-1">{toast.message}</span>
      {toast.action && (
        <button
          type="button"
          className="font-bold text-accent-strong"
          onClick={() => {
            toast.action!.run();
            dismiss(toast.id);
          }}
        >
          {toast.action.label}
        </button>
      )}
      {persistent && (
        <button
          type="button"
          aria-label="Dismiss"
          className="text-muted hover:text-fg"
          onClick={() => dismiss(toast.id)}
        >
          <Icon name="close" size={18} />
        </button>
      )}
    </div>
  );
}

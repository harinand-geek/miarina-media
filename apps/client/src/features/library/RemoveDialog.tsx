import { useEffect, useId, useRef, useState, type KeyboardEvent } from 'react';
import { Button } from '../../components/Button';
import { RadioDot } from '../../components/Controls';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { useUi } from '../../stores/ui';
import { applyRemoval } from './removal';

type Choice = 'remove' | 'delete';

/**
 * Windows v2 "Remove or delete" dialog (CDC COM-10): removing keeps the file,
 * deleting it is a separate, explicit choice. Focus starts on Cancel; Esc and
 * the scrim cancel.
 */
export function RemoveDialog() {
  const media = useUi((s) => s.removal);
  return media ? <Dialog key={media.id} media={media} /> : null;
}

function Dialog({ media }: { media: MediaRecord }) {
  const t = useT();
  const close = () => useUi.getState().askRemoval(null);
  const [choice, setChoice] = useState<Choice>('remove');
  const cancelRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const titleId = useId();

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    cancelRef.current?.focus();
    return () => previous?.focus();
  }, []);

  const destructive = choice === 'delete';

  const confirm = () => applyRemoval(media, destructive, t);

  const onKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      close();
    } else if (e.key === 'Tab') {
      const buttons = dialogRef.current?.querySelectorAll<HTMLButtonElement>('button');
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

  const options: { id: Choice; title: string; body: string }[] = [
    { id: 'remove', title: t('removeOption'), body: t('removeOptionBody') },
    // Windows: the file goes to the Recycle Bin (`trash`, L06).
    { id: 'delete', title: t('deleteOption'), body: t('deleteOptionTrashBody') },
  ];

  return (
    <div
      className="absolute inset-0 z-40 grid animate-fade-in place-items-center bg-scrim"
      onMouseDown={close}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onKeyDown={onKeyDown}
        onMouseDown={(e) => e.stopPropagation()}
        className="flex w-[460px] max-w-[calc(100%-32px)] animate-dialog-in flex-col gap-4 rounded-xl border border-line-strong bg-surface2 p-6 shadow-dialog"
      >
        <h2 id={titleId} className="m-0 text-[18px] font-bold">
          « {media.title} »
        </h2>
        <div role="radiogroup" aria-labelledby={titleId} className="flex flex-col gap-2">
          {options.map((o) => {
            const on = choice === o.id;
            const danger = o.id === 'delete';
            return (
              <button
                key={o.id}
                type="button"
                role="radio"
                aria-checked={on}
                onClick={() => setChoice(o.id)}
                className={`flex gap-3 rounded-md border p-3.5 text-left ${
                  on
                    ? `bg-surface ${danger ? 'border-danger' : 'border-accent'}`
                    : 'border-line hover:bg-surface'
                }`}
              >
                <span className="mt-px">
                  <RadioDot checked={on} size={20} tone={danger ? 'danger' : 'accent'} />
                </span>
                <span className="flex flex-col gap-[3px]">
                  <span className="text-[13.5px] font-bold">{o.title}</span>
                  <span className="text-[12.5px] leading-[1.45] text-muted">{o.body}</span>
                </span>
              </button>
            );
          })}
        </div>
        <span className="break-all font-mono text-[11.5px] text-muted">{media.path}</span>
        <div className="flex justify-end gap-2.5">
          <Button ref={cancelRef} onClick={close} className="h-[38px] text-[13.5px]">
            {t('cancel')}
          </Button>
          <Button
            variant={destructive ? 'destructive' : 'primary'}
            onClick={() => void confirm()}
            className="h-[38px] text-[13.5px]"
          >
            {destructive ? t('deleteConfirm') : t('removeConfirm')}
          </Button>
        </div>
      </div>
    </div>
  );
}

import { useEffect, useRef, useState } from 'react';
import { RadioDot } from '../../components/Controls';
import { BottomSheet } from '../../components/Overlay';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { applyRemoval, displayPath } from './removal';

type Choice = 'remove' | 'delete';

/**
 * Android v2 screen 11 "Remove or delete" (COM-10, P0): removing is the
 * default, deleting names the file and its size; Cancel has the focus.
 */
export function MobileRemoveSheet() {
  const media = useUi((s) => s.removal);
  return media ? <Sheet key={media.id} media={media} /> : null;
}

function Sheet({ media }: { media: MediaRecord }) {
  const t = useT();
  const [choice, setChoice] = useState<Choice>('remove');
  const cancelRef = useRef<HTMLButtonElement>(null);
  const close = () => useUi.getState().askRemoval(null);
  const destructive = choice === 'delete';

  useEffect(() => cancelRef.current?.focus(), []);

  const option = (id: Choice, title: string, children: React.ReactNode) => {
    const on = choice === id;
    const danger = id === 'delete';
    return (
      <button
        type="button"
        role="radio"
        aria-checked={on}
        onClick={() => setChoice(id)}
        className={`flex gap-3 rounded-xl border p-3.5 text-left ${
          on ? (danger ? 'border-danger bg-surface' : 'border-accent bg-selected') : 'border-line bg-surface'
        }`}
      >
        <span className="mt-0.5">
          <RadioDot checked={on} size={20} tone={danger ? 'danger' : 'accent'} />
        </span>
        <span className="flex min-w-0 flex-col gap-[3px]">
          <span className="text-[14.5px] font-bold">{title}</span>
          {children}
        </span>
      </button>
    );
  };

  return (
    <BottomSheet open onClose={close} label={t('mRemoveTitle', { title: media.title })} elevated>
      <div className="flex flex-col gap-1.5 px-1">
        <h2 className="m-0 text-[19px] font-extrabold">{t('mRemoveTitle', { title: media.title })}</h2>
        <p className="m-0 text-[14px] leading-5 text-muted">{t('mRemoveBody')}</p>
      </div>
      <div role="radiogroup" aria-label={t('removeOrDelete')} className="flex flex-col gap-2.5">
        {option(
          'remove',
          t('removeOption'),
          <span className="text-[13px] text-muted">{t('mRemoveOptionBody')}</span>,
        )}
        {option(
          'delete',
          t('mDeleteOption'),
          <>
            <span className="text-[13px] text-muted">{t('mDeleteOptionBody')}</span>
            <span className="break-all font-mono text-[11.5px] text-fg/80">
              {displayPath(media.path)} · {formatBytes(media.sizeBytes)}
            </span>
          </>,
        )}
      </div>
      <div className="flex gap-2.5 pt-1">
        <button
          ref={cancelRef}
          type="button"
          onClick={close}
          className="h-[52px] flex-1 rounded-full border-2 border-accent bg-surface text-[15px] font-bold"
        >
          {t('cancel')}
        </button>
        <button
          type="button"
          onClick={() => void applyRemoval(media, destructive, t)}
          className={`h-[52px] flex-1 rounded-full text-[15px] font-bold ${
            destructive
              ? 'bg-destructive text-white active:bg-destructive-press'
              : 'bg-line-strong text-fg active:bg-secondary-hover'
          }`}
        >
          {destructive ? t('deleteConfirm') : t('removeConfirm')}
        </button>
      </div>
    </BottomSheet>
  );
}

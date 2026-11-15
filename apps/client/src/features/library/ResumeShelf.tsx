import { useEffect, useMemo, useState } from 'react';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import { RESUME_MARGIN_SECS, savedPosition } from '../player/usePlayback';
import { durationLabel } from './format';
import { MediaThumb } from './MediaThumb';
import { useMobileMediaSheet } from './useMobileMediaSheet';

const RESUME_SCAN = 100;
const CAROUSEL = 8;

function useStarted() {
  const [items, setItems] = useState<MediaRecord[]>([]);
  useEffect(() => {
    let alive = true;
    const load = () =>
      backend
        .libraryQuery({ search: '', kind: 'video', sort: 'added', limit: RESUME_SCAN })
        .then((page) => alive && setItems(page.items))
        .catch(() => {});
    void load();
    const stop = backend.onLibraryChanged(() => void load());
    return () => {
      alive = false;
      stop();
    };
  }, []);
  return useMemo(
    () =>
      items
        .filter((m) => {
          const at = savedPosition(m.id);
          return at > 0 && (!m.durationSecs || at < m.durationSecs - RESUME_MARGIN_SECS);
        })
        .slice(0, CAROUSEL),
    [items],
  );
}

/**
 * Android "Continue watching" (COM-04): started videos, newest first, as a
 * carousel whose items form the queue. Lives on top of Videos since the Home
 * tab was folded away (decision 0006); hidden when nothing is started.
 */
export function ResumeShelf() {
  const t = useT();
  const items = useStarted();
  const actionsSheet = useMobileMediaSheet();
  if (!items.length) return null;
  return (
    <section aria-label={t('resumeTitle')} className="flex flex-col gap-2.5">
      <h2 className="m-0 text-[15px] font-bold">{t('resumeTitle')}</h2>
      <ul className="-mx-4 m-0 flex list-none gap-3 overflow-x-auto px-4 pb-1 [scrollbar-width:none]">
        {items.map((item) => {
          const at = savedPosition(item.id);
          const pct = item.durationSecs ? Math.min(100, (at / item.durationSecs) * 100) : 0;
          return (
            <li key={item.id} className="flex w-[168px] shrink-0 flex-col gap-1.5">
              <button
                type="button"
                onClick={() => useMobilePlayback.getState().start(item, items, t('resumeTitle'))}
                onContextMenu={(e) => {
                  e.preventDefault();
                  actionsSheet.open(item);
                }}
                aria-label={t('playTitle', { title: item.title })}
                className="block"
              >
                <MediaThumb media={item} className="h-[94px] w-full rounded-[10px]">
                  {pct > 0 && (
                    <span
                      className="absolute inset-x-0 bottom-0 h-[3px] bg-line"
                      aria-hidden="true"
                    >
                      <span className="block h-full bg-coral" style={{ width: `${pct}%` }} />
                    </span>
                  )}
                </MediaThumb>
              </button>
              <span className="flex items-start gap-1">
                <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span className="truncate text-[13px] font-semibold">{item.title}</span>
                  <span className="font-mono text-[12px] text-muted">
                    {`${formatClock(at, false)} / ${durationLabel(item.durationSecs)}`}
                  </span>
                </span>
                <button
                  type="button"
                  aria-label={t('actionsFor', { title: item.title })}
                  onClick={() => actionsSheet.open(item)}
                  className="-mr-2 grid h-9 w-9 shrink-0 place-items-center text-muted"
                >
                  <Icon name="more_vert" size={20} />
                </button>
              </span>
            </li>
          );
        })}
      </ul>
      {actionsSheet.sheet}
    </section>
  );
}

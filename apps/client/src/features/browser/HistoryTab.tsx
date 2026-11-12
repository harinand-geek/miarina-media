import { useCallback, useEffect, useState } from 'react';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { Favorite, Visit } from '../../services/types';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { useNow } from '../downloads/useNow';
import { groupByDay } from '../history/grouping';
import { hostOf } from './candidates';

/** Waits this long after typing before searching. */
const SEARCH_DELAY_MS = 150;

/**
 * The internal history tab (miarina://history, NAV-03): pages visited and
 * favorites, searchable. Kept on this device; clearing it deletes no file,
 * download or favorite.
 */
export function HistoryTab({
  view,
  onView,
  favorites,
  onOpen,
  onUnstar,
}: {
  view: 'history' | 'favorites';
  onView: (view: 'history' | 'favorites') => void;
  favorites: Favorite[];
  onOpen: (url: string) => void;
  onUnstar: (favorite: Favorite) => void;
}) {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const [query, setQuery] = useState('');
  const [visits, setVisits] = useState<Visit[] | null>(null);
  const now = useNow(60_000);

  const load = useCallback((q: string) => {
    backend
      .browserHistory(q)
      .then(setVisits)
      .catch(() => setVisits([]));
  }, []);
  useEffect(() => {
    const timer = window.setTimeout(() => load(query), SEARCH_DELAY_MS);
    return () => window.clearTimeout(timer);
  }, [query, load]);

  const remove = (visit: Visit) => {
    setVisits((list) => list?.filter((v) => v.id !== visit.id) ?? null);
    void backend.browserHistoryDelete(visit.id).catch(() => load(query));
  };
  const clear = () =>
    useUi.getState().askConfirm({
      title: t('bClearTitle'),
      body: t('bClearBody'),
      confirmLabel: t('clearHistory'),
      onConfirm: () => {
        void backend
          .browserHistoryClear()
          .then(() => {
            setVisits([]);
            useUi.getState().pushToast({ tone: 'success', message: t('bCleared') });
          })
          .catch(() => {});
      },
    });

  const q = query.trim().toLowerCase();
  const stars = favorites.filter(
    (f) => !q || f.title.toLowerCase().includes(q) || f.url.toLowerCase().includes(q),
  );
  const empty = view === 'history' ? visits !== null && visits.length === 0 : stars.length === 0;

  return (
    <main className="h-full overflow-auto">
      <div className="mx-auto flex max-w-[900px] flex-col gap-5 px-8 pb-8 pt-7">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="m-0 flex-1 text-[24px] font-extrabold tracking-[-0.02em]">
            {view === 'history' ? t('bHistory') : t('favorites')}
          </h1>
          <div
            role="radiogroup"
            aria-label={t('bHistoryViews')}
            className="flex rounded-[7px] border border-line bg-bg p-[3px]"
          >
            {(['history', 'favorites'] as const).map((id) => (
              <button
                key={id}
                type="button"
                role="radio"
                aria-checked={view === id}
                onClick={() => onView(id)}
                className={`h-[30px] rounded-[5px] px-3.5 text-[12.5px] font-semibold ${
                  view === id ? 'bg-surface2 text-fg' : 'text-muted'
                }`}
              >
                {id === 'history' ? t('bHistory') : t('favorites')}
              </button>
            ))}
          </div>
          {view === 'history' && (
            <button
              type="button"
              onClick={clear}
              disabled={!visits?.length && !query}
              className="flex h-[34px] items-center gap-2 rounded-sm border border-line-strong px-3 text-[13px] font-semibold disabled:opacity-50"
            >
              <Icon name="delete_sweep" size={18} />
              {t('clearHistory')}
            </button>
          )}
        </div>

        <label className="flex h-10 items-center gap-2 rounded-sm border border-line-strong bg-surface px-3">
          <Icon name="search" size={18} className="text-muted" />
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            aria-label={t('bHistorySearch')}
            placeholder={t('bHistorySearch')}
            className="min-w-0 flex-1 bg-transparent text-[13.5px] outline-none placeholder:text-muted"
          />
        </label>

        {empty ? (
          <p className="m-0 py-10 text-center text-[13.5px] text-muted">
            {q
              ? t('bNoMatch', { q: query.trim() })
              : view === 'history'
                ? t('bHistoryEmpty')
                : t('bFavoritesEmpty')}
          </p>
        ) : view === 'history' ? (
          groupByDay(visits ?? [], (v) => v.visitedAt, now, lang).map((group) => (
            <section key={group.day} aria-label={group.day} className="flex flex-col gap-1">
              <h2 className="m-0 pb-1 text-[12px] font-bold uppercase tracking-[0.06em] text-muted">
                {group.day}
              </h2>
              {group.entries.map((visit) => (
                <PageRow
                  key={visit.id}
                  title={visit.title || hostOf(visit.url)}
                  url={visit.url}
                  time={new Date(visit.visitedAt).toLocaleTimeString(
                    lang === 'fr' ? 'fr-FR' : 'en-GB',
                    {
                      hour: '2-digit',
                      minute: '2-digit',
                    },
                  )}
                  onOpen={() => onOpen(visit.url)}
                  removeLabel={t('bDeleteVisit', { title: visit.title || hostOf(visit.url) })}
                  onRemove={() => remove(visit)}
                />
              ))}
            </section>
          ))
        ) : (
          <section aria-label={t('favorites')} className="flex flex-col gap-1">
            {stars.map((f) => (
              <PageRow
                key={f.url}
                title={f.title}
                url={f.url}
                onOpen={() => onOpen(f.url)}
                removeLabel={t('bRemoveFavorite', { title: f.title })}
                onRemove={() => onUnstar(f)}
              />
            ))}
          </section>
        )}
        <p className="m-0 text-[12px] text-muted">{t('bHistoryNote')}</p>
      </div>
    </main>
  );
}

function PageRow({
  title,
  url,
  time,
  onOpen,
  removeLabel,
  onRemove,
}: {
  title: string;
  url: string;
  time?: string;
  onOpen: () => void;
  removeLabel: string;
  onRemove: () => void;
}) {
  return (
    <div className="group flex items-center gap-3 rounded-sm px-2 hover:bg-surface">
      {time && <span className="w-11 shrink-0 font-mono text-[11.5px] text-muted">{time}</span>}
      <button
        type="button"
        onClick={onOpen}
        title={url}
        className="flex h-11 min-w-0 flex-1 items-center gap-3 text-left"
      >
        <Icon name="public" size={18} className="shrink-0 text-muted" />
        <span className="min-w-0 truncate text-[13.5px] font-semibold">{title}</span>
        <span className="min-w-0 shrink truncate font-mono text-[11.5px] text-muted">
          {hostOf(url)}
        </span>
      </button>
      <button
        type="button"
        onClick={onRemove}
        aria-label={removeLabel}
        title={removeLabel}
        className="grid size-8 shrink-0 place-items-center rounded-sm text-muted hover:bg-line-strong hover:text-fg"
      >
        <Icon name="close" size={18} />
      </button>
    </div>
  );
}

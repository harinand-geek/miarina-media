import { useEffect, useMemo, useState } from 'react';
import { Icon } from '../../components/Icon';
import { VirtualGrid } from '../../components/VirtualGrid';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { savedPosition } from '../player/usePlayback';
import { durationLabel, folderOf, qualityLabel } from './format';
import { MediaThumb } from './MediaThumb';
import { useMobileMediaSheet } from './useMobileMediaSheet';

type Filter = { kind: 'all' } | { kind: 'progress' } | { kind: 'folder'; path: string };

const lastSegment = (path: string) => path.split(/[\\/]/).filter(Boolean).pop() ?? path;
const extension = (path: string) => path.split('.').pop()?.toUpperCase() ?? '';

/** Android v2 Videos (screen 14): filters, 2-column grid, resume bar. */
export function MobileVideos() {
  const t = useT();
  const { items, ready, search, setSearch } = useLibrary();
  const synced = useLibrary((s) => s.kind === 'video' && s.group === null);
  const [filter, setFilter] = useState<Filter>({ kind: 'all' });
  const [searching, setSearching] = useState(false);
  const [asList, setAsList] = useState(false);
  const [scroller, setScroller] = useState<HTMLDivElement | null>(null);
  const actionsSheet = useMobileMediaSheet();

  useEffect(() => {
    useLibrary.getState().show('video', null);
  }, []);

  const all = useMemo(() => (synced ? items : []), [synced, items]);
  const resumeOf = (m: MediaRecord) => {
    const at = savedPosition(m.id);
    return at > 0 && m.durationSecs ? Math.min(100, (at / m.durationSecs) * 100) : 0;
  };
  const inProgress = all.filter((m) => resumeOf(m) > 0);
  const folders = useMemo(() => [...new Set(all.map((m) => folderOf(m.path)))], [all]);
  const shown =
    filter.kind === 'progress'
      ? inProgress
      : filter.kind === 'folder'
        ? all.filter((m) => folderOf(m.path) === filter.path)
        : all;

  const chip = (on: boolean, label: string, onClick: () => void, key: string) => (
    <button
      key={key}
      type="button"
      role="radio"
      aria-checked={on}
      onClick={onClick}
      className={`h-[34px] shrink-0 rounded-full border px-3 text-[12.5px] ${
        on
          ? 'border-chip-border bg-accent-subtle font-bold text-chip-text'
          : 'border-line-strong font-semibold text-muted'
      }`}
    >
      {label}
    </button>
  );

  return (
    <div ref={setScroller} className="relative flex flex-1 flex-col gap-3.5 overflow-auto px-4 pb-3 pt-1">
      <div className="flex h-12 items-center gap-1">
        <h1 className="m-0 flex-1 text-[22px] font-extrabold tracking-[-0.01em]">{t('tabVideos')}</h1>
        <button
          type="button"
          aria-label={t('mSearch')}
          aria-pressed={searching}
          onClick={() => setSearching((s) => !s)}
          className="grid h-11 w-11 place-items-center"
        >
          <Icon name="search" size={24} />
        </button>
        <button
          type="button"
          aria-label={asList ? t('gridView') : t('listView')}
          onClick={() => setAsList((l) => !l)}
          className="grid h-11 w-11 place-items-center"
        >
          <Icon name={asList ? 'grid_view' : 'view_list'} size={24} />
        </button>
      </div>
      {searching && (
        <label className="flex h-12 items-center gap-2.5 rounded-3xl bg-surface px-4">
          <Icon name="search" size={20} className="text-muted" />
          <input
            type="search"
            autoFocus
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t('librarySearch')}
            aria-label={t('librarySearch')}
            className="min-w-0 flex-1 bg-transparent text-[15px] font-medium text-fg outline-none focus-visible:outline-none"
          />
        </label>
      )}
      <div
        role="radiogroup"
        aria-label={t('tabVideos')}
        className="-mx-4 flex gap-2 overflow-x-auto px-4 [scrollbar-width:none]"
      >
        {chip(filter.kind === 'all', t('allVideos', { n: all.length }), () => setFilter({ kind: 'all' }), 'all')}
        {inProgress.length > 0 &&
          chip(
            filter.kind === 'progress',
            t('inProgress', { n: inProgress.length }),
            () => setFilter({ kind: 'progress' }),
            'progress',
          )}
        {folders.length > 1 &&
          folders.map((path) =>
            chip(
              filter.kind === 'folder' && filter.path === path,
              lastSegment(path),
              () => setFilter({ kind: 'folder', path }),
              path,
            ),
          )}
      </div>
      {ready && synced && shown.length === 0 && (
        <p className="py-10 text-center text-[13.5px] text-muted">
          {search.trim() ? t('noMatch', { q: search.trim() }) : t('noItems')}
        </p>
      )}
      <VirtualGrid
        label={t('tabVideos')}
        items={shown}
        scrollRef={{ current: scroller }}
        columns={asList ? 1 : 2}
        columnGap={12}
        rowGap={asList ? 10 : 16}
        rowHeight={(w) => (asList ? 72 : (w * 9) / 16 + 6 + 38)}
        getKey={(m) => String(m.id)}
        renderItem={(m) => {
          const resume = resumeOf(m);
          const meta = [extension(m.path), qualityLabel(m)].filter(Boolean).join(' · ');
          const thumb = (
            <MediaThumb
              media={m}
              className={asList ? 'aspect-video h-[72px] rounded-[10px]' : 'aspect-video w-full rounded-[10px]'}
            >
              {m.durationSecs != null && (
                <span className="absolute bottom-2 right-1.5 rounded-xs bg-[rgb(5_9_13/0.8)] px-[5px] py-px font-mono text-[10.5px] font-bold">
                  {durationLabel(m.durationSecs)}
                </span>
              )}
              {resume > 0 && (
                <span className="absolute inset-x-0 bottom-0 h-[3px] bg-line" aria-hidden="true">
                  <span className="block h-full bg-coral" style={{ width: `${resume}%` }} />
                </span>
              )}
            </MediaThumb>
          );
          return (
            <div className={`flex ${asList ? 'items-center gap-3' : 'flex-col gap-1.5'}`}>
              <button
                type="button"
                onClick={() => useUi.getState().play(m, shown)}
                onContextMenu={(e) => {
                  e.preventDefault();
                  actionsSheet.open(m);
                }}
                aria-label={t('playTitle', { title: m.title })}
                className={asList ? 'shrink-0' : 'block w-full'}
              >
                {thumb}
              </button>
              <div className="flex min-w-0 flex-1 items-start gap-1">
                <span className="flex min-w-0 flex-1 flex-col gap-px">
                  <span className="truncate text-[13.5px] font-bold">{m.title}</span>
                  <span className="truncate font-mono text-[11px] text-muted">
                    {asList ? `${meta} · ${formatBytes(m.sizeBytes)}` : meta}
                  </span>
                </span>
                <button
                  type="button"
                  aria-label={t('moreActions')}
                  onClick={() => actionsSheet.open(m)}
                  className="-mr-2 -mt-1 grid h-9 w-9 shrink-0 place-items-center text-muted"
                >
                  <Icon name="more_vert" size={20} />
                </button>
              </div>
            </div>
          );
        }}
      />
      {actionsSheet.sheet}
    </div>
  );
}

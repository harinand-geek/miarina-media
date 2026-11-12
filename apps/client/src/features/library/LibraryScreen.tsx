import { useEffect, useRef, useState, type KeyboardEvent, type MouseEvent } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { Button } from '../../components/Button';
import { EmptyState, ThumbBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import type { GroupBy, MediaRecord, MediaSort } from '../../services/types';
import { useT, type MessageKey } from '../../i18n';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { usePlayer } from '../../stores/player';
import { useUi, type LibraryView } from '../../stores/ui';
import { playFrom } from '../../app/navigation';
import { durationLabel, qualityLabel } from './format';
import { GroupsView } from './GroupsView';
import { MediaContextMenu, RenameDialog, type MenuTarget } from './MediaActions';
import { useMediaActions } from './useMediaActions';
import { MediaThumb } from './MediaThumb';
import { TracksTable } from './TracksTable';

const LIST_COLUMNS = 'grid-cols-[56px_minmax(0,1fr)_180px_80px_90px_90px]';

const SORTS: Record<MediaSort, MessageKey> = {
  added: 'sortAdded',
  title: 'sortTitle',
  size: 'sortSize',
  duration: 'sortDuration',
};

const GROUP_OF: Partial<Record<LibraryView, GroupBy>> = {
  albums: 'album',
  artists: 'artist',
  folders: 'folder',
};

const folderName = (path: string) => path.split(/[\\/]/).filter(Boolean).pop() ?? path;

export default function LibraryScreen() {
  const t = useT();
  const { search, kind, sort, items, total, overview, ready, group } = useLibrary();
  const { setSearch, setSort } = useLibrary.getState();
  const libraryView = useUi((s) => s.libraryView);
  const opened = useUi((s) => s.libraryGroup);
  const isVideos = libraryView === 'videos';
  const groupBy = GROUP_OF[libraryView] ?? null;
  const showGroups = groupBy !== null && opened === null;
  const wantedKind = isVideos ? 'video' : 'audio';
  const [videoView, setVideoView] = useState<'grid' | 'list'>('grid');
  const [menu, setMenu] = useState<MenuTarget | null>(null);
  const [renaming, setRenaming] = useState<MediaRecord | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const focusRequest = useUi((s) => s.librarySearchFocus);
  const go = useUi((s) => s.go);
  const actions = useMediaActions();

  useEffect(() => {
    if (focusRequest > 0) searchRef.current?.focus();
  }, [focusRequest]);

  // The navigation (view and opened group) decides what the store lists.
  useEffect(() => {
    useLibrary.getState().show(wantedKind, opened);
  }, [wantedKind, opened]);

  const synced = kind === wantedKind && group?.by === opened?.by && group?.name === opened?.name;

  // Library-wide count: hidden while searching, where it would not match.
  const count = search.trim()
    ? undefined
    : opened
      ? total
      : isVideos
        ? overview?.stats.videoCount
        : libraryView === 'tracks'
          ? overview?.stats.audioCount
          : undefined;

  /** Right click, ⇧F10 / context-menu key, plus the design's shortcuts. */
  const itemHandlers = (m: MediaRecord) => ({
    onContextMenu: (e: MouseEvent) => {
      e.preventDefault();
      setMenu({ media: m, x: e.clientX, y: e.clientY });
    },
    onKeyDown: (e: KeyboardEvent<HTMLElement>) => {
      const rect = e.currentTarget.getBoundingClientRect();
      if (e.key === 'ContextMenu' || (e.shiftKey && e.key === 'F10')) {
        e.preventDefault();
        setMenu({ media: m, x: rect.left + 16, y: rect.top + 16 });
      } else if (e.key === 'F2') {
        e.preventDefault();
        setRenaming(m);
      } else if (e.key === 'Delete') {
        e.preventDefault();
        actions.askDelete(m);
      } else if (e.ctrlKey && e.key.toLowerCase() === 'e') {
        e.preventDefault();
        actions.reveal(m);
      }
    },
  });

  const empty = ready && synced && items.length === 0;
  const filtered = search.trim() !== '';
  // The visible list becomes the play queue (COM-03).
  const open = (m: MediaRecord) => actions.open(m, items);
  const editTags = (m: MediaRecord) => useUi.setState({ tagEditor: m });
  const playAll = (shuffle: boolean) => {
    const first = shuffle ? items[Math.floor(Math.random() * items.length)] : items[0];
    if (!first) return;
    playFrom(first, items);
    if (shuffle) usePlayer.getState().setShuffle(true);
  };

  const heading = opened
    ? opened.by === 'folder'
      ? folderName(opened.name)
      : opened.name
    : t(libraryView);

  return (
    <div ref={scrollRef} className="relative flex flex-1 flex-col gap-5 overflow-auto px-10 py-7">
      {opened && (
        <button
          type="button"
          onClick={() => useUi.setState({ libraryGroup: null })}
          className="-mb-2 flex items-center gap-1.5 self-start text-[13px] font-semibold text-muted hover:text-fg"
        >
          <Icon name="arrow_back" size={18} />
          {t('back')}
        </button>
      )}
      <div className="flex items-center gap-3">
        <div className="flex min-w-0 flex-col gap-0.5">
          <h1 className="m-0 flex items-baseline gap-2.5 truncate text-title-lg font-extrabold tracking-[-0.02em]">
            <span className="truncate">{heading}</span>
            {count !== undefined && (
              <span className="font-mono text-[13px] font-medium text-muted">{count}</span>
            )}
          </h1>
          {opened?.by === 'folder' && (
            <span className="truncate font-mono text-[11.5px] text-muted" title={opened.name}>
              {opened.name}
            </span>
          )}
        </div>
        <span className="flex-1" />
        {opened && items.length > 0 && (
          <>
            <Button
              size="sm"
              onClick={() => playAll(false)}
              className="h-9 gap-1.5 !border-transparent !bg-coral text-[13px] !text-coral-ink hover:!bg-coral-hover"
            >
              <Icon name="play_arrow" size={18} fill />
              {t('playAll')}
            </Button>
            <Button size="sm" onClick={() => playAll(true)} className="h-9 gap-1.5 text-[13px]">
              <Icon name="shuffle" size={18} />
              {t('shufflePlay')}
            </Button>
          </>
        )}
        {!showGroups && (
          <label className="flex h-9 w-[280px] items-center gap-2 rounded-sm border border-line bg-surface px-2.5 focus-within:border-accent">
            <Icon name="search" size={18} className="text-muted" />
            <input
              ref={searchRef}
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t('librarySearch')}
              aria-label={t('librarySearch')}
              className="flex-1 bg-transparent text-[13px] font-medium text-fg outline-none focus-visible:outline-none"
            />
          </label>
        )}
        {!showGroups && opened?.by !== 'album' && (
          <Menu
            label={t('sort')}
            trigger={({ open: isOpen, toggle, id }) => (
              <button
                type="button"
                aria-haspopup="menu"
                aria-expanded={isOpen}
                aria-controls={id}
                onClick={toggle}
                className="flex h-9 items-center gap-1.5 rounded-sm border border-line bg-surface px-3 text-[13px]"
              >
                <span className="text-muted">{t('sort')}</span>
                <span className="font-semibold">{t(SORTS[sort])}</span>
                <Icon name="expand_more" size={18} className="text-muted" />
              </button>
            )}
            items={(Object.keys(SORTS) as MediaSort[]).map((key) => ({
              label: t(SORTS[key]),
              selected: key === sort,
              onSelect: () => setSort(key),
            }))}
          />
        )}
        {isVideos && (
          <div
            role="radiogroup"
            aria-label={t('gridView')}
            className="flex rounded-[7px] border border-line bg-surface p-[3px]"
          >
            {(['grid', 'list'] as const).map((v) => (
              <button
                key={v}
                type="button"
                role="radio"
                aria-checked={videoView === v}
                aria-label={v === 'grid' ? t('gridView') : t('listView')}
                title={v === 'grid' ? t('gridView') : t('listView')}
                onClick={() => setVideoView(v)}
                className={`grid h-7 w-8 place-items-center rounded-[5px] text-fg ${videoView === v ? 'bg-line-strong' : ''}`}
              >
                <Icon name={v === 'grid' ? 'grid_view' : 'view_list'} size={18} />
              </button>
            ))}
          </div>
        )}
      </div>

      {showGroups && <GroupsView by={groupBy} />}

      {!showGroups &&
        empty &&
        (filtered || opened ? (
          <EmptyState>{filtered ? t('noMatch', { q: search.trim() }) : t('noItems')}</EmptyState>
        ) : (
          <EmptyState
            icon={isVideos ? 'movie' : 'library_music'}
            title={t('emptyLibTitle')}
            action={
              <Button
                variant="primary"
                size="sm"
                className="h-9 text-[13px]"
                onClick={() => go('home')}
              >
                {t('pasteLink')}
              </Button>
            }
          >
            {t('emptyLibBody')}
          </EmptyState>
        ))}

      {!showGroups && synced && items.length > 0 && !isVideos && (
        <TracksTable
          items={items}
          scrollRef={scrollRef}
          onPlay={open}
          onEditTags={editTags}
          onMore={(m, e) => setMenu({ media: m, x: e.clientX, y: e.clientY })}
          handlers={itemHandlers}
          showTrackNo={opened?.by === 'album'}
        />
      )}

      {synced && items.length > 0 && isVideos && videoView === 'grid' && (
        <VirtualGrid
          label={`Library items, ${total} results`}
          items={items}
          scrollRef={scrollRef}
          minColumnWidth={210}
          columnGap={16}
          rowGap={18}
          rowHeight={(w) => (w * 9) / 16 + 10 + 40}
          getKey={(m) => String(m.id)}
          renderItem={(m) => (
            <button
              type="button"
              onClick={() => open(m)}
              {...itemHandlers(m)}
              className="group flex w-full flex-col gap-2.5 rounded-md text-left"
            >
              <MediaThumb
                media={m}
                className="aspect-video w-full rounded-md text-[10px] group-hover:outline-2 group-hover:outline-offset-2 group-hover:outline-accent"
              >
                {m.durationSecs != null && (
                  <ThumbBadge position="br">{durationLabel(m.durationSecs)}</ThumbBadge>
                )}
                <ThumbBadge position="tl">{qualityLabel(m)}</ThumbBadge>
              </MediaThumb>
              <span className="flex w-full flex-col gap-0.5">
                <span className="truncate text-[13.5px] font-semibold">{m.title}</span>
                <span className="truncate text-[12px] text-muted">
                  {m.sourceHost ? `${m.sourceHost} · ` : ''}
                  {formatBytes(m.sizeBytes)}
                </span>
              </span>
            </button>
          )}
        />
      )}

      {synced && items.length > 0 && isVideos && videoView === 'list' && (
        <LibraryList items={items} scrollRef={scrollRef} onOpen={open} handlers={itemHandlers} />
      )}

      {menu && (
        <MediaContextMenu target={menu} onClose={() => setMenu(null)} onRename={setRenaming} />
      )}
      {renaming && <RenameDialog media={renaming} onClose={() => setRenaming(null)} />}
    </div>
  );
}

function LibraryList({
  items,
  scrollRef,
  onOpen,
  handlers,
}: {
  items: MediaRecord[];
  scrollRef: React.RefObject<HTMLDivElement | null>;
  onOpen: (item: MediaRecord) => void;
  handlers: (m: MediaRecord) => {
    onContextMenu: (e: MouseEvent) => void;
    onKeyDown: (e: KeyboardEvent<HTMLElement>) => void;
  };
}) {
  const t = useT();
  const [body, setBody] = useState<HTMLDivElement | null>(null);
  // eslint-disable-next-line react-hooks/incompatible-library -- TanStack Virtual is not memoizable; the React Compiler is not used here.
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => 49,
    overscan: 8,
    scrollMargin: body?.offsetTop ?? 0,
  });

  return (
    <div
      role="table"
      aria-label={t('libraryItems')}
      className="overflow-hidden rounded-lg border border-surface2"
    >
      <div
        role="row"
        className={`grid ${LIST_COLUMNS} h-9 items-center gap-4 bg-row px-4 text-[11.5px] font-semibold uppercase tracking-[0.04em] text-muted`}
      >
        <span role="columnheader" />
        <span role="columnheader">{t('colTitle')}</span>
        <span role="columnheader">{t('colSource')}</span>
        <span role="columnheader">{t('colLength')}</span>
        <span role="columnheader">{t('colQuality')}</span>
        <span role="columnheader" className="text-right">
          {t('colSize')}
        </span>
      </div>
      <div ref={setBody} className="relative" style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map((row) => {
          const m = items[row.index]!;
          const { onContextMenu, onKeyDown } = handlers(m);
          return (
            <div
              key={m.id}
              role="row"
              tabIndex={0}
              onClick={() => onOpen(m)}
              onContextMenu={onContextMenu}
              onKeyDown={(e) => {
                if (e.key === 'Enter') onOpen(m);
                else onKeyDown(e);
              }}
              className={`absolute left-0 top-0 grid w-full ${LIST_COLUMNS} h-12 cursor-pointer items-center gap-4 border-t border-surface2 px-4 text-[13px] hover:bg-surface`}
              style={{ transform: `translateY(${row.start - virtualizer.options.scrollMargin}px)` }}
            >
              <MediaThumb media={m} className="h-8 w-14 rounded-xs" />
              <span role="cell" className="truncate font-semibold">
                {m.title}
              </span>
              <span role="cell" className="truncate text-muted">
                {m.sourceHost ?? '—'}
              </span>
              <span role="cell" className="font-mono text-[12px] text-muted">
                {durationLabel(m.durationSecs)}
              </span>
              <span role="cell" className="text-muted">
                {qualityLabel(m)}
              </span>
              <span role="cell" className="text-right font-mono text-[12px] text-muted">
                {formatBytes(m.sizeBytes)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

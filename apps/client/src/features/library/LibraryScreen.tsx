import { useEffect, useRef, useState, type KeyboardEvent, type MouseEvent } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { Chip } from '../../components/Controls';
import { Button } from '../../components/Button';
import { EmptyState, ThumbBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import type { MediaKind, MediaRecord, MediaSort } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { SORT_LABELS, durationLabel, qualityLabel } from './format';
import { MediaContextMenu, RenameDialog, type MenuTarget } from './MediaActions';
import { useMediaActions } from './useMediaActions';
import { MediaThumb } from './MediaThumb';

const LIST_COLUMNS = 'grid-cols-[56px_minmax(0,1fr)_180px_80px_90px_90px]';

const KINDS: { value: MediaKind | null; label: string }[] = [
  { value: null, label: 'All' },
  { value: 'video', label: 'Video' },
  { value: 'audio', label: 'Audio' },
];

export default function LibraryScreen() {
  const { search, kind, sort, items, total, overview, ready } = useLibrary();
  const { setSearch, setKind, setSort } = useLibrary.getState();
  const [view, setView] = useState<'grid' | 'list'>('grid');
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

  const counts: Record<string, number | undefined> = {
    All: overview?.stats.count,
    Video: overview?.stats.videoCount,
    Audio: overview?.stats.audioCount,
  };

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

  const empty = ready && items.length === 0;
  const filtered = search.trim() !== '' || kind !== null;

  return (
    <div ref={scrollRef} className="relative flex flex-1 flex-col gap-5 overflow-auto px-10 py-7">
      <div className="flex items-center gap-3">
        <h1 className="m-0 flex-1 text-title-lg font-bold tracking-[-0.02em]">Library</h1>
        <label className="flex h-9 w-[280px] items-center gap-2 rounded-sm border border-line bg-surface px-2.5 focus-within:border-accent">
          <Icon name="search" size={18} className="text-muted" />
          <input
            ref={searchRef}
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search titles"
            aria-label="Search titles"
            className="flex-1 bg-transparent text-[13px] font-medium text-fg outline-none focus-visible:outline-none"
          />
        </label>
        <Menu
          label="Sort by"
          trigger={({ open, toggle, id }) => (
            <button
              type="button"
              aria-haspopup="menu"
              aria-expanded={open}
              aria-controls={id}
              onClick={toggle}
              className="flex h-9 items-center gap-1.5 rounded-sm border border-line bg-surface px-3 text-[13px]"
            >
              <span className="text-muted">Sort</span>
              <span className="font-semibold">{SORT_LABELS[sort]}</span>
              <Icon name="expand_more" size={18} className="text-muted" />
            </button>
          )}
          items={(Object.keys(SORT_LABELS) as MediaSort[]).map((key) => ({
            label: SORT_LABELS[key],
            selected: key === sort,
            onSelect: () => setSort(key),
          }))}
        />
        <div
          role="radiogroup"
          aria-label="View"
          className="flex rounded-[7px] border border-line bg-surface p-[3px]"
        >
          {(['grid', 'list'] as const).map((v) => (
            <button
              key={v}
              type="button"
              role="radio"
              aria-checked={view === v}
              aria-label={v === 'grid' ? 'Grid view' : 'List view'}
              title={v === 'grid' ? 'Grid view' : 'List view'}
              onClick={() => setView(v)}
              className={`grid h-7 w-8 place-items-center rounded-[5px] text-fg ${view === v ? 'bg-line-strong' : ''}`}
            >
              <Icon name={v === 'grid' ? 'grid_view' : 'view_list'} size={18} />
            </button>
          ))}
        </div>
      </div>

      <div className="flex gap-2">
        {KINDS.map((k) => (
          <Chip
            key={k.label}
            selected={kind === k.value}
            onClick={() => setKind(k.value)}
            count={counts[k.label]}
          >
            {k.label}
          </Chip>
        ))}
      </div>

      {empty &&
        (filtered ? (
          <EmptyState>
            {search.trim() ? `No items match “${search.trim()}”.` : 'No items in this category.'}
          </EmptyState>
        ) : (
          <EmptyState
            icon="video_library"
            title="Your library is empty"
            action={
              <Button
                variant="primary"
                size="sm"
                className="h-9 text-[13px]"
                onClick={() => go('home')}
              >
                Paste a link
              </Button>
            }
          >
            Downloaded videos and audio appear here.
          </EmptyState>
        ))}

      {items.length > 0 && view === 'grid' && (
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
              onClick={() => actions.open(m)}
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

      {items.length > 0 && view === 'list' && (
        <LibraryList
          items={items}
          scrollRef={scrollRef}
          onOpen={actions.open}
          handlers={itemHandlers}
        />
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
      aria-label="Library items"
      className="overflow-hidden rounded-lg border border-surface2"
    >
      <div
        role="row"
        className={`grid ${LIST_COLUMNS} h-9 items-center gap-4 bg-row px-4 text-[11.5px] font-semibold uppercase tracking-[0.04em] text-muted`}
      >
        <span role="columnheader" />
        <span role="columnheader">Title</span>
        <span role="columnheader">Source</span>
        <span role="columnheader">Length</span>
        <span role="columnheader">Quality</span>
        <span role="columnheader" className="text-right">
          Size
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

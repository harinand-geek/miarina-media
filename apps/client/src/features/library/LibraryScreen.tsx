import { useEffect, useRef, useState } from 'react';
import { Chip } from '../../components/Controls';
import { Button } from '../../components/Button';
import { EmptyState, Thumbnail, ThumbBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import { useVirtualizer } from '@tanstack/react-virtual';
import type { LibraryItem } from '../../services/types';
import { useUi } from '../../stores/ui';
import { SORT_LABELS, useLibraryFilter, type KindFilter, type SortKey } from './useLibraryFilter';

const LIST_COLUMNS = 'grid-cols-[56px_minmax(0,1fr)_180px_80px_90px_90px]';

export default function LibraryScreen() {
  const { query, setQuery, kind, setKind, sort, setSort, items, counts } = useLibraryFilter();
  const [view, setView] = useState<'grid' | 'list'>('grid');
  const scrollRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const focusRequest = useUi((s) => s.librarySearchFocus);
  const play = useUi((s) => s.play);
  const go = useUi((s) => s.go);

  useEffect(() => {
    if (focusRequest > 0) searchRef.current?.focus();
  }, [focusRequest]);

  const open = (item: LibraryItem) => {
    play(item);
    go('player');
  };

  return (
    <div ref={scrollRef} className="relative flex flex-1 flex-col gap-5 overflow-auto px-10 py-7">
      <div className="flex items-center gap-3">
        <h1 className="m-0 flex-1 text-title-lg font-bold tracking-[-0.02em]">Library</h1>
        <label className="flex h-9 w-[280px] items-center gap-2 rounded-sm border border-line bg-surface px-2.5 focus-within:border-accent">
          <Icon name="search" size={18} className="text-muted" />
          <input
            ref={searchRef}
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
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
          items={(Object.keys(SORT_LABELS) as SortKey[]).map((key) => ({
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
        {(['all', 'video', 'audio'] as KindFilter[]).map((k) => (
          <Chip key={k} selected={kind === k} onClick={() => setKind(k)} count={counts[k]}>
            {k === 'all' ? 'All' : k === 'video' ? 'Video' : 'Audio'}
          </Chip>
        ))}
      </div>

      {items.length === 0 &&
        (query || kind !== 'all' ? (
          <EmptyState>
            {query ? `No items match “${query}”.` : 'No items in this category.'}
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
          label="Library items"
          items={items}
          scrollRef={scrollRef}
          minColumnWidth={210}
          columnGap={16}
          rowGap={18}
          rowHeight={(w) => (w * 9) / 16 + 10 + 40}
          getKey={(m) => m.id}
          renderItem={(m) => (
            <button
              type="button"
              onClick={() => open(m)}
              className="group flex w-full flex-col gap-2.5 rounded-md text-left"
            >
              <Thumbnail
                className="aspect-video w-full rounded-md text-[10px] group-hover:outline-2 group-hover:outline-offset-2 group-hover:outline-accent"
                label={m.kind === 'video' ? 'Video' : 'Audio'}
              >
                <ThumbBadge position="br">{m.duration}</ThumbBadge>
                <ThumbBadge position="tl">{m.quality}</ThumbBadge>
              </Thumbnail>
              <span className="flex w-full flex-col gap-0.5">
                <span className="truncate text-[13.5px] font-semibold">{m.title}</span>
                <span className="text-[12px] text-muted">
                  {m.source} · {m.size}
                </span>
              </span>
            </button>
          )}
        />
      )}

      {items.length > 0 && view === 'list' && (
        <LibraryList items={items} scrollRef={scrollRef} onOpen={open} />
      )}
    </div>
  );
}

function LibraryList({
  items,
  scrollRef,
  onOpen,
}: {
  items: LibraryItem[];
  scrollRef: React.RefObject<HTMLDivElement | null>;
  onOpen: (item: LibraryItem) => void;
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
          return (
            <div
              key={m.id}
              role="row"
              tabIndex={0}
              onClick={() => onOpen(m)}
              onKeyDown={(e) => e.key === 'Enter' && onOpen(m)}
              className={`absolute left-0 top-0 grid w-full ${LIST_COLUMNS} h-12 cursor-pointer items-center gap-4 border-t border-surface2 px-4 text-[13px] hover:bg-surface`}
              style={{ transform: `translateY(${row.start - virtualizer.options.scrollMargin}px)` }}
            >
              <Thumbnail className="h-8 w-14 rounded-xs" />
              <span role="cell" className="truncate font-semibold">
                {m.title}
              </span>
              <span role="cell" className="text-muted">
                {m.source}
              </span>
              <span role="cell" className="font-mono text-[12px] text-muted">
                {m.duration}
              </span>
              <span role="cell" className="text-muted">
                {m.quality}
              </span>
              <span role="cell" className="text-right font-mono text-[12px] text-muted">
                {m.size}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

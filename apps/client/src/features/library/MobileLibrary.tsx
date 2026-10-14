import { useState } from 'react';
import { Chip } from '../../components/Controls';
import { Thumbnail, ThumbBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import { useUi } from '../../stores/ui';
import { SORT_LABELS, useLibraryFilter, type KindFilter, type SortKey } from './useLibraryFilter';

export function MobileLibrary() {
  const { query, setQuery, kind, setKind, sort, setSort, items } = useLibraryFilter();
  const [scroller, setScroller] = useState<HTMLDivElement | null>(null);
  const play = useUi((s) => s.play);

  return (
    <div
      ref={setScroller}
      className="relative flex flex-1 flex-col gap-3.5 overflow-auto px-4 pb-5 pt-2"
    >
      <div className="mt-1 flex h-[52px] items-center gap-2.5 rounded-[26px] bg-surface px-4">
        <Icon name="search" size={22} className="text-muted" />
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search library"
          aria-label="Search library"
          className="min-w-0 flex-1 bg-transparent text-[15px] font-medium text-fg outline-none focus-visible:outline-none"
        />
        <Menu
          label="Sort by"
          trigger={({ open, toggle, id }) => (
            <button
              type="button"
              aria-label="Sort"
              aria-haspopup="menu"
              aria-expanded={open}
              aria-controls={id}
              onClick={toggle}
              className="grid h-11 w-11 place-items-center text-muted"
            >
              <Icon name="sort" size={22} />
            </button>
          )}
          items={(Object.keys(SORT_LABELS) as SortKey[]).map((key) => ({
            label: SORT_LABELS[key],
            selected: key === sort,
            onSelect: () => setSort(key),
          }))}
        />
      </div>
      <div className="flex gap-2 overflow-x-auto">
        {(['all', 'video', 'audio'] as KindFilter[]).map((k) => (
          <Chip key={k} size="mobile" selected={kind === k} onClick={() => setKind(k)}>
            {k === 'all' ? 'All' : k === 'video' ? 'Video' : 'Audio'}
          </Chip>
        ))}
      </div>
      {items.length === 0 && (
        <p className="py-10 text-center text-[13.5px] text-muted">
          {query ? `No items match “${query}”.` : 'Your library is empty.'}
        </p>
      )}
      <VirtualGrid
        label="Library items"
        items={items}
        scrollRef={{ current: scroller }}
        columns={2}
        columnGap={10}
        rowGap={14}
        rowHeight={(w) => (w * 10) / 16 + 8 + 38}
        getKey={(m) => m.id}
        renderItem={(m) => (
          <button
            type="button"
            onClick={() => play(m)}
            className="flex w-full flex-col gap-2 text-left"
          >
            <Thumbnail className="aspect-[16/10] w-full rounded-[10px]">
              <ThumbBadge position="br">{m.duration}</ThumbBadge>
              {m.kind === 'audio' && (
                <Icon
                  name="music_note"
                  size={16}
                  className="absolute left-1.5 top-1.5 text-audio"
                />
              )}
            </Thumbnail>
            <span className="flex w-full flex-col gap-px">
              <span className="truncate text-[13.5px] font-semibold">{m.title}</span>
              <span className="text-[12px] text-muted">
                {m.quality} · {m.size}
              </span>
            </span>
          </button>
        )}
      />
    </div>
  );
}

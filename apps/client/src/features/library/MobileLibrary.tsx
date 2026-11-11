import { useEffect, useState } from 'react';
import { ThumbBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import type { MediaKind, MediaSort } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useT } from '../../i18n';
import { useUi } from '../../stores/ui';
import { SORT_LABELS, durationLabel, qualityLabel } from './format';
import { MediaThumb } from './MediaThumb';
import { useMobileMediaSheet } from './useMobileMediaSheet';

/** Android v2: the Music and Videos tabs each list one kind. */
export function MobileLibrary({ kind }: { kind: MediaKind }) {
  const t = useT();
  const { search, sort, items, ready } = useLibrary();
  const { setSearch, setSort } = useLibrary.getState();
  const synced = useLibrary((s) => s.kind === kind && s.group === null);

  useEffect(() => {
    useLibrary.getState().show(kind, null);
  }, [kind]);
  const [scroller, setScroller] = useState<HTMLDivElement | null>(null);
  const play = useUi((s) => s.play);
  const actionsSheet = useMobileMediaSheet();

  return (
    <div
      ref={setScroller}
      className="relative flex flex-1 flex-col gap-3.5 overflow-auto px-4 pb-5 pt-2"
    >
      <h1 className="m-0 flex h-12 items-center text-[22px] font-extrabold tracking-[-0.01em]">
        {kind === 'audio' ? t('tabMusic') : t('tabVideos')}
      </h1>
      <div className="mt-1 flex h-[52px] items-center gap-2.5 rounded-[26px] bg-surface px-4">
        <Icon name="search" size={22} className="text-muted" />
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
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
          items={(Object.keys(SORT_LABELS) as MediaSort[]).map((key) => ({
            label: SORT_LABELS[key],
            selected: key === sort,
            onSelect: () => setSort(key),
          }))}
        />
      </div>
      {ready && synced && items.length === 0 && (
        <p className="py-10 text-center text-[13.5px] text-muted">
          {search.trim() ? `No items match “${search.trim()}”.` : 'Your library is empty.'}
        </p>
      )}
      <VirtualGrid
        label="Library items"
        items={synced ? items : []}
        scrollRef={{ current: scroller }}
        columns={2}
        columnGap={10}
        rowGap={14}
        rowHeight={(w) => (w * 10) / 16 + 8 + 38}
        getKey={(m) => String(m.id)}
        renderItem={(m) => (
          <button
            type="button"
            onClick={() => play(m)}
            // Long press (Android context menu) opens the actions.
            onContextMenu={(e) => {
              e.preventDefault();
              actionsSheet.open(m);
            }}
            aria-label={`${m.title} (long press for actions)`}
            className="flex w-full flex-col gap-2 text-left"
          >
            <MediaThumb media={m} className="aspect-[16/10] w-full rounded-[10px]">
              {m.durationSecs != null && (
                <ThumbBadge position="br">{durationLabel(m.durationSecs)}</ThumbBadge>
              )}
            </MediaThumb>
            <span className="flex w-full flex-col gap-px">
              <span className="truncate text-[13.5px] font-semibold">{m.title}</span>
              <span className="text-[12px] text-muted">
                {qualityLabel(m)} · {formatBytes(m.sizeBytes)}
              </span>
            </span>
          </button>
        )}
      />
      {actionsSheet.sheet}
    </div>
  );
}

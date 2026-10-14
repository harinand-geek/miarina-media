import { useVirtualizer } from '@tanstack/react-virtual';
import { useLayoutEffect, useState, type ReactNode, type RefObject } from 'react';

interface VirtualGridProps<T> {
  items: T[];
  /** Scroll container that owns the grid. */
  scrollRef: RefObject<HTMLElement | null>;
  /** Auto-fill column minimum width (design: 210 desktop), or a fixed count. */
  minColumnWidth?: number;
  columns?: number;
  columnGap: number;
  rowGap: number;
  /** Row height for a given column width (thumbnail ratio + caption). */
  rowHeight: (columnWidth: number) => number;
  renderItem: (item: T) => ReactNode;
  getKey: (item: T) => string;
  label: string;
}

/** Row-virtualized responsive grid: only visible rows are mounted. */
export function VirtualGrid<T>({
  items,
  scrollRef,
  minColumnWidth = 210,
  columns: fixedColumns,
  columnGap,
  rowGap,
  rowHeight,
  renderItem,
  getKey,
  label,
}: VirtualGridProps<T>) {
  const [width, setWidth] = useState(0);
  const [host, setHost] = useState<HTMLDivElement | null>(null);

  useLayoutEffect(() => {
    if (!host) return;
    const observer = new ResizeObserver(([entry]) => setWidth(entry!.contentRect.width));
    observer.observe(host);
    setWidth(host.getBoundingClientRect().width);
    return () => observer.disconnect();
  }, [host]);

  const columns =
    fixedColumns ?? Math.max(1, Math.floor((width + columnGap) / (minColumnWidth + columnGap)));
  const columnWidth = width > 0 ? (width - columnGap * (columns - 1)) / columns : minColumnWidth;
  const rowCount = Math.ceil(items.length / columns);
  const height = rowHeight(columnWidth);

  // eslint-disable-next-line react-hooks/incompatible-library -- TanStack Virtual is not memoizable; the React Compiler is not used here.
  const virtualizer = useVirtualizer({
    count: rowCount,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => height + rowGap,
    overscan: 3,
    scrollMargin: host?.offsetTop ?? 0,
  });

  useLayoutEffect(() => {
    virtualizer.measure();
  }, [height, columns, virtualizer]);

  return (
    <div
      ref={setHost}
      role="list"
      aria-label={label}
      className="relative w-full"
      style={{ height: virtualizer.getTotalSize() }}
    >
      {virtualizer.getVirtualItems().map((row) => (
        <div
          key={row.key}
          className="absolute left-0 top-0 grid w-full"
          style={{
            transform: `translateY(${row.start - virtualizer.options.scrollMargin}px)`,
            gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`,
            columnGap,
            height,
          }}
        >
          {items.slice(row.index * columns, row.index * columns + columns).map((item) => (
            <div role="listitem" key={getKey(item)} className="min-w-0">
              {renderItem(item)}
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

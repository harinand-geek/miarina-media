import { useDeferredValue, useMemo, useState } from 'react';
import { LIBRARY } from '../../dev/fixtures';
import type { LibraryItem } from '../../services/types';

export type KindFilter = 'all' | 'video' | 'audio';
export type SortKey = 'added' | 'title' | 'size' | 'duration';

export const SORT_LABELS: Record<SortKey, string> = {
  added: 'Date added',
  title: 'Title',
  size: 'Size',
  duration: 'Length',
};

const sizeMb = (s: string) => parseFloat(s) * (s.includes('GB') ? 1024 : 1);

const COMPARATORS: Record<SortKey, ((a: LibraryItem, b: LibraryItem) => number) | null> = {
  added: null, // fixtures are already in "date added" order
  title: (a, b) => a.title.localeCompare(b.title),
  size: (a, b) => sizeMb(b.size) - sizeMb(a.size),
  duration: (a, b) => b.durationSec - a.durationSec,
};

/** Search, kind filter and sort. Phase 3 moves this to SQLite FTS queries. */
export function useLibraryFilter() {
  const [query, setQuery] = useState('');
  const [kind, setKind] = useState<KindFilter>('all');
  const [sort, setSort] = useState<SortKey>('added');
  const deferredQuery = useDeferredValue(query);

  const items = useMemo(() => {
    const q = deferredQuery.trim().toLowerCase();
    const filtered = LIBRARY.filter(
      (m) => (kind === 'all' || m.kind === kind) && m.title.toLowerCase().includes(q),
    );
    const compare = COMPARATORS[sort];
    return compare ? [...filtered].sort(compare) : filtered;
  }, [deferredQuery, kind, sort]);

  const counts = useMemo(
    () => ({
      all: LIBRARY.length,
      video: LIBRARY.filter((m) => m.kind === 'video').length,
      audio: LIBRARY.filter((m) => m.kind === 'audio').length,
    }),
    [],
  );

  return { query, setQuery, kind, setKind, sort, setSort, items, counts };
}

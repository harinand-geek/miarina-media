import { useEffect, useState } from 'react';
import { backend } from '../../services/backend';
import { checkLinkLocally } from '../../services/link';
import type { MediaRecord } from '../../services/types';

const DEBOUNCE_MS = 150;

/**
 * YouTube search page for `q`. The mobile site also works on Windows (the
 * built-in browser follows YouTube's own redirect if it prefers another).
 */
export const youtubeSearch = (q: string, mobile = true) =>
  `https://${mobile ? 'm' : 'www'}.youtube.com/results?search_query=${encodeURIComponent(q.trim())}`;

/** True when the field holds a web link to analyze rather than words. */
export const isWebLink = (text: string) => text.includes('://') && checkLinkLocally(text.trim()).ok;

/**
 * Local music and videos matching `q` (titles, artists, albums, folders);
 * null while the answer for the current words is not there yet.
 * Shared by the Android search page and the Windows title bar search.
 */
export function useLocalResults(q: string, limit: number) {
  const query = q.trim();
  const [found, setFound] = useState<{ query: string; items: MediaRecord[] } | null>(null);
  useEffect(() => {
    if (!query) return;
    let alive = true;
    const timer = window.setTimeout(() => {
      backend
        .libraryQuery({ search: query, kind: null, sort: 'added', limit })
        .then((page) => alive && setFound({ query, items: page.items }))
        .catch(() => alive && setFound({ query, items: [] }));
    }, DEBOUNCE_MS);
    return () => {
      alive = false;
      window.clearTimeout(timer);
    };
  }, [query, limit]);
  return query && found?.query === query ? found.items : null;
}

import type { PlayEntry } from '../player/recentPlays';

/** Automatic lists of Music › Playlists (screen 06). */
export type AutoList = 'recent' | 'most';

/** Longest automatic list. */
export const AUTO_LIST_MAX = 50;

/**
 * Songs of the local play history (newest entry first): latest played
 * first, or most played first. Ties keep the most recently played first.
 */
export function autoListIds(history: PlayEntry[], list: AutoList): number[] {
  const audio = history.filter((e) => e.kind === 'audio');
  if (list === 'recent') return [...new Set(audio.map((e) => e.id))].slice(0, AUTO_LIST_MAX);
  const counts = new Map<number, number>();
  for (const e of audio) counts.set(e.id, (counts.get(e.id) ?? 0) + 1);
  // Array.sort is stable and Map keeps first-seen (newest) order.
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, AUTO_LIST_MAX)
    .map(([id]) => id);
}

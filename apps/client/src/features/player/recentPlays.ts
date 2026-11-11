/**
 * Media the user started playing, most recent first (Home "Continue",
 * Windows v2). Ids only, bounded; a media is "unfinished" while it has a
 * saved resume position (`savePosition` clears it near the end).
 */
const KEY = 'mm:recentPlays:v1';
const MAX = 20;

export function recentPlays(): number[] {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) ?? '[]') as unknown;
    return Array.isArray(raw) ? raw.filter((id): id is number => Number.isInteger(id)) : [];
  } catch {
    return [];
  }
}

export function notePlayed(id: number) {
  try {
    const ids = [id, ...recentPlays().filter((x) => x !== id)].slice(0, MAX);
    localStorage.setItem(KEY, JSON.stringify(ids));
  } catch {
    // Storage unavailable: Home simply shows nothing to continue.
  }
}

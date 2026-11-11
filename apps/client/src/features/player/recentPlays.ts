import { useSyncExternalStore } from 'react';
import type { MediaKind, MediaRecord } from '../../services/types';

/**
 * Local play history (CDC COM-13, Windows v2 History › Plays), separate
 * from download history and cleared on demand. Also feeds Home "Continue":
 * a media is unfinished while it has a saved resume position.
 * Small records only, bounded.
 */
export interface PlayEntry {
  id: number;
  title: string;
  kind: MediaKind;
  /** When playback started (ms). */
  at: number;
  /** Where it stopped (s), 0 while unknown. */
  position: number;
  duration: number;
}

const KEY = 'mm:playHistory:v1';
const MAX = 200;
const listeners = new Set<() => void>();
let cache: PlayEntry[] = [];
let cacheRaw: string | null | undefined;

/** Parsed entries; the same array while storage is unchanged (stable snapshot). */
function read(): PlayEntry[] {
  let text: string | null;
  try {
    text = localStorage.getItem(KEY);
  } catch {
    return cache;
  }
  if (text === cacheRaw) return cache;
  cacheRaw = text;
  try {
    const raw = JSON.parse(text ?? '[]') as unknown;
    cache = Array.isArray(raw)
      ? raw.filter(
          (e): e is PlayEntry =>
            !!e &&
            Number.isInteger(e.id) &&
            typeof e.title === 'string' &&
            typeof e.at === 'number',
        )
      : [];
  } catch {
    cache = [];
  }
  return cache;
}

function write(entries: PlayEntry[]) {
  cache = entries.slice(0, MAX);
  try {
    cacheRaw = JSON.stringify(cache);
    localStorage.setItem(KEY, cacheRaw);
  } catch {
    // Storage unavailable: the history lives for this session only.
  }
  listeners.forEach((l) => l());
}

export function playHistory(): PlayEntry[] {
  return read();
}

/** Ids of media played, most recent first, without repeats. */
export function recentPlays(): number[] {
  return [...new Set(read().map((e) => e.id))];
}

/** A resume of the latest entry within this delay is the same play. */
const SAME_PLAY_MS = 6 * 3_600_000;

export function notePlayed(media: MediaRecord, now = Date.now()) {
  const latest = read()[0];
  if (latest?.id === media.id && now - latest.at < SAME_PLAY_MS) return;
  write([
    {
      id: media.id,
      title: media.title,
      kind: media.kind,
      at: now,
      position: 0,
      duration: media.durationSecs ?? 0,
    },
    ...read(),
  ]);
}

/** Records where the latest play of `id` stopped. */
export function noteStopped(id: number, position: number) {
  const entries = read();
  const at = entries.findIndex((e) => e.id === id);
  if (at < 0 || !Number.isFinite(position)) return;
  const next = [...entries];
  next[at] = { ...entries[at]!, position: Math.max(0, Math.floor(position)) };
  write(next);
}

export function clearPlayHistory() {
  write([]);
}

const subscribe = (l: () => void) => {
  listeners.add(l);
  return () => listeners.delete(l);
};

export function usePlayHistory() {
  return useSyncExternalStore(subscribe, read, read);
}

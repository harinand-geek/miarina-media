import { invoke } from '@tauri-apps/api/core';
import { inTauri } from './platform';

/**
 * Durable playback state (CDC L02, COM-03/04/13).
 *
 * Screens read queues, resume positions and play history synchronously
 * from WebView storage. That copy can be lost or damaged (seen on Android
 * after a forced stop), so every write is also sent, batched, to SQLite
 * (`playback_state`, migration v6). At launch, before any store reads it,
 * SQLite rewrites the local copy; the first launch imports the existing
 * local copy instead. Outside Tauri (browser preview, tests) only the local
 * copy exists.
 */

const FIXED_KEYS = [
  'mm:player:v1',
  'mm:mobile:session:v1',
  'mm:playHistory:v1',
  // Small preferences that must not reset with the WebView profile.
  'mm:lang',
  'mm:resume',
  'mm:mobile:rate',
];
const IMPORTED = 'meta:imported';
const FLUSH_MS = 1000;
const LOAD_TIMEOUT_MS = 1500;
const BATCH = 1000;

export const isDurableKey = (key: string) =>
  FIXED_KEYS.includes(key) || /^mm:position:\d{1,19}$/.test(key);

interface Change {
  key: string;
  value: string | null;
}

let enabled = false;
const pending = new Map<string, string | null>();
let timer: ReturnType<typeof setTimeout> | undefined;

function schedule(key: string, value: string | null) {
  if (!enabled || !isDurableKey(key)) return;
  pending.set(key, value);
  if (!timer) timer = setTimeout(() => void flushDurable(), FLUSH_MS);
}

/** Writes the local copy and queues the durable write. */
export function durableSet(key: string, value: string) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Local copy unavailable: the durable copy still gets it.
  }
  schedule(key, value);
}

export function durableRemove(key: string) {
  try {
    localStorage.removeItem(key);
  } catch {
    // ignore
  }
  schedule(key, null);
}

async function write(changes: Change[]) {
  for (let i = 0; i < changes.length; i += BATCH) {
    await invoke('playback_write', { changes: changes.slice(i, i + BATCH) });
  }
}

/** Sends queued writes now (also when the window hides or closes). */
export async function flushDurable() {
  clearTimeout(timer);
  timer = undefined;
  if (!pending.size) return;
  const changes = [...pending].map(([key, value]) => ({ key, value }));
  pending.clear();
  try {
    await write(changes);
  } catch {
    // Retry later, unless a newer value was queued meanwhile.
    for (const c of changes) if (!pending.has(c.key)) pending.set(c.key, c.value);
    if (!timer) timer = setTimeout(() => void flushDurable(), FLUSH_MS * 5);
  }
}

function localKeys() {
  const keys: string[] = [];
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && isDurableKey(key)) keys.push(key);
    }
  } catch {
    // ignore
  }
  return keys;
}

/**
 * Called once before the app reads any playback state. Never blocks the
 * launch for long: if SQLite does not answer in time, the local copy is
 * used and durable writes stay off until the next launch.
 */
export async function hydrateDurableState(): Promise<'restored' | 'imported' | 'local'> {
  if (!inTauri()) return 'local';
  try {
    const snapshot = await Promise.race([
      invoke<{ imported: boolean; entries: [string, string][] }>('playback_load'),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('timeout')), LOAD_TIMEOUT_MS),
      ),
    ]);
    let result: 'restored' | 'imported';
    if (!snapshot.imported) {
      // First launch with this version: keep what the WebView already had.
      const changes: Change[] = localKeys().map((key) => ({
        key,
        value: localStorage.getItem(key),
      }));
      await write([...changes.filter((c) => c.value !== null), { key: IMPORTED, value: '1' }]);
      result = 'imported';
    } else {
      // SQLite is authoritative: rewrite the local copy from it.
      const remote = new Map(snapshot.entries);
      try {
        for (const key of localKeys()) if (!remote.has(key)) localStorage.removeItem(key);
        for (const [key, value] of remote) localStorage.setItem(key, value);
      } catch {
        // Local storage full or unavailable: screens start without it.
      }
      result = 'restored';
    }
    enabled = true;
    const flushSoon = () => void flushDurable();
    window.addEventListener('pagehide', flushSoon);
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') flushSoon();
    });
    return result;
  } catch {
    return 'local';
  }
}

/** Tests only. */
export function resetDurableStateForTests() {
  enabled = false;
  pending.clear();
  clearTimeout(timer);
  timer = undefined;
}

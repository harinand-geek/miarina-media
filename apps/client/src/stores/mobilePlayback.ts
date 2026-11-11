import { create } from 'zustand';
import type { MediaRecord } from '../services/types';
import type { RepeatMode, SleepTimer } from './player';
import { useUi } from './ui';

/**
 * Android play queue, modes and sound settings (Android v2 screens 07–09).
 * The engine stays in `MobilePlayer` (Media3 through Rust); this store says
 * what comes next. It runs in the foreground only: the MediaSession service
 * of lot L03 takes it over for the lock screen and background.
 */

export const MAX_MOBILE_QUEUE = 500;
export const MOBILE_RATES = [0.5, 0.75, 1, 1.25, 1.5, 2] as const;
const RATE_KEY = 'mm:mobile:rate';
const SESSION_KEY = 'mm:mobile:session:v1';

/**
 * How the player starts a session: open the queue and play, attach to a
 * service that is still playing (app reopened), or wait for Play (queue
 * restored after the process died: no surprise sound, CDC AND-05).
 */
export type StartMode = 'open' | 'attach' | 'deferred';

interface SavedSession {
  queue: MediaRecord[];
  currentId: number;
  source: string | null;
  repeat: RepeatMode;
}
/** "Previous" restarts the track when past this point. */
export const MOBILE_RESTART_SECS = 3;

function savedRate(): number {
  try {
    const r = Number(localStorage.getItem(RATE_KEY));
    return (MOBILE_RATES as readonly number[]).includes(r) ? r : 1;
  } catch {
    return 1;
  }
}

function shuffled<T>(items: T[]): T[] {
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
}

interface MobilePlaybackState {
  /** Changes when a new queue starts: one native player session per queue. */
  session: number;
  queue: MediaRecord[];
  /** "Playing from" label (album, artist, Tracks…), or null. */
  source: string | null;
  shuffle: boolean;
  unshuffled: number[] | null;
  repeat: RepeatMode;
  rate: number;
  sleep: SleepTimer;
  startMode: StartMode;
  /** Opens the player on `item` with `queue` coming next. */
  start: (item: MediaRecord, queue: MediaRecord[], source?: string | null) => void;
  /** Next item; `manual` wraps around when the whole queue repeats. */
  next: (manual?: boolean) => boolean;
  previous: () => boolean;
  playAt: (index: number) => void;
  remove: (index: number) => void;
  move: (from: number, to: number) => void;
  /** Keeps the current item only; no file is touched. */
  clear: () => void;
  setShuffle: (on: boolean) => void;
  cycleRepeat: () => void;
  setRate: (rate: number) => void;
  setSleep: (sleep: 'off' | 'end' | number) => void;
  /** The native player moved to `id` on its own (end of track, lock screen). */
  syncFromNative: (id: number) => void;
  /** Puts back a saved queue, minimized, attached or waiting for Play. */
  restore: (saved: SavedSession, mode: Exclude<StartMode, 'open'>) => void;
}

const current = () => useUi.getState().nowPlaying;
const indexOfCurrent = (queue: MediaRecord[]) => queue.findIndex((m) => m.id === current()?.id);
/** Changes track without changing whether the player is expanded. */
const show = (item: MediaRecord) => useUi.setState({ nowPlaying: item });

export const useMobilePlayback = create<MobilePlaybackState>((set, get) => ({
  session: 0,
  queue: [],
  source: null,
  shuffle: false,
  unshuffled: null,
  repeat: 'off',
  rate: savedRate(),
  sleep: { mode: 'off' },
  startMode: 'open',

  start: (item, queue, source = null) => {
    const list = (queue.some((m) => m.id === item.id) ? queue : [item, ...queue]).slice(
      0,
      MAX_MOBILE_QUEUE,
    );
    set((s) => ({
      queue: list,
      source,
      shuffle: false,
      unshuffled: null,
      session: s.session + 1,
      startMode: 'open',
    }));
    useUi.getState().play(item);
  },

  next: (manual = false) => {
    const { queue, repeat } = get();
    const at = indexOfCurrent(queue);
    let next = at >= 0 ? queue[at + 1] : undefined;
    if (!next && repeat === 'all' && queue.length > 1 && (manual || at === queue.length - 1)) {
      next = queue[0];
    }
    if (!next) return false;
    show(next);
    return true;
  },

  previous: () => {
    const { queue, repeat } = get();
    const at = indexOfCurrent(queue);
    const prev = at > 0 ? queue[at - 1] : repeat === 'all' ? queue[queue.length - 1] : undefined;
    if (!prev || prev.id === current()?.id) return false;
    show(prev);
    return true;
  },

  playAt: (index) => {
    const item = get().queue[index];
    if (item) show(item);
  },

  remove: (index) => {
    const { queue } = get();
    const item = queue[index];
    if (!item) return;
    if (item.id === current()?.id) {
      // The playing item is not removed here: the user stops it from the player.
      return;
    }
    set({ queue: queue.filter((_, i) => i !== index) });
  },

  move: (from, to) => {
    const { queue } = get();
    if (from === to || from < 0 || to < 0 || from >= queue.length || to >= queue.length) return;
    const list = queue.slice();
    const [item] = list.splice(from, 1);
    list.splice(to, 0, item!);
    set({ queue: list });
  },

  clear: () => {
    const item = current();
    set({ queue: item ? [item] : [], shuffle: false, unshuffled: null });
  },

  setShuffle: (on) => {
    const { queue, unshuffled, shuffle } = get();
    if (on === shuffle) return;
    const item = current();
    if (on) {
      const others = shuffled(queue.filter((m) => m.id !== item?.id));
      set({
        shuffle: true,
        unshuffled: queue.map((m) => m.id),
        queue: item ? [item, ...others] : others,
      });
      return;
    }
    const order = new Map((unshuffled ?? []).map((id, i) => [id, i]));
    const list = queue
      .map((m, i) => ({ m, k: order.get(m.id) ?? order.size + i }))
      .sort((a, b) => a.k - b.k)
      .map((x) => x.m);
    set({ shuffle: false, unshuffled: null, queue: list });
  },

  cycleRepeat: () =>
    set((s) => ({ repeat: s.repeat === 'off' ? 'all' : s.repeat === 'all' ? 'one' : 'off' })),

  setRate: (rate) => {
    const r = (MOBILE_RATES as readonly number[]).includes(rate) ? rate : 1;
    try {
      localStorage.setItem(RATE_KEY, String(r));
    } catch {
      // Not persisted: applies to this session.
    }
    set({ rate: r });
  },

  restore: (saved, mode) => {
    const item = saved.queue.find((m) => m.id === saved.currentId);
    if (!item) return;
    set((s) => ({
      queue: saved.queue.slice(0, MAX_MOBILE_QUEUE),
      source: saved.source,
      repeat: saved.repeat,
      shuffle: false,
      unshuffled: null,
      session: s.session + 1,
      startMode: mode,
    }));
    useUi.setState({ nowPlaying: item, mobilePlayerExpanded: false });
  },

  syncFromNative: (id) => {
    const item = get().queue.find((m) => m.id === id);
    if (item && item.id !== current()?.id) show(item);
  },

  setSleep: (sleep) =>
    set({
      sleep:
        sleep === 'off'
          ? { mode: 'off' }
          : sleep === 'end'
            ? { mode: 'end' }
            : { mode: 'minutes', minutes: sleep, endsAt: Date.now() + sleep * 60_000 },
    }),
}));

// Any other way to open the player (Home, a notification) starts a queue of
// one; closing the player clears it.
useUi.subscribe((s, prev) => {
  if (s.nowPlaying === prev.nowPlaying) return;
  const store = useMobilePlayback.getState();
  if (!s.nowPlaying) {
    useMobilePlayback.setState({
      queue: [],
      source: null,
      shuffle: false,
      unshuffled: null,
      sleep: { mode: 'off' },
    });
    return;
  }
  if (!store.queue.some((m) => m.id === s.nowPlaying!.id)) {
    useMobilePlayback.setState({
      queue: [s.nowPlaying],
      source: null,
      shuffle: false,
      unshuffled: null,
      session: store.session + 1,
      startMode: 'open',
    });
  }
});

/** The saved Android session, if any (bounded, small records only). */
export function savedSession(): SavedSession | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as Partial<SavedSession>;
    if (!Array.isArray(s.queue) || typeof s.currentId !== 'number') return null;
    const queue = s.queue.slice(0, MAX_MOBILE_QUEUE);
    if (!queue.some((m) => m.id === s.currentId)) return null;
    return {
      queue,
      currentId: s.currentId,
      source: typeof s.source === 'string' ? s.source : null,
      repeat: s.repeat === 'all' || s.repeat === 'one' ? s.repeat : 'off',
    };
  } catch {
    return null;
  }
}

function persist() {
  const item = useUi.getState().nowPlaying;
  const { queue, source, repeat } = useMobilePlayback.getState();
  try {
    if (!item || !queue.length) localStorage.removeItem(SESSION_KEY);
    else
      localStorage.setItem(
        SESSION_KEY,
        JSON.stringify({ queue, currentId: item.id, source, repeat } satisfies SavedSession),
      );
  } catch {
    // Storage full or unavailable: nothing is restored after a restart.
  }
}

useMobilePlayback.subscribe((s, prev) => {
  if (s.queue !== prev.queue || s.source !== prev.source || s.repeat !== prev.repeat) persist();
});
useUi.subscribe((s, prev) => {
  if (s.nowPlaying !== prev.nowPlaying) persist();
});

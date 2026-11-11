import { create } from 'zustand';
import { notePlayed, noteStopped } from '../features/player/recentPlays';
import { savePosition, savedPosition } from '../features/player/usePlayback';
import type { MediaRecord } from '../services/types';

/**
 * Desktop player contract (CDC COM-01, §11 "Contrat lecteur"). One engine
 * owns the media (`PlayerHost`, a single element for audio and video); React
 * screens are controllers. The playback queue is separate from downloads and
 * from the library (COM-03): clearing it never touches files.
 *
 * Persistence: queue, modes, rate and volume are kept in localStorage, like
 * resume positions. Moving them to SQLite is the data half of lot L02.
 */

export type PlayerState =
  'idle' | 'loading' | 'ready' | 'playing' | 'paused' | 'buffering' | 'ended' | 'error';
export type RepeatMode = 'off' | 'all' | 'one';
export type SleepTimer =
  { mode: 'off' } | { mode: 'minutes'; minutes: number; endsAt: number } | { mode: 'end' };

/** `MediaError.code` mapped to a structured error (WIN-02: no misleading message). */
export interface PlayerError {
  kind: 'aborted' | 'read' | 'decode' | 'unsupported' | 'unknown';
}

export const MIN_RATE = 0.5;
export const MAX_RATE = 2;
/** Bounded queue: no unbounded growth in memory or storage. */
export const MAX_QUEUE = 500;
/** "Previous" restarts the track when past this point. */
export const RESTART_THRESHOLD_SECS = 3;

/** What the engine (PlayerHost) implements. */
export interface PlayerEngine {
  load: (media: MediaRecord, instance: number, startAt: number, autoplay: boolean) => void;
  play: () => void;
  pause: () => void;
  seek: (secs: number) => void;
  setVolume: (volume: number, muted: boolean) => void;
  setRate: (rate: number) => void;
  /** Releases the file; the queue is kept. */
  stop: () => void;
}

/** What the engine reports, tagged with the instance it was loaded for. */
export type EngineReport = Partial<
  Pick<PlayerStore, 'state' | 'position' | 'duration' | 'buffered' | 'error'>
>;

interface PlayerStore {
  media: MediaRecord | null;
  /** Incremented on each load: late answers for a previous media are dropped. */
  instance: number;
  state: PlayerState;
  position: number;
  duration: number;
  buffered: number;
  volume: number;
  muted: boolean;
  rate: number;
  error: PlayerError | null;
  queue: MediaRecord[];
  index: number;
  shuffle: boolean;
  /** Queue order (ids) before shuffling, restored when shuffle goes off. */
  unshuffled: number[] | null;
  repeat: RepeatMode;
  sleep: SleepTimer;
  /** Element of the video screen where the picture is placed. */
  surface: HTMLElement | null;

  playMedia: (media: MediaRecord, queue?: MediaRecord[]) => void;
  playAt: (index: number) => void;
  play: () => void;
  pause: () => void;
  toggle: () => void;
  stop: () => void;
  seek: (secs: number) => void;
  skip: (delta: number) => void;
  setVolume: (volume: number) => void;
  toggleMute: () => void;
  setRate: (rate: number) => void;
  next: () => void;
  previous: () => void;
  playNext: (media: MediaRecord) => void;
  enqueue: (media: MediaRecord) => void;
  removeAt: (index: number) => void;
  move: (from: number, to: number) => void;
  clearQueue: () => void;
  setShuffle: (on: boolean) => void;
  cycleRepeat: () => void;
  setSleep: (sleep: 'off' | 'end' | number) => void;
  /** A library entry changed (tags, title): update its queued copies. */
  refreshMedia: (media: MediaRecord) => void;
  /** A library entry was removed: drop it from the queue. */
  forget: (id: number) => void;
  retry: () => void;
  setSurface: (el: HTMLElement | null) => void;
}

let engine: PlayerEngine | null = null;
let sleepTimer: ReturnType<typeof setTimeout> | undefined;
/** Called when a minutes timer pauses playback (toast in the shell). */
let onSleepEnded: (() => void) | null = null;

export function bindEngine(next: PlayerEngine) {
  engine = next;
  return () => {
    if (engine === next) engine = null;
  };
}

export function onSleepTimerEnded(cb: (() => void) | null) {
  onSleepEnded = cb;
}

const STORAGE_KEY = 'mm:player:v1';

interface Persisted {
  queue: MediaRecord[];
  index: number;
  shuffle: boolean;
  unshuffled: number[] | null;
  repeat: RepeatMode;
  rate: number;
  volume: number;
  muted: boolean;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

function restore(): Partial<Persisted> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const p = JSON.parse(raw) as Partial<Persisted>;
    const queue = Array.isArray(p.queue) ? p.queue.slice(0, MAX_QUEUE) : [];
    return {
      queue,
      index: queue.length ? clamp(Number(p.index) || 0, 0, queue.length - 1) : -1,
      shuffle: p.shuffle === true,
      unshuffled: Array.isArray(p.unshuffled) ? p.unshuffled : null,
      repeat: p.repeat === 'all' || p.repeat === 'one' ? p.repeat : 'off',
      rate: clamp(Number(p.rate) || 1, MIN_RATE, MAX_RATE),
      volume: clamp(Number(p.volume ?? 0.8), 0, 1),
      muted: p.muted === true,
    };
  } catch {
    return {};
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

/** State at startup, read from storage (exported for tests). */
export function initialPlayerState() {
  const saved = restore();
  const queue = saved.queue ?? [];
  const index = saved.index ?? -1;
  const media = queue[index] ?? null;
  return {
    // Restored without sound: playback starts only on request (AND-05 rule).
    media,
    instance: 0,
    state: 'idle' as PlayerState,
    position: media ? savedPosition(media.id) : 0,
    duration: media?.durationSecs ?? 0,
    buffered: 0,
    volume: saved.volume ?? 0.8,
    muted: saved.muted ?? false,
    rate: saved.rate ?? 1,
    error: null,
    queue,
    index,
    shuffle: saved.shuffle ?? false,
    unshuffled: saved.unshuffled ?? null,
    repeat: saved.repeat ?? ('off' as RepeatMode),
    sleep: { mode: 'off' } as SleepTimer,
    surface: null,
  };
}

export const usePlayer = create<PlayerStore>((set, get) => {
  /** Remembers where the current media stopped before switching. */
  const keepPosition = () => {
    const { media, position, duration, state } = get();
    if (media && state !== 'idle' && duration > 0) savePosition(media.id, position, duration);
  };

  const load = (index: number, autoplay = true) => {
    const { queue } = get();
    const media = queue[index];
    if (!media) return;
    keepPosition();
    const instance = get().instance + 1;
    const startAt = savedPosition(media.id);
    set({
      media,
      index,
      instance,
      state: 'loading',
      position: startAt,
      duration: media.durationSecs ?? 0,
      buffered: 0,
      error: null,
    });
    engine?.load(media, instance, startAt, autoplay);
    const { volume, muted, rate } = get();
    engine?.setVolume(volume, muted);
    engine?.setRate(rate);
  };

  /** Next index, or -1 at the end of the queue. */
  const nextIndex = () => {
    const { index, queue, repeat } = get();
    if (index + 1 < queue.length) return index + 1;
    return repeat === 'all' && queue.length ? 0 : -1;
  };

  const clearSleep = () => {
    clearTimeout(sleepTimer);
    sleepTimer = undefined;
    set({ sleep: { mode: 'off' } });
  };

  return {
    ...initialPlayerState(),

    playMedia: (media, queue) => {
      if (queue && queue.length) {
        const list = queue.slice(0, MAX_QUEUE);
        let index = list.findIndex((m) => m.id === media.id);
        if (index < 0) {
          list.unshift(media);
          list.length = Math.min(list.length, MAX_QUEUE);
          index = 0;
        }
        set({ queue: list, shuffle: false, unshuffled: null });
        load(index);
        return;
      }
      const at = get().queue.findIndex((m) => m.id === media.id);
      if (at >= 0) {
        load(at);
        return;
      }
      get().playNext(media);
      load(get().queue.findIndex((m) => m.id === media.id));
    },

    playAt: (index) => load(index),

    play: () => {
      const { state, media, index } = get();
      if (!media) return;
      if (state === 'idle' || state === 'error' || !engine) {
        load(index);
      } else if (state === 'ended') {
        engine.seek(0);
        engine.play();
      } else {
        engine.play();
      }
    },
    pause: () => engine?.pause(),
    toggle: () => {
      const { state } = get();
      if (state === 'playing' || state === 'buffering' || state === 'loading') get().pause();
      else get().play();
    },
    stop: () => {
      keepPosition();
      engine?.stop();
      set({ state: 'idle', buffered: 0 });
    },
    seek: (secs) => {
      const { duration } = get();
      const to = clamp(secs, 0, duration > 0 ? duration : Math.max(0, secs));
      set({ position: to });
      engine?.seek(to);
    },
    skip: (delta) => get().seek(get().position + delta),
    setVolume: (volume) => {
      const v = clamp(volume, 0, 1);
      set({ volume: v, muted: v === 0 ? get().muted : false });
      engine?.setVolume(v, get().muted);
    },
    toggleMute: () => {
      const muted = !get().muted;
      set({ muted });
      engine?.setVolume(get().volume, muted);
    },
    setRate: (rate) => {
      const r = clamp(rate, MIN_RATE, MAX_RATE);
      set({ rate: r });
      engine?.setRate(r);
    },

    next: () => {
      const i = nextIndex();
      if (i >= 0) load(i);
    },
    previous: () => {
      const { position, index, queue, repeat } = get();
      if (position > RESTART_THRESHOLD_SECS || queue.length <= 1) {
        get().seek(0);
        return;
      }
      if (index > 0) load(index - 1);
      else if (repeat === 'all') load(queue.length - 1);
      else get().seek(0);
    },

    playNext: (media) => {
      const { queue, index } = get();
      const current = queue[index];
      const rest = queue.filter((m) => m.id !== media.id);
      const at = current ? rest.findIndex((m) => m.id === current.id) : -1;
      rest.splice(at + 1, 0, media);
      const list = rest.slice(0, MAX_QUEUE);
      set({
        queue: list,
        index: current ? list.findIndex((m) => m.id === current.id) : index,
      });
      if (!get().media) set({ media, index: list.indexOf(media) });
    },
    enqueue: (media) => {
      const { queue, index } = get();
      if (queue.some((m) => m.id === media.id) || queue.length >= MAX_QUEUE) return;
      set({ queue: [...queue, media] });
      if (index < 0) set({ index: 0, media });
    },
    removeAt: (at) => {
      const { queue, index } = get();
      if (at < 0 || at >= queue.length) return;
      const list = queue.filter((_, i) => i !== at);
      if (at !== index) {
        set({ queue: list, index: at < index ? index - 1 : index });
        return;
      }
      // Removing the current media: continue with the following one.
      const wasPlaying = get().state === 'playing';
      if (!list.length) {
        get().stop();
        set({ queue: [], index: -1, media: null, position: 0, duration: 0 });
        return;
      }
      set({ queue: list });
      const nextAt = Math.min(at, list.length - 1);
      if (wasPlaying) load(nextAt);
      else {
        get().stop();
        const media = list[nextAt]!;
        set({
          index: nextAt,
          media,
          position: savedPosition(media.id),
          duration: media.durationSecs ?? 0,
        });
      }
    },
    move: (from, to) => {
      const { queue, index } = get();
      if (from === to || from < 0 || to < 0 || from >= queue.length || to >= queue.length) return;
      const current = queue[index];
      const list = queue.slice();
      const [item] = list.splice(from, 1);
      list.splice(to, 0, item!);
      set({ queue: list, index: current ? list.indexOf(current) : index });
    },
    clearQueue: () => {
      const { media } = get();
      // The current media keeps playing; files and library are untouched.
      set({ queue: media ? [media] : [], index: media ? 0 : -1, unshuffled: null, shuffle: false });
    },
    setShuffle: (on) => {
      const { queue, index, unshuffled, shuffle } = get();
      if (on === shuffle) return;
      const current = queue[index];
      if (on) {
        const others = shuffled(queue.filter((_, i) => i !== index));
        const list = current ? [current, ...others] : others;
        set({
          shuffle: true,
          unshuffled: queue.map((m) => m.id),
          queue: list,
          index: current ? 0 : -1,
        });
        return;
      }
      // Original order for what is still queued; later additions keep their place at the end.
      const order = new Map((unshuffled ?? []).map((id, i) => [id, i]));
      const list = queue
        .map((m, i) => ({ m, k: order.get(m.id) ?? order.size + i }))
        .sort((a, b) => a.k - b.k)
        .map((x) => x.m);
      set({
        shuffle: false,
        unshuffled: null,
        queue: list,
        index: current ? list.indexOf(current) : -1,
      });
    },
    cycleRepeat: () =>
      set((s) => ({ repeat: s.repeat === 'off' ? 'all' : s.repeat === 'all' ? 'one' : 'off' })),

    setSleep: (sleep) => {
      clearSleep();
      if (sleep === 'off') return;
      if (sleep === 'end') {
        set({ sleep: { mode: 'end' } });
        return;
      }
      const ms = sleep * 60_000;
      set({ sleep: { mode: 'minutes', minutes: sleep, endsAt: Date.now() + ms } });
      sleepTimer = setTimeout(() => {
        sleepTimer = undefined;
        set({ sleep: { mode: 'off' } });
        get().pause();
        onSleepEnded?.();
      }, ms);
    },

    refreshMedia: (updated) =>
      set((s) => ({
        queue: s.queue.map((m) => (m.id === updated.id ? updated : m)),
        media: s.media?.id === updated.id ? updated : s.media,
      })),

    forget: (id) => {
      const at = get().queue.findIndex((m) => m.id === id);
      if (at < 0) return;
      if (at === get().index) {
        get().stop();
        const list = get().queue.filter((m) => m.id !== id);
        const index = list.length ? Math.min(at, list.length - 1) : -1;
        const media = list[index] ?? null;
        set({
          queue: list,
          index,
          media,
          position: 0,
          duration: media?.durationSecs ?? 0,
          state: 'idle',
        });
      } else {
        get().removeAt(at);
      }
    },

    retry: () => {
      const { index, position } = get();
      const media = get().queue[index];
      if (!media) return;
      const instance = get().instance + 1;
      set({ instance, state: 'loading', error: null, buffered: 0 });
      engine?.load(media, instance, position, true);
    },

    setSurface: (surface) => set({ surface }),
  };
});

/** Engine → store. Reports for a previous instance are ignored. */
export function reportEngine(instance: number, report: EngineReport) {
  if (instance !== usePlayer.getState().instance) return;
  usePlayer.setState(report);
  if (report.state === 'paused') {
    const { media, position, duration } = usePlayer.getState();
    if (media && duration > 0) savePosition(media.id, position, duration);
  }
}

/** Engine → store: the media reached its end. */
export function reportEnded(instance: number) {
  const store = usePlayer.getState();
  if (instance !== store.instance) return;
  const { media, duration, repeat, sleep, index, queue } = store;
  if (media) savePosition(media.id, 0, duration);
  if (sleep.mode === 'end') {
    usePlayer.setState({ state: 'ended', sleep: { mode: 'off' } });
    onSleepEnded?.();
    return;
  }
  if (repeat === 'one') {
    engine?.seek(0);
    engine?.play();
    return;
  }
  const hasNext = index + 1 < queue.length || (repeat === 'all' && queue.length > 0);
  if (hasNext) store.next();
  else usePlayer.setState({ state: 'ended', position: duration });
}

/** Playing or about to play (for indicators). */
export const isActive = (state: PlayerState) =>
  state === 'playing' || state === 'buffering' || state === 'loading';

// Persist the queue and modes (bounded, small records only).
usePlayer.subscribe((s, prev) => {
  if (
    s.queue === prev.queue &&
    s.index === prev.index &&
    s.shuffle === prev.shuffle &&
    s.repeat === prev.repeat &&
    s.rate === prev.rate &&
    s.volume === prev.volume &&
    s.muted === prev.muted
  )
    return;
  const data: Persisted = {
    queue: s.queue,
    index: s.index,
    shuffle: s.shuffle,
    unshuffled: s.unshuffled,
    repeat: s.repeat,
    rate: s.rate,
    volume: s.volume,
    muted: s.muted,
  };
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch {
    // Storage full or unavailable: the queue lives for this session only.
  }
});

// Play history (History › Plays, Home "Continue"): what actually started
// playing (not a queue restored at launch, which stays paused) and where it
// stopped.
usePlayer.subscribe((s, prev) => {
  if (
    prev.media &&
    (s.media?.id !== prev.media.id || (prev.state === 'playing' && s.state === 'paused'))
  )
    noteStopped(prev.media.id, prev.media.id === s.media?.id ? s.position : prev.position);
  if (
    s.state === 'playing' &&
    s.media &&
    (prev.state !== 'playing' || prev.media?.id !== s.media.id)
  )
    notePlayed(s.media);
});

export function resetPlayerForTests() {
  clearTimeout(sleepTimer);
  sleepTimer = undefined;
  engine = null;
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // ignore
  }
  usePlayer.setState({ ...initialPlayerState() });
}

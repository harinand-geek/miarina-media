import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MediaRecord } from '../services/types';
import {
  bindEngine,
  initialPlayerState,
  reportEnded,
  reportEngine,
  resetPlayerForTests,
  usePlayer,
  type PlayerEngine,
} from './player';

const media = (id: number, kind: MediaRecord['kind'] = 'audio'): MediaRecord =>
  ({
    id,
    title: `Track ${id}`,
    kind,
    path: `C:\\Music\\${id}.mp3`,
    durationSecs: 200,
    sizeBytes: 1,
  }) as MediaRecord;

const LIST = [1, 2, 3, 4].map((id) => media(id));
const ids = () => usePlayer.getState().queue.map((m) => m.id);
const current = () => usePlayer.getState().media?.id;

let engine: { [K in keyof PlayerEngine]: ReturnType<typeof vi.fn> };
let unbind: () => void;

beforeEach(() => {
  resetPlayerForTests();
  localStorage.clear();
  engine = {
    load: vi.fn(),
    play: vi.fn(),
    pause: vi.fn(),
    seek: vi.fn(),
    setVolume: vi.fn(),
    setRate: vi.fn(),
    stop: vi.fn(),
  };
  unbind = bindEngine(engine as unknown as PlayerEngine);
});

afterEach(() => {
  unbind();
  vi.useRealTimers();
});

describe('player contract (COM-01)', () => {
  it('loads with the saved position and ignores answers for a previous media', () => {
    localStorage.setItem('mm:position:2', '42');
    const { playMedia } = usePlayer.getState();
    playMedia(LIST[0]!, LIST);
    const first = usePlayer.getState().instance;
    playMedia(LIST[1]!, LIST);
    expect(engine.load).toHaveBeenLastCalledWith(LIST[1], first + 1, 42, true);

    reportEngine(first, { state: 'playing', position: 150 });
    expect(usePlayer.getState().state).toBe('loading');
    expect(usePlayer.getState().position).toBe(42);

    reportEngine(first + 1, { state: 'playing' });
    expect(usePlayer.getState().state).toBe('playing');
  });

  it('bounds seek and rate', () => {
    usePlayer.getState().playMedia(LIST[0]!, LIST);
    reportEngine(usePlayer.getState().instance, { duration: 100 });
    usePlayer.getState().seek(500);
    expect(engine.seek).toHaveBeenLastCalledWith(100);
    usePlayer.getState().seek(-3);
    expect(engine.seek).toHaveBeenLastCalledWith(0);
    usePlayer.getState().setRate(9);
    expect(usePlayer.getState().rate).toBe(2);
  });

  it('restarts the track on previous after 3 s, else goes back', () => {
    usePlayer.getState().playMedia(LIST[1]!, LIST);
    reportEngine(usePlayer.getState().instance, { position: 10 });
    usePlayer.getState().previous();
    expect(current()).toBe(2);
    expect(engine.seek).toHaveBeenLastCalledWith(0);
    reportEngine(usePlayer.getState().instance, { position: 1 });
    usePlayer.getState().previous();
    expect(current()).toBe(1);
  });
});

describe('play queue (COM-03)', () => {
  it('plays next, appends, reorders and removes without touching files', () => {
    const p = usePlayer.getState();
    p.playMedia(LIST[0]!, LIST.slice(0, 2));
    p.playNext(LIST[3]!);
    expect(ids()).toEqual([1, 4, 2]);
    p.enqueue(LIST[2]!);
    p.enqueue(LIST[2]!); // no duplicate
    expect(ids()).toEqual([1, 4, 2, 3]);
    p.move(3, 0);
    expect(ids()).toEqual([3, 1, 4, 2]);
    expect(usePlayer.getState().index).toBe(1); // still on track 1
    p.removeAt(0);
    expect(ids()).toEqual([1, 4, 2]);
    expect(current()).toBe(1);
    p.clearQueue();
    expect(ids()).toEqual([1]);
    expect(engine.stop).not.toHaveBeenCalled();
  });

  it('continues with the following media when the current one is removed', () => {
    usePlayer.getState().playMedia(LIST[1]!, LIST);
    reportEngine(usePlayer.getState().instance, { state: 'playing' });
    usePlayer.getState().removeAt(1);
    expect(current()).toBe(3);
    expect(engine.load).toHaveBeenLastCalledWith(LIST[2], expect.any(Number), 0, true);
  });

  it('forgets a deleted library entry', () => {
    usePlayer.getState().playMedia(LIST[0]!, LIST);
    usePlayer.getState().forget(1);
    expect(ids()).toEqual([2, 3, 4]);
    expect(current()).toBe(2);
    expect(usePlayer.getState().state).toBe('idle');
    expect(engine.stop).toHaveBeenCalled();
  });
});

describe('end of media, repeat and shuffle (COM-12)', () => {
  it('advances, repeats the queue, repeats one, or stops at the end', () => {
    const p = usePlayer.getState();
    p.playMedia(LIST[3]!, LIST);
    reportEnded(usePlayer.getState().instance);
    expect(usePlayer.getState().state).toBe('ended');

    p.cycleRepeat(); // all
    reportEnded(usePlayer.getState().instance);
    expect(current()).toBe(1);

    p.cycleRepeat(); // one
    const loads = engine.load.mock.calls.length;
    reportEnded(usePlayer.getState().instance);
    expect(current()).toBe(1);
    expect(engine.load.mock.calls.length).toBe(loads);
    expect(engine.seek).toHaveBeenLastCalledWith(0);
  });

  it('keeps the current media first and restores the order after changes', () => {
    const p = usePlayer.getState();
    p.playMedia(LIST[2]!, LIST);
    p.setShuffle(true);
    expect(current()).toBe(3);
    expect(ids()[0]).toBe(3);
    expect([...ids()].sort()).toEqual([1, 2, 3, 4]);
    p.enqueue(media(9));
    p.removeAt(ids().indexOf(2));
    p.setShuffle(false);
    expect(ids()).toEqual([1, 3, 4, 9]);
    expect(current()).toBe(3);
  });
});

describe('sleep timer (AND-11 / Windows v2)', () => {
  it('pauses after the chosen minutes', () => {
    vi.useFakeTimers();
    usePlayer.getState().playMedia(LIST[0]!, LIST);
    usePlayer.getState().setSleep(15);
    vi.advanceTimersByTime(15 * 60_000 - 1);
    expect(engine.pause).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(engine.pause).toHaveBeenCalledOnce();
    expect(usePlayer.getState().sleep.mode).toBe('off');
  });

  it('stops at the end of the track instead of advancing', () => {
    usePlayer.getState().playMedia(LIST[0]!, LIST);
    usePlayer.getState().setSleep('end');
    reportEnded(usePlayer.getState().instance);
    expect(current()).toBe(1);
    expect(usePlayer.getState().state).toBe('ended');
  });
});

describe('persistence', () => {
  it('restores the queue without starting playback', () => {
    usePlayer.getState().playMedia(LIST[1]!, LIST);
    usePlayer.getState().setRate(1.5);
    const restored = initialPlayerState();
    expect(restored.queue.map((m) => m.id)).toEqual([1, 2, 3, 4]);
    expect(restored.media?.id).toBe(2);
    expect(restored.rate).toBe(1.5);
    // Restored without sound (AND-05 rule).
    expect(restored.state).toBe('idle');
  });
});

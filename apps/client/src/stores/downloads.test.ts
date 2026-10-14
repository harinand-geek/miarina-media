import { beforeEach, describe, expect, it } from 'vitest';
import { isRunning, summarize, useDownloads } from './downloads';
import { effectiveConcurrency, useSettings } from './settings';

const store = () => useDownloads.getState();

beforeEach(() => {
  useDownloads.setState(useDownloads.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
});

describe('download simulation', () => {
  it('advances running tasks and leaves paused ones untouched', () => {
    const [running, , paused] = store().tasks;
    store().tick(1, 3);
    const after = store().tasks;
    expect(after.find((t) => t.id === running!.id)!.percent).toBeCloseTo(
      running!.percent + running!.rate,
    );
    expect(after.find((t) => t.id === paused!.id)!.percent).toBe(paused!.percent);
  });

  it('completes a task at 100 % and records it in history', () => {
    store().tick(100, 3);
    const completed = store().tasks.filter((t) => t.status === 'completed');
    expect(completed.length).toBeGreaterThan(0);
    expect(
      store().history[0]!.entries.some(
        (e) => e.status === 'Completed' && e.title === completed[0]!.title,
      ),
    ).toBe(true);
  });

  it('starts queued items only when a slot is free', () => {
    const queued = store().queue.length;
    store().tick(1, 2); // two already running: no slot
    expect(store().queue).toHaveLength(queued);
    store().tick(1, 3); // one slot
    expect(store().queue).toHaveLength(queued - 1);
    expect(store().tasks.filter(isRunning)).toHaveLength(3);
  });

  it('cancels a task and logs it as Cancelled', () => {
    const id = store().tasks[0]!.id;
    store().cancel(id);
    expect(store().tasks.find((t) => t.id === id)).toBeUndefined();
    expect(store().history[0]!.entries[0]!.status).toBe('Cancelled');
  });

  it('reorders the queue and ignores out-of-range moves', () => {
    const [a, b] = store().queue;
    store().moveQueued(0, 1);
    expect(
      store()
        .queue.slice(0, 2)
        .map((q) => q.id),
    ).toEqual([b!.id, a!.id]);
    const before = store().queue;
    store().moveQueued(0, -1);
    expect(store().queue).toBe(before);
  });

  it('pause all / resume all', () => {
    store().pauseAll();
    expect(store().tasks.some(isRunning)).toBe(false);
    expect(summarize(store().tasks).stateLabel).toBe('All paused');
    store().resumeAll();
    expect(store().tasks.filter(isRunning)).toHaveLength(3);
  });
});

describe('resource modes', () => {
  it('bound concurrency according to the mode', () => {
    const s = (resourceMode: 'eco' | 'balanced' | 'performance', concurrency: number) =>
      effectiveConcurrency({ resourceMode, concurrency });
    expect(s('eco', 8)).toBe(1);
    expect(s('balanced', 8)).toBe(3);
    expect(s('balanced', 2)).toBe(2);
    expect(s('performance', 8)).toBe(8);
  });

  it('clamps the user concurrency setting', () => {
    useSettings.getState().setConcurrency(42);
    expect(useSettings.getState().concurrency).toBe(8);
    useSettings.getState().setConcurrency(0);
    expect(useSettings.getState().concurrency).toBe(1);
  });
});

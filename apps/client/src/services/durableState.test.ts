import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const invoke = vi.fn();
vi.mock('@tauri-apps/api/core', () => ({
  invoke: (...args: unknown[]) => invoke(...args),
  isTauri: () => true,
}));

const durable = await import('./durableState');

beforeEach(() => {
  localStorage.clear();
  invoke.mockReset();
  durable.resetDurableStateForTests();
});
afterEach(() => vi.useRealTimers());

const writes = () =>
  invoke.mock.calls
    .filter(([cmd]) => cmd === 'playback_write')
    .flatMap(([, args]) => (args as { changes: { key: string; value: string | null }[] }).changes);

describe('durable playback state (L02)', () => {
  it('imports the existing local copy on the first launch', async () => {
    localStorage.setItem('mm:position:7', '75');
    localStorage.setItem('mm:player:v1', '{"queue":[]}');
    localStorage.setItem('mm:lang', 'fr');
    localStorage.setItem('mm:sidebar', 'collapsed');
    invoke.mockImplementation(async (cmd: string) =>
      cmd === 'playback_load' ? { imported: false, entries: [] } : undefined,
    );
    expect(await durable.hydrateDurableState()).toBe('imported');
    const sent = writes();
    expect(sent).toEqual(
      expect.arrayContaining([
        { key: 'mm:position:7', value: '75' },
        { key: 'mm:player:v1', value: '{"queue":[]}' },
        { key: 'mm:lang', value: 'fr' },
        { key: 'meta:imported', value: '1' },
      ]),
    );
    // Unrelated keys stay local.
    expect(sent.some((c) => c.key === 'mm:sidebar')).toBe(false);
  });

  it('rewrites a lost or stale local copy from SQLite', async () => {
    localStorage.setItem('mm:position:3', '40');
    localStorage.setItem('mm:sidebar', 'collapsed');
    invoke.mockImplementation(async (cmd: string) =>
      cmd === 'playback_load'
        ? {
            imported: true,
            entries: [
              ['mm:position:7', '75'],
              ['mm:mobile:session:v1', '{"queue":[],"currentId":1}'],
            ],
          }
        : undefined,
    );
    expect(await durable.hydrateDurableState()).toBe('restored');
    expect(localStorage.getItem('mm:position:7')).toBe('75');
    expect(localStorage.getItem('mm:mobile:session:v1')).toContain('currentId');
    expect(localStorage.getItem('mm:position:3')).toBeNull();
    expect(localStorage.getItem('mm:sidebar')).toBe('collapsed');
  });

  it('batches writes, keeps the latest value and retries after a failure', async () => {
    invoke.mockImplementation(async (cmd: string) =>
      cmd === 'playback_load' ? { imported: true, entries: [] } : undefined,
    );
    await durable.hydrateDurableState();
    vi.useFakeTimers();
    durable.durableSet('mm:position:7', '10');
    durable.durableSet('mm:position:7', '15');
    durable.durableRemove('mm:player:v1');
    durable.durableSet('mm:sidebar', 'open');
    expect(localStorage.getItem('mm:position:7')).toBe('15');

    invoke.mockRejectedValueOnce(new Error('busy'));
    await vi.advanceTimersByTimeAsync(1000);
    expect(writes()).toEqual([
      { key: 'mm:position:7', value: '15' },
      { key: 'mm:player:v1', value: null },
    ]);
    invoke.mockClear();
    await vi.advanceTimersByTimeAsync(5000);
    expect(writes()).toEqual([
      { key: 'mm:position:7', value: '15' },
      { key: 'mm:player:v1', value: null },
    ]);
  });

  it('keeps the local copy when SQLite does not answer, without durable writes', async () => {
    invoke.mockImplementation(() => new Promise(() => {}));
    vi.useFakeTimers();
    const result = durable.hydrateDurableState();
    await vi.advanceTimersByTimeAsync(1500);
    expect(await result).toBe('local');
    invoke.mockClear();
    durable.durableSet('mm:position:7', '20');
    await vi.advanceTimersByTimeAsync(2000);
    expect(invoke).not.toHaveBeenCalled();
    expect(localStorage.getItem('mm:position:7')).toBe('20');
  });
});

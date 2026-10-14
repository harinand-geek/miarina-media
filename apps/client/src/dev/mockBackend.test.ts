import { afterEach, describe, expect, it } from 'vitest';
import type { BackendEvent } from '../services/types';
import { MockBackend, mockLimits } from './mockBackend';

let unsubscribe: (() => void) | undefined;
afterEach(() => unsubscribe?.());

async function running(backend: MockBackend) {
  return (await backend.listTasks()).filter((t) => t.state === 'downloading');
}

describe('mock backend contract', () => {
  it('fills free slots up to the concurrency limit', async () => {
    const backend = new MockBackend();
    unsubscribe = backend.subscribe(() => {});
    expect(await running(backend)).toHaveLength(3);
  });

  it('lowers the limit in Eco mode for new starts', async () => {
    const backend = new MockBackend();
    const settings = await backend.setResourceMode('eco');
    expect(settings.limits.maxDownloads).toBe(1);
    unsubscribe = backend.subscribe(() => {});
    // The two seeded transfers keep running; nothing new is started.
    expect(await running(backend)).toHaveLength(2);
  });

  it('rejects invalid transitions like the Rust state machine', async () => {
    const backend = new MockBackend();
    await expect(backend.resume('d1')).resolves.toBeUndefined(); // no-op while downloading
    await backend.cancel('d1');
    await expect(backend.pause('d1')).rejects.toThrow(/not found/);
  });

  it('emits a cancelled history entry', async () => {
    const backend = new MockBackend();
    const events: BackendEvent[] = [];
    unsubscribe = backend.subscribe((e) => events.push(e));
    await backend.cancel('d2');
    expect(events.some((e) => e.type === 'history' && e.payload.status === 'canceled')).toBe(true);
  });

  it('mirrors the Rust resource limits', () => {
    expect(mockLimits('balanced', 8).maxDownloads).toBe(3);
    expect(mockLimits('performance', 6).maxDownloads).toBe(6);
    expect(mockLimits('eco', 6)).toMatchObject({
      maxDownloads: 1,
      progressInterval: 2000,
      reducedMotion: true,
    });
  });
});

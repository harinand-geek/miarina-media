import { act, renderHook, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MediaRecord } from '../../services/types';

const invoke = vi.fn();
vi.mock('@tauri-apps/api/core', () => ({
  invoke: (...args: unknown[]) => invoke(...args),
  isTauri: () => true,
}));

const { useNativePlayback } = await import('./useNativePlayback');
const { useMobilePlayback } = await import('../../stores/mobilePlayback');
const { useUi } = await import('../../stores/ui');
const { restoreMobileSession } = await import('./restoreSession');

const media = {
  id: 7,
  kind: 'video',
  durationSecs: null,
} as unknown as MediaRecord;

const status = (positionMs: number, playing = true) => ({
  open: true,
  positionMs,
  durationMs: 52_000,
  bufferedMs: positionMs,
  playing,
  ended: false,
  rate: 1,
});

beforeEach(() => {
  localStorage.clear();
  invoke.mockReset();
  invoke.mockImplementation(async (cmd: string) => {
    if (cmd === 'player_open') return true;
    if (cmd === 'player_status') return status(12_500);
    if (cmd === 'player_close') return { open: false, positionMs: 30_400, durationMs: 52_000 };
    return undefined;
  });
});

afterEach(() => vi.useRealTimers());

describe('useNativePlayback', () => {
  it('opens at the saved position, follows the native clock and saves on close', async () => {
    localStorage.setItem('mm:position:7', '21');
    const { result, unmount } = renderHook(() => useNativePlayback(media));
    expect(invoke).toHaveBeenCalledWith('player_open', { ids: [7], index: 0, positionSecs: 21 });

    await waitFor(() => expect(result.current.time).toBe(12.5), { timeout: 2000 });
    expect(result.current.duration).toBe(52);
    expect(result.current.playing).toBe(true);

    act(() => result.current.toggle());
    expect(invoke).toHaveBeenCalledWith('player_pause');
    act(() => result.current.skip(10));
    expect(invoke).toHaveBeenCalledWith('player_seek', { positionSecs: 22.5 });
    act(() => result.current.setRate(1.5));
    expect(invoke).toHaveBeenCalledWith('player_rate', { rate: 1.5 });

    unmount();
    await waitFor(() => expect(localStorage.getItem('mm:position:7')).toBe('30'));
    expect(invoke).toHaveBeenCalledWith('player_close');
  });

  it('reports an error when the file cannot be opened', async () => {
    invoke.mockImplementation(async (cmd: string) => {
      if (cmd === 'player_open') throw new Error('not_found');
      return undefined;
    });
    const { result } = renderHook(() => useNativePlayback(media));
    await waitFor(() => expect(result.current.error).toBe(true));
    expect(invoke).not.toHaveBeenCalledWith('player_status');
  });
});

describe('native queue session (L03)', () => {
  const track = (id: number) =>
    ({ id, kind: 'audio', title: `T${id}`, durationSecs: 200 }) as unknown as MediaRecord;
  const tracks = [1, 2, 3].map(track);
  let current = 1;

  beforeEach(() => {
    current = 1;
    useUi.setState(useUi.getInitialState(), true);
    useMobilePlayback.setState({ repeat: 'off', sleep: { mode: 'off' } });
    useMobilePlayback.getState().start(tracks[0]!, tracks, 'Album');
    invoke.mockImplementation(async (cmd: string) => {
      if (cmd === 'player_open') return false;
      if (cmd === 'player_status')
        return { ...status(5_000), index: current - 1, mediaId: current };
      return undefined;
    });
  });

  const render = () =>
    renderHook(() => useNativePlayback(useUi((s) => s.nowPlaying) ?? tracks[0]!));

  it('hands the whole queue to the service and follows it when it moves on', async () => {
    render();
    expect(invoke).toHaveBeenCalledWith('player_open', {
      ids: [1, 2, 3],
      index: 0,
      positionSecs: 0,
    });
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('player_repeat', { mode: 'off' }));
    current = 2; // e.g. end of track with the screen locked
    await waitFor(() => expect(useUi.getState().nowPlaying?.id).toBe(2), { timeout: 2000 });
    expect(invoke).not.toHaveBeenCalledWith('player_skip', expect.anything());
  });

  it('forwards track changes, queue order and repeat from the UI', async () => {
    render();
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('player_repeat', { mode: 'off' }));
    act(() => {
      useMobilePlayback.getState().next(true);
    });
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('player_skip', { index: 1 }));
    // Statuses still naming track 1 must not pull the UI back.
    await new Promise((r) => setTimeout(r, 600));
    expect(useUi.getState().nowPlaying?.id).toBe(2);
    current = 2;
    act(() => useMobilePlayback.getState().move(2, 0));
    expect(invoke).toHaveBeenCalledWith('player_queue', { ids: [3, 1, 2], currentIndex: 2 });
    act(() => useMobilePlayback.getState().cycleRepeat());
    expect(invoke).toHaveBeenCalledWith('player_repeat', { mode: 'all' });
  });

  it('pauses after the current track for the end-of-track sleep timer', async () => {
    render();
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('player_repeat', { mode: 'off' }));
    act(() => useMobilePlayback.getState().setSleep('end'));
    current = 2;
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('player_pause'), { timeout: 2000 });
    expect(useMobilePlayback.getState().sleep.mode).toBe('off');
  });
});

describe('restore after a restart (AND-05)', () => {
  const track = (id: number) =>
    ({ id, kind: 'audio', title: `T${id}`, durationSecs: 200 }) as unknown as MediaRecord;
  const tracks = [1, 2, 3].map(track);

  beforeEach(() => {
    useUi.setState(useUi.getInitialState(), true);
    useMobilePlayback.setState({ repeat: 'off', sleep: { mode: 'off' }, startMode: 'open' });
  });

  const saveQueueOn = (id: number) => {
    useMobilePlayback.getState().start(tracks[0]!, tracks, 'Album · Test');
    useMobilePlayback.getState().playAt(id - 1);
    useMobilePlayback.getState().cycleRepeat();
    // A new process: memory is gone, storage stays.
    const stored = localStorage.getItem('mm:mobile:session:v1');
    useUi.setState(useUi.getInitialState(), true);
    useMobilePlayback.setState({ queue: [], source: null, repeat: 'off', startMode: 'open' });
    localStorage.setItem('mm:mobile:session:v1', stored!);
    invoke.mockReset();
  };

  it('attaches to the service when it still plays the saved queue', async () => {
    saveQueueOn(2);
    invoke.mockImplementation(async (cmd: string) =>
      cmd === 'player_status' ? { ...status(40_000), index: 1, mediaId: 2 } : undefined,
    );
    await restoreMobileSession();
    expect(useUi.getState().nowPlaying?.id).toBe(2);
    expect(useUi.getState().mobilePlayerExpanded).toBe(false);
    expect(useMobilePlayback.getState().source).toBe('Album · Test');
    expect(useMobilePlayback.getState().repeat).toBe('all');
    const { result } = renderHook(() => useNativePlayback(useUi((s) => s.nowPlaying)!));
    await waitFor(() => expect(result.current.time).toBe(40), { timeout: 2000 });
    expect(invoke).not.toHaveBeenCalledWith('player_open', expect.anything());
  });

  it('offers the saved queue paused and opens it only on Play', async () => {
    saveQueueOn(3);
    localStorage.setItem('mm:position:3', '75');
    invoke.mockImplementation(async (cmd: string) => {
      if (cmd === 'player_status') return { open: false };
      if (cmd === 'player_open') return false;
      return undefined;
    });
    await restoreMobileSession();
    expect(useUi.getState().nowPlaying?.id).toBe(3);
    const { result } = renderHook(() => useNativePlayback(useUi((s) => s.nowPlaying)!));
    await new Promise((r) => setTimeout(r, 400));
    expect(invoke).not.toHaveBeenCalledWith('player_open', expect.anything());
    expect(result.current.playing).toBe(false);
    expect(result.current.time).toBe(75);
    act(() => result.current.toggle());
    expect(invoke).toHaveBeenCalledWith('player_open', {
      ids: [1, 2, 3],
      index: 2,
      positionSecs: 75,
    });
  });

  it('offers the saved queue when the service does not answer', async () => {
    saveQueueOn(2);
    invoke.mockImplementation((cmd: string) =>
      cmd === 'player_status' ? new Promise(() => {}) : Promise.resolve(undefined),
    );
    vi.useFakeTimers();
    const restoring = restoreMobileSession();
    await vi.advanceTimersByTimeAsync(3000);
    await restoring;
    expect(useUi.getState().nowPlaying?.id).toBe(2);
    expect(useMobilePlayback.getState().startMode).toBe('deferred');
  });

  it('keeps the resume point fresh while playing (process may be killed)', async () => {
    saveQueueOn(2);
    invoke.mockImplementation(async (cmd: string) =>
      cmd === 'player_status' ? { ...status(40_000), index: 1, mediaId: 2 } : undefined,
    );
    await restoreMobileSession();
    renderHook(() => useNativePlayback(useUi((s) => s.nowPlaying)!));
    await waitFor(() => expect(localStorage.getItem('mm:position:2')).toBe('40'), {
      timeout: 2000,
    });
  });

  it('does nothing without a saved session', async () => {
    localStorage.clear();
    invoke.mockImplementation(async () => ({ open: false }));
    await restoreMobileSession();
    expect(useUi.getState().nowPlaying).toBeNull();
  });
});

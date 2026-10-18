import { act, renderHook, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MediaRecord } from '../../services/types';

const invoke = vi.fn();
vi.mock('@tauri-apps/api/core', () => ({
  invoke: (...args: unknown[]) => invoke(...args),
  isTauri: () => true,
}));

const { useNativePlayback } = await import('./useNativePlayback');

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
    expect(invoke).toHaveBeenCalledWith('player_open', { id: 7, positionSecs: 21 });

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

import { act, renderHook } from '@testing-library/react';
import { beforeEach, expect, it, vi } from 'vitest';
import { usePlayback, savedPosition } from './usePlayback';
import type { MediaRecord } from '../../services/types';

vi.mock('../../services/backend', () => ({
  backend: { mediaUrl: () => 'asset://test/video.mp4' },
}));

beforeEach(() => localStorage.clear());

it('remembers playback when React detaches the element before cleanup', () => {
  const media = { id: 42, path: '/video.mp4', durationSecs: 120 } as MediaRecord;
  const { result, unmount } = renderHook(() => usePlayback(media));
  const video = document.createElement('video');
  Object.defineProperty(video, 'duration', { value: 120 });
  video.currentTime = 37;
  act(() => result.current.attachMedia(video));
  act(() => result.current.attachMedia(null));
  unmount();
  expect(savedPosition(42)).toBe(37);
});

it('reloads a failed decoder at the interrupted position and clears the error', async () => {
  const media = { id: 43, path: '/video.mp4', durationSecs: 322 } as MediaRecord;
  const { result } = renderHook(() => usePlayback(media));
  const video = document.createElement('video');
  Object.defineProperty(video, 'duration', { value: 322 });
  let error: { code: number } | null = { code: 3 };
  Object.defineProperty(video, 'error', { get: () => error });
  video.play = vi.fn().mockResolvedValue(undefined);
  video.load = vi.fn(() => {
    error = null;
    video.currentTime = 0;
  });
  act(() => {
    result.current.attachMedia(video);
    video.currentTime = 184;
    video.dispatchEvent(new Event('error'));
  });
  expect(result.current.errorCode).toBe(3);
  expect(result.current.error).toBe(true);
  expect(result.current.playing).toBe(false);
  act(() => result.current.retry());
  expect(video.load).toHaveBeenCalledTimes(1);
  await act(async () => {
    video.dispatchEvent(new Event('loadedmetadata'));
    video.dispatchEvent(new Event('loadeddata'));
  });
  expect(video.currentTime).toBe(184);
  expect(video.play).toHaveBeenCalled();
  expect(result.current.error).toBe(false);
  expect(result.current.errorCode).toBeNull();
});

it('keeps an unsupported-source error distinct and reports a failed retry', () => {
  const media = { id: 44, path: '/video.mp4', durationSecs: 120 } as MediaRecord;
  const { result } = renderHook(() => usePlayback(media));
  const video = document.createElement('video');
  Object.defineProperty(video, 'error', { value: { code: 4 } });
  video.load = vi.fn();
  act(() => {
    result.current.attachMedia(video);
    video.dispatchEvent(new Event('error'));
  });
  expect(result.current.errorCode).toBe(4);
  act(() => result.current.retry());
  act(() => video.dispatchEvent(new Event('error')));
  expect(result.current.error).toBe(true);
  expect(result.current.errorCode).toBe(4);
});

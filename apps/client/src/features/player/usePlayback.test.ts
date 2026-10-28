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

import { act, renderHook } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import type { MediaFormat, MediaInfo, TaskRecord } from '../../services/types';
import { useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { useStartActions } from './useAnalysis';

const format: MediaFormat = {
  id: 'mp3',
  quality: 'MP3 · 320 kbps',
  detail: 'MP3',
  size: '24 MB',
  extension: 'mp3',
};
const info: MediaInfo = {
  url: 'https://example.org/media',
  host: 'example.org',
  engine: 'ytdlp',
  title: 'Example',
  subtitle: '',
  publisher: '',
  formats: { video: [], audio: [format], subtitles: [] },
};

afterEach(() => {
  useDownloads.setState(useDownloads.getInitialState(), true);
  useUi.setState(useUi.getInitialState(), true);
});

it('ignores rapid duplicate downloads and queue requests, then permits retry after failure', async () => {
  let finish!: (value: TaskRecord | null) => void;
  // Keep creation pending so repeated taps happen before the backend answers.
  const pendingStart = vi.fn(
    () =>
      new Promise<TaskRecord | null>((resolve) => {
        finish = resolve;
      }),
  );
  useDownloads.setState({ start: pendingStart });
  const { result } = renderHook(() => useStartActions());
  let request!: Promise<TaskRecord | null>;
  act(() => {
    request = result.current.download(info, format, 'audio');
    void result.current.download(info, format, 'audio');
    void result.current.addToQueue(info, format, 'audio');
  });
  expect(pendingStart).toHaveBeenCalledTimes(1);
  expect(result.current.starting).toBe(true);
  await act(async () => {
    finish(null);
    await request;
  });
  expect(result.current.starting).toBe(false);
  expect(useUi.getState().toasts).toHaveLength(0);
  act(() => {
    request = result.current.download(info, format, 'audio');
  });
  expect(pendingStart).toHaveBeenCalledTimes(2);
  await act(async () => {
    finish(null);
    await request;
  });
});

it('releases the guard if task creation unexpectedly rejects', async () => {
  const start = vi.fn().mockRejectedValueOnce(new Error('unavailable')).mockResolvedValue(null);
  useDownloads.setState({ start });
  const { result } = renderHook(() => useStartActions());
  await act(async () => {
    await expect(result.current.download(info, format, 'audio')).rejects.toThrow('unavailable');
  });
  expect(result.current.starting).toBe(false);
  await act(async () => {
    await result.current.download(info, format, 'audio');
  });
  expect(start).toHaveBeenCalledTimes(2);
});

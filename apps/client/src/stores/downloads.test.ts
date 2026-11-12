import { beforeEach, describe, expect, it } from 'vitest';
import type { DownloadTask, TaskRecord } from '../services/types';
import { isQueued, summarize, useDownloads } from './downloads';
import { statusLabel } from '../features/downloads/status';

const MB = 1024 * 1024;

function record(id: string, patch: Partial<TaskRecord> = {}): TaskRecord {
  return {
    id,
    url: `https://example.org/${id}.mp4`,
    sourceHost: 'example.org',
    title: `Movie ${id}`,
    kind: 'video',
    engine: 'http',
    formatId: null,
    formatLabel: 'MP4',
    state: 'downloading',
    position: 1,
    destDir: 'C:/Videos',
    fileName: `${id}.mp4`,
    partPath: null,
    finalPath: null,
    totalBytes: 100 * MB,
    downloadedBytes: 0,
    supportsResume: true,
    attempts: 0,
    errorCode: null,
    errorMessage: null,
    createdAt: 0,
    updatedAt: 0,
    completedAt: null,
    thumbnail: null,
    ...patch,
  };
}

const state = () => useDownloads.getState();

beforeEach(() => {
  useDownloads.setState(useDownloads.getInitialState(), true);
});

describe('backend events', () => {
  it('applies progress to the matching task only', () => {
    state().apply({ type: 'task', payload: record('a') });
    state().apply({ type: 'task', payload: record('b') });
    state().apply({
      type: 'progress',
      payload: {
        id: 'a',
        downloaded: 40 * MB,
        total: 100 * MB,
        bytesPerSec: 2 * MB,
        supportsResume: true,
        etaSecs: 30,
      },
    });
    expect(state().tasks.a!.downloadedBytes).toBe(40 * MB);
    expect(state().tasks.a!.etaSecs).toBe(30);
    expect(state().tasks.b!.downloadedBytes).toBe(0);
  });

  it('keeps the latest byte count when a stale record arrives', () => {
    state().apply({ type: 'task', payload: record('a') });
    state().apply({
      type: 'progress',
      payload: {
        id: 'a',
        downloaded: 60 * MB,
        total: 100 * MB,
        bytesPerSec: MB,
        supportsResume: true,
        etaSecs: 40,
      },
    });
    state().apply({ type: 'task', payload: record('a', { downloadedBytes: 50 * MB }) });
    expect(state().tasks.a!.downloadedBytes).toBe(60 * MB);
  });

  it('never lets a late command snapshot overwrite a newer event', async () => {
    // Regression: the Download response ("waiting") arrived after the
    // "downloading" event and kept the row in the queue for the whole transfer.
    const { resetMockBackend } = await import('../services/backend');
    const backend = resetMockBackend();
    const stale = record('late', { state: 'waiting' });
    backend.start = async () => {
      state().apply({ type: 'task', payload: { ...stale, state: 'downloading' } });
      return stale;
    };
    await state().start({
      url: stale.url,
      title: stale.title,
      kind: 'video',
      engine: 'http',
      formatId: null,
      formatLabel: 'MP4',
      extension: 'mp4',
      startNow: true,
    });
    expect(state().tasks.late!.state).toBe('downloading');
  });

  it('drops canceled tasks and records history', () => {
    state().apply({ type: 'task', payload: record('a') });
    state().apply({ type: 'task', payload: record('a', { state: 'canceled' }) });
    expect(state().tasks.a).toBeUndefined();
    state().apply({
      type: 'history',
      payload: {
        id: 1,
        taskId: 'a',
        url: 'https://example.org/a.mp4',
        title: 'Movie a',
        sourceHost: 'example.org',
        formatLabel: 'MP4',
        totalBytes: null,
        doneBytes: 0,
        status: 'canceled',
        reason: null,
        finalPath: null,
        finishedAt: 1,
      },
    });
    expect(state().history).toHaveLength(1);
  });

  it('shows retry countdowns as errors, not as queued items', () => {
    state().apply({ type: 'task', payload: record('a', { state: 'waiting', attempts: 1 }) });
    state().apply({ type: 'retrying', payload: { id: 'a', retry: 1, inSecs: 8, reason: 'reset' } });
    const task = state().tasks.a!;
    expect(isQueued(task)).toBe(false);
    expect(statusLabel(task)).toMatch(/^Connection lost · retrying in [78] s$/);
  });
});

describe('summaries and labels', () => {
  const task = (patch: Partial<DownloadTask>): DownloadTask => ({
    ...record('x'),
    bytesPerSec: 0,
    etaSecs: null,
    ...patch,
  });

  it('separates running, active and queued tasks', () => {
    const summary = summarize({
      a: task({ id: 'a', state: 'downloading', bytesPerSec: 3 * MB }),
      b: task({ id: 'b', state: 'paused' }),
      c: task({ id: 'c', state: 'queued' }),
      d: task({ id: 'd', state: 'completed' }),
    });
    expect(summary.running).toHaveLength(1);
    expect(summary.active.map((t) => t.id)).toEqual(['a', 'b']);
    expect(summary.queued.map((t) => t.id)).toEqual(['c']);
    expect(summary.openCount).toBe(3);
    expect(summary.speedLabel).toBe('3.0 MB/s');
  });

  it('never promises a resume the source does not support', () => {
    expect(statusLabel(task({ state: 'paused', supportsResume: true, downloadedBytes: MB }))).toBe(
      'Paused',
    );
    expect(statusLabel(task({ state: 'paused', supportsResume: false, downloadedBytes: MB }))).toBe(
      'Paused · will restart',
    );
  });

  it('labels disk-full failures', () => {
    expect(statusLabel(task({ state: 'failed', errorCode: 'disk_full' }))).toBe(
      'Failed · disk full',
    );
    expect(statusLabel(task({ state: 'failed', errorCode: 'http' }))).toBe('Failed');
  });
});

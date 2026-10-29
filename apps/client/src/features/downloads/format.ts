import { formatBytes, formatSpeed, percentOf } from '../../stores/downloads';
import type { DownloadTask } from '../../services/types';

export function etaLabel(seconds: number) {
  const s = Math.max(0, Math.round(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${ss}` : `${m}:${ss}`;
}

export function doneLabel(task: DownloadTask) {
  return task.totalBytes
    ? `${formatBytes(task.downloadedBytes)} of ${formatBytes(task.totalBytes)}`
    : formatBytes(task.downloadedBytes);
}

/** Seconds left before an automatic retry, counted from the notice. */
export function retryIn(task: DownloadTask, now = Date.now()) {
  if (!task.retry) return 0;
  return Math.max(0, Math.ceil(task.retry.inSecs - (now - task.retry.at) / 1000));
}

/**
 * Status text. State is always carried by words, never by color alone, and
 * never promises a resume the source does not support.
 */
export function statusLabel(task: DownloadTask) {
  switch (task.state) {
    case 'completed':
      return 'Completed';
    case 'paused':
      return task.supportsResume || task.downloadedBytes === 0 ? 'Paused' : 'Paused · will restart';
    case 'failed':
      return task.errorCode === 'disk_full' || task.errorCode === 'insufficient_space'
        ? 'Failed · disk full'
        : 'Failed';
    case 'processing':
      return 'Processing media…';
    case 'waiting':
      return task.retry
        ? `Connection lost · retrying in ${retryIn(task)} s`
        : 'Waiting for a free slot';
    case 'queued':
      return 'Waiting for a free slot';
    case 'analyzing':
      return 'Reading available formats…';
    case 'downloading':
      if (task.bytesPerSec <= 0) return 'Starting…';
      return task.etaSecs !== null
        ? `${formatSpeed(task.bytesPerSec)} · ${etaLabel(task.etaSecs)} left`
        : formatSpeed(task.bytesPerSec);
    case 'canceled':
      return 'Canceled';
  }
}

export type BarTone = 'active' | 'paused' | 'error' | 'complete';

export function barTone(task: DownloadTask): BarTone {
  if (task.state === 'completed') return 'complete';
  if (task.state === 'failed' || task.retry) return 'error';
  if (task.state === 'paused') return 'paused';
  return 'active';
}

export function statusTone(task: DownloadTask) {
  if (task.state === 'completed') return 'text-accent-strong';
  if (task.state === 'failed' || task.retry) return 'text-danger';
  if (task.state === 'paused') return 'text-warn';
  return 'text-muted';
}

/** Screen reader label, e.g. "Tears of Steel, 60 percent, 1 minute left". */
export function progressAriaLabel(task: DownloadTask) {
  // Live announcements are throttled to 10 % steps (design system §8).
  const percent = Math.floor(percentOf(task) / 10) * 10;
  if (task.state !== 'downloading' || task.etaSecs === null) {
    return `${task.title}, ${percent} percent, ${statusLabel(task)}`;
  }
  const minutes = Math.max(1, Math.round(task.etaSecs / 60));
  return `${task.title}, ${percent} percent, ${minutes} minute${minutes > 1 ? 's' : ''} left`;
}

/** Indeterminate bar while the size is unknown or during processing. */
export function barValue(task: DownloadTask): number | null {
  if (task.state === 'processing') return null;
  if (task.state === 'downloading' && !task.totalBytes) return null;
  return percentOf(task);
}

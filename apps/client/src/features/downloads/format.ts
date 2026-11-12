import { percentOf } from '../../stores/downloads';
import type { DownloadTask } from '../../services/types';

export function etaLabel(seconds: number) {
  const s = Math.max(0, Math.round(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${ss}` : `${m}:${ss}`;
}

/** Seconds left before an automatic retry, counted from the notice. */
export function retryIn(task: DownloadTask, now = Date.now()) {
  if (!task.retry) return 0;
  return Math.max(0, Math.ceil(task.retry.inSecs - (now - task.retry.at) / 1000));
}

export type BarTone = 'active' | 'paused' | 'error' | 'complete';

export function barTone(task: DownloadTask): BarTone {
  if (task.state === 'completed') return 'complete';
  if (task.state === 'failed' || task.retry) return 'error';
  if (task.state === 'paused') return 'paused';
  return 'active';
}

/** Indeterminate bar while the size is unknown or during processing. */
export function barValue(task: DownloadTask): number | null {
  if (task.state === 'processing') return null;
  if (task.state === 'downloading' && !task.totalBytes) return null;
  return percentOf(task);
}

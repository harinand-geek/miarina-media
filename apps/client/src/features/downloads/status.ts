import { useMemo } from 'react';
import { t as translateNow, type Translate } from '../../i18n';
import { backend } from '../../services/backend';
import type { DownloadTask, HistoryEntry, MediaRecord } from '../../services/types';
import {
  formatBytes,
  formatSpeed,
  isOpen,
  ordered,
  percentOf,
  useDownloads,
} from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { etaLabel, retryIn } from './format';

export interface Status {
  icon: string;
  text: string;
  /** Text color class: the state is always carried by words too. */
  tone: string;
  detail: string;
}

const pct = (task: DownloadTask) => `${Math.floor(percentOf(task))} %`;

const extOf = (task: DownloadTask) => (task.fileName.split('.').pop() ?? '').toUpperCase();

/** "246 MB / 372 MB · 6.4 MB/s · 0:20" (Windows) or "62 % · 0:20" (Android). */
function transferDetail(task: DownloadTask, wide: boolean) {
  if (!wide) return task.etaSecs !== null ? `${pct(task)} · ${etaLabel(task.etaSecs)}` : pct(task);
  const parts = [
    task.totalBytes
      ? `${formatBytes(task.downloadedBytes)} / ${formatBytes(task.totalBytes)}`
      : formatBytes(task.downloadedBytes),
  ];
  if (task.bytesPerSec > 0) parts.push(formatSpeed(task.bytesPerSec));
  if (task.etaSecs !== null) parts.push(etaLabel(task.etaSecs));
  return parts.join(' · ');
}

/**
 * Icon + words for each state (Windows and Android v2, DL-02, DL-06):
 * conversion is shown as its own step, and a resume is only promised
 * when the source supports it.
 */
export function statusOf(task: DownloadTask, t: Translate, now: number, wide = false): Status {
  const resumeAt =
    task.supportsResume && task.downloadedBytes > 0
      ? t('stResumeAt', { n: Math.floor(percentOf(task)) })
      : '';
  if (task.retry?.offline) {
    return { icon: 'wifi_off', text: t('stOffline'), tone: 'text-warn', detail: resumeAt };
  }
  if (task.retry) {
    return {
      icon: 'wifi_off',
      text: t('stRetry', { n: retryIn(task, now) }),
      tone: 'text-danger',
      detail: resumeAt,
    };
  }
  switch (task.state) {
    case 'downloading':
      return {
        icon: 'downloading',
        text: task.bytesPerSec > 0 ? t('stDownloading') : t('stStarting'),
        tone: 'text-accent-strong',
        detail: transferDetail(task, wide),
      };
    case 'processing': {
      const ext = extOf(task);
      return {
        icon: 'sync',
        text: !ext
          ? t('stConverting')
          : task.kind === 'audio'
            ? t('stConvertingTo', { ext })
            : t('stFinalizing', { ext }),
        tone: 'text-accent-strong',
        detail: wide ? t('stStep') : '',
      };
    }
    case 'paused':
      return {
        icon: 'pause_circle',
        text:
          task.supportsResume || task.downloadedBytes === 0 ? t('stPaused') : t('stPausedRestart'),
        tone: 'text-warn',
        detail: wide && task.totalBytes ? formatBytes(task.totalBytes) : pct(task),
      };
    case 'failed': {
      const disk = task.errorCode === 'disk_full' || task.errorCode === 'insufficient_space';
      const denied = task.errorCode === 'access_denied';
      const hint = disk ? t('stDiskFullHint') : denied ? t('stAccessDeniedHint') : '';
      return {
        icon: 'error',
        text: disk ? t('stDiskFull') : denied ? t('stAccessDenied') : t('stFailed'),
        tone: 'text-danger',
        detail: [resumeAt, hint].filter(Boolean).join(' · '),
      };
    }
    case 'analyzing':
      return { icon: 'hourglass_empty', text: t('stAnalyzing'), tone: 'text-muted', detail: '' };
    default:
      return {
        icon: 'schedule',
        text: t('stQueued'),
        tone: 'text-muted',
        detail: task.totalBytes ? formatBytes(task.totalBytes) : '',
      };
  }
}

/**
 * Reason of a failed download in the user's language when the engine
 * failure is a known one (the stored reason is the engine's English text).
 */
export function failureReason(reason: string | null | undefined, t: Translate) {
  if (!reason) return null;
  if (reason.startsWith('the disk is full')) return t('whyDiskFull');
  if (reason.startsWith('not enough free space')) return t('whyNoSpace');
  if (reason.startsWith('the destination folder cannot be written to')) return t('whyDenied');
  return reason;
}

/** Queued or waiting for a slot: the main action starts it now. */
export const waitsForSlot = (task: DownloadTask) =>
  task.state === 'queued' || (task.state === 'waiting' && !task.retry);

/** The three lists of both Downloads screens. */
export function useDownloadLists() {
  const tasks = useDownloads((s) => s.tasks);
  const history = useDownloads((s) => s.history);
  return useMemo(() => {
    const all = ordered(tasks);
    const active = all.filter((x) => isOpen(x) && x.state !== 'failed');
    const failedTasks = all.filter((x) => x.state === 'failed');
    const failedHistory = history.filter((h) => h.status === 'failed');
    const done = history.filter((h) => h.status === 'completed');
    return {
      active,
      failedTasks,
      failedHistory,
      done,
      counts: {
        active: active.length,
        done: done.length,
        failed: failedTasks.length + failedHistory.length,
      },
    };
  }, [tasks, history]);
}

/** The library item a finished download became, if it is still there. */
export async function mediaOfDownload(entry: HistoryEntry): Promise<MediaRecord | null> {
  const match = (m: MediaRecord) =>
    m.taskId === entry.taskId || (!!entry.finalPath && m.path === entry.finalPath);
  const known = useLibrary.getState().items.find(match) ?? useLibrary.getState().recent.find(match);
  if (known) return known;
  try {
    const page = await backend.libraryQuery({ search: '', kind: null, sort: 'added', limit: 200 });
    return page.items.find(match) ?? null;
  } catch {
    return null;
  }
}

/** Status words in the interface language (tests, screen readers). */
export function statusLabel(task: DownloadTask, now = Date.now()) {
  return statusOf(task, translateNow, now).text;
}

/** Screen reader label, e.g. "Tears of Steel, 60 percent, 1 min left". */
export function progressAriaLabel(task: DownloadTask) {
  // Live announcements are throttled to 10 % steps (design system §8).
  const n = Math.floor(percentOf(task) / 10) * 10;
  if (task.state !== 'downloading' || task.etaSecs === null) {
    return translateNow('progressAria', { title: task.title, n, status: statusLabel(task) });
  }
  const m = Math.max(1, Math.round(task.etaSecs / 60));
  return translateNow('progressAriaEta', { title: task.title, n, m });
}

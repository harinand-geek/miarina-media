import { create } from 'zustand';
import { backend } from '../services/backend';
import type {
  BackendEvent,
  DownloadTask,
  HistoryEntry,
  StartRequest,
  TaskRecord,
} from '../services/types';
import { useUi } from './ui';

// Mirror of the Rust download manager. State changes only arrive through
// backend events; actions forward user intent and surface errors.

interface DownloadsState {
  tasks: Record<string, DownloadTask>;
  history: HistoryEntry[];
  ready: boolean;
  /** Loads tasks and history, then follows backend events. */
  init: () => () => void;
  apply: (event: BackendEvent) => void;
  start: (request: StartRequest) => Promise<TaskRecord | null>;
  pause: (id: string) => void;
  resume: (id: string) => void;
  cancel: (id: string) => void;
  retry: (id: string) => void;
  startNow: (id: string) => void;
  move: (id: string, index: number) => void;
  pauseAll: () => void;
  resumeAll: () => void;
  reveal: (id: string) => void;
  revealHistory: (id: number) => void;
  clearHistory: () => void;
}

const toTask = (record: TaskRecord, previous?: DownloadTask): DownloadTask => ({
  ...record,
  // A record may lag behind the last progress event; keep the larger value.
  downloadedBytes:
    previous && record.state === previous.state
      ? Math.max(previous.downloadedBytes, record.downloadedBytes)
      : record.downloadedBytes,
  bytesPerSec: record.state === 'downloading' ? (previous?.bytesPerSec ?? 0) : 0,
  etaSecs: record.state === 'downloading' ? (previous?.etaSecs ?? null) : null,
  retry: record.state === 'waiting' ? previous?.retry : undefined,
});

function report(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  useUi.getState().pushToast({ tone: 'error', message });
}

const run = (action: () => Promise<unknown>) => {
  action().catch(report);
};

export const useDownloads = create<DownloadsState>((set, get) => ({
  tasks: {},
  history: [],
  ready: false,

  init: () => {
    const unsubscribe = backend.subscribe((event) => get().apply(event));
    void Promise.all([backend.listTasks(), backend.listHistory()])
      .then(([records, history]) => {
        set((s) => {
          const tasks = { ...s.tasks };
          for (const r of records) tasks[r.id] = toTask(r, tasks[r.id]);
          return { tasks, history, ready: true };
        });
      })
      .catch(report);
    return unsubscribe;
  },

  apply: (event) =>
    set((s) => {
      switch (event.type) {
        case 'progress': {
          const p = event.payload;
          const task = s.tasks[p.id];
          if (!task) return s;
          return {
            tasks: {
              ...s.tasks,
              [p.id]: {
                ...task,
                downloadedBytes: p.downloaded,
                totalBytes: p.total ?? task.totalBytes,
                bytesPerSec: p.bytesPerSec,
                etaSecs: p.etaSecs,
                supportsResume: p.supportsResume,
                retry: undefined,
              },
            },
          };
        }
        case 'task': {
          const record = event.payload;
          if (record.state === 'canceled') {
            // eslint-disable-next-line @typescript-eslint/no-unused-vars
            const { [record.id]: _removed, ...rest } = s.tasks;
            return { tasks: rest };
          }
          return { tasks: { ...s.tasks, [record.id]: toTask(record, s.tasks[record.id]) } };
        }
        case 'removed': {
          // eslint-disable-next-line @typescript-eslint/no-unused-vars
          const { [event.payload.id]: _removed, ...rest } = s.tasks;
          return { tasks: rest };
        }
        case 'retrying': {
          const { id, inSecs, reason } = event.payload;
          const task = s.tasks[id];
          if (!task) return s;
          return {
            tasks: { ...s.tasks, [id]: { ...task, retry: { inSecs, reason, at: Date.now() } } },
          };
        }
        case 'history':
          return {
            history: [event.payload, ...s.history.filter((h) => h.id !== event.payload.id)],
          };
      }
    }),

  start: async (request) => {
    try {
      const record = await backend.start(request);
      set((s) => ({ tasks: { ...s.tasks, [record.id]: toTask(record, s.tasks[record.id]) } }));
      return record;
    } catch (e) {
      report(e);
      return null;
    }
  },
  pause: (id) => run(() => backend.pause(id)),
  resume: (id) => run(() => backend.resume(id)),
  cancel: (id) => run(() => backend.cancel(id)),
  retry: (id) => run(() => backend.retry(id)),
  startNow: (id) => run(() => backend.startNow(id)),
  move: (id, index) => run(() => backend.move(id, index)),
  pauseAll: () => run(() => backend.pauseAll()),
  resumeAll: () => run(() => backend.resumeAll()),
  reveal: (id) => run(() => backend.reveal(id)),
  revealHistory: (id) => run(() => backend.revealHistory(id)),
  clearHistory: () =>
    run(async () => {
      await backend.clearHistory();
      set({ history: [] });
    }),
}));

// ------------------------------------------------------------- selectors

export const isRunning = (t: DownloadTask) => t.state === 'downloading' || t.state === 'processing';

/** Waiting for a slot (not a retry backoff). */
export const isQueued = (t: DownloadTask) =>
  t.state === 'queued' || (t.state === 'waiting' && !t.retry && t.attempts === 0);

/** Rows of the "active" list: everything that is neither queued nor gone. */
export const isActiveRow = (t: DownloadTask) => !isQueued(t) && t.state !== 'canceled';

export const isOpen = (t: DownloadTask) => t.state !== 'completed' && t.state !== 'canceled';

export function ordered(tasks: Record<string, DownloadTask>) {
  return Object.values(tasks).sort((a, b) => a.position - b.position);
}

export function percentOf(t: Pick<DownloadTask, 'downloadedBytes' | 'totalBytes'>) {
  return t.totalBytes ? Math.min(100, (t.downloadedBytes / t.totalBytes) * 100) : 0;
}

export function formatBytes(bytes: number) {
  const KB = 1024;
  if (bytes >= KB ** 3) return `${(bytes / KB ** 3).toFixed(2)} GB`;
  if (bytes >= KB ** 2) return `${Math.round(bytes / KB ** 2)} MB`;
  if (bytes >= KB) return `${Math.round(bytes / KB)} KB`;
  return `${bytes} B`;
}

export function formatSpeed(bytesPerSec: number) {
  return `${(bytesPerSec / 1024 ** 2).toFixed(1)} MB/s`;
}

/** Aggregates used by the sidebar card, Home and the Downloads header. */
export function summarize(tasks: Record<string, DownloadTask>) {
  const all = ordered(tasks);
  const active = all.filter((t) => isOpen(t) && !isQueued(t));
  const running = active.filter(isRunning);
  const queued = all.filter(isQueued);
  const speed = running.reduce((acc, t) => acc + t.bytesPerSec, 0);
  return {
    active,
    running,
    queued,
    /** Badge count: everything still to finish. */
    openCount: all.filter(isOpen).length,
    // Paused only when something is actually paused; nothing to show when idle.
    speedLabel: speed > 0 ? formatSpeed(speed) : running.length || !active.length ? '—' : 'Paused',
    stateLabel: running.length
      ? `${running.length} downloading`
      : active.length
        ? 'All paused'
        : 'Idle',
    overallPercent: active.length
      ? Math.round(active.reduce((acc, t) => acc + percentOf(t), 0) / active.length)
      : 0,
  };
}

import { create } from 'zustand';
import { DOWNLOADS, HISTORY, QUEUE } from '../dev/fixtures';
import type { DownloadTask, HistoryEntry, HistoryGroup, QueueItem } from '../services/types';

// Phase 1 simulation of the download manager. The real scheduler, state
// machine and persistence live in Rust from Phase 2 on.

interface DownloadsState {
  tasks: DownloadTask[];
  queue: QueueItem[];
  history: HistoryGroup[];
  /** Advances simulated progress by `seconds` and fills free slots. */
  tick: (seconds: number, maxActive: number) => void;
  pause: (id: string) => void;
  resume: (id: string) => void;
  pauseAll: () => void;
  resumeAll: () => void;
  cancel: (id: string) => void;
  start: (item: Omit<DownloadTask, 'id' | 'percent' | 'rate' | 'status'>) => void;
  enqueue: (item: Omit<QueueItem, 'id'>) => void;
  startNow: (queueId: string) => void;
  removeQueued: (queueId: string) => void;
  moveQueued: (from: number, to: number) => void;
  clearHistory: () => void;
}

let seq = 0;
const nextId = (prefix: string) => `${prefix}-${Date.now()}-${++seq}`;
const SIMULATED_RATE = 1.5;

function nowTime() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function addToHistory(history: HistoryGroup[], entry: HistoryEntry): HistoryGroup[] {
  const [first, ...rest] = history;
  if (first?.day === 'Today') return [{ ...first, entries: [entry, ...first.entries] }, ...rest];
  return [{ day: 'Today', entries: [entry] }, ...history];
}

export function formatMb(mb: number) {
  return mb >= 1024 ? `${(mb / 1024).toFixed(2)} GB` : `${Math.round(mb)} MB`;
}

function parseSize(size: string) {
  const value = parseFloat(size);
  return size.includes('GB') ? value * 1024 : value;
}

export const isActive = (t: DownloadTask) => t.status !== 'completed';
export const isRunning = (t: DownloadTask) => t.status === 'downloading';

export const useDownloads = create<DownloadsState>((set) => ({
  tasks: DOWNLOADS,
  queue: QUEUE,
  history: HISTORY,

  tick: (seconds, maxActive) =>
    set((s) => {
      let history = s.history;
      const tasks = s.tasks.map((t): DownloadTask => {
        if (!isRunning(t)) return t;
        const percent = Math.min(100, t.percent + t.rate * seconds);
        if (percent < 100) return { ...t, percent };
        history = addToHistory(history, {
          id: nextId('h'),
          time: nowTime(),
          title: t.title,
          source: t.source,
          format: t.format,
          size: formatMb(t.totalMb),
          status: 'Completed',
        });
        return { ...t, percent: 100, status: 'completed' };
      });
      // A freed slot starts the next queued item (design: "Starts
      // automatically when a slot frees up").
      const queue = [...s.queue];
      let running = tasks.filter(isRunning).length;
      while (running < maxActive && queue.length > 0) {
        const next = queue.shift()!;
        tasks.push({
          id: nextId('d'),
          title: next.title,
          source: 'studio.blender.org',
          kind: next.kind,
          format: next.format,
          totalMb: parseSize(next.size),
          percent: 0,
          rate: SIMULATED_RATE,
          status: 'downloading',
        });
        running++;
      }
      return { tasks, queue, history };
    }),

  pause: (id) =>
    set((s) => ({
      tasks: s.tasks.map((t) => (t.id === id && isRunning(t) ? { ...t, status: 'paused' } : t)),
    })),
  resume: (id) =>
    set((s) => ({
      tasks: s.tasks.map((t) =>
        t.id === id && (t.status === 'paused' || t.status === 'waiting_wifi')
          ? { ...t, status: 'downloading' }
          : t,
      ),
    })),
  pauseAll: () =>
    set((s) => ({ tasks: s.tasks.map((t) => (isRunning(t) ? { ...t, status: 'paused' } : t)) })),
  resumeAll: () =>
    set((s) => ({
      tasks: s.tasks.map((t) => (t.status === 'paused' ? { ...t, status: 'downloading' } : t)),
    })),
  cancel: (id) =>
    set((s) => {
      const task = s.tasks.find((t) => t.id === id);
      if (!task) return s;
      return {
        tasks: s.tasks.filter((t) => t.id !== id),
        history: addToHistory(s.history, {
          id: nextId('h'),
          time: nowTime(),
          title: task.title,
          source: task.source,
          format: task.format,
          size: `${formatMb((task.totalMb * task.percent) / 100)} of ${formatMb(task.totalMb)}`,
          status: 'Cancelled',
        }),
      };
    }),
  start: (item) =>
    set((s) => ({
      tasks: [
        { ...item, id: nextId('d'), percent: 0, rate: SIMULATED_RATE, status: 'downloading' },
        ...s.tasks,
      ],
    })),
  enqueue: (item) => set((s) => ({ queue: [...s.queue, { ...item, id: nextId('q') }] })),
  startNow: (queueId) =>
    set((s) => {
      const item = s.queue.find((q) => q.id === queueId);
      if (!item) return s;
      return {
        queue: s.queue.filter((q) => q.id !== queueId),
        tasks: [
          ...s.tasks,
          {
            id: nextId('d'),
            title: item.title,
            source: 'studio.blender.org',
            kind: item.kind,
            format: item.format,
            totalMb: parseSize(item.size),
            percent: 0,
            rate: SIMULATED_RATE,
            status: 'downloading',
          },
        ],
      };
    }),
  removeQueued: (queueId) => set((s) => ({ queue: s.queue.filter((q) => q.id !== queueId) })),
  moveQueued: (from, to) =>
    set((s) => {
      if (to < 0 || to >= s.queue.length || from === to) return s;
      const queue = [...s.queue];
      const [moved] = queue.splice(from, 1);
      queue.splice(to, 0, moved!);
      return { queue };
    }),
  clearHistory: () => set({ history: [] }),
}));

/** Aggregates used by the sidebar card, Home and the Downloads header. */
export function summarize(tasks: DownloadTask[]) {
  const active = tasks.filter(isActive);
  const running = active.filter(isRunning);
  const speed = running.reduce((acc, t) => acc + (t.totalMb * t.rate) / 100, 0);
  return {
    active,
    running,
    speedLabel: speed > 0 ? `${speed.toFixed(1)} MB/s` : 'Paused',
    stateLabel: running.length
      ? `${running.length} downloading`
      : active.length
        ? 'All paused'
        : 'Idle',
    overallPercent: active.length
      ? Math.round(active.reduce((acc, t) => acc + t.percent, 0) / active.length)
      : 0,
  };
}

import { memo, useMemo, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { EmptyState, Thumbnail } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import type { DownloadTask } from '../../services/types';
import {
  formatBytes,
  isActiveRow,
  isOpen,
  isQueued,
  ordered,
  percentOf,
  summarize,
  useDownloads,
} from '../../stores/downloads';
import { effectiveConcurrency, useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { useNow } from './useNow';
import { barTone, barValue, doneLabel, progressAriaLabel, statusLabel, statusTone } from './format';

export function DownloadsScreen() {
  const tasks = useDownloads((s) => s.tasks);
  const pauseAll = useDownloads((s) => s.pauseAll);
  const resumeAll = useDownloads((s) => s.resumeAll);
  const concurrency = useSettings(effectiveConcurrency);
  const summary = useMemo(() => summarize(tasks), [tasks]);
  // Row ids only change when tasks are added, removed or reordered, so a
  // progress event re-renders a single row, not the list.
  const activeKey = ordered(tasks)
    .filter(isActiveRow)
    .map((t) => t.id)
    .join('|');
  const activeIds = useMemo(() => (activeKey ? activeKey.split('|') : []), [activeKey]);

  return (
    <div className="flex flex-1 flex-col gap-6 overflow-auto px-10 py-7">
      <div className="flex items-end gap-3">
        <div className="flex flex-1 flex-col gap-1">
          <h1 className="m-0 text-title-lg font-bold tracking-[-0.02em]">Downloads</h1>
          <span className="text-[13px] text-muted">
            {summary.stateLabel}
            {summary.running.length > 0 && ` · ${summary.speedLabel} total`} · up to {concurrency}{' '}
            at once
          </span>
        </div>
        <Button size="sm" icon="pause" className="h-9 text-[13px]" onClick={pauseAll}>
          Pause all
        </Button>
        <Button size="sm" icon="play_arrow" className="h-9 text-[13px]" onClick={resumeAll}>
          Resume all
        </Button>
      </div>

      <section aria-label="Active downloads" className="flex flex-col gap-2">
        {activeIds.length === 0 && (
          <EmptyState>Nothing downloading. Paste a link on Home to start.</EmptyState>
        )}
        {activeIds.map((id) => (
          <DownloadRowById key={id} id={id} />
        ))}
      </section>

      <QueueSection />
    </div>
  );
}

function DownloadRowById({ id }: { id: string }) {
  const task = useDownloads((s) => s.tasks[id]);
  return task ? <DownloadRow task={task} /> : null;
}

const DownloadRow = memo(function DownloadRow({ task }: { task: DownloadTask }) {
  const { pause, resume, cancel, retry, reveal } = useDownloads.getState();
  const askConfirm = useUi((s) => s.askConfirm);
  // Re-render every second while a retry countdown is shown.
  useNow(task.retry ? 1000 : null);
  const done = task.state === 'completed';
  const failed = task.state === 'failed';
  const paused = task.state === 'paused';
  const willRestart = paused && !task.supportsResume && task.downloadedBytes > 0;

  const primary = done
    ? { icon: 'folder_open', label: 'Show in folder', run: () => reveal(task.id) }
    : failed
      ? { icon: 'refresh', label: 'Retry', run: () => retry(task.id) }
      : paused
        ? {
            icon: 'play_arrow',
            label: willRestart ? 'Restart from the beginning' : 'Resume',
            run: () => resume(task.id),
          }
        : { icon: 'pause', label: 'Pause', run: () => pause(task.id) };
  // Merging or converting cannot be suspended (it finishes or is cancelled).
  const processing = task.state === 'processing';

  return (
    <div className="flex items-center gap-4 rounded-lg border border-surface2 bg-surface px-4 py-3.5">
      <Thumbnail
        className="h-[54px] w-24 rounded-sm"
        label={task.kind === 'video' ? 'Video' : 'Audio'}
      />
      <div className="flex min-w-0 flex-1 flex-col gap-2">
        <div className="flex justify-between gap-3">
          <span className="truncate text-[14px] font-semibold">{task.title}</span>
          <span className="font-mono text-[13px] font-medium tabular">
            {Math.floor(percentOf(task))}%
          </span>
        </div>
        <ProgressBar value={barValue(task)} tone={barTone(task)} label={progressAriaLabel(task)} />
        <div className="flex gap-3.5 text-[12px] text-muted">
          <span>{task.sourceHost}</span>
          <span>{task.formatLabel}</span>
          <span className="font-mono tabular">{doneLabel(task)}</span>
          <span className="flex-1" />
          <span
            className={`font-semibold tabular ${statusTone(task)}`}
            title={failed ? (task.errorMessage ?? undefined) : undefined}
          >
            {statusLabel(task)}
          </span>
        </div>
      </div>
      <div className="flex gap-0.5">
        <IconButton
          icon={primary.icon}
          label={processing ? 'Cannot pause while preparing the file' : primary.label}
          tone="default"
          disabled={processing}
          onClick={primary.run}
        />
        <IconButton
          icon="close"
          label={failed ? 'Remove' : 'Cancel'}
          tone="danger-hover"
          disabled={done}
          onClick={() =>
            failed
              ? cancel(task.id)
              : askConfirm({
                  title: 'Cancel this download?',
                  body: `“${task.title}” will stop and the partial file (${formatBytes(task.downloadedBytes)}) will be deleted.`,
                  confirmLabel: 'Cancel download',
                  onConfirm: () => cancel(task.id),
                })
          }
        />
      </div>
    </div>
  );
});

function QueueSection() {
  const tasks = useDownloads((s) => s.tasks);
  const { startNow, cancel, move } = useDownloads.getState();
  const [dragFrom, setDragFrom] = useState<number | null>(null);
  const open = useMemo(() => ordered(tasks).filter(isOpen), [tasks]);
  const queue = useMemo(() => open.filter(isQueued), [open]);

  /** Moves queue item `from` to the place of queue item `to`. */
  const reorder = (from: number, to: number) => {
    const item = queue[from];
    const target = queue[to];
    if (!item || !target || from === to) return;
    move(
      item.id,
      open.findIndex((t) => t.id === target.id),
    );
  };

  return (
    <section aria-label="Queue" className="flex flex-col gap-2.5">
      <div className="flex items-center justify-between">
        <h2 className="m-0 text-heading font-bold">
          Queue <span className="font-medium text-muted">· {queue.length}</span>
        </h2>
        <span className="text-[12px] text-muted">
          Drag to reorder. Starts automatically when a slot frees up.
        </span>
      </div>
      {queue.length > 0 && (
        <ol className="m-0 list-none overflow-hidden rounded-lg border border-surface2 p-0">
          {queue.map((item, index) => (
            <li
              key={item.id}
              draggable
              onDragStart={() => setDragFrom(index)}
              onDragOver={(e) => e.preventDefault()}
              onDrop={() => {
                if (dragFrom !== null) reorder(dragFrom, index);
                setDragFrom(null);
              }}
              className={`flex h-[52px] items-center gap-3.5 border-b border-surface2 bg-row pl-2 pr-3 last:border-b-0 hover:bg-surface ${
                dragFrom === index ? 'opacity-60' : ''
              }`}
            >
              <button
                type="button"
                aria-label={`Reorder ${item.title}. Use Alt and the arrow keys to move.`}
                onKeyDown={(e) => {
                  if (!e.altKey) return;
                  if (e.key === 'ArrowUp') reorder(index, index - 1);
                  if (e.key === 'ArrowDown') reorder(index, index + 1);
                }}
                className="cursor-grab text-faint"
              >
                <Icon name="drag_indicator" />
              </button>
              <span className="w-[18px] font-mono text-[12px] font-medium text-muted">
                {index + 1}
              </span>
              <span className="flex-1 truncate text-[13.5px] font-semibold">{item.title}</span>
              <span className="w-[140px] truncate text-[12.5px] text-muted">
                {item.formatLabel}
              </span>
              <span className="w-[70px] text-right font-mono text-[12.5px] font-medium text-muted">
                {item.totalBytes ? formatBytes(item.totalBytes) : '—'}
              </span>
              <Button
                variant="link"
                size="sm"
                className="h-[30px] px-2.5"
                onClick={() => startNow(item.id)}
              >
                Start now
              </Button>
              <IconButton
                icon="delete"
                label={`Remove ${item.title}`}
                size={30}
                iconSize={18}
                onClick={() => cancel(item.id)}
              />
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

import { memo, useMemo, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { EmptyState, Thumbnail } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { notAvailableYet } from '../../services/prototype';
import type { DownloadTask } from '../../services/types';
import { summarize, useDownloads } from '../../stores/downloads';
import { effectiveConcurrency, useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { doneLabel, progressAriaLabel, statusLabel, statusTone } from './format';

export function DownloadsScreen() {
  const tasks = useDownloads((s) => s.tasks);
  const pauseAll = useDownloads((s) => s.pauseAll);
  const resumeAll = useDownloads((s) => s.resumeAll);
  const concurrency = useSettings(effectiveConcurrency);
  const summary = useMemo(() => summarize(tasks), [tasks]);
  const taskIds = useMemo(() => tasks.map((t) => t.id), [tasks]);

  return (
    <div className="flex flex-1 flex-col gap-6 overflow-auto px-10 py-7">
      <div className="flex items-end gap-3">
        <div className="flex flex-1 flex-col gap-1">
          <h1 className="m-0 text-title-lg font-bold tracking-[-0.02em]">Downloads</h1>
          <span className="text-[13px] text-muted">
            {summary.stateLabel} · {summary.speedLabel} total · up to {concurrency} at once
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
        {taskIds.length === 0 && (
          <EmptyState>Nothing downloading. Paste a link on Home to start.</EmptyState>
        )}
        {taskIds.map((id) => (
          <DownloadRowById key={id} id={id} />
        ))}
      </section>

      <QueueSection />
    </div>
  );
}

/** Each row subscribes to its own task so one progress tick re-renders one row. */
function DownloadRowById({ id }: { id: string }) {
  const task = useDownloads((s) => s.tasks.find((t) => t.id === id));
  return task ? <DownloadRow task={task} /> : null;
}

const DownloadRow = memo(function DownloadRow({ task }: { task: DownloadTask }) {
  const pause = useDownloads((s) => s.pause);
  const resume = useDownloads((s) => s.resume);
  const cancel = useDownloads((s) => s.cancel);
  const askConfirm = useUi((s) => s.askConfirm);
  const done = task.status === 'completed';
  const paused = task.status === 'paused' || task.status === 'waiting_wifi';

  const toggle = () => {
    if (done) notAvailableYet('Showing the file in its folder');
    else if (paused) resume(task.id);
    else pause(task.id);
  };

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
            {Math.floor(task.percent)}%
          </span>
        </div>
        <ProgressBar
          value={task.percent}
          tone={done ? 'complete' : paused ? 'paused' : 'active'}
          label={progressAriaLabel(task)}
        />
        <div className="flex gap-3.5 text-[12px] text-muted">
          <span>{task.source}</span>
          <span>{task.format}</span>
          <span className="font-mono tabular">{doneLabel(task)}</span>
          <span className="flex-1" />
          <span className={`font-semibold tabular ${statusTone(task)}`}>{statusLabel(task)}</span>
        </div>
      </div>
      <div className="flex gap-0.5">
        <IconButton
          icon={done ? 'folder_open' : paused ? 'play_arrow' : 'pause'}
          label={done ? 'Show in folder' : paused ? 'Resume' : 'Pause'}
          tone="default"
          onClick={toggle}
        />
        <IconButton
          icon="close"
          label="Cancel"
          tone="danger-hover"
          disabled={done}
          onClick={() =>
            askConfirm({
              title: 'Cancel this download?',
              body: `“${task.title}” will stop and the partial file (${doneLabel(task).split(' of ')[0]}) will be deleted.`,
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
  const queue = useDownloads((s) => s.queue);
  const startNow = useDownloads((s) => s.startNow);
  const remove = useDownloads((s) => s.removeQueued);
  const move = useDownloads((s) => s.moveQueued);
  const [dragFrom, setDragFrom] = useState<number | null>(null);

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
                if (dragFrom !== null) move(dragFrom, index);
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
                  if (e.key === 'ArrowUp') move(index, index - 1);
                  if (e.key === 'ArrowDown') move(index, index + 1);
                }}
                className="cursor-grab text-faint"
              >
                <Icon name="drag_indicator" />
              </button>
              <span className="w-[18px] font-mono text-[12px] font-medium text-muted">
                {index + 1}
              </span>
              <span className="flex-1 text-[13.5px] font-semibold">{item.title}</span>
              <span className="w-[140px] text-[12.5px] text-muted">{item.format}</span>
              <span className="w-[70px] text-right font-mono text-[12.5px] font-medium text-muted">
                {item.size}
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
                onClick={() => remove(item.id)}
              />
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

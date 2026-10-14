import { useMemo, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { Segmented } from '../../components/Controls';
import { EmptyState } from '../../components/Feedback';
import { Menu } from '../../components/Menu';
import type { HistoryEntry, HistoryStatus } from '../../services/types';
import { formatBytes, useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { groupByDay } from './grouping';

type Filter = 'all' | 'completed' | 'failed';

const STATUS: Record<HistoryStatus, { label: string; color: string }> = {
  completed: { label: 'Completed', color: 'text-accent-strong' },
  failed: { label: 'Failed', color: 'text-danger' },
  canceled: { label: 'Cancelled', color: 'text-muted' },
};

const ROW_COLUMNS = 'grid-cols-[52px_minmax(0,1fr)_150px_80px_110px_72px]';

function timeLabel(ts: number) {
  const d = new Date(ts);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function sizeLabel(entry: HistoryEntry) {
  if (entry.status === 'completed') return formatBytes(entry.totalBytes ?? entry.doneBytes);
  if (!entry.doneBytes) return '—';
  return entry.totalBytes
    ? `${formatBytes(entry.doneBytes)} of ${formatBytes(entry.totalBytes)}`
    : formatBytes(entry.doneBytes);
}

export default function HistoryScreen() {
  const history = useDownloads((s) => s.history);
  const clear = useDownloads((s) => s.clearHistory);
  const askConfirm = useUi((s) => s.askConfirm);
  const [filter, setFilter] = useState<Filter>('all');

  const groups = useMemo(
    () => groupByDay(history.filter((e) => filter === 'all' || e.status === filter)),
    [history, filter],
  );

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-10 py-7">
      <div className="flex items-center gap-3">
        <h1 className="m-0 flex-1 text-title-lg font-bold tracking-[-0.02em]">History</h1>
        <Segmented<Filter>
          label="Filter history"
          value={filter}
          onChange={setFilter}
          className="!self-auto border-line bg-surface"
          options={[
            { value: 'all', label: 'All' },
            { value: 'completed', label: 'Completed' },
            { value: 'failed', label: 'Failed' },
          ]}
        />
        <Button
          size="sm"
          className="h-9 border-line-strong bg-transparent text-[13px] hover:bg-surface"
          disabled={history.length === 0}
          onClick={() =>
            askConfirm({
              title: 'Clear download history?',
              body: 'This removes the list of past downloads. Files already saved in your library are not deleted.',
              confirmLabel: 'Clear history',
              onConfirm: clear,
            })
          }
        >
          Clear history
        </Button>
      </div>

      {groups.map((group) => (
        <section key={group.day} aria-label={group.day} className="flex flex-col gap-1.5">
          <h2 className="m-0 text-[12px] font-bold text-muted">{group.day}</h2>
          <div className="rounded-lg border border-surface2">
            {group.entries.map((entry) => (
              <HistoryRow key={entry.id} entry={entry} />
            ))}
          </div>
        </section>
      ))}

      {groups.length === 0 && (
        <EmptyState>
          {history.length === 0
            ? 'History is empty. Finished, failed and cancelled downloads appear here.'
            : `No ${filter} downloads.`}
        </EmptyState>
      )}
    </div>
  );
}

function HistoryRow({ entry }: { entry: HistoryEntry }) {
  const task = useDownloads((s) => s.tasks[entry.taskId]);
  const { retry, revealHistory } = useDownloads.getState();
  const analyze = useUi((s) => s.analyze);
  const pushToast = useUi((s) => s.pushToast);
  const completed = entry.status === 'completed';
  const status = STATUS[entry.status];

  // A failed task still exists and keeps its format; a cancelled one is
  // analyzed again from its source link.
  const retryEntry = () => {
    if (task?.state === 'failed') retry(task.id);
    else analyze(entry.url);
  };

  return (
    <div
      className={`grid ${ROW_COLUMNS} h-[50px] items-center gap-4 border-b border-surface2 pl-4 pr-3 text-[13px] last:border-b-0 hover:bg-surface`}
    >
      <span className="font-mono text-[12px] font-medium text-muted">
        {timeLabel(entry.finishedAt)}
      </span>
      <div className="flex min-w-0 flex-col">
        <span className="truncate font-semibold">{entry.title}</span>
        <span className="truncate text-[11.5px] text-muted">
          {entry.reason ? `${entry.sourceHost} · ${entry.reason}` : entry.sourceHost}
        </span>
      </div>
      <span className="truncate text-muted">{entry.formatLabel}</span>
      <span className="font-mono text-[12px] font-medium text-muted">{sizeLabel(entry)}</span>
      <span className={`flex items-center gap-[7px] text-[12.5px] font-semibold ${status.color}`}>
        <span className="h-[7px] w-[7px] rounded-full bg-current" aria-hidden="true" />
        {status.label}
      </span>
      <div className="flex justify-end gap-0.5">
        <IconButton
          icon={completed ? 'folder_open' : 'refresh'}
          label={completed ? 'Show in folder' : 'Retry'}
          size={30}
          iconSize={18}
          onClick={completed ? () => revealHistory(entry.id) : retryEntry}
        />
        <Menu
          label={`Actions for ${entry.title}`}
          trigger={({ open, toggle, id }) => (
            <IconButton
              icon="more_horiz"
              label="More"
              size={30}
              iconSize={18}
              aria-haspopup="menu"
              aria-expanded={open}
              aria-controls={id}
              onClick={toggle}
            />
          )}
          items={[
            {
              label: 'Copy source link',
              icon: 'content_copy',
              shortcut: 'Ctrl C',
              onSelect: () => {
                navigator.clipboard
                  ?.writeText(entry.url)
                  .then(() => pushToast({ tone: 'success', message: 'Source link copied' }))
                  .catch(() => pushToast({ tone: 'error', message: 'Could not copy the link.' }));
              },
            },
          ]}
        />
      </div>
    </div>
  );
}

import { useMemo, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { Segmented } from '../../components/Controls';
import { EmptyState } from '../../components/Feedback';
import { Menu } from '../../components/Menu';
import { notAvailableYet } from '../../services/prototype';
import type { HistoryEntry, HistoryStatus } from '../../services/types';
import { useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';

type Filter = 'All' | 'Completed' | 'Failed';

const STATUS_COLOR: Record<HistoryStatus, string> = {
  Completed: 'text-accent-strong',
  Failed: 'text-danger',
  Cancelled: 'text-muted',
};

const ROW_COLUMNS = 'grid-cols-[52px_minmax(0,1fr)_150px_80px_110px_72px]';

export default function HistoryScreen() {
  const history = useDownloads((s) => s.history);
  const clear = useDownloads((s) => s.clearHistory);
  const askConfirm = useUi((s) => s.askConfirm);
  const [filter, setFilter] = useState<Filter>('All');

  const groups = useMemo(
    () =>
      history
        .map((g) => ({
          ...g,
          entries: g.entries.filter((e) => filter === 'All' || e.status === filter),
        }))
        .filter((g) => g.entries.length > 0),
    [history, filter],
  );

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-10 py-7">
      <div className="flex items-center gap-3">
        <h1 className="m-0 flex-1 text-title-lg font-bold tracking-[-0.02em]">History</h1>
        <Segmented
          label="Filter history"
          value={filter}
          onChange={setFilter}
          className="!self-auto border-line bg-surface"
          options={(['All', 'Completed', 'Failed'] as Filter[]).map((f) => ({
            value: f,
            label: f,
          }))}
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
            : `No ${filter.toLowerCase()} downloads.`}
        </EmptyState>
      )}
    </div>
  );
}

function HistoryRow({ entry }: { entry: HistoryEntry }) {
  const start = useDownloads((s) => s.start);
  const pushToast = useUi((s) => s.pushToast);
  const go = useUi((s) => s.go);
  const completed = entry.status === 'Completed';

  const retry = () => {
    start({
      title: entry.title,
      source: entry.source,
      kind: 'video',
      format: entry.format,
      totalMb: 300,
    });
    pushToast({
      tone: 'success',
      message: `Retrying · ${entry.title}`,
      action: { label: 'View', run: () => go('downloads') },
    });
  };

  return (
    <div
      className={`grid ${ROW_COLUMNS} h-[50px] items-center gap-4 border-b border-surface2 pl-4 pr-3 text-[13px] last:border-b-0 hover:bg-surface`}
    >
      <span className="font-mono text-[12px] font-medium text-muted">{entry.time}</span>
      <div className="flex min-w-0 flex-col">
        <span className="truncate font-semibold">{entry.title}</span>
        <span className="truncate text-[11.5px] text-muted">
          {entry.reason ? `${entry.source} · ${entry.reason}` : entry.source}
        </span>
      </div>
      <span className="text-muted">{entry.format}</span>
      <span className="font-mono text-[12px] font-medium text-muted">{entry.size}</span>
      <span
        className={`flex items-center gap-[7px] text-[12.5px] font-semibold ${STATUS_COLOR[entry.status]}`}
      >
        <span className="h-[7px] w-[7px] rounded-full bg-current" aria-hidden="true" />
        {entry.status}
      </span>
      <div className="flex justify-end gap-0.5">
        <IconButton
          icon={completed ? 'folder_open' : 'refresh'}
          label={completed ? 'Show in folder' : 'Retry'}
          size={30}
          iconSize={18}
          onClick={completed ? () => notAvailableYet('Showing the file in its folder') : retry}
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
                void navigator.clipboard?.writeText(`https://${entry.source}`);
                pushToast({ tone: 'success', message: 'Source link copied' });
              },
            },
          ]}
        />
      </div>
    </div>
  );
}

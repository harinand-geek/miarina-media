import { memo, useMemo, useState, type KeyboardEvent, type ReactNode } from 'react';
import { Icon } from '../../components/Icon';
import { LocalThumb } from '../../components/LocalThumb';
import { ProgressBar } from '../../components/ProgressBar';
import { useT, type MessageKey } from '../../i18n';
import { backend } from '../../services/backend';
import type { DownloadTask, HistoryEntry } from '../../services/types';
import {
  formatBytes,
  isOpen,
  isRunning,
  ordered,
  percentOf,
  summarize,
  useDownloads,
} from '../../stores/downloads';
import { effectiveConcurrency, useSettings } from '../../stores/settings';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { playFrom } from '../../app/navigation';
import { barTone, barValue } from './format';
import {
  failureReason,
  mediaOfDownload,
  progressAriaLabel,
  statusOf,
  useDownloadLists,
  waitsForSlot,
  type Status,
} from './status';
import { useNow } from './useNow';

type Tab = 'active' | 'done' | 'failed';

const TAB_LABEL: Record<Tab, MessageKey> = {
  active: 'tabActive',
  done: 'tabDone',
  failed: 'tabFailed',
};

interface Action {
  icon: string;
  label: string;
  run: () => void;
  disabled?: boolean;
}

function report(e: unknown) {
  useUi
    .getState()
    .pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });
}

const openDownloadFolder = () => void backend.openDownloadFolder().catch(report);

/** Moves `id` to the place of `target` in the backend's open-task order. */
function moveTo(id: string, target: string) {
  const { tasks, move } = useDownloads.getState();
  const index = ordered(tasks)
    .filter(isOpen)
    .findIndex((x) => x.id === target);
  if (index >= 0 && id !== target) move(id, index);
}

/** Windows v2 screen 3: active, done and failed downloads. */
export function DownloadsScreen() {
  const t = useT();
  const [tab, setTab] = useState<Tab>('active');
  const tasks = useDownloads((s) => s.tasks);
  const { pauseAll, resumeAll } = useDownloads.getState();
  const concurrency = useSettings(effectiveConcurrency);
  const lists = useDownloadLists();
  const summary = useMemo(() => summarize(tasks), [tasks]);
  const anyRunning = lists.active.some(isRunning);
  const anyPaused = lists.active.some((x) => x.state === 'paused');
  // Row ids only change when tasks are added, removed or reordered, so a
  // progress event re-renders a single row, not the list.
  const key = (tab === 'failed' ? lists.failedTasks : lists.active).map((x) => x.id).join('|');
  const ids = useMemo(() => (key ? key.split('|') : []), [key]);
  const queuedIds = useMemo(
    () => lists.active.filter(waitsForSlot).map((x) => x.id),
    [lists.active],
  );

  const subtitle = anyRunning
    ? t('dlSubRunning', { n: summary.running.length, speed: summary.speedLabel })
    : anyPaused
      ? t('dlSubPaused')
      : t('dlSubIdle', { n: concurrency });
  const empty =
    tab === 'done'
      ? lists.done.length === 0
      : tab === 'failed'
        ? lists.counts.failed === 0
        : ids.length === 0;

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-12 py-8">
      <div className="flex items-end gap-3">
        <div className="flex flex-1 flex-col gap-1">
          <h1 className="m-0 text-[24px] font-extrabold tracking-[-0.02em]">{t('downloads')}</h1>
          <span className="text-[13px] text-muted">{subtitle}</span>
        </div>
        <button
          type="button"
          onClick={anyRunning ? pauseAll : resumeAll}
          disabled={!anyRunning && !anyPaused}
          className="flex h-9 items-center gap-1.5 rounded-sm border border-line-strong bg-surface2 px-3.5 text-[13px] font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50"
        >
          <Icon name={anyRunning || !anyPaused ? 'pause' : 'play_arrow'} size={18} />
          {anyRunning || !anyPaused ? t('pauseAll') : t('resumeAll')}
          <span className="font-mono text-[11px] text-muted">Ctrl P</span>
        </button>
      </div>

      <div
        role="radiogroup"
        aria-label={t('downloadLists')}
        className="flex self-start rounded-[7px] border border-line bg-bg p-[3px]"
      >
        {(['active', 'done', 'failed'] as const).map((id) => (
          <button
            key={id}
            type="button"
            role="radio"
            aria-checked={tab === id}
            onClick={() => setTab(id)}
            className={`h-[30px] rounded-[5px] px-3.5 text-[12.5px] font-semibold ${
              tab === id ? 'bg-line-strong text-fg' : 'text-muted hover:text-fg'
            }`}
          >
            {t(TAB_LABEL[id], { n: lists.counts[id] })}
          </button>
        ))}
      </div>

      <ul className="m-0 flex list-none flex-col gap-2 p-0">
        {tab !== 'done' && ids.map((id) => <TaskRowById key={id} id={id} queuedIds={queuedIds} />)}
        {tab === 'failed' &&
          lists.failedHistory.map((h) => <FailedHistoryRow key={h.id} entry={h} />)}
        {tab === 'done' && lists.done.map((h) => <DoneRow key={h.id} entry={h} />)}
      </ul>

      {empty && (
        <div className="rounded-[10px] border border-dashed border-line-strong p-12 text-center text-[13.5px] text-muted">
          {t('dlNothing')}
        </div>
      )}
    </div>
  );
}

function TaskRowById({ id, queuedIds }: { id: string; queuedIds: string[] }) {
  const task = useDownloads((s) => s.tasks[id]);
  return task ? <TaskRow task={task} queuedIds={queuedIds} /> : null;
}

const TaskRow = memo(function TaskRow({
  task,
  queuedIds,
}: {
  task: DownloadTask;
  queuedIds: string[];
}) {
  const t = useT();
  const { pause, resume, cancel, retry, restart, startNow } = useDownloads.getState();
  // Re-render every second while a retry countdown is shown.
  const now = useNow(task.retry ? 1000 : null);
  const status = statusOf(task, t, now, true);
  const busy = task.state === 'processing' || task.state === 'analyzing';
  const queued = waitsForSlot(task);

  const main: Action =
    task.state === 'failed'
      ? { icon: 'refresh', label: t('actRetry', { title: task.title }), run: () => retry(task.id) }
      : task.state === 'paused'
        ? {
            icon: 'play_arrow',
            label: t('actResume', { title: task.title }),
            run: () => resume(task.id),
          }
        : queued
          ? {
              icon: 'play_arrow',
              label: t('actStart', { title: task.title }),
              run: () => startNow(task.id),
            }
          : {
              icon: 'pause',
              label: busy ? t('cannotPause') : t('actPause', { title: task.title }),
              run: () => pause(task.id),
              disabled: busy,
            };
  const close: Action =
    task.state === 'failed'
      ? {
          icon: 'close',
          label: t('removeNamed', { title: task.title }),
          run: () => cancel(task.id),
        }
      : {
          icon: 'close',
          label: t('cancelNamed', { title: task.title }),
          run: () =>
            useUi.getState().askConfirm({
              title: t('cancelTitle'),
              body: t('cancelBody', { title: task.title }),
              confirmLabel: t('cancelConfirm'),
              onConfirm: () => cancel(task.id),
            }),
        };

  /** Queue order: Alt + arrows, or drag a queued row onto another. */
  const reorder = (delta: number) => {
    const at = queuedIds.indexOf(task.id);
    const target = queuedIds[at + delta];
    if (at >= 0 && target) moveTo(task.id, target);
  };

  return (
    <Row
      kind={task.kind}
      thumbnail={task.thumbnail}
      title={task.title}
      format={task.formatLabel}
      status={status}
      percent={task.state === 'queued' ? null : `${Math.floor(percentOf(task))}%`}
      progress={
        <ProgressBar
          value={task.state === 'queued' ? 0 : barValue(task)}
          tone={barTone(task)}
          label={progressAriaLabel(task)}
        />
      }
      actions={[
        main,
        // Partial data kept: a resume is tried first; starting over is a
        // separate, explicit choice (PAR-04).
        ...(task.state === 'failed' && task.downloadedBytes > 0
          ? [
              {
                icon: 'restart_alt',
                label: t('actRestart', { title: task.title }),
                run: () => restart(task.id),
              },
            ]
          : []),
        { icon: 'folder_open', label: t('openFolder'), run: openDownloadFolder },
        close,
      ]}
      drag={
        queued
          ? {
              label: t('reorderNamed', { title: task.title }),
              id: task.id,
              onKey: (e) => {
                if (!e.altKey) return;
                if (e.key === 'ArrowUp') reorder(-1);
                if (e.key === 'ArrowDown') reorder(1);
              },
              onDrop: (from) => moveTo(from, task.id),
            }
          : undefined
      }
    />
  );
});

function DoneRow({ entry }: { entry: HistoryEntry }) {
  const t = useT();
  const { revealHistory } = useDownloads.getState();
  const library = useLibrary((s) => s.items);
  const recent = useLibrary((s) => s.recent);
  const media = [...recent, ...library].find(
    (m) => m.taskId === entry.taskId || (!!entry.finalPath && m.path === entry.finalPath),
  );
  const play = async () => {
    const found = media ?? (await mediaOfDownload(entry));
    if (found) playFrom(found);
    else useUi.getState().pushToast({ tone: 'error', message: t('fileGone') });
  };
  return (
    <Row
      kind={media?.kind ?? 'video'}
      thumbnail={media?.thumbnail ?? null}
      title={entry.title}
      format={entry.formatLabel}
      status={{
        icon: 'check_circle',
        text: t('stDone'),
        tone: 'text-accent-strong',
        detail: formatBytes(entry.doneBytes),
      }}
      percent="100%"
      progress={
        <ProgressBar value={100} tone="complete" label={`${entry.title}, ${t('stDone')}`} />
      }
      actions={[
        {
          icon: 'play_arrow',
          label: t('playTitle', { title: entry.title }),
          run: () => void play(),
        },
        { icon: 'folder_open', label: t('showInFolder'), run: () => revealHistory(entry.id) },
      ]}
    />
  );
}

function FailedHistoryRow({ entry }: { entry: HistoryEntry }) {
  const t = useT();
  return (
    <Row
      kind="video"
      thumbnail={null}
      title={entry.title}
      format={entry.formatLabel}
      status={{
        icon: 'error',
        text: failureReason(entry.reason, t) ?? t('stFailed'),
        tone: 'text-danger',
        detail: '',
      }}
      percent={null}
      actions={[]}
    />
  );
}

function Row({
  kind,
  thumbnail,
  title,
  format,
  status,
  percent,
  progress,
  actions,
  drag,
}: {
  kind: 'video' | 'audio';
  thumbnail: string | null;
  title: string;
  format: string;
  status: Status;
  percent: string | null;
  progress?: ReactNode;
  actions: Action[];
  drag?: {
    label: string;
    id: string;
    onKey: (e: KeyboardEvent) => void;
    onDrop: (from: string) => void;
  };
}) {
  const thumb = (
    <LocalThumb
      path={thumbnail}
      kind={kind}
      className="aspect-video w-[72px] shrink-0 rounded-md border border-line"
    />
  );
  return (
    <li
      className="flex items-center gap-4 rounded-lg border border-line bg-surface px-4 py-3.5"
      draggable={!!drag}
      onDragStart={drag ? (e) => e.dataTransfer.setData('text/x-miarina-task', drag.id) : undefined}
      onDragOver={drag ? (e) => e.preventDefault() : undefined}
      onDrop={
        drag
          ? (e) => {
              e.preventDefault();
              const from = e.dataTransfer.getData('text/x-miarina-task');
              if (from) drag.onDrop(from);
            }
          : undefined
      }
    >
      {drag ? (
        <button
          type="button"
          aria-label={drag.label}
          onKeyDown={drag.onKey}
          className="shrink-0 cursor-grab rounded-md"
        >
          {thumb}
        </button>
      ) : (
        thumb
      )}
      <div className="flex min-w-0 flex-1 flex-col gap-2">
        <div className="flex min-w-0 items-center gap-2.5">
          <span className="truncate text-[13.5px] font-bold">{title}</span>
          <span className="shrink-0 whitespace-nowrap font-mono text-[11.5px] text-muted">
            {format}
          </span>
        </div>
        {progress}
        <div className="flex min-w-0 items-center gap-1.5 text-[12px]">
          <Icon name={status.icon} size={15} className={status.tone} />
          <span className={`truncate font-semibold ${status.tone}`}>{status.text}</span>
          {status.detail && (
            <span className="shrink-0 font-mono text-muted tabular">{status.detail}</span>
          )}
        </div>
      </div>
      <span className="w-12 shrink-0 text-right font-mono text-[12.5px] text-muted tabular">
        {percent}
      </span>
      <div className="flex shrink-0 gap-0.5">
        {actions.map((a) => (
          <button
            key={a.icon}
            type="button"
            aria-label={a.label}
            title={a.label}
            disabled={a.disabled}
            onClick={a.run}
            className="grid h-[34px] w-[34px] place-items-center rounded-sm text-muted enabled:hover:bg-line enabled:hover:text-fg disabled:opacity-40"
          >
            <Icon name={a.icon} />
          </button>
        ))}
      </div>
    </li>
  );
}

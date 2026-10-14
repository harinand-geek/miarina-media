import { useMemo, useState } from 'react';
import { Segmented } from '../../components/Controls';
import { Thumbnail } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import {
  formatBytes,
  isActiveRow,
  isOpen,
  isQueued,
  isRunning,
  ordered,
  percentOf,
  useDownloads,
} from '../../stores/downloads';
import { barTone, barValue, progressAriaLabel, statusLabel, statusTone } from './format';

type Tab = 'active' | 'queue' | 'done';

interface CardProps {
  title: string;
  kind: 'video' | 'audio';
  detail: string;
  status: string;
  statusClass: string;
  icon: string;
  actionLabel: string;
  onAction: () => void;
  actionDisabled?: boolean;
  progress?: {
    value: number | null;
    percent: number;
    label: string;
    tone: ReturnType<typeof barTone>;
  };
}

function Card({
  title,
  kind,
  detail,
  status,
  statusClass,
  icon,
  actionLabel,
  onAction,
  actionDisabled,
  progress,
}: CardProps) {
  return (
    <div className="flex flex-col gap-3 rounded-[16px] bg-surface p-3.5">
      <div className="flex items-center gap-3">
        <Thumbnail
          className="h-16 w-16 rounded-[10px]"
          label={kind === 'video' ? 'Video' : 'Audio'}
        />
        <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
          <span className="truncate text-[14.5px] font-bold">{title}</span>
          <span className="truncate text-[12.5px] text-muted">{detail}</span>
          <span className={`text-[12.5px] font-semibold ${statusClass}`}>{status}</span>
        </div>
        <button
          type="button"
          aria-label={actionLabel}
          disabled={actionDisabled}
          onClick={onAction}
          className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-surface2 text-fg disabled:opacity-50"
        >
          <Icon name={icon} size={24} fill />
        </button>
      </div>
      {progress && (
        <div className="flex items-center gap-2.5">
          <ProgressBar
            value={progress.value}
            height={6}
            tone={progress.tone}
            label={progress.label}
            className="flex-1"
          />
          <span className="w-[76px] text-right font-mono text-[12px] font-medium text-muted tabular">
            {Math.floor(progress.percent)}%
          </span>
        </div>
      )}
    </div>
  );
}

export function MobileDownloads() {
  const [tab, setTab] = useState<Tab>('active');
  const tasks = useDownloads((s) => s.tasks);
  const history = useDownloads((s) => s.history);
  const library = useLibrary((s) => s.items);
  const play = useUi((s) => s.play);
  const pushToast = useUi((s) => s.pushToast);

  /** Plays the library entry created by a finished download. */
  const playDone = (taskId: string, finalPath: string | null) => {
    const media = library.find((m) => m.taskId === taskId || (finalPath && m.path === finalPath));
    if (media) play(media);
    else pushToast({ tone: 'error', message: 'This file is no longer in the library.' });
  };
  const { pause, resume, retry, startNow, pauseAll, resumeAll } = useDownloads.getState();

  const all = useMemo(() => ordered(tasks), [tasks]);
  const active = useMemo(() => all.filter((t) => isOpen(t) && isActiveRow(t)), [all]);
  const queue = useMemo(() => all.filter(isQueued), [all]);
  const done = useMemo(() => history.filter((h) => h.status === 'completed'), [history]);
  const anyRunning = active.some(isRunning);

  const empty =
    (tab === 'active' && !active.length) ||
    (tab === 'queue' && !queue.length) ||
    (tab === 'done' && !done.length);

  return (
    <div className="flex flex-1 flex-col gap-3.5 overflow-auto px-4 pb-5 pt-2">
      <header className="flex h-12 items-center">
        <h1 className="m-0 flex-1 text-[22px] font-bold tracking-[-0.02em]">Downloads</h1>
        <button
          type="button"
          onClick={anyRunning ? pauseAll : resumeAll}
          className="h-10 rounded-[20px] border border-line-strong px-3.5 text-[13px] font-semibold"
        >
          {anyRunning ? 'Pause all' : 'Resume all'}
        </button>
      </header>
      <Segmented<Tab>
        label="Download lists"
        variant="mobile"
        value={tab}
        onChange={setTab}
        options={[
          { value: 'active', label: `Active · ${active.length}` },
          { value: 'queue', label: `Queue · ${queue.length}` },
          { value: 'done', label: 'Done' },
        ]}
      />

      {tab === 'active' &&
        active.map((t) => {
          const failed = t.state === 'failed';
          const paused = t.state === 'paused';
          return (
            <Card
              key={t.id}
              title={t.title}
              kind={t.kind}
              detail={t.formatLabel}
              status={statusLabel(t)}
              statusClass={statusTone(t)}
              icon={failed ? 'refresh' : paused ? 'play_arrow' : 'pause'}
              actionLabel={
                failed ? `Retry ${t.title}` : paused ? `Resume ${t.title}` : `Pause ${t.title}`
              }
              onAction={() => (failed ? retry(t.id) : paused ? resume(t.id) : pause(t.id))}
              actionDisabled={t.state === 'processing'}
              progress={{
                value: barValue(t),
                percent: percentOf(t),
                label: progressAriaLabel(t),
                tone: barTone(t),
              }}
            />
          );
        })}

      {tab === 'queue' &&
        queue.map((q) => (
          <Card
            key={q.id}
            title={q.title}
            kind={q.kind}
            detail={
              q.totalBytes ? `${q.formatLabel} · ${formatBytes(q.totalBytes)}` : q.formatLabel
            }
            status="Waiting for a free slot"
            statusClass="text-muted"
            icon="play_arrow"
            actionLabel={`Start ${q.title} now`}
            onAction={() => startNow(q.id)}
          />
        ))}

      {tab === 'done' &&
        done.map((h) => (
          <Card
            key={h.id}
            title={h.title}
            kind="video"
            detail={`${h.formatLabel} · ${formatBytes(h.doneBytes)}`}
            status="Saved to Internal storage"
            statusClass="text-accent-strong"
            icon="play_arrow"
            actionLabel={`Play ${h.title}`}
            onAction={() => playDone(h.taskId, h.finalPath)}
          />
        ))}

      {empty && (
        <div className="flex flex-col items-center gap-1.5 px-6 py-12 text-center">
          <Icon name="download_done" size={36} className="text-faint-icon" />
          <span className="font-bold">Nothing here</span>
          <span className="text-[13px] text-muted">Items you add will show up in this list.</span>
        </div>
      )}
    </div>
  );
}

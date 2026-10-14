import { useMemo, useState } from 'react';
import { Segmented } from '../../components/Controls';
import { Thumbnail } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { LIBRARY } from '../../dev/fixtures';
import { formatMb, isActive, isRunning, useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { progressAriaLabel, statusLabel, statusTone } from './format';

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
  progress?: { value: number; label: string; paused: boolean };
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
          <span className="text-[12.5px] text-muted">{detail}</span>
          <span className={`text-[12.5px] font-semibold ${statusClass}`}>{status}</span>
        </div>
        <button
          type="button"
          aria-label={actionLabel}
          onClick={onAction}
          className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-surface2 text-fg"
        >
          <Icon name={icon} size={24} fill />
        </button>
      </div>
      {progress && (
        <div className="flex items-center gap-2.5">
          <ProgressBar
            value={progress.value}
            height={6}
            tone={progress.paused ? 'paused' : 'active'}
            label={progress.label}
            className="flex-1"
          />
          <span className="w-[76px] text-right font-mono text-[12px] font-medium text-muted tabular">
            {Math.floor(progress.value)}%
          </span>
        </div>
      )}
    </div>
  );
}

export function MobileDownloads() {
  const [tab, setTab] = useState<Tab>('active');
  const tasks = useDownloads((s) => s.tasks);
  const queue = useDownloads((s) => s.queue);
  const { pause, resume, pauseAll, resumeAll, startNow } = useDownloads.getState();
  const play = useUi((s) => s.play);

  const active = useMemo(() => tasks.filter(isActive), [tasks]);
  const done = useMemo(() => tasks.filter((t) => t.status === 'completed'), [tasks]);
  const anyRunning = active.some(isRunning);

  // "Done" always lists saved library items, so only Active and Queue can be empty.
  const empty =
    (tab === 'active' && active.length === 0) || (tab === 'queue' && queue.length === 0);

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
          const paused = !isRunning(t);
          return (
            <Card
              key={t.id}
              title={t.title}
              kind={t.kind}
              detail={t.format}
              status={statusLabel(t)}
              statusClass={statusTone(t)}
              icon={paused ? 'play_arrow' : 'pause'}
              actionLabel={paused ? `Resume ${t.title}` : `Pause ${t.title}`}
              onAction={() => (paused ? resume(t.id) : pause(t.id))}
              progress={{ value: t.percent, label: progressAriaLabel(t), paused }}
            />
          );
        })}

      {tab === 'queue' &&
        queue.map((q) => (
          <Card
            key={q.id}
            title={q.title}
            kind={q.kind}
            detail={`${q.format} · ${q.size}`}
            status="Waiting for a free slot"
            statusClass="text-muted"
            icon="play_arrow"
            actionLabel={`Start ${q.title} now`}
            onAction={() => startNow(q.id)}
          />
        ))}

      {tab === 'done' && (
        <>
          {done.map((t) => (
            <Card
              key={t.id}
              title={t.title}
              kind={t.kind}
              detail={`${t.format} · ${formatMb(t.totalMb)}`}
              status="Saved to Internal storage"
              statusClass="text-accent-strong"
              icon="play_arrow"
              actionLabel={`Play ${t.title}`}
              onAction={() => play(LIBRARY[0]!)}
            />
          ))}
          {LIBRARY.slice(0, 2).map((item) => (
            <Card
              key={item.id}
              title={item.title}
              kind={item.kind}
              detail={`${item.quality} · ${item.size}`}
              status="Saved to Internal storage"
              statusClass="text-accent-strong"
              icon="play_arrow"
              actionLabel={`Play ${item.title}`}
              onAction={() => play(item)}
            />
          ))}
        </>
      )}

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

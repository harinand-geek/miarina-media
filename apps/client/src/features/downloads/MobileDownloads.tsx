import { useState } from 'react';
import { Icon } from '../../components/Icon';
import { LocalThumb } from '../../components/LocalThumb';
import { ProgressBar } from '../../components/ProgressBar';
import { useT } from '../../i18n';
import type { DownloadTask, HistoryEntry } from '../../services/types';
import { formatBytes, isRunning, useDownloads } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
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
import { LinkCard } from '../home/LinkCard';

type Tab = 'active' | 'done' | 'failed';

function Row({
  title,
  format,
  kind,
  thumbnail,
  status,
  progress,
  actions,
}: {
  title: string;
  format: string;
  kind: 'video' | 'audio';
  thumbnail: string | null;
  status: Status;
  progress?: { value: number | null; label: string; tone: ReturnType<typeof barTone> };
  actions: { icon: string; label: string; run: () => void; disabled?: boolean }[];
}) {
  return (
    <li className="flex gap-3 border-b border-divider py-3">
      <LocalThumb path={thumbnail} kind={kind} className="h-11 w-[72px] rounded-md" />
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <div className="flex items-baseline gap-2">
          <span className="min-w-0 flex-1 truncate text-[14px] font-bold">{title}</span>
          <span className="shrink-0 font-mono text-[11px] text-muted">{format}</span>
        </div>
        {progress && (
          <ProgressBar
            value={progress.value}
            height={6}
            tone={progress.tone}
            label={progress.label}
            className="w-full"
          />
        )}
        <div className="flex items-center gap-1.5 text-[12px]">
          <Icon name={status.icon} size={16} className={status.tone} />
          <span className={`min-w-0 flex-1 truncate font-semibold ${status.tone}`}>
            {status.text}
          </span>
          {status.detail && (
            <span className="shrink-0 font-mono text-muted tabular">{status.detail}</span>
          )}
        </div>
      </div>
      <div className="flex shrink-0 items-start">
        {actions.map((a) => (
          <button
            key={a.icon}
            type="button"
            aria-label={a.label}
            disabled={a.disabled}
            onClick={a.run}
            className="grid h-11 w-10 place-items-center text-muted disabled:opacity-40"
          >
            <Icon name={a.icon} size={24} />
          </button>
        ))}
      </div>
    </li>
  );
}

/**
 * Android v2 Downloads (screen 04), last tab of the bar since decision 0006:
 * the link card of the former Home comes first, then the three lists.
 */
export function MobileDownloads({ onBrowser }: { onBrowser: () => void }) {
  const t = useT();
  const [tab, setTab] = useState<Tab>('active');
  const { active: open, failedTasks, failedHistory, done, counts } = useDownloadLists();
  const library = useLibrary((s) => s.items);
  const play = useUi((s) => s.play);
  const pushToast = useUi((s) => s.pushToast);
  const { pause, resume, retry, startNow, pauseAll, resumeAll, cancel } = useDownloads.getState();

  const anyRunning = open.some(isRunning);
  const anyPaused = open.some((x) => x.state === 'paused');
  const retrying = open.some((x) => x.retry);
  const now = useNow(retrying ? 1000 : null);

  const mediaOf = (h: HistoryEntry) =>
    library.find((m) => m.taskId === h.taskId || (h.finalPath && m.path === h.finalPath));
  const playDone = async (h: HistoryEntry) => {
    const media = await mediaOfDownload(h);
    if (media) play(media);
    else pushToast({ tone: 'error', message: t('fileGone') });
  };
  const askCancel = (task: DownloadTask) =>
    useUi.getState().askConfirm({
      title: t('cancelTitle'),
      body: t('cancelBody', { title: task.title }),
      confirmLabel: t('cancelConfirm'),
      onConfirm: () => cancel(task.id),
    });

  const taskRow = (task: DownloadTask) => {
    const status = statusOf(task, t, now);
    const main =
      task.state === 'failed'
        ? {
            icon: 'refresh',
            label: t('actRetry', { title: task.title }),
            run: () => retry(task.id),
          }
        : task.state === 'paused'
          ? {
              icon: 'play_arrow',
              label: t('actResume', { title: task.title }),
              run: () => resume(task.id),
            }
          : waitsForSlot(task)
            ? {
                icon: 'play_arrow',
                label: t('actStart', { title: task.title }),
                run: () => startNow(task.id),
              }
            : {
                icon: 'pause',
                label: t('actPause', { title: task.title }),
                run: () => pause(task.id),
                disabled: task.state === 'processing' || task.state === 'analyzing',
              };
    return (
      <Row
        key={task.id}
        title={task.title}
        format={task.formatLabel}
        kind={task.kind}
        thumbnail={task.thumbnail}
        status={status}
        progress={
          task.state === 'queued' || task.state === 'analyzing'
            ? undefined
            : { value: barValue(task), label: progressAriaLabel(task), tone: barTone(task) }
        }
        actions={[
          main,
          {
            icon: 'close',
            label: t('cancelNamed', { title: task.title }),
            run: () => askCancel(task),
          },
        ]}
      />
    );
  };

  const empty = counts[tab] === 0;

  return (
    <div className="flex flex-1 flex-col gap-3.5 overflow-auto px-4 pb-3 pt-1">
      <header className="flex h-12 shrink-0 items-center gap-2">
        <h1 className="m-0 flex-1 text-[22px] font-extrabold tracking-[-0.01em]">
          {t('downloads')}
        </h1>
        {(anyRunning || anyPaused) && (
          <button
            type="button"
            aria-label={anyRunning ? t('pauseAll') : t('resumeAll')}
            onClick={anyRunning ? pauseAll : resumeAll}
            className="flex h-10 items-center gap-1.5 rounded-full border border-line-strong bg-surface2 px-3 text-[13px] font-semibold"
          >
            <Icon name={anyRunning ? 'pause' : 'play_arrow'} size={18} />
            {t('pauseAllShort')}
          </button>
        )}
      </header>

      <LinkCard onBrowser={onBrowser} />

      <div
        role="radiogroup"
        aria-label={t('downloadLists')}
        className="flex rounded-[20px] border border-line bg-sidebar p-[3px]"
      >
        {(['active', 'done', 'failed'] as const).map((id) => (
          <button
            key={id}
            type="button"
            role="radio"
            aria-checked={tab === id}
            onClick={() => setTab(id)}
            className={`h-9 flex-1 rounded-[17px] text-[13px] ${
              tab === id ? 'bg-line-strong font-bold text-fg' : 'font-semibold text-muted'
            }`}
          >
            {t(id === 'active' ? 'tabActive' : id === 'done' ? 'tabDone' : 'tabFailed', {
              n: counts[id],
            })}
          </button>
        ))}
      </div>

      <ul className="m-0 flex list-none flex-col p-0">
        {tab === 'active' && open.map(taskRow)}
        {tab === 'failed' && failedTasks.map(taskRow)}
        {tab === 'failed' &&
          failedHistory.map((h) => (
            <Row
              key={`h${h.id}`}
              title={h.title}
              format={h.formatLabel}
              kind="video"
              thumbnail={null}
              status={{
                icon: 'error',
                text: failureReason(h.reason, t) ?? t('stFailed'),
                tone: 'text-danger',
                detail: '',
              }}
              actions={[]}
            />
          ))}
        {tab === 'done' &&
          done.map((h) => {
            const media = mediaOf(h);
            return (
              <Row
                key={h.id}
                title={h.title}
                format={h.formatLabel}
                kind={media?.kind ?? 'video'}
                thumbnail={media?.thumbnail ?? null}
                status={{
                  icon: 'check_circle',
                  text: t('stDone'),
                  tone: 'text-accent-strong',
                  detail: formatBytes(h.doneBytes),
                }}
                actions={[
                  {
                    icon: 'play_arrow',
                    label: t('playTitle', { title: h.title }),
                    run: () => void playDone(h),
                  },
                ]}
              />
            );
          })}
      </ul>

      {empty && (
        <div className="flex flex-col items-center gap-1.5 px-6 py-12 text-center">
          <Icon name="download_done" size={36} className="text-faint-icon" />
          <span className="font-bold">{t('dlEmptyTitle')}</span>
          <span className="text-[13px] text-muted">{t('dlEmptyBody')}</span>
        </div>
      )}
    </div>
  );
}

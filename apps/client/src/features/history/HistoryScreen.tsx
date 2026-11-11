import { useMemo, useState, type ReactNode } from 'react';
import { IconButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Menu } from '../../components/Menu';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { HistoryEntry } from '../../services/types';
import { formatBytes, useDownloads } from '../../stores/downloads';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { playFrom } from '../../app/navigation';
import { durationLabel } from '../library/format';
import { clearPlayHistory, usePlayHistory, type PlayEntry } from '../player/recentPlays';
import { useNow } from '../downloads/useNow';
import { groupByDay } from './grouping';

type Tab = 'downloads' | 'plays';

const AUDIO_FORMATS = /^(MP3|FLAC|M4A|OPUS|OGG|WAV|AAC|ALAC|VORBIS)\b/i;

function timeLabel(ts: number) {
  const d = new Date(ts);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** Windows v2 screen 10: downloads and plays, grouped by day (COM-13). */
export default function HistoryScreen() {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const [tab, setTab] = useState<Tab>('downloads');
  const history = useDownloads((s) => s.history);
  const clearDownloads = useDownloads((s) => s.clearHistory);
  const plays = usePlayHistory();
  const askConfirm = useUi((s) => s.askConfirm);
  // Day labels move on at midnight.
  const now = useNow(60_000);

  const dlGroups = useMemo(
    () => groupByDay(history, (e) => e.finishedAt, now, lang),
    [history, now, lang],
  );
  const playGroups = useMemo(() => groupByDay(plays, (e) => e.at, now, lang), [plays, now, lang]);
  const empty = tab === 'downloads' ? history.length === 0 : plays.length === 0;

  const clear = () =>
    askConfirm(
      tab === 'downloads'
        ? {
            title: t('clearDlTitle'),
            body: t('clearDlBody'),
            confirmLabel: t('clearHistory'),
            onConfirm: clearDownloads,
          }
        : {
            title: t('clearPlaysTitle'),
            body: t('clearPlaysBody'),
            confirmLabel: t('clearHistory'),
            onConfirm: clearPlayHistory,
          },
    );

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-12 py-8">
      <div className="flex items-center gap-3">
        <h1 className="m-0 flex-1 text-[24px] font-extrabold tracking-[-0.02em]">{t('history')}</h1>
        <div
          role="radiogroup"
          aria-label={t('histKind')}
          className="flex rounded-[7px] border border-line bg-bg p-[3px]"
        >
          {(['downloads', 'plays'] as const).map((id) => (
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
              {t(id === 'downloads' ? 'histDownloads' : 'histPlays')}
            </button>
          ))}
        </div>
        <button
          type="button"
          disabled={empty}
          onClick={clear}
          className="flex h-9 items-center gap-1.5 rounded-sm border border-line-strong bg-surface2 px-3.5 text-[13px] font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50"
        >
          <Icon name="delete_sweep" size={18} />
          {t('clearHistory')}
        </button>
      </div>

      {tab === 'downloads' &&
        dlGroups.map((group) => (
          <Group key={group.day} day={group.day}>
            {group.entries.map((entry) => (
              <DownloadRow key={entry.id} entry={entry} />
            ))}
          </Group>
        ))}
      {tab === 'plays' &&
        playGroups.map((group) => (
          <Group key={group.day} day={group.day}>
            {group.entries.map((entry) => (
              <PlayRow key={`${entry.id}-${entry.at}`} entry={entry} />
            ))}
          </Group>
        ))}

      {empty ? (
        <div className="rounded-[10px] border border-dashed border-line-strong p-12 text-center text-[13.5px] text-muted">
          {t(tab === 'downloads' ? 'histEmptyDl' : 'histEmptyPlays')}
        </div>
      ) : (
        <span className="text-[12px] text-muted">
          {t(tab === 'downloads' ? 'histNoteDl' : 'histNotePlays')}
        </span>
      )}
    </div>
  );
}

function Group({ day, children }: { day: string; children: ReactNode }) {
  return (
    <section aria-label={day} className="flex flex-col gap-1.5">
      <h2 className="m-0 py-1.5 text-[11px] font-bold uppercase tracking-[0.06em] text-faint">
        {day}
      </h2>
      <ul className="m-0 flex list-none flex-col gap-1.5 p-0">{children}</ul>
    </section>
  );
}

const ROW =
  'flex h-[52px] items-center gap-3.5 rounded-lg border border-line bg-surface px-3.5 text-left text-fg';

function DownloadRow({ entry }: { entry: HistoryEntry }) {
  const t = useT();
  const task = useDownloads((s) => s.tasks[entry.taskId]);
  const { retry, revealHistory } = useDownloads.getState();
  const analyze = useUi((s) => s.analyze);
  const pushToast = useUi((s) => s.pushToast);
  const completed = entry.status === 'completed';

  const icon = completed
    ? AUDIO_FORMATS.test(entry.formatLabel)
      ? 'music_note'
      : 'movie'
    : entry.status === 'failed'
      ? 'error'
      : 'cancel';
  const meta = completed
    ? [entry.formatLabel, formatBytes(entry.totalBytes ?? entry.doneBytes), entry.sourceHost]
        .filter(Boolean)
        .join(' · ')
    : entry.status === 'failed'
      ? entry.reason
        ? t('failedBecause', { reason: entry.reason })
        : t('stFailed')
      : `${t('stCanceled')} · ${entry.sourceHost}`;

  // A failed task still exists and keeps its format; a cancelled one is
  // analyzed again from its source link.
  const retryEntry = () => {
    if (task?.state === 'failed') retry(task.id);
    else analyze(entry.url);
  };

  return (
    <li className={ROW}>
      <span className="w-11 shrink-0 font-mono text-[12px] text-muted">
        {timeLabel(entry.finishedAt)}
      </span>
      <Icon name={icon} className={entry.status === 'failed' ? 'text-danger' : 'text-muted'} />
      <span className="min-w-0 flex-1 truncate text-[13.5px] font-bold">{entry.title}</span>
      <span className="shrink-0 truncate font-mono text-[11.5px] text-muted">{meta}</span>
      <Menu
        label={t('actionsFor', { title: entry.title })}
        trigger={({ open, toggle, id }) => (
          <IconButton
            icon="more_horiz"
            label={t('moreActions')}
            size={30}
            iconSize={18}
            aria-haspopup="menu"
            aria-expanded={open}
            aria-controls={id}
            onClick={toggle}
          />
        )}
        items={[
          completed
            ? {
                label: t('showInFolder'),
                icon: 'folder_open',
                onSelect: () => revealHistory(entry.id),
              }
            : { label: t('tryAgain'), icon: 'refresh', onSelect: retryEntry },
          {
            label: t('copySourceLink'),
            icon: 'content_copy',
            onSelect: () => {
              navigator.clipboard
                ?.writeText(entry.url)
                .then(() => pushToast({ tone: 'success', message: t('linkCopied') }))
                .catch(() => pushToast({ tone: 'error', message: t('copyFailed') }));
            },
          },
        ]}
      />
    </li>
  );
}

function PlayRow({ entry }: { entry: PlayEntry }) {
  const t = useT();
  const pushToast = useUi((s) => s.pushToast);
  const pos = durationLabel(entry.position);
  const meta = !entry.position
    ? durationLabel(entry.duration || null)
    : entry.kind === 'audio' && entry.duration
      ? t('playedOf', { pos, dur: durationLabel(entry.duration) })
      : t('stoppedAt', { pos });
  const play = () =>
    void backend
      .libraryGet(entry.id)
      .then((media) => playFrom(media))
      .catch(() => pushToast({ tone: 'error', message: t('fileGone') }));

  return (
    <li>
      <button
        type="button"
        onClick={play}
        aria-label={t('playTitle', { title: entry.title })}
        className={`${ROW} w-full hover:bg-surface2`}
      >
        <span className="w-11 shrink-0 font-mono text-[12px] text-muted">
          {timeLabel(entry.at)}
        </span>
        <Icon name={entry.kind === 'audio' ? 'music_note' : 'movie'} className="text-muted" />
        <span className="min-w-0 flex-1 truncate text-[13.5px] font-bold">{entry.title}</span>
        <span className="shrink-0 font-mono text-[11.5px] text-muted">{meta}</span>
      </button>
    </li>
  );
}

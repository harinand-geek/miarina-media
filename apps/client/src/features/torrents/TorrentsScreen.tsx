import { useCallback, useEffect, useState } from 'react';
import { PlannedBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { useT, type Translate } from '../../i18n';
import { inTauri } from '../../services/platform';
import {
  torrents,
  type TorrentPreview,
  type TorrentRow,
  type TorrentSnapshot,
} from '../../services/torrents';
import { formatBytes } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { etaLabel } from '../downloads/format';

const rate = (bytesPerSec: number) =>
  bytesPerSec >= 1024 ** 2
    ? `${(bytesPerSec / 1024 ** 2).toFixed(1)} MB/s`
    : `${Math.round(bytesPerSec / 1024)} KB/s`;

const message = (e: unknown, fallback: string) =>
  typeof e === 'object' && e && 'message' in e ? String(e.message) : fallback;

const SECONDARY =
  'flex items-center gap-1.5 rounded-sm border border-line-strong bg-surface2 font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50';

/** Windows v2 screen 9: torrents with visible, stoppable sharing (TOR-01..04). */
export default function TorrentsScreen() {
  const t = useT();
  const [snapshot, setSnapshot] = useState<TorrentSnapshot>({
    enabled: false,
    rows: [],
    downloadLimit: 0,
    uploadLimit: 0,
  });
  const [magnet, setMagnet] = useState('');
  const [preview, setPreview] = useState<TorrentPreview | null>(null);
  const [selected, setSelected] = useState<number[]>([]);
  const [sequential, setSequential] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  // The browser preview shows sample torrents in development.
  const native = inTauri() || (import.meta.env.DEV && import.meta.env.MODE !== 'test');
  const fallback = t('torFailed');

  const refresh = useCallback(async () => {
    setSnapshot(await torrents.list());
  }, []);
  useEffect(() => {
    if (!native) return;
    let active = true;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      try {
        const next = await torrents.list();
        if (active) setSnapshot(next);
      } catch (e) {
        if (active) setError(message(e, ''));
      } finally {
        if (active)
          timer = setTimeout(() => {
            void poll();
          }, 1500);
      }
    };
    void poll();
    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [native]);

  const run = async (action: () => Promise<void>) => {
    setBusy(true);
    setError('');
    try {
      await action();
      await refresh();
    } catch (e) {
      setError(message(e, fallback));
    } finally {
      setBusy(false);
    }
  };
  const inspect = (link: string | null) =>
    run(async () => {
      const next = await torrents.preview(link);
      setPreview(next);
      setSelected(next?.files.map((f) => f.index) ?? []);
    });

  const sharing = snapshot.rows.some((r) => r.phase === 'downloading' || r.phase === 'finished');
  const pill = !snapshot.enabled
    ? t('torSessionOff')
    : sharing
      ? t('torSessionSharing')
      : t('torSessionOn');

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-12 py-8">
      <div className="flex items-end gap-3">
        <div className="flex flex-1 flex-col gap-1">
          <h1 className="m-0 text-[24px] font-extrabold tracking-[-0.02em]">{t('torrents')}</h1>
          <span className="max-w-[760px] text-[13px] text-muted">{t('torSub')}</span>
        </div>
        {native && (
          <>
            <span
              role="status"
              className={`flex h-[30px] items-center gap-1.5 rounded-full px-3 text-[12.5px] font-bold ${
                snapshot.enabled && sharing
                  ? 'bg-coral-subtle text-coral-strong'
                  : 'bg-surface2 text-muted'
              }`}
            >
              <span className="h-2 w-2 rounded-full bg-current" aria-hidden="true" />
              {pill}
            </span>
            <button
              type="button"
              disabled={busy}
              onClick={() =>
                void run(async () => {
                  if (snapshot.enabled) {
                    await torrents.disable();
                    setPreview(null);
                  } else {
                    await torrents.enable();
                  }
                })
              }
              className={`${SECONDARY} h-9 px-3.5 text-[13px] ${snapshot.enabled ? '!text-danger' : ''}`}
            >
              <Icon name={snapshot.enabled ? 'stop_circle' : 'play_circle'} size={18} />
              {snapshot.enabled ? t('torStopAll') : t('torEnable')}
            </button>
          </>
        )}
      </div>

      {error && (
        <p
          role="alert"
          className="m-0 rounded-lg border border-danger/40 bg-surface p-3 text-[13px]"
        >
          {error}
        </p>
      )}
      {!native && <p className="m-0 text-[13.5px] text-muted">{t('torOnlyApp')}</p>}

      {snapshot.enabled && (
        <form
          className="flex gap-2.5"
          onSubmit={(e) => {
            e.preventDefault();
            void inspect(magnet);
          }}
        >
          <div className="flex h-11 flex-1 items-center gap-2.5 rounded-sm border border-line-strong bg-bg px-3.5 focus-within:border-accent">
            <Icon name="hub" size={18} className="text-muted" />
            <input
              aria-label={t('torMagnet')}
              placeholder="magnet:?xt=urn:btih:…"
              spellCheck={false}
              className="min-w-0 flex-1 bg-transparent font-mono text-[13px] font-medium text-fg outline-none focus-visible:outline-none"
              value={magnet}
              onChange={(e) => setMagnet(e.target.value)}
            />
          </div>
          <button
            type="submit"
            disabled={busy || !magnet.trim()}
            className="h-11 rounded-sm bg-accent px-4 text-[13.5px] font-bold text-accent-ink enabled:hover:bg-accent-hover disabled:opacity-50"
          >
            {busy ? t('torWait') : t('torInspect')}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void inspect(null)}
            className={`${SECONDARY} h-11 px-3.5 text-[13px]`}
          >
            <Icon name="file_open" size={18} />
            {t('torOpenFile')}
          </button>
        </form>
      )}

      {preview && (
        <section
          aria-label={preview.name}
          className="flex flex-col gap-3 rounded-[10px] border border-accent bg-surface p-4"
        >
          <h2 className="m-0 text-[14px] font-bold">{preview.name}</h2>
          <p className="m-0 text-[12.5px] text-muted">{t('torPreviewNote')}</p>
          <div className="flex max-h-64 flex-col overflow-auto">
            {preview.files.map((f) => (
              <label
                key={f.index}
                className="flex items-center gap-3 border-b border-line py-2 text-[13px] last:border-b-0"
              >
                <input
                  type="checkbox"
                  className="accent-[var(--color-accent)]"
                  checked={selected.includes(f.index)}
                  onChange={(e) =>
                    setSelected((old) =>
                      e.target.checked ? [...old, f.index] : old.filter((i) => i !== f.index),
                    )
                  }
                />
                <span className="min-w-0 flex-1 break-all">{f.path}</span>
                <span className="shrink-0 font-mono text-[12px] text-muted">
                  {formatBytes(f.size)}
                </span>
              </label>
            ))}
          </div>
          <label className="flex items-center gap-2 text-[13px]">
            <input
              type="checkbox"
              className="accent-[var(--color-accent)]"
              checked={sequential}
              onChange={(e) => setSequential(e.target.checked)}
            />
            {t('torSequential')}
          </label>
          <div className="flex gap-2.5">
            <button
              type="button"
              disabled={busy || !selected.length}
              onClick={() =>
                void run(async () => {
                  await torrents.start(preview.hash, selected, sequential);
                  setPreview(null);
                })
              }
              className="h-9 rounded-sm bg-accent px-4 text-[13px] font-bold text-accent-ink enabled:hover:bg-accent-hover disabled:opacity-50"
            >
              {t('torStart')}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => setPreview(null)}
              className={`${SECONDARY} h-9 px-3.5 text-[13px]`}
            >
              {t('cancel')}
            </button>
          </div>
        </section>
      )}

      {snapshot.rows.length > 0 && (
        <div className="flex flex-col gap-2.5">
          {snapshot.rows.map((row) => (
            <TorrentCard
              key={row.hash}
              row={row}
              busy={busy}
              enabled={snapshot.enabled}
              act={(action) => void run(() => torrents.action(row.hash, action))}
            />
          ))}
        </div>
      )}
      {snapshot.enabled && !snapshot.rows.length && !preview && (
        <div className="rounded-[10px] border border-dashed border-line-strong p-12 text-center text-[13.5px] text-muted">
          {t('torEmpty')}
        </div>
      )}

      {snapshot.enabled && (
        <Limits
          snapshot={snapshot}
          busy={busy}
          apply={(download, upload) =>
            void run(async () => {
              await torrents.limits(download, upload);
              useUi.getState().pushToast({ tone: 'success', message: t('torLimitsSaved') });
            })
          }
        />
      )}
    </div>
  );
}

interface Stat {
  icon: string;
  label: string;
  value: string;
  tone?: string;
}

function describe(row: TorrentRow, t: Translate) {
  const done = row.total > 0 && row.done >= row.total;
  const ratio = row.total > 0 ? (row.uploaded / row.total).toFixed(1) : '0.0';
  const transfer = `${formatBytes(row.done)} / ${formatBytes(row.total)}`;
  switch (row.phase) {
    case 'finished':
      return {
        icon: 'check_circle',
        meta: t('torDoneSharing', { size: formatBytes(row.total) }),
        stats: [
          { icon: 'north', label: t('torSharing'), value: rate(row.upSpeed), tone: 'text-coral' },
          { icon: 'balance', label: t('torRatio'), value: ratio },
          { icon: 'group', label: t('torPeers'), value: String(row.peers) },
        ] as Stat[],
      };
    case 'paused':
      return {
        icon: 'pause_circle',
        meta: done
          ? t('torDoneMeta', { size: formatBytes(row.total) })
          : t('torPausedMeta', { done: formatBytes(row.done), total: formatBytes(row.total) }),
        stats: [{ icon: 'balance', label: t('torRatio'), value: ratio }] as Stat[],
      };
    case 'error':
      return { icon: 'error', meta: t('torError'), stats: [] as Stat[] };
    case 'checking':
      return { icon: 'sync', meta: t('torChecking'), stats: [] as Stat[] };
    case 'inactive':
      return { icon: 'stop_circle', meta: t('torInactive'), stats: [] as Stat[] };
    default: {
      const left = row.downSpeed > 0 ? (row.total - row.done) / row.downSpeed : null;
      const stats: Stat[] = [
        {
          icon: 'south',
          label: t('torDown'),
          value: rate(row.downSpeed),
          tone: 'text-accent-strong',
        },
        { icon: 'north', label: t('torUp'), value: rate(row.upSpeed) },
        { icon: 'group', label: t('torPeers'), value: String(row.peers) },
      ];
      if (left !== null)
        stats.push({ icon: 'schedule', label: t('torLeft'), value: etaLabel(left) });
      return { icon: 'downloading', meta: transfer, stats };
    }
  }
}

function TorrentCard({
  row,
  busy,
  enabled,
  act,
}: {
  row: TorrentRow;
  busy: boolean;
  enabled: boolean;
  act: (action: 'pause' | 'resume' | 'remove' | 'reveal') => void;
}) {
  const t = useT();
  const info = describe(row, t);
  const stopped = row.phase === 'paused' || row.phase === 'error';
  const primary = stopped
    ? { icon: 'play_arrow', label: t('torResume'), action: 'resume' as const }
    : row.phase === 'finished'
      ? { icon: 'stop_circle', label: t('torStopSharing'), action: 'pause' as const }
      : { icon: 'pause', label: t('pause'), action: 'pause' as const };
  const percent = row.total ? (row.done / row.total) * 100 : 0;

  return (
    <article className="flex flex-col gap-3 rounded-[10px] border border-line bg-surface p-4">
      <div className="flex items-center gap-3">
        <Icon
          name={info.icon}
          size={22}
          className={row.phase === 'error' ? 'text-danger' : 'text-muted'}
        />
        <div className="flex min-w-0 flex-1 flex-col gap-0.5">
          <h2 className="m-0 truncate text-[13.5px] font-bold">{row.name}</h2>
          <span className="truncate font-mono text-[11.5px] text-muted">{info.meta}</span>
        </div>
        <button
          type="button"
          disabled={busy || !enabled || row.phase === 'inactive' || row.phase === 'checking'}
          onClick={() => act(primary.action)}
          className={`${SECONDARY} h-8 px-3 text-[12.5px]`}
        >
          <Icon name={primary.icon} size={17} />
          {primary.label}
        </button>
        <button
          type="button"
          aria-label={t('openFolder')}
          title={t('openFolder')}
          disabled={busy}
          onClick={() => act('reveal')}
          className="grid h-8 w-8 place-items-center rounded-sm text-muted enabled:hover:bg-line enabled:hover:text-fg disabled:opacity-40"
        >
          <Icon name="folder_open" size={18} />
        </button>
        <button
          type="button"
          aria-label={t('torRemoveNamed', { name: row.name })}
          title={t('torRemove')}
          disabled={busy || !enabled}
          onClick={() =>
            useUi.getState().askConfirm({
              title: t('torRemoveTitle'),
              body: t('torRemoveBody'),
              confirmLabel: t('torRemove'),
              onConfirm: () => act('remove'),
            })
          }
          className="grid h-8 w-8 place-items-center rounded-sm text-muted enabled:hover:bg-line enabled:hover:text-fg disabled:opacity-40"
        >
          <Icon name="close" size={18} />
        </button>
      </div>
      <ProgressBar
        value={percent}
        tone={row.phase === 'error' ? 'error' : row.phase === 'paused' ? 'paused' : 'active'}
        label={`${row.name}, ${Math.floor(percent)} %`}
      />
      {info.stats.length > 0 && (
        <div className="flex flex-wrap gap-5 text-[12px] text-muted">
          {info.stats.map((s) => (
            <span key={s.icon} className="flex items-center gap-1.5">
              <Icon name={s.icon} size={15} className={s.tone ?? 'text-muted'} />
              <span className="font-semibold text-fg">{s.label}</span>
              <span className="font-mono tabular">{s.value}</span>
            </span>
          ))}
        </div>
      )}
    </article>
  );
}

/** Rate limits are real; ratio and seeding-time targets are not built yet (UX-06). */
function Limits({
  snapshot,
  busy,
  apply,
}: {
  snapshot: TorrentSnapshot;
  busy: boolean;
  apply: (download: number, upload: number) => void;
}) {
  const t = useT();
  const [down, setDown] = useState<string | null>(null);
  const [up, setUp] = useState<string | null>(null);
  const commit = () => {
    if (down === null && up === null) return;
    apply(
      down === null ? snapshot.downloadLimit : Number(down) * 1024,
      up === null ? snapshot.uploadLimit : Number(up) * 1024,
    );
    setDown(null);
    setUp(null);
  };
  const field = (label: string, hint: string, value: string, set: (v: string) => void) => (
    <label className="flex flex-col gap-1.5">
      <span className="text-[12.5px] font-bold">{label}</span>
      <input
        type="number"
        min="0"
        max="4194303"
        step="1"
        disabled={busy}
        value={value}
        onChange={(e) => set(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') commit();
        }}
        className="h-9 rounded-sm border border-line-strong bg-bg px-2.5 font-mono text-[12.5px] text-fg outline-none focus:border-accent"
      />
      <span className="text-[11.5px] text-muted">{hint}</span>
    </label>
  );
  const planned = (label: string, hint: string) => (
    <div className="flex flex-col gap-1.5" title={t('plannedHint')}>
      <span className="flex items-center gap-2 text-[12.5px] font-bold text-muted">
        {label}
        <PlannedBadge label={t('planned')} />
      </span>
      <div className="flex h-9 items-center rounded-sm border border-line bg-bg px-2.5 font-mono text-[12.5px] text-faint">
        —
      </div>
      <span className="text-[11.5px] text-muted">{hint}</span>
    </div>
  );
  return (
    <section className="grid grid-cols-4 gap-4 rounded-[10px] border border-line p-[18px] max-[1100px]:grid-cols-2">
      {field(
        t('torDownLimit'),
        t('torUnlimited'),
        down ?? String(snapshot.downloadLimit / 1024),
        setDown,
      )}
      {field(t('torUpLimit'), t('torCapped'), up ?? String(snapshot.uploadLimit / 1024), setUp)}
      {planned(t('torTargetRatio'), t('torRatioDesc'))}
      {planned(t('torSeedTime'), t('torSeedDesc'))}
    </section>
  );
}

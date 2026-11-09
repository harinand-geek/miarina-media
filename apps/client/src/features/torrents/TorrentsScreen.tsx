import { useCallback, useEffect, useState } from 'react';
import { torrents, type TorrentPreview, type TorrentSnapshot } from '../../services/torrents';
import { inTauri } from '../../services/platform';
import { useUi } from '../../stores/ui';

const button =
  'rounded-md border border-divider bg-surface px-4 py-2 text-sm hover:bg-surface2 disabled:opacity-50';
const input = 'rounded-md border border-divider bg-surface px-3 py-2 text-fg';
const bytes = (n: number) =>
  n < 1048576 ? `${(n / 1024).toFixed(1)} KiB` : `${(n / 1048576).toFixed(1)} MiB`;
const message = (e: unknown) =>
  typeof e === 'object' && e && 'message' in e
    ? String(e.message)
    : 'The operation could not be completed.';

export default function TorrentsScreen() {
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
  const [down, setDown] = useState<string | null>(null);
  const [up, setUp] = useState<string | null>(null);
  const native = inTauri();
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
        if (active) setError(message(e));
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
      setError(message(e));
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
  return (
    <section className="flex-1 overflow-auto p-10">
      <h1 className="text-2xl font-bold">Torrents</h1>
      <p className="mt-2 max-w-3xl text-sm text-muted">
        Add a magnet link or a .torrent file, choose its files and follow the transfer. Torrents
        share downloaded pieces with peers, including after completion. Pause to stop sharing.
      </p>
      {error && (
        <p role="alert" className="mt-4 rounded-md border border-divider bg-surface p-3">
          {error}
        </p>
      )}
      {!native && (
        <p className="mt-6 text-muted">
          Torrent transfers are available in the Windows application.
        </p>
      )}
      {native && !snapshot.enabled && (
        <button
          className={`${button} mt-6`}
          disabled={busy}
          onClick={() => void run(() => torrents.enable())}
        >
          Enable torrent session
        </button>
      )}
      {snapshot.enabled && (
        <>
          <button
            className={`${button} mt-4`}
            disabled={busy}
            onClick={() =>
              void run(async () => {
                await torrents.disable();
                setPreview(null);
              })
            }
          >
            Stop all torrents and sharing
          </button>
          <form
            className="mt-6 flex gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              void inspect(magnet);
            }}
          >
            <input
              aria-label="Magnet link"
              placeholder="magnet:?xt=urn:btih:…"
              className={`${input} min-w-0 flex-1`}
              value={magnet}
              onChange={(e) => setMagnet(e.target.value)}
            />
            <button className={button} disabled={busy || !magnet.trim()}>
              {busy ? 'Please wait…' : 'Inspect link'}
            </button>
            <button
              type="button"
              className={button}
              disabled={busy}
              onClick={() => void inspect(null)}
            >
              Open .torrent
            </button>
          </form>
          <details className="mt-5 rounded-md border border-divider p-4">
            <summary className="cursor-pointer">Transfer limits</summary>
            <p className="mt-2 text-sm text-muted">
              KiB/s · 0 = unlimited. Current: ↓ {bytes(snapshot.downloadLimit)}/s · ↑{' '}
              {bytes(snapshot.uploadLimit)}/s
            </p>
            <form
              className="mt-3 flex items-end gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                void run(async () => {
                  await torrents.limits(
                    down === null ? snapshot.downloadLimit : Number(down) * 1024,
                    up === null ? snapshot.uploadLimit : Number(up) * 1024,
                  );
                  setDown(null);
                  setUp(null);
                });
              }}
            >
              <label className="flex flex-col gap-1 text-sm">
                Download
                <input
                  className={input}
                  type="number"
                  min="0"
                  max="4194303"
                  step="1"
                  required
                  value={down ?? String(snapshot.downloadLimit / 1024)}
                  onChange={(e) => setDown(e.target.value)}
                />
              </label>
              <label className="flex flex-col gap-1 text-sm">
                Upload
                <input
                  className={input}
                  type="number"
                  min="0"
                  max="4194303"
                  step="1"
                  required
                  value={up ?? String(snapshot.uploadLimit / 1024)}
                  onChange={(e) => setUp(e.target.value)}
                />
              </label>
              <button className={button} disabled={busy}>
                Apply
              </button>
            </form>
          </details>
        </>
      )}
      {preview && (
        <div className="mt-6 rounded-lg border border-divider bg-surface p-5">
          <h2 className="font-semibold">{preview.name}</h2>
          <p className="mt-1 text-sm text-muted">
            Files are saved in a new folder under your download folder / Torrents. Small boundary
            pieces of unselected files may also be written.
          </p>
          <div className="my-4 max-h-64 overflow-auto">
            {preview.files.map((f) => (
              <label key={f.index} className="flex gap-3 py-2 text-sm">
                <input
                  type="checkbox"
                  checked={selected.includes(f.index)}
                  onChange={(e) =>
                    setSelected((old) =>
                      e.target.checked ? [...old, f.index] : old.filter((i) => i !== f.index),
                    )
                  }
                />
                <span className="min-w-0 flex-1 break-all">{f.path}</span>
                <span className="shrink-0 text-muted">{bytes(f.size)}</span>
              </label>
            ))}
          </div>
          <label className="flex gap-2 text-sm">
            <input
              type="checkbox"
              checked={sequential}
              onChange={(e) => setSequential(e.target.checked)}
            />
            Download pieces in order
          </label>
          <div className="mt-4 flex gap-3">
            <button
              className={button}
              disabled={busy || !selected.length}
              onClick={() =>
                void run(async () => {
                  await torrents.start(preview.hash, selected, sequential);
                  setPreview(null);
                })
              }
            >
              Start download
            </button>
            <button className={button} disabled={busy} onClick={() => setPreview(null)}>
              Cancel
            </button>
          </div>
        </div>
      )}
      <div className="mt-6 space-y-3">
        {snapshot.rows.map((row) => (
          <article className="rounded-lg border border-divider bg-surface p-5" key={row.hash}>
            <div className="flex justify-between gap-4">
              <h2 className="min-w-0 break-all font-semibold">{row.name}</h2>
              <span className="text-sm text-accent-strong">
                {row.phase === 'finished' ? 'Complete · sharing' : row.phase}
              </span>
            </div>
            <progress
              className="mt-3 h-2 w-full accent-accent-strong"
              aria-label={`${row.name} progress`}
              value={row.done}
              max={row.total || 1}
            />
            <p className="mt-2 text-sm text-muted">
              {bytes(row.done)} / {bytes(row.total)} · ↓ {bytes(row.downSpeed)}/s · ↑{' '}
              {bytes(row.upSpeed)}/s · {row.peers} peers
            </p>
            <div className="mt-3 flex gap-2">
              <button
                className={button}
                disabled={
                  busy || !snapshot.enabled || row.phase === 'inactive' || row.phase === 'checking'
                }
                onClick={() =>
                  void run(() =>
                    torrents.action(
                      row.hash,
                      ['paused', 'error'].includes(row.phase) ? 'resume' : 'pause',
                    ),
                  )
                }
              >
                {['paused', 'error'].includes(row.phase) ? 'Resume' : 'Pause'}
              </button>
              <button
                className={button}
                disabled={busy}
                onClick={() => void run(() => torrents.action(row.hash, 'reveal'))}
              >
                Open folder
              </button>
              <button
                className={button}
                disabled={busy || !snapshot.enabled}
                onClick={() =>
                  useUi.getState().askConfirm({
                    title: 'Remove torrent?',
                    body: 'The downloaded files will be kept. The transfer and sharing will stop.',
                    confirmLabel: 'Remove',
                    onConfirm: () => {
                      void run(() => torrents.action(row.hash, 'remove'));
                    },
                  })
                }
              >
                Remove
              </button>
            </div>
          </article>
        ))}
      </div>
      {snapshot.enabled && !snapshot.rows.length && !preview && (
        <p className="mt-10 text-center text-muted">Your torrents will appear here.</p>
      )}
    </section>
  );
}

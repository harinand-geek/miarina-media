import { useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { PlannedBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { backend } from '../../services/backend';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { addedLabel, qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { LinkIssueNote } from './LinkIssueNote';
import { linkFieldBorder, useLinkInput } from './useLinkInput';

/** Long folder paths are shortened like the design ("C:\…\Videos\Miarina"). */
function shortPath(path: string) {
  const parts = path.split(/[\\/]/).filter(Boolean);
  return parts.length > 3 ? [parts[0], '…', ...parts.slice(-2)].join('\\') : path;
}

/** "C:\Users\…" → "Drive C:" (Windows); empty elsewhere. */
function driveName(path: string) {
  const match = /^([A-Za-z]):/.exec(path);
  return match ? `Drive ${match[1]!.toUpperCase()}:` : '';
}

interface QuickAction {
  icon: string;
  title: string;
  detail: string;
  planned?: boolean;
  run?: () => void;
}

export function HomeScreen() {
  const { url, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();
  const [dragging, setDragging] = useState(false);
  const go = useUi((s) => s.go);
  const play = useUi((s) => s.play);
  const pushToast = useUi((s) => s.pushToast);
  const recent = useLibrary((s) => s.recent);
  const overview = useLibrary((s) => s.overview);
  const stats = overview?.stats;
  const disk = overview?.disk;
  const share = (bytes: number) => (disk?.total ? `${(bytes / disk.total) * 100}%` : '0%');

  const quick: QuickAction[] = [
    {
      icon: 'music_note',
      title: 'Audio only',
      detail: 'Extract MP3, M4A or FLAC',
      run: () => void submit(url, 'audio'),
    },
    {
      icon: 'playlist_play',
      title: 'Playlist',
      detail: 'Download every item at once',
      planned: true,
    },
    {
      icon: 'format_list_bulleted',
      title: 'Batch links',
      detail: 'Paste several URLs, one per line',
      planned: true,
    },
    {
      icon: 'folder_open',
      title: 'Open folder',
      detail: shortPath(overview?.downloadDir ?? ''),
      run: () =>
        void backend
          .openDownloadFolder()
          .catch((e: unknown) =>
            pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
          ),
    },
  ];

  return (
    <div
      className="flex flex-1 flex-col gap-7 overflow-auto px-10 py-8"
      onDragOver={(e) => {
        e.preventDefault();
        if (!dragging) setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        const text = e.dataTransfer.getData('text').trim();
        if (text) {
          change(text);
          void submit(text);
        }
      }}
    >
      <div className="flex flex-col gap-1.5">
        <h1 className="m-0 text-[26px] font-bold tracking-[-0.02em]">Download from a link</h1>
        <p className="m-0 text-[14px] text-muted">
          Paste a link, or drop it anywhere in this window.
        </p>
      </div>

      <section
        aria-label="Link"
        className={`flex flex-col gap-3.5 rounded-lg border border-dashed bg-surface p-5 transition-colors duration-150 ${
          dragging ? 'border-accent' : 'border-overlay-border'
        }`}
      >
        <form
          className="flex gap-2.5"
          onSubmit={(e) => {
            e.preventDefault();
            void submit();
          }}
        >
          <div className="flex flex-1 flex-col gap-1.5">
            <div
              className={`flex h-12 items-center gap-2.5 rounded-sm border bg-bg px-3.5 transition-[border-color,box-shadow] duration-150 focus-within:shadow-[0_0_0_3px_rgba(53,201,189,.18)] ${linkFieldBorder(issue)}`}
            >
              <Icon name="link" className={issue?.tone === 'warn' ? 'text-warn' : 'text-muted'} />
              <input
                ref={inputRef}
                value={url}
                onChange={(e) => change(e.target.value)}
                placeholder="https://"
                aria-label="Media link"
                aria-invalid={issue?.tone === 'warn'}
                aria-describedby={issue ? 'link-error' : undefined}
                spellCheck={false}
                autoComplete="off"
                className="h-full flex-1 bg-transparent font-mono text-[14px] text-fg outline-none focus-visible:outline-none"
              />
            </div>
          </div>
          <Button size="lg" icon="content_paste" onClick={paste} className="text-[13.5px]">
            Paste
          </Button>
          <Button type="submit" variant="primary" size="lg" className="px-[22px]">
            Analyze
          </Button>
        </form>
        {issue && <LinkIssueNote id="link-error" issue={issue} onFix={applyFix} />}
        <div className="flex justify-between gap-4 text-[12.5px] text-muted">
          <span>
            {dragging
              ? 'Release to add this link'
              : 'Tip: drag a link from your browser onto this window.'}
          </span>
          <span>Only download media you own or have permission to save.</span>
        </div>
      </section>

      <div className="grid grid-cols-4 gap-3">
        {quick.map((q) => (
          <button
            key={q.title}
            type="button"
            disabled={q.planned}
            onClick={q.run}
            className="flex flex-col gap-3 rounded-lg border border-surface2 bg-surface p-4 text-left text-fg enabled:hover:border-overlay-border enabled:hover:bg-card-hover disabled:cursor-default"
          >
            <span className="flex w-full items-start justify-between">
              <span
                className={`grid h-[34px] w-[34px] place-items-center rounded-md bg-surface2 ${q.planned ? 'text-faint' : 'text-accent-strong'}`}
              >
                <Icon name={q.icon} />
              </span>
              {q.planned && <PlannedBadge />}
            </span>
            <span className="flex flex-col gap-[3px]">
              <span className={`text-[14px] font-semibold ${q.planned ? 'text-muted' : ''}`}>
                {q.title}
              </span>
              <span className="text-[12.5px] text-muted">{q.detail}</span>
            </span>
          </button>
        ))}
      </div>

      <div className="grid grid-cols-[minmax(0,2fr)_minmax(0,1fr)] gap-4 max-[1023px]:grid-cols-1">
        <section
          aria-label="Recent downloads"
          className="rounded-lg border border-surface2 bg-surface py-2"
        >
          <div className="flex items-center justify-between px-[18px] pb-2 pt-2.5">
            <h2 className="m-0 text-heading font-bold">Recent downloads</h2>
            <button
              type="button"
              onClick={() => go('history')}
              className="text-[12.5px] font-semibold text-accent-strong hover:text-accent-hover"
            >
              View history
            </button>
          </div>
          {recent.length === 0 && (
            <p className="m-0 px-[18px] py-6 text-[13px] text-muted">
              Nothing downloaded yet. Paste a link above to start.
            </p>
          )}
          {recent.map((item) => (
            <div
              key={item.id}
              className="flex items-center gap-3.5 px-[18px] py-2.5 hover:bg-card-hover"
            >
              <MediaThumb media={item} className="h-10 w-[72px] rounded-[5px]" />
              <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
                <span className="truncate text-[13.5px] font-semibold">{item.title}</span>
                <span className="truncate text-[12px] text-muted">
                  {[item.sourceHost, qualityLabel(item), formatBytes(item.sizeBytes)]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              </div>
              <span className="text-[12px] text-muted">{addedLabel(item.addedAt)}</span>
              <IconButton
                icon="play_arrow"
                label={`Play ${item.title}`}
                fill
                size={32}
                tone="accent-hover"
                onClick={() => {
                  play(item);
                  go('player');
                }}
              />
            </div>
          ))}
        </section>

        <section
          aria-label="Library overview"
          className="flex flex-col gap-4 rounded-lg border border-surface2 bg-surface p-[18px]"
        >
          <h2 className="m-0 text-heading font-bold">Library</h2>
          <div className="flex items-baseline gap-2">
            <span className="text-[34px] font-bold tracking-[-0.02em]">{stats?.count ?? 0}</span>
            <span className="text-[13px] text-muted">
              items · {formatBytes(stats?.totalBytes ?? 0)}
            </span>
          </div>
          <div className="flex flex-col gap-2.5 text-[13px]">
            <div className="flex items-center gap-2.5">
              <span className="h-2 w-2 rounded-[2px] bg-accent" />
              <span className="flex-1">Video</span>
              <span className="font-mono text-[12px] text-muted">
                {stats?.videoCount ?? 0} · {formatBytes(stats?.videoBytes ?? 0)}
              </span>
            </div>
            <div className="flex items-center gap-2.5">
              <span className="h-2 w-2 rounded-[2px] bg-audio" />
              <span className="flex-1">Audio</span>
              <span className="font-mono text-[12px] text-muted">
                {stats?.audioCount ?? 0} · {formatBytes(stats?.audioBytes ?? 0)}
              </span>
            </div>
          </div>
          {disk && (
            <div className="flex flex-col gap-1.5">
              <div className="flex h-1.5 overflow-hidden rounded-[3px] bg-line" aria-hidden="true">
                <div className="bg-accent" style={{ width: share(stats?.videoBytes ?? 0) }} />
                <div className="bg-audio" style={{ width: share(stats?.audioBytes ?? 0) }} />
                <div
                  className="bg-faint-icon"
                  style={{
                    width: share(Math.max(0, disk.total - disk.free - (stats?.totalBytes ?? 0))),
                  }}
                />
              </div>
              <span className="text-[12px] text-muted">
                {driveName(overview?.downloadDir ?? '')} {formatBytes(disk.free)} free of{' '}
                {formatBytes(disk.total)}
              </span>
            </div>
          )}
          <Button size="sm" className="mt-auto h-9 text-[13px]" onClick={() => go('library')}>
            Open library
          </Button>
        </section>
      </div>
    </div>
  );
}

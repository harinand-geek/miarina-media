import { useMemo } from 'react';
import { Button, IconButton } from '../../components/Button';
import { ThumbBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { Logo } from '../../components/Logo';
import { ProgressBar } from '../../components/ProgressBar';
import { useLibrary } from '../../stores/library';
import { durationLabel, qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { formatBytes, percentOf, summarize, useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import type { MobileTab } from '../../app/MobileShell';
import { LinkIssueNote } from './LinkIssueNote';
import { linkFieldBorder, useLinkInput } from './useLinkInput';
import { backend } from '../../services/backend';

export function MobileHome({
  onNavigate,
  onOpenSettings,
}: {
  onNavigate: (tab: MobileTab) => void;
  onOpenSettings: () => void;
}) {
  const { url, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();
  const tasks = useDownloads((s) => s.tasks);
  const summary = useMemo(() => summarize(tasks), [tasks]);
  const play = useUi((s) => s.play);
  const recent = useLibrary((s) => s.recent);
  const first = summary.active[0];

  const quick = [
    { icon: 'music_note', label: 'Audio', run: () => void submit(url, 'audio') },
    { icon: 'playlist_play', label: 'Playlist', planned: true },
    { icon: 'format_list_bulleted', label: 'Batch', planned: true },
    { icon: 'folder_open', label: 'Files', run: () => onNavigate('library') },
  ];

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-4 pb-5 pt-2">
      <header className="flex h-12 items-center gap-2.5">
        <Logo size={26} />
        <span className="flex-1 text-[18px] font-bold tracking-[-0.01em]">Miarina Media</span>
        <IconButton
          icon="search"
          label="Search library"
          size={44}
          iconSize={24}
          tone="default"
          className="rounded-full"
          onClick={() => onNavigate('library')}
        />
        <IconButton
          icon="settings"
          label="Settings"
          size={44}
          iconSize={24}
          tone="default"
          className="rounded-full"
          onClick={onOpenSettings}
        />
      </header>

      <form
        className="flex flex-col gap-3 rounded-[16px] bg-surface p-4"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <label htmlFor="mobile-link" className="text-[15px] font-bold">
          Paste a link
        </label>
        <div
          className={`flex h-[52px] items-center gap-2 rounded-[10px] border bg-bg pl-3.5 pr-1.5 transition-colors duration-150 ${linkFieldBorder(issue)}`}
        >
          <input
            id="mobile-link"
            ref={inputRef}
            value={url}
            onChange={(e) => change(e.target.value)}
            placeholder="https://"
            inputMode="url"
            autoComplete="off"
            aria-invalid={issue?.tone === 'warn'}
            aria-describedby={issue ? 'mobile-link-issue' : undefined}
            className="h-full min-w-0 flex-1 bg-transparent font-mono text-[14px] text-fg outline-none focus-visible:outline-none"
          />
          <button
            type="button"
            onClick={paste}
            className="flex h-10 items-center gap-1.5 rounded-md bg-surface2 px-3 text-[13px] font-semibold"
          >
            <Icon name="content_paste" size={18} />
            Paste
          </button>
        </div>
        {issue && <LinkIssueNote id="mobile-link-issue" issue={issue} onFix={applyFix} compact />}
        <Button type="submit" variant="primary" pill className="h-[52px] text-[15px]">
          Analyze link
        </Button>
        {/* Sharing from other apps needs the Android share intent (not built yet). */}
        {backend.kind === 'mock' && (
          <span className="text-center text-[12px] text-muted">
            Or share a link to Miarina Media from any app.
          </span>
        )}
      </form>

      <div className="grid grid-cols-4 gap-2">
        {quick.map((q) => (
          <button
            key={q.label}
            type="button"
            disabled={q.planned}
            aria-label={q.planned ? `${q.label} (planned)` : q.label}
            onClick={q.run}
            className="flex flex-col items-center gap-2 rounded-[12px] px-1 py-3 text-[12px] font-semibold text-fg disabled:text-muted"
          >
            <span
              className={`relative grid h-[52px] w-[52px] place-items-center rounded-[16px] bg-surface ${q.planned ? 'text-faint' : 'text-accent-strong'}`}
            >
              <Icon name={q.icon} size={24} />
              {q.planned && (
                <span className="absolute -right-1 -top-1 rounded-xs bg-planned px-1 font-mono text-[9px] font-bold text-planned-ink">
                  LATER
                </span>
              )}
            </span>
            {q.label}
          </button>
        ))}
      </div>

      {first && (
        <button
          type="button"
          onClick={() => onNavigate('downloads')}
          className="flex flex-col gap-2.5 rounded-[16px] bg-surface p-3.5 text-left"
        >
          <span className="flex w-full justify-between text-[13px]">
            <span className="font-bold">{summary.stateLabel}</span>
            <span className="font-mono text-accent-strong">
              {summary.speedLabel === 'Paused' ? '—' : summary.speedLabel}
            </span>
          </span>
          <span className="flex w-full justify-between text-[13px] text-muted">
            <span className="truncate">{first.title}</span>
            <span className="font-mono tabular">{Math.floor(percentOf(first))}%</span>
          </span>
          <ProgressBar
            value={percentOf(first)}
            label={`${first.title}, ${Math.floor(percentOf(first))} percent`}
            className="w-full"
          />
        </button>
      )}

      <section aria-label="Recent" className="flex flex-col gap-1">
        <div className="flex h-9 items-center justify-between">
          <h2 className="m-0 text-[15px] font-bold">Recent</h2>
          <button
            type="button"
            onClick={() => onNavigate('library')}
            className="text-[13px] font-semibold text-accent-strong"
          >
            See all
          </button>
        </div>
        {recent.length === 0 && (
          <p className="m-0 py-4 text-[13px] text-muted">Your downloads will appear here.</p>
        )}
        {recent.map((item) => (
          <div key={item.id} className="flex min-h-16 items-center gap-3">
            <button
              type="button"
              onClick={() => play(item)}
              className="flex min-w-0 flex-1 items-center gap-3 text-left"
            >
              <MediaThumb media={item} className="h-[45px] w-20 rounded-md">
                {item.durationSecs != null && (
                  <ThumbBadge position="br">{durationLabel(item.durationSecs)}</ThumbBadge>
                )}
              </MediaThumb>
              <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                <span className="truncate text-[14px] font-semibold">{item.title}</span>
                <span className="text-[12px] text-muted">
                  {qualityLabel(item)} · {formatBytes(item.sizeBytes)}
                </span>
              </span>
            </button>
            <IconButton
              icon="more_vert"
              label="More actions (not designed yet)"
              size={44}
              iconSize={24}
              disabled
            />
          </div>
        ))}
      </section>
    </div>
  );
}

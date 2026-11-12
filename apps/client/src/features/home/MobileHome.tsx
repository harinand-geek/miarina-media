import { useEffect, useMemo, useState } from 'react';
import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Logo } from '../../components/Logo';
import { ProgressBar } from '../../components/ProgressBar';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';
import { percentOf, summarize, useDownloads } from '../../stores/downloads';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import type { MobileTab } from '../../app/MobileShell';
import { formatClock } from '../../hooks/usePlaybackClock';
import { durationLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { useMobileMediaSheet } from '../library/useMobileMediaSheet';
import { RESUME_MARGIN_SECS, savedPosition } from '../player/usePlayback';
import { useUpdates } from '../settings/useUpdates';
import { LinkIssueNote } from './LinkIssueNote';
import { linkFieldBorder, useLinkInput } from './useLinkInput';

/** Started media first (COM-04); latest downloads when nothing is started. */
const RESUME_SCAN = 100;
const CAROUSEL = 8;

function useHomeMedia() {
  const [items, setItems] = useState<MediaRecord[]>([]);
  useEffect(() => {
    let alive = true;
    const load = () =>
      backend
        .libraryQuery({ search: '', kind: null, sort: 'added', limit: RESUME_SCAN })
        .then((page) => alive && setItems(page.items))
        .catch(() => {});
    void load();
    const stop = backend.onLibraryChanged(() => void load());
    return () => {
      alive = false;
      stop();
    };
  }, []);
  return useMemo(() => {
    const started = items.filter((m) => {
      const at = savedPosition(m.id);
      return at > 0 && (!m.durationSecs || at < m.durationSecs - RESUME_MARGIN_SECS);
    });
    return started.length
      ? { resume: true, items: started.slice(0, CAROUSEL) }
      : { resume: false, items: items.slice(0, CAROUSEL) };
  }, [items]);
}

/** Android v2 Home (screen 01): link first, quick actions, downloads, continue. */
export function MobileHome({
  onNavigate,
  onOpenSettings,
}: {
  onNavigate: (tab: MobileTab) => void;
  onOpenSettings: () => void;
}) {
  const t = useT();
  const { url, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();
  const tasks = useDownloads((s) => s.tasks);
  const summary = useMemo(() => summarize(tasks), [tasks]);
  const updateWaiting = useUpdates((s) => s.phase === 'available' || s.phase === 'ready');
  const home = useHomeMedia();
  const actionsSheet = useMobileMediaSheet();
  const first = summary.active[0];

  const quick = [
    { icon: 'music_note', label: t('qAudio'), run: () => void submit(url, 'audio') },
    { icon: 'playlist_play', label: t('qPlaylist'), planned: true },
    { icon: 'travel_explore', label: t('tabBrowser'), run: () => onNavigate('browser') },
    { icon: 'folder_open', label: t('qFiles'), run: () => onNavigate('music') },
  ];

  const downloadsTitle = [
    summary.running.length
      ? t('sumRunning', { n: summary.running.length })
      : summary.offline
        ? t('sumOffline')
        : t('sumPaused'),
    summary.queued.length ? t('sumQueue', { n: summary.queued.length }) : null,
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-4 pb-4 pt-1">
      <header className="flex h-12 shrink-0 items-center gap-2.5">
        <Logo size={26} />
        <span className="flex-1 text-[18px] font-extrabold tracking-[-0.01em]">Miarina Media</span>
        <button
          type="button"
          aria-label={t('searchLibrary')}
          onClick={() => onNavigate('music')}
          className="grid h-11 w-11 place-items-center rounded-full"
        >
          <Icon name="search" size={24} />
        </button>
        <button
          type="button"
          aria-label={updateWaiting ? `${t('settings')} — ${t('updateAvailable')}` : t('settings')}
          onClick={onOpenSettings}
          className="relative grid h-11 w-11 place-items-center rounded-full"
        >
          <Icon name="settings" size={24} />
          {updateWaiting && (
            <span className="absolute right-2.5 top-2.5 h-2 w-2 rounded-full bg-accent" />
          )}
        </button>
      </header>

      <form
        className="flex flex-col gap-3 rounded-2xl bg-surface p-4"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <label htmlFor="mobile-link" className="text-[15px] font-bold">
          {t('homeLink')}
        </label>
        <div
          className={`flex h-[52px] items-center gap-2 rounded-[10px] border bg-bg pl-3.5 pr-1.5 transition-colors duration-150 focus-within:shadow-[0_0_0_3px_rgba(53,201,189,0.16)] ${linkFieldBorder(issue)}`}
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
            className="flex h-10 items-center gap-1.5 rounded-sm bg-surface2 px-3 text-[13px] font-semibold"
          >
            <Icon name="content_paste" size={18} />
            {t('pasteShort')}
          </button>
        </div>
        {issue && <LinkIssueNote id="mobile-link-issue" issue={issue} onFix={applyFix} compact />}
        <Button type="submit" variant="primary" pill className="h-[52px] gap-2 text-[15px]">
          {t('analyzeLink')}
          <Icon name="arrow_forward" size={20} />
        </Button>
        <span className="text-center text-[12px] text-muted">{t('shareHint')}</span>
      </form>

      <div className="grid grid-cols-4 gap-2">
        {quick.map((q) => (
          <button
            key={q.icon}
            type="button"
            disabled={q.planned}
            aria-label={q.planned ? t('plannedNamed', { name: q.label }) : q.label}
            onClick={q.run}
            className="flex flex-col items-center gap-2 text-[12px] font-semibold text-fg disabled:text-muted"
          >
            <span
              className={`relative grid h-[52px] w-[52px] place-items-center rounded-2xl bg-surface ${q.planned ? 'text-faint' : 'text-accent-strong'}`}
            >
              <Icon name={q.icon} size={24} />
              {q.planned && (
                <span className="absolute -right-2 -top-[5px] rounded-xs bg-planned-ink px-1 py-px font-mono text-[9px] font-bold text-planned">
                  {t('planned')}
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
          className="flex flex-col gap-2.5 rounded-2xl bg-surface p-3.5 text-left"
        >
          <span className="flex w-full justify-between gap-3 text-[13px]">
            <span className="truncate font-bold">{downloadsTitle}</span>
            <span className="font-mono text-accent-strong">
              {summary.running.length ? summary.speedLabel : '—'}
            </span>
          </span>
          <span className="flex w-full justify-between gap-3 text-[13px] text-muted">
            <span className="truncate">
              {[first.title, first.formatLabel].filter(Boolean).join(' — ')}
            </span>
            <span className="font-mono tabular">{Math.floor(percentOf(first))} %</span>
          </span>
          <ProgressBar
            value={percentOf(first)}
            height={6}
            label={`${first.title}, ${Math.floor(percentOf(first))} %`}
            className="w-full"
          />
        </button>
      )}

      <section
        aria-label={home.resume ? t('resumeTitle') : t('recentTitle')}
        className="flex flex-col gap-2.5"
      >
        <div className="flex items-center justify-between">
          <h2 className="m-0 text-[15px] font-bold">
            {home.resume ? t('resumeTitle') : t('recentTitle')}
          </h2>
          <button
            type="button"
            onClick={() => onNavigate('videos')}
            className="text-[13px] font-semibold text-coral-strong"
          >
            {t('seeAll')}
          </button>
        </div>
        {home.items.length === 0 && (
          <p className="m-0 py-4 text-[13px] text-muted">{t('homeEmpty')}</p>
        )}
        <ul className="-mx-4 m-0 flex list-none gap-3 overflow-x-auto px-4 pb-1 [scrollbar-width:none]">
          {home.items.map((item, i) => {
            const at = savedPosition(item.id);
            const pct =
              home.resume && item.durationSecs ? Math.min(100, (at / item.durationSecs) * 100) : 0;
            return (
              <li key={item.id} className="flex w-[168px] shrink-0 flex-col gap-1.5">
                <button
                  type="button"
                  onClick={() =>
                    useMobilePlayback
                      .getState()
                      .start(item, home.items, home.resume ? t('resumeTitle') : t('recentTitle'))
                  }
                  onContextMenu={(e) => {
                    e.preventDefault();
                    actionsSheet.open(item);
                  }}
                  aria-label={t('playTitle', { title: item.title })}
                  className="block"
                >
                  <MediaThumb media={item} className="h-[94px] w-full rounded-[10px]">
                    {pct > 0 && (
                      <span
                        className="absolute inset-x-0 bottom-0 h-[3px] bg-line"
                        aria-hidden="true"
                      >
                        <span className="block h-full bg-coral" style={{ width: `${pct}%` }} />
                      </span>
                    )}
                    {i === 0 && (
                      <span className="absolute bottom-2 right-1.5 grid h-7 w-7 place-items-center rounded-full bg-coral text-coral-ink">
                        <Icon name="play_arrow" size={18} fill />
                      </span>
                    )}
                  </MediaThumb>
                </button>
                <span className="flex items-start gap-1">
                  <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span className="truncate text-[13px] font-semibold">{item.title}</span>
                    <span className="font-mono text-[12px] text-muted">
                      {home.resume
                        ? `${formatClock(at, false)} / ${durationLabel(item.durationSecs)}`
                        : durationLabel(item.durationSecs)}
                    </span>
                  </span>
                  <button
                    type="button"
                    aria-label={t('actionsFor', { title: item.title })}
                    onClick={() => actionsSheet.open(item)}
                    className="-mr-2 grid h-9 w-9 shrink-0 place-items-center text-muted"
                  >
                    <Icon name="more_vert" size={20} />
                  </button>
                </span>
              </li>
            );
          })}
        </ul>
      </section>
      {actionsSheet.sheet}
    </div>
  );
}

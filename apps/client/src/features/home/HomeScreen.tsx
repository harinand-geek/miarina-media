import { useEffect, useState } from 'react';
import { PlannedBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { openSection, playFrom } from '../../app/navigation';
import { qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { recentPlays } from '../player/recentPlays';
import { savedPosition } from '../player/usePlayback';
import { LinkIssueNote } from './LinkIssueNote';
import { linkFieldBorder, useLinkInput } from './useLinkInput';

interface QuickAction {
  icon: string;
  title: string;
  detail: string;
  planned?: boolean;
  run?: () => void;
}

/** "MP4 · 1080p · 410 MB" for the recent list. */
function recentMeta(m: MediaRecord) {
  const ext = m.path.split('.').pop()?.toUpperCase();
  const quality = qualityLabel(m);
  return [ext, quality !== ext ? quality : null, m.sizeBytes ? formatBytes(m.sizeBytes) : null]
    .filter(Boolean)
    .join(' · ');
}

interface ContinueItem {
  media: MediaRecord;
  position: number;
}

const CONTINUE_MAX = 3;

/** Unfinished media the user played last (resume position still saved). */
function useContinueItems() {
  const [items, setItems] = useState<ContinueItem[]>([]);
  // The library changes when files are added, removed or retagged.
  const version = useLibrary((s) => s.recent);
  useEffect(() => {
    let alive = true;
    const ids = recentPlays()
      .filter((id) => savedPosition(id) > 0)
      .slice(0, CONTINUE_MAX * 2);
    void Promise.all(ids.map((id) => backend.libraryGet(id).catch(() => null))).then((found) => {
      if (!alive) return;
      setItems(
        found
          .filter((m): m is MediaRecord => !!m && !m.missing)
          .slice(0, CONTINUE_MAX)
          .map((media) => ({ media, position: savedPosition(media.id) })),
      );
    });
    return () => {
      alive = false;
    };
  }, [version]);
  return items;
}

/** Windows v2 screen 1: from link to library. */
export function HomeScreen() {
  const t = useT();
  const { url, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();
  const [dragging, setDragging] = useState(false);
  const go = useUi((s) => s.go);
  const recent = useLibrary((s) => s.recent);
  const resume = useContinueItems();

  const quick: QuickAction[] = [
    {
      icon: 'music_note',
      title: t('qAudio'),
      detail: t('qAudioDesc'),
      run: () => void submit(url, 'audio'),
    },
    { icon: 'playlist_play', title: t('qPlaylist'), detail: t('qPlaylistDesc'), planned: true },
    { icon: 'stacks', title: t('qBatch'), detail: t('qBatchDesc'), planned: true },
    { icon: 'hub', title: t('qTorrent'), detail: t('qTorrentDesc'), run: () => go('torrents') },
  ];

  return (
    <div
      className="flex flex-1 flex-col gap-8 overflow-auto px-12 py-9"
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
        <h1 className="m-0 text-[28px] font-extrabold leading-[34px] tracking-[-0.02em]">
          {t('homeTitle')}
        </h1>
        <p className="m-0 text-[14px] text-muted">{t('homeSub')}</p>
      </div>

      <section
        aria-label={t('linkLabel')}
        className={`flex flex-col gap-3 rounded-xl border bg-surface p-5 transition-colors duration-150 ${
          dragging ? 'border-accent' : 'border-line'
        }`}
      >
        <form
          className="flex gap-2.5"
          onSubmit={(e) => {
            e.preventDefault();
            void submit();
          }}
        >
          <div
            className={`flex h-12 flex-1 items-center gap-2.5 rounded-md border bg-bg pl-3.5 pr-[9px] transition-[border-color,box-shadow] duration-150 focus-within:shadow-[0_0_0_3px_rgba(53,201,189,.16)] ${linkFieldBorder(issue)}`}
          >
            <Icon name="link" className={issue?.tone === 'warn' ? 'text-warn' : 'text-muted'} />
            <input
              ref={inputRef}
              value={url}
              onChange={(e) => change(e.target.value)}
              placeholder="https://"
              aria-label={t('linkLabel')}
              aria-invalid={issue?.tone === 'warn'}
              aria-describedby={issue ? 'link-error' : undefined}
              spellCheck={false}
              autoComplete="off"
              className="h-full min-w-0 flex-1 bg-transparent font-mono text-[14px] font-medium text-fg outline-none focus-visible:outline-none"
            />
            <button
              type="button"
              onClick={paste}
              className="flex h-[30px] items-center gap-1.5 rounded-sm border border-line-strong bg-surface2 px-2.5 text-[12.5px] font-semibold text-fg hover:bg-secondary-hover"
            >
              <Icon name="content_paste" size={16} />
              {t('pasteShort')}
            </button>
          </div>
          <button
            type="submit"
            className="flex h-12 items-center gap-2 rounded-md bg-accent px-[22px] text-[14px] font-bold text-accent-ink hover:bg-accent-hover active:bg-accent-press"
          >
            {t('analyze')}
            <Icon name="arrow_forward" size={18} />
          </button>
        </form>
        {issue && <LinkIssueNote id="link-error" issue={issue} onFix={applyFix} />}
        <div className="flex flex-wrap gap-[18px] text-[12.5px] text-muted">
          <span className="flex items-center gap-1.5">
            <kbd className="rounded-xs border border-line-strong px-1.5 py-px font-mono text-[11px] font-medium">
              Ctrl V
            </kbd>
            {t('hintPaste')}
          </span>
          <span className="flex items-center gap-1.5">
            <Icon name="drag_pan" size={16} />
            {dragging ? t('hintDropping') : t('hintDrop')}
          </span>
          <span className="flex items-center gap-1.5">
            <Icon name="extension" size={16} />
            {t('hintExt')}
          </span>
        </div>
      </section>

      <div className="grid grid-cols-4 gap-3.5 max-[1100px]:grid-cols-2">
        {quick.map((q) => (
          <button
            key={q.icon}
            type="button"
            disabled={q.planned}
            onClick={q.run}
            className="relative flex items-center gap-3.5 rounded-[10px] border border-line bg-surface p-4 text-left text-fg enabled:hover:bg-surface2 disabled:cursor-default"
          >
            <span
              className={`grid h-10 w-10 shrink-0 place-items-center rounded-lg ${
                q.planned ? 'bg-surface2 text-faint' : 'bg-accent-subtle text-chip-text'
              }`}
            >
              <Icon name={q.icon} />
            </span>
            <span className="flex min-w-0 flex-col gap-0.5">
              <span className={`text-[14px] font-bold ${q.planned ? 'text-muted' : ''}`}>
                {q.title}
              </span>
              <span className="text-[12.5px] text-muted">{q.detail}</span>
            </span>
            {q.planned && (
              <span className="absolute right-2.5 top-2.5" title={t('plannedHint')}>
                <PlannedBadge label={t('planned')} />
              </span>
            )}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-[minmax(0,1.25fr)_minmax(0,1fr)] gap-7 max-[1100px]:grid-cols-1">
        <section aria-labelledby="home-continue" className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h2 id="home-continue" className="m-0 text-[16px] font-bold">
              {t('continueTitle')}
            </h2>
            <button
              type="button"
              onClick={() => openSection('library')}
              className="text-[13px] font-semibold text-accent-strong hover:text-accent-hover"
            >
              {t('seeLibrary')}
            </button>
          </div>
          {resume.length === 0 ? (
            <p className="m-0 text-[13px] text-muted">{t('continueEmpty')}</p>
          ) : (
            <div className="grid grid-cols-3 gap-3.5">
              {resume.map(({ media, position }) => (
                <ContinueCard key={media.id} media={media} position={position} />
              ))}
            </div>
          )}
        </section>

        <section aria-labelledby="home-recent" className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h2 id="home-recent" className="m-0 text-[16px] font-bold">
              {t('recentTitle')}
            </h2>
            <button
              type="button"
              onClick={() => go('history')}
              className="text-[13px] font-semibold text-accent-strong hover:text-accent-hover"
            >
              {t('history')}
            </button>
          </div>
          {recent.length === 0 ? (
            <p className="m-0 text-[13px] text-muted">{t('homeEmpty')}</p>
          ) : (
            <ul className="m-0 list-none overflow-hidden rounded-[10px] border border-line p-0">
              {recent.map((item) => (
                <li
                  key={item.id}
                  className="flex h-14 items-center gap-3 border-b border-line bg-surface px-3.5 last:border-b-0"
                >
                  <Icon
                    name={item.kind === 'video' ? 'movie' : 'music_note'}
                    className={item.kind === 'video' ? 'text-muted' : 'text-audio'}
                  />
                  <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span className="truncate text-[13px] font-bold">{item.title}</span>
                    <span className="truncate font-mono text-[11.5px] text-muted">
                      {recentMeta(item)}
                    </span>
                  </div>
                  <button
                    type="button"
                    aria-label={t('playTitle', { title: item.title })}
                    onClick={() => playFrom(item)}
                    className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-coral-subtle text-coral-strong hover:bg-coral hover:text-coral-ink"
                  >
                    <Icon name="play_arrow" fill />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}

function ContinueCard({ media, position }: { media: MediaRecord; position: number }) {
  const t = useT();
  const duration = media.durationSecs ?? 0;
  const percent = duration ? Math.min(100, (position / duration) * 100) : 0;
  const meta =
    media.kind === 'video' && duration
      ? t('minutesLeft', { n: Math.max(1, Math.round((duration - position) / 60)) })
      : (media.artist ?? media.sourceHost ?? '');
  return (
    <button
      type="button"
      onClick={() => playFrom(media)}
      aria-label={t('playTitle', { title: media.title })}
      className="group flex min-w-0 flex-col gap-2 text-left"
    >
      <MediaThumb
        media={media}
        className="relative aspect-video w-full rounded-lg border border-line"
      >
        <span className="absolute bottom-2.5 right-2 grid h-8 w-8 place-items-center rounded-full bg-coral text-coral-ink group-hover:bg-coral-hover">
          <Icon name="play_arrow" fill />
        </span>
        <span className="absolute inset-x-0 bottom-0 h-[3px] bg-black/30" aria-hidden="true">
          <span className="block h-full bg-coral" style={{ width: `${percent}%` }} />
        </span>
      </MediaThumb>
      <span className="truncate text-[13px] font-bold">{media.title}</span>
      <span className="-mt-1.5 truncate text-[12px] text-muted">{meta}</span>
    </button>
  );
}

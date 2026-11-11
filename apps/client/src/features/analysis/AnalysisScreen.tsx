import { useState, type ReactNode } from 'react';
import { DelayedSkeletons, Skeleton, ThumbBadge } from '../../components/Feedback';
import { LocalThumb } from '../../components/LocalThumb';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { useT, type MessageKey } from '../../i18n';
import type { FormatGroup, MediaFormat, MediaInfo } from '../../services/types';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { ComponentsPrompt } from './ComponentsPrompt';
import { NoMediaFound } from './NoMediaFound';
import { defaultFormat, useAnalysis, useStartActions } from './useAnalysis';

const GROUPS: FormatGroup[] = ['video', 'audio', 'subtitles'];

const TABS: { id: FormatGroup; label: MessageKey; icon: string }[] = [
  { id: 'video', label: 'fmtVideo', icon: 'movie' },
  { id: 'audio', label: 'qAudio', icon: 'music_note' },
  { id: 'subtitles', label: 'fmtSubs', icon: 'closed_caption' },
];

const EMPTY: Record<FormatGroup, MessageKey> = {
  video: 'noVideoFormats',
  audio: 'noAudioFormats',
  subtitles: 'noSubsFormats',
};

/** Windows v2 screen 2: formats of the pasted link. */
export function AnalysisScreen() {
  const url = useUi((s) => s.pendingUrl);
  const go = useUi((s) => s.go);
  const openInBrowser = useUi((s) => s.openInBrowser);
  const { state, retry } = useAnalysis(url);

  if (state.status === 'ready') return <AnalysisResult info={state.info} />;
  return (
    <Scroll>
      {state.status === 'loading' && <AnalysisSkeleton />}
      {state.status === 'no_media' && (
        <NoMediaFound
          onRetry={retry}
          onOpenBrowser={() => openInBrowser(url)}
          reason={state.message}
        />
      )}
      {state.status === 'needs_components' && (
        <ComponentsPrompt
          components={state.components}
          onInstalled={retry}
          onDismiss={() => go('home')}
        />
      )}
    </Scroll>
  );
}

/** Scrolling area with the Back link (the action bar stays below it). */
function Scroll({ children }: { children: ReactNode }) {
  const t = useT();
  const go = useUi((s) => s.go);
  return (
    <div className="flex min-h-0 flex-1 flex-col gap-5 overflow-auto px-12 pb-6 pt-6">
      <button
        type="button"
        onClick={() => go('home')}
        className="flex items-center gap-1.5 self-start text-[13px] font-semibold text-muted hover:text-fg"
      >
        <Icon name="arrow_back" size={18} />
        {t('back')}
      </button>
      {children}
    </div>
  );
}

function AnalysisSkeleton() {
  const t = useT();
  return (
    <div className="flex flex-col gap-5" aria-busy="true">
      <div className="flex items-center gap-5">
        <DelayedSkeletons>
          <Skeleton className="aspect-video w-56 shrink-0 rounded-lg" />
        </DelayedSkeletons>
        <div className="flex flex-1 flex-col gap-2.5">
          <DelayedSkeletons>
            <Skeleton className="h-6 w-[50%]" />
          </DelayedSkeletons>
          <div className="flex items-center gap-2.5 text-[13px] text-muted">
            <ProgressBar value={null} height={3} label={t('stAnalyzing')} className="w-[120px]" />
            {t('stAnalyzing')}
          </div>
        </div>
      </div>
      <div className="flex max-w-[880px] flex-col gap-2">
        <DelayedSkeletons>
          <Skeleton className="h-14 rounded-lg" />
          <Skeleton className="h-14 rounded-lg" />
          <Skeleton className="h-14 rounded-lg" />
        </DelayedSkeletons>
      </div>
    </div>
  );
}

const heightOf = (f: MediaFormat) => Number.parseInt(f.quality, 10) || 0;

/** Chips under the title, from what the source really offers. */
function chipsOf(info: MediaInfo, t: ReturnType<typeof useT>) {
  const chips: { icon: string; label: string }[] = [];
  const best = Math.max(0, ...info.formats.video.map(heightOf));
  if (best > 0)
    chips.push({ icon: 'high_quality', label: t('upTo', { q: best >= 2160 ? '4K' : `${best}p` }) });
  const subs = info.formats.subtitles.length;
  if (subs > 0)
    chips.push({
      icon: 'closed_caption',
      label: subs === 1 ? t('subsOne') : t('subsCount', { n: subs }),
    });
  return chips;
}

function AnalysisResult({ info }: { info: MediaInfo }) {
  const t = useT();
  const requestedTab = useUi((s) => s.analysisTab);
  const setTab = useUi((s) => s.setAnalysisTab);
  const go = useUi((s) => s.go);
  const downloadDir = useSettings((s) => s.downloadDir);
  const pickDownloadDir = useSettings((s) => s.pickDownloadDir);
  const [selected, setSelected] = useState<Partial<Record<FormatGroup, string>>>({});
  const { download, addToQueue, starting } = useStartActions();

  // A direct audio file only has an "Audio only" format: open that tab.
  const tab = info.formats[requestedTab].length
    ? requestedTab
    : (GROUPS.find((g) => info.formats[g].length) ?? requestedTab);
  const formats = info.formats[tab];
  const format = formats.find((f) => f.id === selected[tab]) ?? defaultFormat(formats);
  const kind = tab === 'audio' ? 'audio' : 'video';
  // Subtitle files need the extractor engine (not part of this slice).
  const canDownload = !!format && tab !== 'subtitles';
  const source = [info.host, info.publisher, info.license].filter(Boolean).join(' · ');
  const note =
    tab === 'subtitles' ? t('subsPlanned') : tab === 'audio' ? t('noteAudio') : t('noteVideo');

  return (
    <>
      <Scroll>
        <div className="flex items-center gap-5">
          <LocalThumb
            path={info.thumbnail}
            kind={kind}
            className="aspect-video w-56 shrink-0 rounded-lg border border-line text-[10.5px]"
          >
            {info.duration && <ThumbBadge position="br">{info.duration}</ThumbBadge>}
          </LocalThumb>
          <div className="flex min-w-0 flex-col gap-2">
            <h1 className="m-0 text-[22px] font-extrabold tracking-[-0.02em]">{info.title}</h1>
            <span className="truncate font-mono text-[12.5px] text-muted">{source}</span>
            {chipsOf(info, t).length > 0 && (
              <div className="flex flex-wrap gap-2">
                {chipsOf(info, t).map((c) => (
                  <span
                    key={c.icon}
                    className="flex h-[26px] items-center gap-1.5 rounded-full border border-line bg-surface2 px-2.5 text-[12px] font-semibold text-muted"
                  >
                    <Icon name={c.icon} size={15} />
                    {c.label}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>

        <div
          role="tablist"
          aria-label={t('formatType')}
          className="flex gap-6 border-b border-line"
        >
          {TABS.map((tb) => {
            const on = tb.id === tab;
            return (
              <button
                key={tb.id}
                type="button"
                role="tab"
                aria-selected={on}
                onClick={() => setTab(tb.id)}
                className={`-mb-px flex h-10 items-center gap-2 border-b-2 text-[13.5px] font-semibold ${
                  on ? 'border-accent text-fg' : 'border-transparent text-muted hover:text-fg'
                }`}
              >
                <Icon name={tb.icon} size={18} />
                {t(tb.label)}
              </button>
            );
          })}
        </div>

        <div className="flex max-w-[880px] flex-col gap-2">
          <div role="radiogroup" aria-label={t('quality')} className="flex flex-col gap-2">
            {formats.length === 0 && (
              <p className="m-0 rounded-lg border border-dashed border-line-strong px-4 py-5 text-[13px] text-muted">
                {t(EMPTY[tab])}
              </p>
            )}
            {formats.map((f) => {
              const on = f.id === format?.id;
              return (
                <button
                  key={f.id}
                  type="button"
                  role="radio"
                  aria-checked={on}
                  onClick={() => setSelected((s) => ({ ...s, [tab]: f.id }))}
                  className={`flex h-14 items-center gap-3.5 rounded-lg border px-4 text-left text-fg ${
                    on
                      ? 'border-accent bg-accent-subtle'
                      : 'border-line bg-surface hover:bg-surface2'
                  }`}
                >
                  <span
                    className={`grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full border-2 ${
                      on ? 'border-accent' : 'border-faint'
                    }`}
                    aria-hidden="true"
                  >
                    {on && <span className="h-2 w-2 rounded-full bg-accent" />}
                  </span>
                  <span className="w-[120px] shrink-0 text-[14px] font-bold">{f.quality}</span>
                  <span className="min-w-0 flex-1 truncate font-mono text-[12.5px] text-muted">
                    {f.detail}
                  </span>
                  {f.tag && (
                    <span className="rounded-xs bg-accent-subtle px-2 py-[3px] text-[11px] font-bold text-chip-text">
                      {f.tag === 'Recommended' ? t('tagRecommended') : t('tagBest')}
                    </span>
                  )}
                  <span className="w-[84px] shrink-0 text-right font-mono text-[12.5px] text-muted">
                    {f.size}
                  </span>
                </button>
              );
            })}
          </div>
          <span className="pt-1 text-[12px] text-muted">{note}</span>
          {info.notice && <span className="text-[12px] text-warn">{info.notice}</span>}
        </div>
      </Scroll>

      <div className="flex h-[68px] shrink-0 items-center gap-3 border-t border-line bg-sidebar px-12">
        <Icon name="folder" className="text-muted" />
        <span className="min-w-0 truncate font-mono text-[12.5px] text-muted" title={downloadDir}>
          {downloadDir}
        </span>
        <button
          type="button"
          onClick={pickDownloadDir}
          className="shrink-0 text-[13px] font-semibold text-accent-strong hover:text-accent-hover"
        >
          {t('change')}
        </button>
        <div className="flex-1" />
        <button
          type="button"
          disabled={!canDownload || starting}
          onClick={() => format && addToQueue(info, format, kind)}
          className="h-10 shrink-0 rounded-sm border border-line-strong bg-surface2 px-4 text-[13.5px] font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50"
        >
          {t('addToQueue')}
        </button>
        <button
          type="button"
          disabled={!canDownload || starting}
          aria-busy={starting}
          onClick={async () => {
            if (format && (await download(info, format, kind))) go('downloads');
          }}
          className="flex h-10 shrink-0 items-center gap-2 rounded-sm bg-accent px-5 text-[13.5px] font-bold text-accent-ink enabled:hover:bg-accent-hover disabled:opacity-50"
        >
          <Icon name="download" size={18} />
          {starting
            ? t('stStarting')
            : format && format.size && format.size !== '—'
              ? t('downloadSize', { size: format.size })
              : t('downloadVerb')}
        </button>
      </div>
    </>
  );
}

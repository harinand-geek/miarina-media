import { useState } from 'react';
import { Button } from '../../components/Button';
import { Tabs, RadioDot } from '../../components/Controls';
import { DelayedSkeletons, Skeleton, ThumbBadge } from '../../components/Feedback';
import { LocalThumb } from '../../components/LocalThumb';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import type { FormatGroup, MediaInfo } from '../../services/types';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { ComponentsPrompt } from './ComponentsPrompt';
import { NoMediaFound } from './NoMediaFound';
import { defaultFormat, downloadTitle, useAnalysis, useStartActions } from './useAnalysis';

const GROUPS: FormatGroup[] = ['video', 'audio', 'subtitles'];
const GROUP_NAMES: Record<FormatGroup, string> = {
  video: 'video',
  audio: 'audio-only',
  subtitles: 'subtitle',
};

export function AnalysisScreen() {
  const url = useUi((s) => s.pendingUrl);
  const go = useUi((s) => s.go);
  const { state, retry } = useAnalysis(url);

  return (
    <div className="flex flex-1 flex-col gap-5 overflow-auto px-10 pt-6">
      <button
        type="button"
        onClick={() => go('home')}
        className="flex items-center gap-1.5 self-start text-[13px] font-semibold text-muted hover:text-fg"
      >
        <Icon name="arrow_back" size={18} />
        Home
      </button>
      {state.status === 'loading' && <AnalysisSkeleton />}
      {state.status === 'no_media' && <NoMediaFound onRetry={retry} reason={state.message} />}
      {state.status === 'needs_components' && (
        <ComponentsPrompt
          components={state.components}
          onInstalled={retry}
          onDismiss={() => go('home')}
        />
      )}
      {state.status === 'ready' && <AnalysisResult info={state.info} />}
    </div>
  );
}

function AnalysisSkeleton() {
  return (
    <div className="grid grid-cols-[400px_minmax(0,1fr)] gap-8" aria-busy="true">
      <DelayedSkeletons>
        <div className="flex flex-col gap-3.5">
          <Skeleton className="aspect-video rounded-lg" />
          <Skeleton className="h-3 w-[70%]" />
          <Skeleton className="h-3 w-1/2" />
        </div>
      </DelayedSkeletons>
      <div className="flex flex-col gap-3.5">
        <DelayedSkeletons>
          <Skeleton className="h-6 w-[60%]" />
        </DelayedSkeletons>
        <div className="flex items-center gap-2.5 text-[13px] text-muted">
          <ProgressBar
            value={null}
            height={3}
            label="Reading available formats"
            className="w-[120px]"
          />
          Reading available formats…
        </div>
        <DelayedSkeletons>
          <Skeleton className="h-14 rounded-md" />
          <Skeleton className="h-14 rounded-md" />
          <Skeleton className="h-14 rounded-md" />
        </DelayedSkeletons>
      </div>
    </div>
  );
}

function AnalysisResult({ info }: { info: MediaInfo }) {
  const requestedTab = useUi((s) => s.analysisTab);
  const setTab = useUi((s) => s.setAnalysisTab);
  const go = useUi((s) => s.go);
  const downloadDir = useSettings((s) => s.downloadDir);
  const pickDownloadDir = useSettings((s) => s.pickDownloadDir);
  const [selected, setSelected] = useState<Partial<Record<FormatGroup, string>>>({});
  const { download, addToQueue } = useStartActions();

  // A direct audio file only has an "Audio only" format: open that tab.
  const tab = info.formats[requestedTab].length
    ? requestedTab
    : (GROUPS.find((g) => info.formats[g].length) ?? requestedTab);
  const formats = info.formats[tab];
  const format = formats.find((f) => f.id === selected[tab]) ?? defaultFormat(formats);
  const kind = tab === 'audio' ? 'audio' : 'video';
  // Subtitle files need the extractor engine (not part of this slice).
  const canDownload = !!format && tab !== 'subtitles';

  return (
    <div className="grid grid-cols-[400px_minmax(0,1fr)] gap-8 pb-6 max-[1100px]:grid-cols-[320px_minmax(0,1fr)]">
      <div className="flex flex-col gap-[18px]">
        <LocalThumb
          path={info.thumbnail}
          kind={kind}
          className="aspect-video rounded-lg text-[11px]"
          label="No preview from this source"
        >
          {info.duration && <ThumbBadge position="br">{info.duration}</ThumbBadge>}
        </LocalThumb>
        <dl className="m-0 grid grid-cols-[100px_1fr] gap-y-2.5 text-[13px]">
          <dt className="text-muted">Source</dt>
          <dd className="m-0">{info.host}</dd>
          <dt className="text-muted">Published by</dt>
          <dd className="m-0">{info.publisher}</dd>
          <dt className="text-muted">Duration</dt>
          <dd className="m-0">{info.duration ?? '—'}</dd>
          {info.released && (
            <>
              <dt className="text-muted">Released</dt>
              <dd className="m-0">{info.released}</dd>
            </>
          )}
          {info.license && (
            <>
              <dt className="text-muted">License</dt>
              <dd className="m-0">{info.license}</dd>
            </>
          )}
        </dl>
      </div>

      <div className="flex min-w-0 flex-col gap-[18px]">
        <div className="flex flex-col gap-1.5">
          <h1 className="m-0 text-title-lg font-bold tracking-[-0.02em]">{info.title}</h1>
          <span className="text-[13px] text-muted">{info.subtitle}</span>
        </div>
        <Tabs
          label="Format type"
          value={tab}
          onChange={setTab}
          options={[
            { value: 'video', label: 'Video' },
            { value: 'audio', label: 'Audio only' },
            { value: 'subtitles', label: 'Subtitles' },
          ]}
        />
        <div role="radiogroup" aria-label="Quality" className="flex flex-col gap-1.5">
          {formats.length === 0 && (
            <p className="m-0 rounded-md border border-dashed border-line-strong px-4 py-5 text-[13px] text-muted">
              This source has no {GROUP_NAMES[tab]} formats.
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
                className={`flex h-[52px] items-center gap-3.5 rounded-md border px-4 text-left ${
                  on
                    ? 'border-accent bg-selected'
                    : 'border-surface2 bg-surface hover:bg-card-hover'
                }`}
              >
                <RadioDot checked={on} />
                <span className="w-[130px] text-[14px] font-bold">{f.quality}</span>
                <span className="flex-1 text-[13px] text-muted">{f.detail}</span>
                {f.tag && (
                  <span className="rounded-xs bg-accent-subtle px-2 py-[3px] text-[11.5px] font-semibold text-chip-text">
                    {f.tag}
                  </span>
                )}
                <span className="w-20 text-right font-mono text-[13px] font-medium">{f.size}</span>
              </button>
            );
          })}
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="flex flex-col gap-1.5">
            <span className="text-[12px] font-semibold text-muted">Save to</span>
            <div className="flex h-10 items-center gap-2 rounded-sm border border-line-strong bg-bg px-3 font-mono text-[12.5px]">
              <Icon name="folder" size={18} className="text-muted" />
              <span className="flex-1 truncate" title={downloadDir}>
                {downloadDir}
              </span>
              <button
                type="button"
                onClick={pickDownloadDir}
                className="font-sans text-[12.5px] font-semibold text-accent-strong"
              >
                Change
              </button>
            </div>
          </div>
          <div className="flex flex-col gap-1.5">
            <span className="text-[12px] font-semibold text-muted">File name</span>
            <div
              className="flex h-10 items-center truncate rounded-sm border border-line-strong bg-bg px-3 font-mono text-[12.5px]"
              title="Unsafe characters are replaced and an existing file is never overwritten."
            >
              {format ? `${downloadTitle(info, format)}.${format.extension}` : '—'}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2.5 border-t border-surface2 pt-[18px]">
          <span className="flex-1 text-[13px] text-muted">
            {tab === 'subtitles' ? (
              'Subtitle downloads arrive with the extractor engine.'
            ) : format ? (
              <>
                Selected:{' '}
                <span className="font-semibold text-fg">
                  {format.quality} · {format.size}
                </span>
              </>
            ) : null}
          </span>
          <Button disabled={!canDownload} onClick={() => format && addToQueue(info, format, kind)}>
            Add to queue
          </Button>
          <Button
            variant="primary"
            icon="download"
            className="px-5"
            disabled={!canDownload}
            onClick={async () => {
              if (format && (await download(info, format, kind))) go('downloads');
            }}
          >
            Download
          </Button>
        </div>
      </div>
    </div>
  );
}

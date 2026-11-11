import { useState } from 'react';
import { Button } from '../../components/Button';
import { RadioDot } from '../../components/Controls';
import { DelayedSkeletons, Skeleton } from '../../components/Feedback';
import { LocalThumb } from '../../components/LocalThumb';
import { Icon } from '../../components/Icon';
import { BottomSheet } from '../../components/Overlay';
import { useT } from '../../i18n';
import type { MediaInfo } from '../../services/types';
import { useUi } from '../../stores/ui';
import { ComponentsPrompt } from './ComponentsPrompt';
import { NoMediaFound } from './NoMediaFound';
import { defaultFormat, useAnalysis, useStartActions } from './useAnalysis';
import { useAndroidStorage } from '../settings/useAndroidStorage';

interface AnalysisSheetProps {
  onOpenStorage: () => void;
  onStarted: () => void;
}

/** Android: analysis opens as a bottom sheet, never a full page. */
export function AnalysisSheet({ onOpenStorage, onStarted }: AnalysisSheetProps) {
  const t = useT();
  const open = useUi((s) => s.screen === 'analysis');
  const url = useUi((s) => s.pendingUrl);
  const go = useUi((s) => s.go);
  const { state, retry } = useAnalysis(url, open);
  const choices = useUi((s) => s.analysisChoices);
  const analyzeChoice = useUi((s) => s.analyzeChoice);

  return (
    <BottomSheet open={open} onClose={() => go('home')} label={t('analyzeLink')} elevated>
      {choices.length > 1 && (
        // Design M3: the other media of the browser page.
        <div
          role="radiogroup"
          aria-label={t('mediaOnPage')}
          className="-mx-4 flex gap-2 overflow-x-auto px-4"
        >
          {choices.map((c) => {
            const on = c.url === url;
            return (
              <button
                key={c.url}
                type="button"
                role="radio"
                aria-checked={on}
                onClick={() => analyzeChoice(c.url)}
                className={`flex h-8 max-w-[220px] shrink-0 items-center gap-1.5 rounded-2xl border px-3 text-[12.5px] font-semibold ${
                  on
                    ? 'border-chip-border bg-accent-subtle text-chip-text'
                    : 'border-line-strong text-muted'
                }`}
              >
                <Icon name={c.kind === 'audio' ? 'music_note' : 'movie'} size={16} />
                <span className="truncate">{c.label}</span>
              </button>
            );
          })}
        </div>
      )}
      {state.status === 'loading' && (
        <div className="flex flex-col gap-3 pb-6 pt-2" aria-busy="true">
          <DelayedSkeletons>
            <Skeleton className="aspect-video rounded-[12px]" />
            <Skeleton className="h-4 w-[70%]" />
          </DelayedSkeletons>
          <span className="text-[13px] text-muted">{t('stAnalyzing')}</span>
        </div>
      )}
      {state.status === 'no_media' && <NoMediaFound onRetry={retry} reason={state.message} />}
      {state.status === 'needs_components' && (
        <ComponentsPrompt
          components={state.components}
          onInstalled={retry}
          onDismiss={() => go('home')}
        />
      )}
      {state.status === 'ready' && (
        <SheetContent
          info={state.info}
          onOpenStorage={onOpenStorage}
          onStarted={() => {
            go('home');
            onStarted();
          }}
        />
      )}
    </BottomSheet>
  );
}

function SheetContent({
  info,
  onOpenStorage,
  onStarted,
}: {
  info: MediaInfo;
  onOpenStorage: () => void;
  onStarted: () => void;
}) {
  const t = useT();
  const requestedTab = useUi((s) => (s.analysisTab === 'audio' ? 'audio' : 'video'));
  // A direct audio file only has an "Audio only" format: open that tab.
  const initialTab =
    info.formats[requestedTab].length || !info.formats.audio.length ? requestedTab : 'audio';
  const [tab, setTab] = useState<'video' | 'audio'>(initialTab);
  const [selected, setSelected] = useState<Partial<Record<'video' | 'audio', string>>>({});
  const storage = useAndroidStorage(tab);
  const { download, addToQueue, starting } = useStartActions();

  const formats = info.formats[tab];
  const format = formats.find((f) => f.id === selected[tab]) ?? defaultFormat(formats);
  const tabs = [
    { id: 'video', label: t('fmtVideo') },
    { id: 'audio', label: t('qAudio') },
    { id: 'subtitles', label: t('fmtSubs') },
  ] as const;

  return (
    <>
      <div className="flex items-center gap-3">
        <LocalThumb
          path={info.thumbnail}
          kind={tab === 'audio' ? 'audio' : 'video'}
          className="h-[54px] w-24 rounded-md"
          label=""
        />
        <div className="flex min-w-0 flex-col gap-[3px]">
          <span className="text-[16px] font-extrabold [overflow-wrap:anywhere]">{info.title}</span>
          <span className="font-mono text-[12px] text-muted">
            {[info.host, info.duration].filter(Boolean).join(' · ')}
          </span>
          {info.license && <span className="text-[12px] text-muted">{info.license}</span>}
        </div>
      </div>
      <div
        role="radiogroup"
        aria-label={t('formatType')}
        className="flex rounded-[20px] border border-line bg-bg p-[3px]"
      >
        {tabs.map((x) => {
          // Subtitle download (DL-08) is not available yet.
          const planned = x.id === 'subtitles';
          const on = x.id === tab;
          return (
            <button
              key={x.id}
              type="button"
              role="radio"
              aria-checked={on}
              disabled={planned}
              title={planned ? t('subsPlanned') : undefined}
              onClick={() => x.id !== 'subtitles' && setTab(x.id)}
              className={`h-9 flex-1 rounded-[17px] text-[13px] disabled:opacity-45 ${
                on ? 'bg-line-strong font-bold text-fg' : 'font-semibold text-muted'
              }`}
            >
              {x.label}
            </button>
          );
        })}
      </div>
      <div role="radiogroup" aria-label={t('quality')} className="flex flex-col gap-2">
        {formats.length === 0 && (
          <p className="m-0 rounded-xl border border-dashed border-line-strong px-4 py-5 text-[13px] text-muted">
            {tab === 'audio' ? t('noAudioFormats') : t('noVideoFormats')}
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
              className={`flex min-h-[60px] items-center gap-3 rounded-xl border px-3.5 text-left ${on ? 'border-accent bg-selected' : 'border-line bg-surface'}`}
            >
              <RadioDot checked={on} size={20} />
              <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                <span className="flex items-center gap-2 text-[14.5px] font-bold">
                  {f.quality}
                  {f.tag && (
                    <span className="rounded-xs bg-accent-subtle px-1.5 py-0.5 text-[10.5px] font-bold text-chip-text">
                      {f.tag === 'Recommended' ? t('tagRecommended') : t('tagBest')}
                    </span>
                  )}
                </span>
                <span className="truncate font-mono text-[12px] text-muted">{f.detail}</span>
              </span>
              <span className={`font-mono text-[13px] ${on ? 'text-fg' : 'text-muted'}`}>
                {f.size}
              </span>
            </button>
          );
        })}
      </div>
      <button
        type="button"
        onClick={storage.canChange ? onOpenStorage : undefined}
        disabled={!storage.canChange}
        className="flex min-h-12 items-center gap-2.5 py-1 text-left text-[13px]"
      >
        <Icon name={storage.icon} size={20} className="text-muted" />
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="text-[12px] text-muted">{t('saveTo')}</span>
          <span className="truncate font-mono text-[12.5px]">{storage.label}</span>
        </span>
        {storage.canChange && <span className="font-bold text-chip-text">{t('change')}</span>}
      </button>
      <div className="flex gap-2.5">
        <Button
          pill
          className="h-[52px] px-[18px] text-[14px]"
          disabled={!format || starting}
          onClick={async () => {
            if (format) await addToQueue(info, format, tab);
          }}
        >
          {t('toQueue')}
        </Button>
        <Button
          variant="primary"
          pill
          className="h-[52px] flex-1 gap-2 text-[15px] font-extrabold"
          disabled={!format || starting}
          aria-busy={starting}
          onClick={async () => {
            if (format && (await download(info, format, tab))) onStarted();
          }}
        >
          <Icon name="download" size={22} />
          {starting
            ? t('stStarting')
            : format
              ? t('downloadSize', { size: format.size })
              : t('downloadVerb')}
        </Button>
      </div>
    </>
  );
}

import { useState } from 'react';
import { Button } from '../../components/Button';
import { RadioDot, Segmented } from '../../components/Controls';
import { DelayedSkeletons, Skeleton } from '../../components/Feedback';
import { LocalThumb } from '../../components/LocalThumb';
import { Icon } from '../../components/Icon';
import { BottomSheet } from '../../components/Overlay';
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
  const open = useUi((s) => s.screen === 'analysis');
  const url = useUi((s) => s.pendingUrl);
  const go = useUi((s) => s.go);
  const { state, retry } = useAnalysis(url, open);

  return (
    <BottomSheet open={open} onClose={() => go('home')} label="Analyze link">
      {state.status === 'loading' && (
        <div className="flex flex-col gap-3 pb-6 pt-2" aria-busy="true">
          <DelayedSkeletons>
            <Skeleton className="aspect-video rounded-[12px]" />
            <Skeleton className="h-4 w-[70%]" />
          </DelayedSkeletons>
          <span className="text-[13px] text-muted">Reading available formats…</span>
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
  const requestedTab = useUi((s) => (s.analysisTab === 'audio' ? 'audio' : 'video'));
  // A direct audio file only has an "Audio only" format: open that tab.
  const initialTab =
    info.formats[requestedTab].length || !info.formats.audio.length ? requestedTab : 'audio';
  const [tab, setTab] = useState<'video' | 'audio'>(initialTab);
  const [selected, setSelected] = useState<Partial<Record<'video' | 'audio', string>>>({});
  const storage = useAndroidStorage(tab);
  const { download } = useStartActions();

  const formats = info.formats[tab];
  const format = formats.find((f) => f.id === selected[tab]) ?? defaultFormat(formats);

  return (
    <>
      <div className="flex gap-3">
        <LocalThumb
          path={info.thumbnail}
          kind={tab === 'audio' ? 'audio' : 'video'}
          className="h-[68px] w-[120px] rounded-[10px]"
          label=""
        />
        <div className="flex min-w-0 flex-col gap-[3px]">
          <span className="text-[16px] font-bold">{info.title}</span>
          <span className="text-[12.5px] text-muted">
            {info.host} · {info.duration}
          </span>
          {info.license && <span className="text-[12.5px] text-muted">{info.license}</span>}
        </div>
      </div>
      <Segmented
        label="Format type"
        variant="mobile-sunken"
        value={tab}
        onChange={setTab}
        options={[
          { value: 'video', label: 'Video' },
          { value: 'audio', label: 'Audio only' },
        ]}
      />
      <div role="radiogroup" aria-label="Quality" className="flex flex-col gap-1.5">
        {formats.length === 0 && (
          <p className="m-0 rounded-[12px] border border-dashed border-line-strong px-4 py-5 text-[13px] text-muted">
            This source has no {tab === 'audio' ? 'audio-only' : 'video'} formats.
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
              className={`flex min-h-14 items-center gap-3.5 rounded-[12px] border px-3.5 text-left ${on ? 'border-accent bg-selected' : 'border-line bg-bg'}`}
            >
              <RadioDot checked={on} size={20} />
              <span className="flex flex-1 flex-col">
                <span className="text-[14.5px] font-bold">{f.quality}</span>
                <span className="text-[12px] text-muted">{f.detail}</span>
              </span>
              <span className="font-mono text-[13px] font-medium">{f.size}</span>
            </button>
          );
        })}
      </div>
      <button
        type="button"
        onClick={storage.canChange ? onOpenStorage : undefined}
        disabled={!storage.canChange}
        className="flex min-h-14 items-center gap-3 px-1 text-left"
      >
        <Icon name={storage.icon} size={24} className="text-muted" />
        <span className="flex flex-1 flex-col">
          <span className="text-[12px] text-muted">Save to</span>
          <span className="text-[14px] font-semibold">{storage.label}</span>
        </span>
        {storage.canChange && (
          <span className="text-[13px] font-bold text-accent-strong">Change</span>
        )}
      </button>
      <Button
        variant="primary"
        pill
        className="h-[52px] text-[15px]"
        disabled={!format}
        onClick={async () => {
          if (format && (await download(info, format, tab))) onStarted();
        }}
      >
        {format ? `Download · ${format.size}` : 'Download'}
      </Button>
    </>
  );
}

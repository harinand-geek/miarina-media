import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Button } from '../../components/Button';
import { RadioDot, Tabs } from '../../components/Controls';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { ToastHost } from '../../components/ToastHost';
import { backend } from '../../services/backend';
import type { BrowserSnapshot, FormatGroup, MediaFormat, MediaInfo } from '../../services/types';
import { formatBytes, formatSpeed, isRunning, useDownloads } from '../../stores/downloads';
import { useSettings } from '../../stores/settings';
import { ComponentsPrompt } from '../analysis/ComponentsPrompt';
import { defaultFormat, downloadTitle, useAnalysis } from '../analysis/useAnalysis';
import { candidates, hostOf, kindLabel, mainCandidate, type Candidate } from './candidates';
import { useBrowserState } from './useBrowserState';
import { useT, type MessageKey } from '../../i18n';

/** "Saved · Play" stays this long, then the button returns to "found" (design B). */
const DONE_MS = 4000;

/**
 * Transparent layer above the page (designs D1, D2, B): the floating
 * download button, or the format sheet with its scrim.
 */
export function BrowserOverlay() {
  const state = useBrowserState();
  const [started, setStarted] = useState<string[]>([]);
  // Downloads shown by the button belong to the current page.
  const [pageUrl, setPageUrl] = useState('');
  if (state && state.url !== pageUrl) {
    setPageUrl(state.url);
    setStarted([]);
  }
  if (!state || state.startPage) return null;
  const list = candidates(state);
  if (!list.length) return null;

  const onStarted = (ids: string[]) => setStarted((s) => [...s, ...ids]);
  return state.sheet ? (
    <FormatSheet state={state} list={list} onStarted={onStarted} />
  ) : (
    <DownloadFab list={list} started={started} onStarted={onStarted} />
  );
}

// ------------------------------------------------------------ floating button

type FabView =
  { kind: 'found' } | { kind: 'downloading'; percent: number; speed: number } | { kind: 'done' };

/** Button state from the downloads started on this page. */
function useFabView(started: string[]): FabView {
  const tasks = useDownloads((s) => s.tasks);
  const mine = started.map((id) => tasks[id]).filter((t) => t !== undefined);
  const active = mine.filter(
    (t) => isRunning(t) || t.state === 'queued' || t.state === 'waiting' || t.state === 'analyzing',
  );
  const lastDone = Math.max(0, ...mine.map((t) => t.completedAt ?? 0));

  // "Done" shows when a new completion arrives, then hides after 4 s.
  const [seenDone, setSeenDone] = useState(0);
  const [doneVisible, setDoneVisible] = useState(false);
  if (lastDone !== seenDone) {
    setSeenDone(lastDone);
    setDoneVisible(lastDone > 0);
  }
  useEffect(() => {
    if (!doneVisible) return;
    const timer = setTimeout(() => setDoneVisible(false), DONE_MS);
    return () => clearTimeout(timer);
  }, [doneVisible, seenDone]);

  if (active.length) {
    const total = active.reduce((acc, t) => acc + (t.totalBytes ?? 0), 0);
    const done = active.reduce((acc, t) => acc + t.downloadedBytes, 0);
    return {
      kind: 'downloading',
      percent: total ? Math.min(100, (done / total) * 100) : 0,
      speed: active.reduce((acc, t) => acc + t.bytesPerSec, 0),
    };
  }
  return doneVisible ? { kind: 'done' } : { kind: 'found' };
}

function DownloadFab({
  list,
  started,
  onStarted,
}: {
  list: Candidate[];
  started: string[];
  onStarted: (ids: string[]) => void;
}) {
  const t = useT();
  const ref = useRef<HTMLDivElement>(null);
  const view = useFabView(started);
  const [busy, setBusy] = useState(false);

  // The overlay webview is sized to the button: report every size change.
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const report = () => {
      const r = el.getBoundingClientRect();
      void backend.browserFabSize(r.width, r.height);
    };
    report();
    const observer = new ResizeObserver(report);
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const quickDownload = async () => {
    const main = mainCandidate(list);
    if (!main || busy) return;
    setBusy(true);
    const result = await startCandidates([main], null, 'video', true);
    setBusy(false);
    if (result.ok) onStarted(result.ids);
    // Analysis failed or tools are missing: the sheet explains why.
    else void backend.browserSheet(true);
  };

  const pill = 'flex h-[52px] items-center rounded-[26px] text-[14px] font-bold';
  return (
    <div ref={ref} className="inline-flex w-max whitespace-nowrap">
      {view.kind === 'downloading' ? (
        <button
          type="button"
          onClick={() => void backend.browserShowInApp('downloads')}
          aria-label={t('dlPercent', { n: Math.round(view.percent) })}
          className={`${pill} relative gap-2 overflow-hidden bg-bg pl-4 pr-[18px] text-fg`}
        >
          <Icon name="downloading" size={22} />
          {Math.round(view.percent)}% · {formatSpeed(view.speed)}
          <span
            className="absolute bottom-0 left-0 h-[3px] bg-accent"
            style={{ width: `${view.percent}%` }}
          />
        </button>
      ) : view.kind === 'done' ? (
        <button
          type="button"
          onClick={() => void backend.browserShowInApp('library')}
          className={`${pill} gap-2 bg-accent-subtle pl-4 pr-[18px] text-chip-text`}
        >
          <Icon name="check_circle" size={22} />
          {t('savedPlay')}
        </button>
      ) : (
        <div className={`${pill} bg-accent text-accent-ink`}>
          <button
            type="button"
            onClick={() => void quickDownload()}
            disabled={busy}
            title={t('quickDlTitle')}
            className="flex h-full items-center gap-2 rounded-l-[26px] pl-[18px] pr-4 hover:bg-accent-hover"
          >
            <Icon
              name={busy ? 'progress_activity' : 'download'}
              size={22}
              className={busy ? 'animate-spin' : ''}
            />
            {list.length > 1 ? t('downloadCount', { n: list.length }) : t('downloadVerb')}
          </button>
          <span className="h-7 w-px bg-accent-ink/25" />
          <button
            type="button"
            aria-label={t('chooseMedia')}
            title={`${t('chooseMedia')} · Ctrl+Shift+S`}
            onClick={() => void backend.browserSheet(true)}
            className="grid h-full w-11 place-items-center rounded-r-[26px] hover:bg-accent-hover"
          >
            <Icon name="expand_less" />
          </button>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------- downloads

type StartResult = { ok: true; ids: string[] } | { ok: false };

/**
 * Analyzes each candidate and queues it. The first one uses `chosen` when
 * given; the others take the default format of the same group.
 */
async function startCandidates(
  items: Candidate[],
  chosen: { info: MediaInfo; format: MediaFormat } | null,
  group: 'video' | 'audio',
  startNow: boolean,
): Promise<StartResult> {
  const ids: string[] = [];
  for (const [i, item] of items.entries()) {
    let info: MediaInfo;
    let format: MediaFormat | undefined;
    let kind = group;
    if (i === 0 && chosen) {
      ({ info, format } = chosen);
    } else {
      const result = await backend.analyze(item.url).catch(() => null);
      if (!result?.ok) {
        if (i === 0) return { ok: false };
        continue;
      }
      info = result.info;
      format = defaultFormat(info.formats[group]);
      if (!format) {
        // Direct files often have a single group.
        kind = group === 'video' ? 'audio' : 'video';
        format = defaultFormat(info.formats[kind]);
      }
    }
    if (!format) continue;
    const record = await useDownloads.getState().start({
      url: info.url,
      title: downloadTitle(info, format),
      kind,
      engine: info.engine,
      formatId: format.id === 'original' ? null : format.id,
      formatLabel: format.quality,
      extension: format.extension,
      startNow,
    });
    if (record) ids.push(record.id);
  }
  return ids.length ? { ok: true, ids } : { ok: false };
}

// ----------------------------------------------------------------- the sheet

const GROUPS: { value: FormatGroup; label: MessageKey }[] = [
  { value: 'video', label: 'fmtVideo' },
  { value: 'audio', label: 'qAudio' },
  { value: 'subtitles', label: 'fmtSubs' },
];

function FormatSheet({
  state,
  list,
  onStarted,
}: {
  state: BrowserSnapshot;
  list: Candidate[];
  onStarted: (ids: string[]) => void;
}) {
  const t = useT();
  const [checked, setChecked] = useState<string[]>(() => {
    const main = mainCandidate(list);
    return main ? [main.id] : [];
  });
  const selected = list.filter((c) => checked.includes(c.id));
  const primary = selected[0];
  const { state: analysis, retry } = useAnalysis(primary?.url ?? '', !!primary);
  const [tab, setTab] = useState<FormatGroup>('video');
  const [formatId, setFormatId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const downloadDir = useSettings((s) => s.downloadDir);
  const pickDownloadDir = useSettings((s) => s.pickDownloadDir);
  const panel = useRef<HTMLElement>(null);

  useEffect(() => {
    panel.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') void backend.browserSheet(false);
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  const close = () => void backend.browserSheet(false);
  const info = analysis.status === 'ready' ? analysis.info : null;
  // Direct files often only have an audio or a video group: open that one.
  const group =
    info && !info.formats[tab].length
      ? (GROUPS.find((g) => info.formats[g.value].length)?.value ?? tab)
      : tab;
  const formats = info?.formats[group] ?? [];
  const format = formats.find((f) => f.id === formatId) ?? defaultFormat(formats);
  const canStart = !!info && !!format && group !== 'subtitles' && !busy;
  const sizeLabel =
    selected.length === 1 && format?.size && format.size !== '—' ? ` · ${format.size}` : '';

  const toggle = (id: string) => {
    setChecked((c) => (c.includes(id) ? c.filter((x) => x !== id) : [...c, id]));
    setFormatId(null);
  };

  const start = async (startNow: boolean) => {
    if (!info || !format) return;
    setBusy(true);
    const kind = group === 'audio' ? 'audio' : 'video';
    const result = await startCandidates(selected, { info, format }, kind, startNow);
    setBusy(false);
    if (result.ok) {
      onStarted(result.ids);
      close();
    }
  };

  return (
    <div className="fixed inset-0">
      <div className="absolute inset-0 bg-scrim" onClick={close} aria-hidden="true" />
      <section
        ref={panel}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby="sheet-title"
        className="absolute bottom-6 right-6 flex max-h-[min(640px,calc(100%-48px))] w-[440px] flex-col overflow-hidden rounded-xl border border-overlay-border bg-surface2 shadow-dialog outline-none"
      >
        <header className="flex items-start gap-3 pb-3 pl-[18px] pr-3 pt-4">
          <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
            <h2 id="sheet-title" className="m-0 text-[17px] font-bold">
              {t('sheetTitle')}
            </h2>
            <span className="truncate font-mono text-[12px] text-muted">
              {hostOf(state.url)} · {t('mediaFound', { n: list.length })}
            </span>
          </div>
          <button
            type="button"
            aria-label={t('close')}
            onClick={close}
            className="grid size-8 place-items-center rounded-sm text-muted hover:bg-line hover:text-fg"
          >
            <Icon name="close" size={18} />
          </button>
        </header>

        <ul
          aria-label={t('mediaOnPage')}
          className="m-0 flex max-h-[176px] list-none flex-col gap-1.5 overflow-auto px-3 py-0"
        >
          {list.map((c) => {
            const on = checked.includes(c.id);
            return (
              <li key={c.id}>
                <label
                  className={`flex cursor-pointer items-center gap-2.5 rounded-md border px-2.5 py-2 ${
                    on ? 'border-chip-border bg-selected' : 'border-line bg-surface'
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={on}
                    onChange={() => toggle(c.id)}
                    className="size-5 shrink-0 accent-accent"
                  />
                  <span className="grid h-[30px] w-[52px] shrink-0 place-items-center rounded-xs bg-surface text-muted">
                    <Icon
                      name={
                        c.kind === 'audio'
                          ? 'music_note'
                          : c.kind === 'page'
                            ? 'smart_display'
                            : 'movie'
                      }
                      size={16}
                    />
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate text-[13px] font-semibold" title={c.url}>
                      {c.title}
                    </span>
                    <span className="truncate font-mono text-[11.5px] text-muted">
                      {kindLabel(c.kind)} · {c.sizeBytes ? formatBytes(c.sizeBytes) : c.detail}
                    </span>
                  </span>
                </label>
              </li>
            );
          })}
        </ul>

        <div className="mx-[18px] mt-3.5">
          <Tabs
            label={t('formatType')}
            value={group}
            onChange={(g) => {
              setTab(g);
              setFormatId(null);
            }}
            options={GROUPS.map((g) => ({ value: g.value, label: t(g.label) }))}
          />
        </div>
        <div className="flex min-h-[120px] flex-col gap-1 overflow-auto px-3 py-2.5">
          {!primary && <p className="m-0 px-1 py-4 text-[13px] text-muted">{t('selectOne')}</p>}
          {primary && analysis.status === 'loading' && (
            <div className="flex items-center gap-2.5 px-1 py-4 text-[13px] text-muted">
              <ProgressBar value={null} height={3} label={t('stAnalyzing')} className="w-[120px]" />
              {t('stAnalyzing')}
            </div>
          )}
          {primary && analysis.status === 'no_media' && (
            <div className="flex flex-col items-start gap-2 px-1 py-3 text-[13px]">
              <span className="font-semibold text-danger">{t('noMediaTitle')}</span>
              <span className="text-muted">{analysis.message ?? t('itemProtected')}</span>
              <Button size="sm" onClick={retry}>
                {t('tryAgain')}
              </Button>
            </div>
          )}
          {primary && analysis.status === 'needs_components' && (
            <ComponentsPrompt
              components={analysis.components}
              onInstalled={retry}
              onDismiss={close}
            />
          )}
          {info && group === 'subtitles' && (
            <p className="m-0 px-1 py-4 text-[13px] text-muted">{t('subsPlanned')}</p>
          )}
          {info && group !== 'subtitles' && formats.length === 0 && (
            <p className="m-0 px-1 py-4 text-[13px] text-muted">{t('noFormatsGroup')}</p>
          )}
          {info && group !== 'subtitles' && formats.length > 0 && (
            <div role="radiogroup" aria-label={t('quality')} className="flex flex-col gap-1">
              {formats.map((f) => {
                const on = f.id === format?.id;
                return (
                  <button
                    key={f.id}
                    type="button"
                    role="radio"
                    aria-checked={on}
                    onClick={() => setFormatId(f.id)}
                    className={`flex items-center gap-3 rounded-md border p-2.5 text-left ${
                      on ? 'border-accent bg-selected' : 'border-line bg-bg hover:bg-card-hover'
                    }`}
                  >
                    <RadioDot checked={on} />
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="text-[13.5px] font-bold">
                        {f.quality}
                        {f.tag && (
                          <span className="ml-2 rounded-xs bg-accent-subtle px-1.5 py-0.5 font-mono text-[10px] font-bold text-chip-text">
                            {f.tag === 'Recommended' ? t('tagRecommended') : t('tagBest')}
                          </span>
                        )}
                      </span>
                      <span className="truncate text-[12px] text-muted">{f.detail}</span>
                    </span>
                    <span className="font-mono text-[12px] font-medium text-muted">{f.size}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <footer className="mt-auto flex flex-col gap-3 border-t border-line-strong px-[18px] py-3.5">
          <div className="flex items-center justify-between gap-3 text-[12.5px] text-muted">
            <span className="flex min-w-0 items-center gap-1.5">
              <Icon name="folder" size={16} />
              <span className="truncate font-mono text-fg" title={downloadDir}>
                {downloadDir}
              </span>
            </span>
            <button
              type="button"
              onClick={pickDownloadDir}
              className="font-semibold text-accent-strong hover:text-accent-hover"
            >
              {t('change')}
            </button>
          </div>
          <div className="flex gap-2">
            <Button className="flex-1" disabled={!canStart} onClick={() => void start(false)}>
              {t('addToQueue')}
            </Button>
            <Button
              variant="primary"
              icon="download"
              className="flex-[1.4]"
              disabled={!canStart}
              onClick={() => void start(true)}
            >
              {selected.length > 1 ? t('downloadN', { n: selected.length }) : t('downloadVerb')}
              {sizeLabel}
            </Button>
          </div>
        </footer>
      </section>
      <ToastHost />
    </div>
  );
}

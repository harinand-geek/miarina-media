import { useCallback, useEffect, useState } from 'react';
import { backend } from '../../services/backend';
import type { ComponentStatus, MediaFormat, MediaInfo } from '../../services/types';
import { useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';

export type AnalysisState =
  | { status: 'loading' }
  | { status: 'ready'; info: MediaInfo }
  | { status: 'no_media'; message?: string }
  | { status: 'needs_components'; components: ComponentStatus[] };

/** Runs the analysis for the pending URL; canceled when the view closes. */
export function useAnalysis(url: string, enabled = true) {
  const [attempt, setAttempt] = useState(0);
  const [result, setResult] = useState<{ key: string; state: AnalysisState } | null>(null);
  const key = `${attempt}:${url}`;

  useEffect(() => {
    if (!enabled || !url) return;
    const controller = new AbortController();
    backend
      .analyze(url, controller.signal)
      .then((r) =>
        setResult({
          key,
          state: r.ok
            ? { status: 'ready', info: r.info }
            : r.reason === 'needs_components'
              ? { status: 'needs_components', components: r.components }
              : { status: 'no_media', message: r.reason === 'no_media' ? r.message : undefined },
        }),
      )
      .catch((e: unknown) => {
        if (e instanceof DOMException && e.name === 'AbortError') return;
        const message = e instanceof Error ? e.message : undefined;
        setResult({ key, state: { status: 'no_media', message } });
      });
    return () => controller.abort();
  }, [key, url, enabled]);

  // Loading until the result for the current request arrives.
  const state: AnalysisState = result?.key === key ? result.state : { status: 'loading' };
  const retry = useCallback(() => setAttempt((n) => n + 1), []);
  return { state, retry };
}

export function shortQuality(format: MediaFormat) {
  return format.quality.split(' ·')[0] ?? format.quality;
}

/** Title used for the file: "Tears of Steel (1080p)", or the plain title for an original file. */
export function downloadTitle(info: MediaInfo, format: MediaFormat) {
  return format.id === 'original' ? info.title : `${info.title} (${shortQuality(format)})`;
}

/** Download / queue actions shared by the desktop screen and Android sheet. */
export function useStartActions() {
  const start = useDownloads((s) => s.start);
  const pushToast = useUi((s) => s.pushToast);
  const go = useUi((s) => s.go);

  const request = (
    info: MediaInfo,
    format: MediaFormat,
    kind: 'video' | 'audio',
    startNow: boolean,
  ) =>
    start({
      url: info.url,
      title: downloadTitle(info, format),
      kind,
      engine: info.engine,
      formatId: format.id === 'original' ? null : format.id,
      formatLabel: format.quality,
      extension: format.extension,
      startNow,
    });

  /** "Download": starts immediately, even above the concurrency limit. */
  const download = (info: MediaInfo, format: MediaFormat, kind: 'video' | 'audio') =>
    request(info, format, kind, true);

  /** "Add to queue": waits for a free slot. */
  const addToQueue = async (info: MediaInfo, format: MediaFormat, kind: 'video' | 'audio') => {
    if (await request(info, format, kind, false)) {
      pushToast({
        tone: 'success',
        message: `Added to queue · ${shortQuality(format)}`,
        action: { label: 'View', run: () => go('downloads') },
      });
    }
  };

  return { download, addToQueue };
}

const heightOf = (f: MediaFormat) => Number.parseInt(f.quality, 10) || 0;

/**
 * Pre-selected format: the source's recommended one, else the best quality
 * up to 1080p (sensible size), else the first offered.
 */
export function defaultFormat(formats: MediaFormat[]): MediaFormat | undefined {
  return (
    formats.find((f) => f.tag === 'Recommended') ??
    formats
      .filter((f) => heightOf(f) > 0 && heightOf(f) <= 1080)
      .sort((a, b) => heightOf(b) - heightOf(a))[0] ??
    formats[0]
  );
}

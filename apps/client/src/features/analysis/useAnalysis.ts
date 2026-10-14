import { useCallback, useEffect, useState } from 'react';
import { analyzeLink } from '../../services/backend';
import type { MediaFormat, MediaInfo } from '../../services/types';
import { useDownloads } from '../../stores/downloads';
import { useUi } from '../../stores/ui';

export type AnalysisState =
  { status: 'loading' } | { status: 'ready'; info: MediaInfo } | { status: 'no_media' };

/** Runs the analysis for the pending URL; canceled when the view closes. */
export function useAnalysis(url: string, enabled = true) {
  const [attempt, setAttempt] = useState(0);
  const [result, setResult] = useState<{ key: string; state: AnalysisState } | null>(null);
  const key = `${attempt}:${url}`;

  useEffect(() => {
    if (!enabled || !url) return;
    const controller = new AbortController();
    analyzeLink(url, controller.signal)
      .then((r) =>
        setResult({
          key,
          state: r.ok ? { status: 'ready', info: r.info } : { status: 'no_media' },
        }),
      )
      .catch((e: unknown) => {
        if (!(e instanceof DOMException && e.name === 'AbortError'))
          setResult({ key, state: { status: 'no_media' } });
      });
    return () => controller.abort();
  }, [key, url, enabled]);

  // Loading until the result for the current request arrives.
  const state: AnalysisState = result?.key === key ? result.state : { status: 'loading' };
  const retry = useCallback(() => setAttempt((n) => n + 1), []);
  return { state, retry };
}

const EXTENSIONS: Record<string, string> = { MP4: 'mp4', WebM: 'webm', SRT: 'srt' };
const AUDIO_EXTENSIONS: Record<string, string> = {
  flac: 'flac',
  mp3: 'mp3',
  m4a: 'm4a',
  opus: 'opus',
};

export function fileExtension(format: MediaFormat) {
  return AUDIO_EXTENSIONS[format.id] ?? EXTENSIONS[format.detail.split(' · ')[0] ?? ''] ?? 'mp4';
}

export function shortQuality(format: MediaFormat) {
  return format.quality.split(' ·')[0] ?? format.quality;
}

/** Download / queue actions shared by the desktop screen and Android sheet. */
export function useStartActions() {
  const start = useDownloads((s) => s.start);
  const enqueue = useDownloads((s) => s.enqueue);
  const pushToast = useUi((s) => s.pushToast);
  const go = useUi((s) => s.go);

  const download = (info: MediaInfo, format: MediaFormat, kind: 'video' | 'audio') =>
    start({
      title: `${info.title} (${shortQuality(format)})`,
      source: info.host,
      kind,
      format: format.quality,
      totalMb:
        parseFloat(format.size) *
        (format.size.includes('GB') ? 1024 : format.size.includes('KB') ? 1 / 1024 : 1),
    });

  const addToQueue = (info: MediaInfo, format: MediaFormat, kind: 'video' | 'audio') => {
    enqueue({ title: info.title, kind, format: format.quality, size: format.size });
    pushToast({
      tone: 'success',
      message: `Added to queue · ${shortQuality(format)}`,
      action: { label: 'View', run: () => go('downloads') },
    });
  };

  return { download, addToQueue };
}

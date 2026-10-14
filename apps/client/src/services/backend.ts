// Phase 1 mock backend. It reproduces the prototype behavior on top of the
// development fixtures; Phase 2 replaces it with typed Tauri commands.

import { ANALYZED, NO_MEDIA_HOSTS } from '../dev/fixtures';
import { checkLink } from './link';
import type { AnalyzeResult } from './types';

const ANALYSIS_DELAY_MS = 900;

export async function analyzeLink(input: string, signal?: AbortSignal): Promise<AnalyzeResult> {
  const link = await checkLink(input);
  if (!link.ok) return { ok: false, reason: 'invalid_link', code: link.code };

  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(resolve, ANALYSIS_DELAY_MS);
    signal?.addEventListener('abort', () => {
      clearTimeout(timer);
      reject(new DOMException('Analysis canceled', 'AbortError'));
    });
  });

  const host = link.host.replace(/^www\./, '');
  if (NO_MEDIA_HOSTS.some((h) => host === h || host.endsWith(`.${h}`))) {
    return { ok: false, reason: 'no_media' };
  }
  return { ok: true, info: { ...ANALYZED, url: link.url, host } };
}

/** True while screens are backed by development fixtures (Phase 1). */
export const USING_FIXTURES = true;

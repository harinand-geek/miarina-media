import type { BrowserSnapshot, DetectedKind } from '../../services/types';

/** Something the user can download from the current page. */
export interface Candidate {
  id: string;
  /** What gets analyzed: a media URL, or the page itself (extractor). */
  url: string;
  kind: DetectedKind | 'page';
  title: string;
  detail: string;
  sizeBytes: number | null;
}

const KIND_LABEL: Record<Candidate['kind'], string> = {
  video: 'Video',
  audio: 'Audio',
  hls: 'Stream (HLS)',
  dash: 'Stream (DASH)',
  page: 'Page player',
};

export const kindLabel = (kind: Candidate['kind']) => KIND_LABEL[kind];

export function hostOf(url: string) {
  try {
    return new URL(url).host;
  } catch {
    return '';
  }
}

/**
 * Media found on the page, plus the page itself when it plays a stream
 * (MSE): only the extractor can read those, from the page URL.
 */
export function candidates(state: BrowserSnapshot): Candidate[] {
  const items: Candidate[] = state.media.map((m) => ({
    id: m.url,
    url: m.url,
    kind: m.kind,
    title: m.name ? decodeName(m.name) : m.host,
    detail: m.host,
    sizeBytes: m.sizeBytes,
  }));
  if (state.streamPlayer && state.url) {
    items.unshift({
      id: `page:${state.url}`,
      url: state.url,
      kind: 'page',
      title: state.title || hostOf(state.url),
      detail: hostOf(state.url),
      sizeBytes: null,
    });
  }
  return items;
}

/** Pre-selected item: the page player, else the first video, else the first item. */
export function mainCandidate(list: Candidate[]): Candidate | undefined {
  return list.find((c) => c.kind === 'page') ?? list.find((c) => c.kind === 'video') ?? list[0];
}

function decodeName(name: string) {
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

/** Address bar: host in full color, the rest muted (design D1). */
export function splitAddress(url: string): { host: string; rest: string; secure: boolean } {
  try {
    const u = new URL(url);
    const rest = `${u.pathname === '/' ? '' : u.pathname}${u.search}`;
    return { host: u.host, rest, secure: u.protocol === 'https:' };
  } catch {
    return { host: url, rest: '', secure: false };
  }
}

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

/** "Film.webm.720p.vp9.webm" → 720; 0 when the name gives no height. */
const heightIn = (title: string) => Number(/(\d{3,4})p(?![a-z])/i.exec(title)?.[1] ?? 0);

/**
 * Pre-selected item: the page player, else the best video variant up to
 * 1080p (pages often list a huge original next to sized copies), else the
 * first video, else the first item.
 */
export function mainCandidate(list: Candidate[]): Candidate | undefined {
  const videos = list.filter((c) => c.kind === 'video');
  const sized = videos
    .filter((c) => heightIn(c.title) > 0 && heightIn(c.title) <= 1080)
    .sort((a, b) => heightIn(b.title) - heightIn(a.title));
  return list.find((c) => c.kind === 'page') ?? sized[0] ?? videos[0] ?? list[0];
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

/**
 * Chip labels for the sheet: variants of one file ("Film.webm",
 * "Film.webm.480p.vp9.webm") are named by what they add ("480p.vp9.webm").
 */
export function distinctLabels(names: string[]): string[] {
  const shortest = [...names].sort((a, b) => a.length - b.length)[0];
  if (names.length < 2 || !shortest || !names.every((n) => n.startsWith(shortest))) return names;
  return names.map((name) => name.slice(shortest.length).replace(/^[._\-\s]+/, '') || name);
}

// Frontend contracts. In Phase 2 these become types generated from the Rust
// crates (ts-rs) into packages/shared-types.

export type MediaKind = 'video' | 'audio';
export type FormatGroup = 'video' | 'audio' | 'subtitles';

export interface MediaFormat {
  id: string;
  quality: string;
  /** Container, codec and frame rate summary, e.g. "MP4 · H.264 · 24 fps". */
  detail: string;
  size: string;
  tag?: 'Best quality' | 'Recommended';
}

export interface MediaInfo {
  url: string;
  host: string;
  title: string;
  subtitle: string;
  publisher: string;
  duration: string;
  released?: string;
  license?: string;
  formats: Record<FormatGroup, MediaFormat[]>;
}

export interface LibraryItem {
  id: string;
  title: string;
  source: string;
  kind: MediaKind;
  duration: string;
  durationSec: number;
  size: string;
  quality: string;
  addedAgo?: string;
}

export type DownloadStatus = 'downloading' | 'paused' | 'waiting_wifi' | 'completed';

export interface DownloadTask {
  id: string;
  title: string;
  source: string;
  kind: MediaKind;
  format: string;
  totalMb: number;
  percent: number;
  /** Simulated percent gained per second (fixtures only). */
  rate: number;
  status: DownloadStatus;
}

export interface QueueItem {
  id: string;
  title: string;
  kind: MediaKind;
  format: string;
  size: string;
}

export type HistoryStatus = 'Completed' | 'Failed' | 'Cancelled';

export interface HistoryEntry {
  id: string;
  time: string;
  title: string;
  source: string;
  format: string;
  size: string;
  status: HistoryStatus;
  reason?: string;
}

export interface HistoryGroup {
  day: string;
  entries: HistoryEntry[];
}

export type LinkErrorCode =
  | 'empty'
  | 'too_long'
  | 'malformed'
  | 'unsupported_scheme'
  | 'missing_host'
  | 'contains_credentials';

export type AnalyzeResult =
  | { ok: true; info: MediaInfo }
  | { ok: false; reason: 'no_media' | 'invalid_link'; code?: LinkErrorCode };

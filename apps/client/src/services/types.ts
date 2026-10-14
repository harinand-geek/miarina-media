// Frontend contracts. Download, history and settings types mirror the Rust
// DTOs (`storage::TaskRecord`, `download_engine::ManagerEvent`, …) field for
// field; keep them in sync with crates/storage and apps/client/src-tauri.

export type MediaKind = 'video' | 'audio';
export type FormatGroup = 'video' | 'audio' | 'subtitles';
export type EngineId = 'http' | 'ytdlp';

export interface MediaFormat {
  id: string;
  quality: string;
  /** Container, codec and frame rate summary, e.g. "MP4 · H.264 · 24 fps". */
  detail: string;
  size: string;
  /** File extension the download will be saved with. */
  extension: string;
  sizeBytes?: number | null;
  tag?: 'Best quality' | 'Recommended';
}

export interface MediaInfo {
  url: string;
  host: string;
  engine: EngineId;
  title: string;
  subtitle: string;
  publisher: string;
  duration?: string | null;
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

/** `media_core::TaskState`. */
export type TaskState =
  | 'queued'
  | 'analyzing'
  | 'waiting'
  | 'downloading'
  | 'paused'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'canceled';

/** `storage::TaskRecord`. */
export interface TaskRecord {
  id: string;
  url: string;
  sourceHost: string;
  title: string;
  kind: MediaKind;
  engine: string;
  formatId: string | null;
  formatLabel: string;
  state: TaskState;
  position: number;
  destDir: string;
  fileName: string;
  partPath: string | null;
  finalPath: string | null;
  totalBytes: number | null;
  downloadedBytes: number;
  supportsResume: boolean;
  attempts: number;
  errorCode: string | null;
  errorMessage: string | null;
  createdAt: number;
  updatedAt: number;
  completedAt: number | null;
}

/** A task plus live, non-persisted transfer figures. */
export interface DownloadTask extends TaskRecord {
  bytesPerSec: number;
  etaSecs: number | null;
  /** Set while waiting for an automatic retry. */
  retry?: { inSecs: number; reason: string; at: number };
}

export interface ProgressPayload {
  id: string;
  downloaded: number;
  total: number | null;
  bytesPerSec: number;
  supportsResume: boolean;
  etaSecs: number | null;
}

export type HistoryStatus = 'completed' | 'failed' | 'canceled';

/** `storage::HistoryEntry`. */
export interface HistoryEntry {
  id: number;
  taskId: string;
  /** Source page or file (local only, never logged). */
  url: string;
  title: string;
  sourceHost: string;
  formatLabel: string;
  totalBytes: number | null;
  doneBytes: number;
  status: HistoryStatus;
  reason: string | null;
  finalPath: string | null;
  finishedAt: number;
}

/** `download_engine::ManagerEvent`. */
export type BackendEvent =
  | { type: 'progress'; payload: ProgressPayload }
  | { type: 'task'; payload: TaskRecord }
  | { type: 'removed'; payload: { id: string } }
  | { type: 'retrying'; payload: { id: string; retry: number; inSecs: number; reason: string } }
  | { type: 'history'; payload: HistoryEntry };

export type ResourceMode = 'eco' | 'balanced' | 'performance';

/** `resource_manager::Limits`. */
export interface Limits {
  maxDownloads: number;
  maxConversions: number;
  ffmpegThreads: number;
  concurrentFragments: number;
  progressInterval: number;
  thumbnailPx: number;
  childPriority: 'below_normal' | 'normal';
  reducedMotion: boolean;
}

export interface BackendSettings {
  downloadDir: string;
  concurrency: number;
  resourceMode: ResourceMode;
  limits: Limits;
}

export interface StartRequest {
  url: string;
  title: string;
  kind: MediaKind;
  engine: EngineId;
  formatId: string | null;
  formatLabel: string;
  extension: string;
  startNow: boolean;
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

/** Error shape returned by Tauri commands (`CommandError`). */
export interface CommandError {
  code: string;
  message: string;
}

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
  tag?: 'Best quality' | 'Recommended' | null;
}

export interface MediaInfo {
  url: string;
  host: string;
  engine: EngineId;
  title: string;
  subtitle: string;
  publisher: string;
  duration?: string | null;
  released?: string | null;
  license?: string | null;
  /** Advice shown under the formats (e.g. FFmpeg missing). */
  notice?: string | null;
  /** Local copy of the site's picture (asset protocol path). */
  thumbnail?: string | null;
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
  /** Source thumbnail cached at analysis time. */
  thumbnail: string | null;
}

/** A task plus live, non-persisted transfer figures. */
export interface DownloadTask extends TaskRecord {
  bytesPerSec: number;
  etaSecs: number | null;
  /**
   * Set while waiting for an automatic retry; `offline`: no network at all,
   * the task goes on by itself when it is back (no retry spent).
   */
  retry?: { inSecs: number; reason: string; at: number; offline?: boolean };
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
  | {
      type: 'retrying';
      payload: { id: string; retry: number; inSecs: number; reason: string; offline?: boolean };
    }
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
  /** Separate audio folder (Android shared `Music/Miarina`). */
  audioDownloadDir?: string | null;
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
  thumbnail?: string | null;
}

export type LinkErrorCode =
  | 'empty'
  | 'too_long'
  | 'malformed'
  | 'unsupported_scheme'
  | 'missing_host'
  | 'contains_credentials';

/** `download_engine::components::ComponentStatus`. */
export interface ComponentStatus {
  id: 'yt_dlp' | 'ffmpeg' | 'quickjs';
  name: string;
  version: string;
  license: string;
  downloadBytes: number;
  installed: boolean;
  /** Shipped with the Windows installer rather than downloaded. */
  bundled: boolean;
}

/** `commands::YtDlpUpdateDto`. */
export interface YtDlpUpdate {
  status: 'up_to_date' | 'updated';
  version: string;
  checkedAt: number;
}

export interface InstallProgress {
  id: ComponentStatus['id'];
  name: string;
  downloaded: number;
  total: number;
}

export type AnalyzeResult =
  | { ok: true; info: MediaInfo }
  | { ok: false; reason: 'invalid_link'; code?: LinkErrorCode }
  | { ok: false; reason: 'no_media'; message?: string }
  | { ok: false; reason: 'needs_components'; components: ComponentStatus[] };

/** Error shape returned by Tauri commands (`CommandError`). */
export interface CommandError {
  code: string;
  message: string;
}

/** `storage::MediaRecord`. */
export interface MediaRecord {
  id: number;
  path: string;
  title: string;
  kind: MediaKind;
  sourceHost: string | null;
  sourceUrl: string | null;
  taskId: string | null;
  sizeBytes: number;
  durationSecs: number | null;
  width: number | null;
  height: number | null;
  videoCodec: string | null;
  audioCodec: string | null;
  container: string | null;
  thumbnail: string | null;
  probed: boolean;
  missing: boolean;
  addedAt: number;
  modifiedAt: number;
  artist?: string | null;
  album?: string | null;
  albumArtist?: string | null;
  year?: number | null;
  genre?: string | null;
  trackNo?: number | null;
  discNo?: number | null;
  /** Marked as a favorite (COM-06). */
  favorite?: boolean;
  /** The picture was chosen (or removed) by the user (COM-07). */
  coverCustom?: boolean;
}

/** `storage::PlaylistSummary` (COM-06). */
export interface PlaylistSummary {
  id: number;
  name: string;
  count: number;
  durationSecs: number;
  /** Up to four thumbnails for the cover mosaic. */
  covers: string[];
  updatedAt: number;
}

/** `storage::Playlist`: entries in order, missing files included. */
export interface Playlist {
  id: number;
  name: string;
  items: MediaRecord[];
}

/** Result of an M3U import (COM-11). */
export interface PlaylistImport {
  playlist: PlaylistSummary;
  added: number;
  /** Entries not in the library, or web addresses (never fetched). */
  skipped: number;
}

/** `storage::MediaTags` (tag editor, COM-07). */
export interface MediaTags {
  title: string | null;
  artist: string | null;
  album: string | null;
  albumArtist: string | null;
  year: number | null;
  genre: string | null;
  trackNo: number | null;
  discNo: number | null;
  comment: string | null;
  lyrics: string | null;
}

export type GroupBy = 'album' | 'artist' | 'folder';

/** `storage::MediaGroup`: an album, artist or folder of the music library. */
export interface MediaGroup {
  name: string;
  /** Album artist (albums) or number of albums (artists). */
  detail: string | null;
  count: number;
  durationSecs: number;
  year: number | null;
  thumbnail: string | null;
}

export type MediaSort = 'added' | 'title' | 'size' | 'duration';

export interface MediaQuery {
  search: string;
  kind: MediaKind | null;
  album?: string | null;
  artist?: string | null;
  folder?: string | null;
  /** Favorites only. */
  favorites?: boolean;
  sort: MediaSort;
  offset?: number;
  limit?: number;
}

export interface MediaPage {
  items: MediaRecord[];
  total: number;
}

export interface MediaStats {
  count: number;
  totalBytes: number;
  videoCount: number;
  videoBytes: number;
  audioCount: number;
  audioBytes: number;
}

export interface DiskSpace {
  free: number;
  total: number;
}

export interface LibraryOverview {
  stats: MediaStats;
  disk: DiskSpace | null;
  downloadDir: string;
}

export interface StorageUsage {
  downloadDir: string;
  disk: DiskSpace | null;
  libraryBytes: number;
  thumbnailBytes: number;
  orphanTempBytes: number;
  orphanTempCount: number;
}

// Built-in browser (decision 0001). Detected items are untrusted page data,
// already filtered in Rust (media_core::detect).
export type DetectedKind = 'video' | 'audio' | 'hls' | 'dash';

export interface DetectedMedia {
  kind: DetectedKind;
  url: string;
  host: string;
  /** Last path segment, for display. */
  name: string;
  sizeBytes: number | null;
  via: 'network' | 'page';
}

export interface BrowserSnapshot {
  url: string;
  title: string;
  loading: boolean;
  canGoBack: boolean;
  canGoForward: boolean;
  /** No page yet: the start page fills the window. */
  startPage: boolean;
  /** The format sheet is open (the overlay covers the page). */
  sheet: boolean;
  media: DetectedMedia[];
  /** The page streams through MSE: only the page URL can be analyzed. */
  streamPlayer: boolean;
  /** Android: page load progress, 0–100. */
  progress?: number;
  /** Android: gesture on the native floating button since the last poll. */
  fab?: 'tap' | 'hold' | null;
}

/** A starred page, shown on the browser's start page. */
export interface Favorite {
  url: string;
  title: string;
}

/** Android: where the native page view goes, in CSS pixels of the app. */
export interface BrowserFrame {
  x: number;
  y: number;
  width: number;
  height: number;
  visible: boolean;
  /** Floating button label; null hides the button. */
  fab: string | null;
  /** Return a picture of the page before hiding it. */
  snapshot: boolean;
}

export type BrowserAction = 'back' | 'forward' | 'reload' | 'stop' | 'home';
export type AppScreenRequest = 'downloads' | 'library' | 'player';

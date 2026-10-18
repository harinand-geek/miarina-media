// Single entry point to the native backend. Inside Tauri every call goes to
// a validated Rust command; in a plain browser (UI preview, tests) a mock
// that honors the same contract and events is used instead.

import { convertFileSrc, invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { MockBackend } from '../dev/mockBackend';
import { checkLink } from './link';
import { inTauri } from './platform';
import type {
  AnalyzeResult,
  BackendEvent,
  BackendSettings,
  AppScreenRequest,
  BrowserAction,
  BrowserFrame,
  Favorite,
  BrowserSnapshot,
  CommandError,
  ComponentStatus,
  InstallProgress,
  HistoryEntry,
  LibraryOverview,
  MediaInfo,
  MediaPage,
  MediaQuery,
  MediaRecord,
  ResourceMode,
  StartRequest,
  StorageUsage,
  TaskRecord,
  YtDlpUpdate,
} from './types';

export interface Backend {
  readonly kind: 'tauri' | 'mock';
  analyze(url: string, signal?: AbortSignal): Promise<AnalyzeResult>;
  listTasks(): Promise<TaskRecord[]>;
  start(request: StartRequest): Promise<TaskRecord>;
  pause(id: string): Promise<void>;
  resume(id: string): Promise<void>;
  cancel(id: string): Promise<void>;
  retry(id: string): Promise<void>;
  startNow(id: string): Promise<void>;
  move(id: string, index: number): Promise<void>;
  pauseAll(): Promise<void>;
  resumeAll(): Promise<void>;
  reveal(id: string): Promise<void>;
  listHistory(): Promise<HistoryEntry[]>;
  clearHistory(): Promise<void>;
  revealHistory(id: number): Promise<void>;
  getSettings(): Promise<BackendSettings>;
  setConcurrency(value: number): Promise<BackendSettings>;
  setResourceMode(mode: ResourceMode): Promise<BackendSettings>;
  /** Native folder picker; `null` when the user cancels. */
  pickDownloadDir(): Promise<BackendSettings | null>;
  componentsStatus(): Promise<ComponentStatus[]>;
  /** Downloads the missing tools (explicit user consent, decision D3). */
  installComponents(onProgress: (p: InstallProgress) => void): Promise<ComponentStatus[]>;
  /** Installs a newer yt-dlp if its signature verifies (Windows). */
  updateYtDlp(): Promise<YtDlpUpdate>;
  subscribe(listener: (event: BackendEvent) => void): () => void;

  // Library (Phase 3)
  libraryQuery(query: MediaQuery): Promise<MediaPage>;
  libraryOverview(): Promise<LibraryOverview>;
  /** One entry, after checking that its file still exists. */
  libraryGet(id: number): Promise<MediaRecord>;
  libraryRename(id: number, title: string): Promise<MediaRecord>;
  /** Deletes the file from disk. */
  libraryDelete(id: number): Promise<void>;
  libraryReveal(id: number): Promise<void>;
  /** Opens the file with the system player (formats the WebView cannot play). */
  libraryOpenExternal(id: number): Promise<void>;
  /** Android share sheet for a library file. */
  libraryShare(id: number): Promise<void>;
  libraryRescan(): Promise<void>;
  /** Opens the download folder in the file manager. */
  openDownloadFolder(): Promise<void>;
  onLibraryChanged(listener: () => void): () => void;
  /** URL the WebView can stream (asset protocol, range requests). */
  mediaUrl(path: string): string;
  storageUsage(): Promise<StorageUsage>;
  clearThumbnails(): Promise<number>;
  cleanTemp(): Promise<number>;

  // Built-in browser (desktop window, decision 0001)
  /** Opens or focuses the browser window; `false` when unavailable (browser preview). */
  openBrowser(url?: string): Promise<boolean>;
  /** Navigates the page; resolves with the normalized URL. */
  browserNavigate(address: string): Promise<string>;
  browserNav(action: BrowserAction): Promise<void>;
  browserState(): Promise<BrowserSnapshot>;
  browserSheet(open: boolean): Promise<void>;
  /** Size of the floating button, so the transparent overlay covers nothing else. */
  browserFabSize(width: number, height: number): Promise<void>;
  /** Brings the main window forward on a screen. */
  browserShowInApp(screen: AppScreenRequest): Promise<void>;
  onBrowserState(listener: (state: BrowserSnapshot) => void): () => void;
  /** Android: places or hides the native page view; may return a picture of the page. */
  browserFrame(frame: BrowserFrame): Promise<string | null>;
  browserFavorites(): Promise<Favorite[]>;
  /** Stars or unstars a page; returns the new list. */
  browserFavoriteToggle(url: string, title: string): Promise<Favorite[]>;
  /** Shortcuts pressed while the web page had keyboard focus. */
  onBrowserShortcut(listener: (name: string) => void): () => void;
  /** Main window: another window asks to show a screen. */
  onAppNavigate(listener: (screen: AppScreenRequest) => void): () => void;
}

/** Subscribes to a Tauri event; returns a synchronous unsubscribe. */
function onEvent<T>(name: string, listener: (payload: T) => void) {
  let unlisten: (() => void) | undefined;
  let closed = false;
  void listen<T>(name, (e) => listener(e.payload)).then((fn) => {
    if (closed) fn();
    else unlisten = fn;
  });
  return () => {
    closed = true;
    unlisten?.();
  };
}

export class BackendError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

async function call<T>(command: string, args?: Record<string, unknown>): Promise<T> {
  try {
    return await invoke<T>(command, args);
  } catch (e) {
    const err = e as Partial<CommandError> | string;
    if (typeof err === 'string') throw new BackendError('unknown', err);
    throw new BackendError(err.code ?? 'unknown', err.message ?? 'Unexpected error');
  }
}

export type AnalysisDto =
  | { status: 'ready'; info: MediaInfo }
  | { status: 'no_media'; reason: string }
  | { status: 'needs_components'; components: ComponentStatus[] };

/** Maps the `analyze_link` DTO to the UI result. */
export function mapAnalysis(result: AnalysisDto): AnalyzeResult {
  switch (result.status) {
    case 'ready':
      return { ok: true, info: result.info };
    case 'needs_components':
      return { ok: false, reason: 'needs_components', components: result.components };
    case 'no_media':
      return { ok: false, reason: 'no_media', message: result.reason };
  }
}

class TauriBackend implements Backend {
  readonly kind = 'tauri' as const;

  async analyze(url: string, signal?: AbortSignal): Promise<AnalyzeResult> {
    const link = await checkLink(url);
    if (!link.ok) return { ok: false, reason: 'invalid_link', code: link.code };
    const result = await call<AnalysisDto>('analyze_link', { url: link.url });
    if (signal?.aborted) throw new DOMException('Analysis canceled', 'AbortError');
    return mapAnalysis(result);
  }

  listTasks = () => call<TaskRecord[]>('downloads_list');
  start = (request: StartRequest) => call<TaskRecord>('downloads_start', { request });
  pause = (id: string) => call<void>('downloads_pause', { id });
  resume = (id: string) => call<void>('downloads_resume', { id });
  cancel = (id: string) => call<void>('downloads_cancel', { id });
  retry = (id: string) => call<void>('downloads_retry', { id });
  startNow = (id: string) => call<void>('downloads_start_now', { id });
  move = (id: string, index: number) => call<void>('downloads_move', { id, index });
  pauseAll = () => call<void>('downloads_pause_all');
  resumeAll = () => call<void>('downloads_resume_all');
  reveal = (id: string) => call<void>('downloads_reveal', { id });
  listHistory = () => call<HistoryEntry[]>('history_list', { limit: 200 });
  clearHistory = async () => {
    await call<number>('history_clear');
  };
  revealHistory = (id: number) => call<void>('history_reveal', { id });
  getSettings = () => call<BackendSettings>('settings_get');
  setConcurrency = (value: number) => call<BackendSettings>('settings_set_concurrency', { value });
  setResourceMode = (mode: ResourceMode) =>
    call<BackendSettings>('settings_set_resource_mode', { mode });
  pickDownloadDir = () => call<BackendSettings | null>('settings_pick_download_dir');
  componentsStatus = () => call<ComponentStatus[]>('components_status');
  updateYtDlp = () => call<YtDlpUpdate>('components_update_ytdlp');

  async installComponents(onProgress: (p: InstallProgress) => void) {
    const unlisten = await listen<InstallProgress>('components://progress', (e) =>
      onProgress(e.payload),
    );
    try {
      return await call<ComponentStatus[]>('components_install');
    } finally {
      unlisten();
    }
  }

  subscribe(listener: (event: BackendEvent) => void) {
    return onEvent<BackendEvent>('downloads://event', listener);
  }

  libraryQuery = (query: MediaQuery) => call<MediaPage>('library_query', { query });
  libraryOverview = () => call<LibraryOverview>('library_overview');
  libraryGet = (id: number) => call<MediaRecord>('library_get', { id });
  libraryRename = (id: number, title: string) => call<MediaRecord>('library_rename', { id, title });
  libraryDelete = (id: number) => call<void>('library_delete', { id });
  libraryReveal = (id: number) => call<void>('library_reveal', { id });
  libraryOpenExternal = (id: number) => call<void>('library_open_external', { id });
  libraryShare = (id: number) => call<void>('library_share', { id });
  openDownloadFolder = () => call<void>('downloads_open_folder');
  libraryRescan = async () => {
    await call('library_rescan');
  };
  onLibraryChanged = (listener: () => void) => onEvent<null>('library://changed', listener);
  mediaUrl = (path: string) => convertFileSrc(path);
  storageUsage = () => call<StorageUsage>('storage_usage');
  clearThumbnails = () => call<number>('storage_clear_thumbnails');
  cleanTemp = () => call<number>('storage_clean_temp');

  openBrowser = async (url?: string) => {
    await call<void>('browser_open', { url: url ?? null });
    return true;
  };
  browserNavigate = (address: string) => call<string>('browser_navigate', { address });
  browserNav = (action: BrowserAction) => call<void>('browser_nav', { action });
  browserState = () => call<BrowserSnapshot>('browser_state');
  browserSheet = (open: boolean) => call<void>('browser_sheet', { open });
  browserFabSize = (width: number, height: number) =>
    call<void>('browser_fab_size', { width, height });
  browserShowInApp = (screen: AppScreenRequest) => call<void>('browser_show_in_app', { screen });
  onBrowserState = (listener: (state: BrowserSnapshot) => void) =>
    onEvent<BrowserSnapshot>('browser://state', listener);
  browserFrame = (frame: BrowserFrame) => call<string | null>('browser_frame', { ...frame });
  browserFavorites = () => call<Favorite[]>('browser_favorites');
  browserFavoriteToggle = (url: string, title: string) =>
    call<Favorite[]>('browser_favorite_toggle', { url, title });
  onBrowserShortcut = (listener: (name: string) => void) =>
    onEvent<string>('browser://shortcut', listener);
  onAppNavigate = (listener: (screen: AppScreenRequest) => void) =>
    onEvent<AppScreenRequest>('app://navigate', listener);
}

// `let` + live ES module binding: importers always see the current backend.
export let backend: Backend = inTauri() ? new TauriBackend() : new MockBackend();

/** Test helper: start every test from a fresh mock. */
export function resetMockBackend() {
  backend = new MockBackend();
  return backend;
}

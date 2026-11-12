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
  AppScreenRequest,
  BackendEvent,
  BackendSettings,
  BrowserAction,
  BrowserFrame,
  BrowserSnapshot,
  CommandError,
  ComponentStatus,
  Favorite,
  GroupBy,
  HistoryEntry,
  InstallProgress,
  LibraryOverview,
  MediaGroup,
  Playlist,
  PlaylistImport,
  PlaylistSummary,
  MediaInfo,
  MediaPage,
  MediaQuery,
  MediaRecord,
  MediaTags,
  NativePlayerAction,
  NativePlayerStateEvent,
  NativePlayerStatus,
  NativePlayerTracksEvent,
  ResourceMode,
  StartRequest,
  StorageUsage,
  TaskRecord,
  Visit,
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
  /** Starts a failed or paused task over from zero, dropping its partial data. */
  restart(id: string): Promise<void>;
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
  libraryTags(id: number): Promise<MediaTags>;
  libraryUpdateTags(id: number, tags: MediaTags, writeToFile: boolean): Promise<MediaRecord>;
  libraryGroups(by: GroupBy): Promise<MediaGroup[]>;
  librarySetFavorite(id: number, favorite: boolean): Promise<MediaRecord>;
  /** Cover from a picture picked in the system dialog; `null` if canceled (COM-07). */
  libraryCoverPick(id: number): Promise<MediaRecord | null>;
  /** Cover from the thumbnail the source offered at download time. */
  libraryCoverSource(id: number): Promise<MediaRecord>;
  /** Cover from the frame of a video at `atSecs`. */
  libraryCoverFrame(id: number, atSecs: number): Promise<MediaRecord>;
  /** No picture for this entry. */
  libraryCoverRemove(id: number): Promise<MediaRecord>;
  libraryHasSourceCover(id: number): Promise<boolean>;
  playlists(): Promise<PlaylistSummary[]>;
  playlistGet(id: number): Promise<Playlist>;
  playlistCreate(name: string, ids: number[]): Promise<PlaylistSummary>;
  playlistRename(id: number, name: string): Promise<void>;
  playlistDelete(id: number): Promise<void>;
  playlistAdd(id: number, ids: number[]): Promise<void>;
  playlistRemove(id: number, index: number): Promise<void>;
  playlistMove(id: number, from: number, to: number): Promise<void>;
  /** System file dialog; `null` when canceled. */
  playlistImport(): Promise<PlaylistImport | null>;
  /** System save dialog; the saved path, or `null` when canceled. */
  playlistExport(id: number): Promise<string | null>;
  /** Forgets the entry; the file stays on disk and scans skip it (COM-10). */
  libraryRemove(id: number): Promise<void>;
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
  /** Windows: the libVLC engine (started on first call). */
  nativePlayerStatus(): Promise<NativePlayerStatus>;
  nativePlayerOpen(
    id: number,
    startSecs: number,
    autoplay: boolean,
    instance: number,
  ): Promise<void>;
  nativePlayerControl(action: NativePlayerAction, value?: number): Promise<void>;
  nativePlayerVolume(volume: number, muted: boolean): Promise<void>;
  /** Picks a subtitle file in the system dialog; `false` if canceled. */
  nativePlayerAddSubtitle(): Promise<boolean>;
  nativePlayerFrame(
    frame: { x: number; y: number; width: number; height: number },
    visible: boolean,
  ): Promise<void>;
  onNativePlayerState(cb: (e: NativePlayerStateEvent) => void): () => void;
  onNativePlayerTracks(cb: (e: NativePlayerTracksEvent) => void): () => void;
  onNativePlayerClick(cb: (kind: 'click' | 'dblclick') => void): () => void;
  /** Windows: opens a tab (start page, an address, or the history tab). */
  browserTabNew(options?: { kind?: 'history'; address?: string }): Promise<number>;
  browserTabClose(id: number): Promise<void>;
  /** Selects a tab, or the next (1) / previous (-1) one. */
  browserTabSelect(target: { id?: number; step?: number }): Promise<void>;
  /** Visited pages, newest first, matching `query` (title or address). */
  browserHistory(query: string): Promise<Visit[]>;
  browserHistoryDelete(id: number): Promise<void>;
  browserHistoryClear(): Promise<number>;
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
  restart = (id: string) => call<void>('downloads_restart', { id });
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
  libraryTags = (id: number) => call<MediaTags>('library_tags', { id });
  libraryUpdateTags = (id: number, tags: MediaTags, writeToFile: boolean) =>
    call<MediaRecord>('library_update_tags', { id, tags, writeToFile });
  libraryGroups = (by: GroupBy) => call<MediaGroup[]>('library_groups', { by });
  librarySetFavorite = (id: number, favorite: boolean) =>
    call<MediaRecord>('library_set_favorite', { id, favorite });
  libraryCoverPick = (id: number) => call<MediaRecord | null>('library_cover_pick', { id });
  libraryCoverSource = (id: number) => call<MediaRecord>('library_cover_source', { id });
  libraryCoverFrame = (id: number, atSecs: number) =>
    call<MediaRecord>('library_cover_frame', { id, atSecs });
  libraryCoverRemove = (id: number) => call<MediaRecord>('library_cover_remove', { id });
  libraryHasSourceCover = (id: number) => call<boolean>('library_has_source_cover', { id });
  playlists = () => call<PlaylistSummary[]>('playlists_list');
  playlistGet = (id: number) => call<Playlist>('playlist_get', { id });
  playlistCreate = (name: string, ids: number[]) =>
    call<PlaylistSummary>('playlist_create', { name, ids });
  playlistRename = (id: number, name: string) => call<void>('playlist_rename', { id, name });
  playlistDelete = (id: number) => call<void>('playlist_delete', { id });
  playlistAdd = (id: number, ids: number[]) => call<void>('playlist_add', { id, ids });
  playlistRemove = (id: number, index: number) => call<void>('playlist_remove', { id, index });
  playlistMove = (id: number, from: number, to: number) =>
    call<void>('playlist_move', { id, from, to });
  playlistImport = () => call<PlaylistImport | null>('playlist_import');
  playlistExport = (id: number) => call<string | null>('playlist_export', { id });
  libraryRemove = (id: number) => call<void>('library_remove', { id });
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
  nativePlayerStatus = () => call<NativePlayerStatus>('native_player_status');
  nativePlayerOpen = (id: number, startSecs: number, autoplay: boolean, instance: number) =>
    call<void>('native_player_open', { id, startSecs, autoplay, instance });
  nativePlayerControl = (action: NativePlayerAction, value?: number) =>
    call<void>('native_player_control', { action, value: value ?? null });
  nativePlayerVolume = (volume: number, muted: boolean) =>
    call<void>('native_player_volume', { volume, muted });
  nativePlayerAddSubtitle = () => call<boolean>('native_player_add_subtitle');
  nativePlayerFrame = (
    frame: { x: number; y: number; width: number; height: number },
    visible: boolean,
  ) => call<void>('native_player_frame', { ...frame, visible });
  onNativePlayerState = (cb: (e: NativePlayerStateEvent) => void) =>
    onEvent<NativePlayerStateEvent>('native-player://state', cb);
  onNativePlayerTracks = (cb: (e: NativePlayerTracksEvent) => void) =>
    onEvent<NativePlayerTracksEvent>('native-player://tracks', cb);
  onNativePlayerClick = (cb: (kind: 'click' | 'dblclick') => void) =>
    onEvent<'click' | 'dblclick'>('native-player://click', cb);
  browserTabNew = (options: { kind?: 'history'; address?: string } = {}) =>
    call<number>('browser_tab_new', {
      kind: options.kind ?? null,
      address: options.address ?? null,
    });
  browserTabClose = (id: number) => call<void>('browser_tab_close', { id });
  browserTabSelect = (target: { id?: number; step?: number }) =>
    call<void>('browser_tab_select', { id: target.id ?? null, step: target.step ?? null });
  browserHistory = (query: string) => call<Visit[]>('browser_history', { query, limit: null });
  browserHistoryDelete = (id: number) => call<void>('browser_history_delete', { id });
  browserHistoryClear = () => call<number>('browser_history_clear');
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

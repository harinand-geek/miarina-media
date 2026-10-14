// Single entry point to the native backend. Inside Tauri every call goes to
// a validated Rust command; in a plain browser (UI preview, tests) a mock
// that honors the same contract and events is used instead.

import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { MockBackend } from '../dev/mockBackend';
import { checkLink } from './link';
import { inTauri } from './platform';
import type {
  AnalyzeResult,
  BackendEvent,
  BackendSettings,
  CommandError,
  ComponentStatus,
  InstallProgress,
  HistoryEntry,
  MediaInfo,
  ResourceMode,
  StartRequest,
  TaskRecord,
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
  subscribe(listener: (event: BackendEvent) => void): () => void;
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
    let unlisten: (() => void) | undefined;
    let closed = false;
    void listen<BackendEvent>('downloads://event', (e) => listener(e.payload)).then((fn) => {
      if (closed) fn();
      else unlisten = fn;
    });
    return () => {
      closed = true;
      unlisten?.();
    };
  }
}

// `let` + live ES module binding: importers always see the current backend.
export let backend: Backend = inTauri() ? new TauriBackend() : new MockBackend();

/** Test helper: start every test from a fresh mock. */
export function resetMockBackend() {
  backend = new MockBackend();
  return backend;
}

/**
 * Screens still backed by development fixtures: the media library, its
 * overview cards and the player arrive in Phase 3.
 */
export const LIBRARY_USES_FIXTURES = true;

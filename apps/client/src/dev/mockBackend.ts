// In-browser stand-in for the Rust backend (UI preview and tests). It follows
// the same contract: validated transitions, bounded concurrency, throttled
// progress events. It never touches the file system or the network.

import { checkLink } from '../services/link';
import type {
  AppScreenRequest,
  BrowserAction,
  BrowserSnapshot,
  AnalyzeResult,
  BackendEvent,
  BackendSettings,
  ComponentStatus,
  InstallProgress,
  HistoryEntry,
  LibraryOverview,
  Limits,
  MediaPage,
  MediaQuery,
  MediaRecord,
  ResourceMode,
  StartRequest,
  StorageUsage,
  TaskRecord,
  TaskState,
} from '../services/types';
import { ANALYZED, DOWNLOADS, HISTORY, LIBRARY, NO_MEDIA_HOSTS } from './fixtures';

const sizeBytes = (size: string) =>
  Math.round(
    parseFloat(size) * (size.includes('GB') ? 1024 ** 3 : size.includes('KB') ? 1024 : 1024 ** 2),
  );

/** Library rows built from the design fixtures. */
function seedLibrary(): MediaRecord[] {
  const now = Date.now();
  return LIBRARY.map((item, i) => {
    const height = Number.parseInt(item.quality, 10) || (item.quality === '4K' ? 2160 : null);
    return {
      id: i + 1,
      path: `C:\\Users\\Rina\\Videos\\Miarina\\${item.title}.${item.kind === 'video' ? 'mp4' : 'mp3'}`,
      title: item.title,
      kind: item.kind,
      sourceHost: item.source,
      sourceUrl: `https://example.org/${item.id}`,
      taskId: null,
      sizeBytes: sizeBytes(item.size),
      durationSecs: item.durationSec,
      width: height ? Math.round((height * 16) / 9) : null,
      height: item.kind === 'video' ? height : null,
      videoCodec: item.kind === 'video' ? 'h264' : null,
      audioCodec: item.kind === 'video' ? 'aac' : item.quality.startsWith('FLAC') ? 'flac' : 'mp3',
      container: item.kind === 'video' ? 'mov' : 'mp3',
      thumbnail: null,
      probed: true,
      missing: false,
      addedAt: now - i * 3_600_000,
      modifiedAt: now - i * 3_600_000,
    };
  });
}

const MB = 1024 * 1024;
const ANALYSIS_DELAY_MS = 900;
const MAX_USER_DOWNLOADS = 8;
/** Links on this host need the (mock) media tools to be installed first. */
export const NEEDS_TOOLS_HOST = 'needs-tools.test';

/** Mirror of `resource_manager::limits` for Windows. */
export function mockLimits(mode: ResourceMode, userDownloads: number): Limits {
  const user = Math.min(MAX_USER_DOWNLOADS, Math.max(1, userDownloads));
  switch (mode) {
    case 'eco':
      return {
        maxDownloads: 1,
        maxConversions: 1,
        ffmpegThreads: 1,
        concurrentFragments: 1,
        progressInterval: 2000,
        thumbnailPx: 240,
        childPriority: 'below_normal',
        reducedMotion: true,
      };
    case 'balanced':
      return {
        maxDownloads: Math.min(user, 3),
        maxConversions: 1,
        ffmpegThreads: 2,
        concurrentFragments: 2,
        progressInterval: 1000,
        thumbnailPx: 360,
        childPriority: 'normal',
        reducedMotion: false,
      };
    case 'performance':
      return {
        maxDownloads: user,
        maxConversions: 2,
        ffmpegThreads: 4,
        concurrentFragments: 4,
        progressInterval: 1000,
        thumbnailPx: 480,
        childPriority: 'normal',
        reducedMotion: false,
      };
  }
}

/** Mirror of `TaskState::can_transition`. */
const TRANSITIONS: Record<TaskState, TaskState[]> = {
  queued: ['analyzing', 'waiting', 'failed', 'canceled'],
  analyzing: ['waiting', 'failed', 'canceled'],
  waiting: ['downloading', 'paused', 'canceled'],
  downloading: ['processing', 'completed', 'paused', 'waiting', 'failed', 'canceled'],
  paused: ['waiting', 'canceled'],
  processing: ['completed', 'failed', 'canceled'],
  completed: [],
  failed: ['queued', 'canceled'],
  canceled: [],
};

type MockTask = TaskRecord & { speedMb: number };

let seq = 0;

export class MockBackend {
  readonly kind = 'mock' as const;
  private tasks = new Map<string, MockTask>();
  private history: HistoryEntry[] = [...HISTORY];
  private settings: BackendSettings;
  private library: MediaRecord[] = seedLibrary();
  private libraryListeners = new Set<() => void>();
  private listeners = new Set<(e: BackendEvent) => void>();
  private timer: ReturnType<typeof setInterval> | undefined;
  private lastTick = 0;
  private toolsInstalled = false;
  private browser: BrowserSnapshot = { ...BROWSER_START };
  private browserListeners = new Set<(state: BrowserSnapshot) => void>();

  constructor() {
    const now = Date.now();
    DOWNLOADS.forEach((seed, i) => {
      const total = seed.mb * MB;
      this.tasks.set(seed.id, {
        id: seed.id,
        url: `https://${seed.host}/${seed.id}`,
        sourceHost: seed.host,
        title: seed.title,
        kind: seed.kind,
        engine: 'http',
        formatId: null,
        formatLabel: seed.format,
        state: seed.state,
        position: i + 1,
        destDir: 'C:\\Users\\Rina\\Videos\\Miarina',
        fileName: `${seed.title}.mp4`,
        partPath: null,
        finalPath: null,
        totalBytes: total,
        downloadedBytes: Math.round((total * seed.percent) / 100),
        supportsResume: true,
        attempts: 0,
        errorCode: null,
        errorMessage: null,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
        speedMb: seed.speed,
      });
    });
    this.settings = {
      downloadDir: 'C:\\Users\\Rina\\Videos\\Miarina',
      concurrency: 3,
      resourceMode: 'balanced',
      limits: mockLimits('balanced', 3),
    };
  }

  // ------------------------------------------------------------- contract

  async analyze(url: string, signal?: AbortSignal): Promise<AnalyzeResult> {
    const link = await checkLink(url);
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
      return { ok: false, reason: 'no_media', message: 'live streams are not supported' };
    }
    if (host === NEEDS_TOOLS_HOST && !this.toolsInstalled) {
      return { ok: false, reason: 'needs_components', components: this.components() };
    }
    return { ok: true, info: { ...ANALYZED, url: link.url, host } };
  }

  async listTasks() {
    return this.open().map(strip);
  }

  async start(request: StartRequest) {
    const id = `m${Date.now().toString(16)}${++seq}`;
    const now = Date.now();
    const position = Math.max(0, ...[...this.tasks.values()].map((t) => t.position)) + 1;
    const task: MockTask = {
      id,
      url: request.url,
      sourceHost: new URL(request.url).hostname,
      title: request.title,
      kind: request.kind,
      engine: request.engine,
      formatId: request.formatId,
      formatLabel: request.formatLabel,
      state: 'queued',
      position,
      destDir: this.settings.downloadDir,
      fileName: `${request.title}.${request.extension}`,
      partPath: null,
      finalPath: null,
      totalBytes: 300 * MB,
      downloadedBytes: 0,
      supportsResume: true,
      attempts: 0,
      errorCode: null,
      errorMessage: null,
      createdAt: now,
      updatedAt: now,
      completedAt: null,
      speedMb: 8,
    };
    this.tasks.set(id, task);
    this.emitTask(task);
    if (request.startNow) {
      this.transition(id, 'waiting');
      this.transition(id, 'downloading');
    }
    this.schedule();
    return strip(this.tasks.get(id)!);
  }

  async pause(id: string) {
    const t = this.get(id);
    if (t.state === 'queued') this.transition(id, 'waiting');
    if (t.state !== 'paused') this.transition(id, 'paused');
    this.schedule();
  }

  async resume(id: string) {
    if (this.get(id).state === 'paused') this.transition(id, 'waiting');
    this.schedule();
  }

  async cancel(id: string) {
    const t = this.get(id);
    this.transition(id, 'canceled');
    this.addHistory(t, 'canceled', null);
    this.tasks.delete(id);
    this.schedule();
  }

  async retry(id: string) {
    this.transition(id, 'queued');
    this.schedule();
  }

  async startNow(id: string) {
    const t = this.get(id);
    if (t.state === 'paused' || t.state === 'queued') this.transition(id, 'waiting');
    this.transition(id, 'downloading');
    this.ensureTimer();
  }

  async move(id: string, index: number) {
    const ids = this.open().map((t) => t.id);
    const from = ids.indexOf(id);
    if (from < 0) return;
    ids.splice(from, 1);
    ids.splice(Math.min(index, ids.length), 0, id);
    ids.forEach((taskId, i) => {
      const t = this.tasks.get(taskId)!;
      t.position = i + 1;
      this.emitTask(t);
    });
  }

  async pauseAll() {
    for (const t of this.open()) {
      if (t.state === 'downloading' || t.state === 'waiting' || t.state === 'queued') {
        await this.pause(t.id);
      }
    }
  }

  async resumeAll() {
    for (const t of this.open()) if (t.state === 'paused') this.transition(t.id, 'waiting');
    this.schedule();
  }

  async reveal() {
    throw new Error('Showing files is only available in the desktop app.');
  }

  async listHistory() {
    return [...this.history];
  }

  async clearHistory() {
    this.history = [];
  }

  async revealHistory() {
    throw new Error('Showing files is only available in the desktop app.');
  }

  async getSettings() {
    return { ...this.settings };
  }

  async setConcurrency(value: number) {
    const concurrency = Math.min(MAX_USER_DOWNLOADS, Math.max(1, value));
    this.settings = {
      ...this.settings,
      concurrency,
      limits: mockLimits(this.settings.resourceMode, concurrency),
    };
    this.schedule();
    return { ...this.settings };
  }

  async setResourceMode(mode: ResourceMode) {
    this.settings = {
      ...this.settings,
      resourceMode: mode,
      limits: mockLimits(mode, this.settings.concurrency),
    };
    this.restartTimer();
    this.schedule();
    return { ...this.settings };
  }

  async pickDownloadDir() {
    return null;
  }

  // ------------------------------------------------------------- library

  async libraryQuery(query: MediaQuery): Promise<MediaPage> {
    const words = query.search
      .toLowerCase()
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .split(/[^\p{L}\p{N}]+/u)
      .filter(Boolean);
    const text = (m: MediaRecord) =>
      `${m.title} ${m.sourceHost ?? ''}`
        .toLowerCase()
        .normalize('NFD')
        .replace(/\p{Diacritic}/gu, '');
    const matches = this.library.filter(
      (m) =>
        !m.missing &&
        (!query.kind || m.kind === query.kind) &&
        words.every((w) =>
          text(m)
            .split(/[^\p{L}\p{N}]+/u)
            .some((t) => t.startsWith(w)),
        ),
    );
    const compare: Record<MediaQuery['sort'], (a: MediaRecord, b: MediaRecord) => number> = {
      added: (a, b) => b.addedAt - a.addedAt,
      title: (a, b) => a.title.localeCompare(b.title),
      size: (a, b) => b.sizeBytes - a.sizeBytes,
      duration: (a, b) => (b.durationSecs ?? -1) - (a.durationSecs ?? -1),
    };
    const sorted = [...matches].sort(compare[query.sort]);
    const offset = query.offset ?? 0;
    return { items: sorted.slice(offset, offset + (query.limit || 10_000)), total: matches.length };
  }

  async libraryOverview(): Promise<LibraryOverview> {
    const present = this.library.filter((m) => !m.missing);
    const sum = (list: MediaRecord[]) => list.reduce((acc, m) => acc + m.sizeBytes, 0);
    const video = present.filter((m) => m.kind === 'video');
    const audio = present.filter((m) => m.kind === 'audio');
    return {
      stats: {
        count: present.length,
        totalBytes: sum(present),
        videoCount: video.length,
        videoBytes: sum(video),
        audioCount: audio.length,
        audioBytes: sum(audio),
      },
      disk: { free: 140 * 1024 ** 3, total: 256 * 1024 ** 3 },
      downloadDir: this.settings.downloadDir,
    };
  }

  async libraryGet(id: number) {
    const item = this.library.find((m) => m.id === id);
    if (!item) throw new Error('This item is no longer in the library.');
    return { ...item };
  }

  async libraryRename(id: number, title: string) {
    const item = await this.libraryGet(id);
    const clean = title.replace(/[<>:"/\\|?*]/g, '_').trim() || 'download';
    const renamed = {
      ...item,
      title: clean,
      path: item.path.replace(/[^\\]+(\.\w+)$/, `${clean}$1`),
    };
    this.library = this.library.map((m) => (m.id === id ? renamed : m));
    this.libraryChanged();
    return renamed;
  }

  async libraryDelete(id: number) {
    await this.libraryGet(id);
    this.library = this.library.filter((m) => m.id !== id);
    this.libraryChanged();
  }

  async libraryReveal() {
    throw new Error('Showing files is only available in the desktop app.');
  }

  async libraryOpenExternal() {
    throw new Error('Opening files is only available in the desktop app.');
  }

  async libraryRescan() {}

  async openDownloadFolder() {
    throw new Error('Opening folders is only available in the desktop app.');
  }

  onLibraryChanged(listener: () => void) {
    this.libraryListeners.add(listener);
    return () => this.libraryListeners.delete(listener);
  }

  /** The mock has no files: the player shows its placeholder surface. */
  mediaUrl() {
    return '';
  }

  async storageUsage(): Promise<StorageUsage> {
    const overview = await this.libraryOverview();
    return {
      downloadDir: this.settings.downloadDir,
      disk: overview.disk,
      libraryBytes: overview.stats.totalBytes,
      thumbnailBytes: 412 * MB,
      orphanTempBytes: 1.2 * 1024 * MB,
      orphanTempCount: 2,
    };
  }

  async clearThumbnails() {
    return 412 * MB;
  }

  async cleanTemp() {
    return 1.2 * 1024 * MB;
  }

  // Built-in browser: the preview has no second window. The state below
  // drives the browser UI and overlay pages in tests and the dev preview.

  async openBrowser() {
    return false;
  }

  async browserNavigate(address: string) {
    // Same rule as `parse_address` in Rust: a bare host gets https://.
    const text = address.trim();
    const bare =
      !text.includes('://') &&
      !/\s/.test(text) &&
      (text.includes('.') || text.startsWith('localhost'));
    const link = await checkLink(bare ? `https://${text}` : text.includes('://') ? text : '');
    if (!link.ok) throw new Error('Enter a web address, like example.org');
    this.setBrowser({ ...BROWSER_DEMO, url: link.url });
    return link.url;
  }

  async browserNav(action: BrowserAction) {
    if (action === 'home') this.setBrowser({ ...BROWSER_START });
  }

  async browserState() {
    return this.browser;
  }

  async browserSheet(open: boolean) {
    this.setBrowser({ ...this.browser, sheet: open && !this.browser.startPage });
  }

  async browserFabSize() {}

  async browserShowInApp(screen: AppScreenRequest) {
    void screen;
  }

  onBrowserState(listener: (state: BrowserSnapshot) => void) {
    this.browserListeners.add(listener);
    return () => this.browserListeners.delete(listener);
  }

  onBrowserShortcut() {
    return () => {};
  }

  onAppNavigate() {
    return () => {};
  }

  /** Test helper: puts the browser on the demo page. */
  showBrowserDemo(patch: Partial<BrowserSnapshot> = {}) {
    this.setBrowser({ ...BROWSER_DEMO, ...patch });
  }

  private setBrowser(next: BrowserSnapshot) {
    this.browser = next;
    for (const listener of this.browserListeners) listener(next);
  }

  private libraryChanged() {
    for (const listener of this.libraryListeners) listener();
  }

  async componentsStatus() {
    return this.components();
  }

  async installComponents(onProgress: (p: InstallProgress) => void) {
    for (const c of this.components()) {
      onProgress({ id: c.id, name: c.name, downloaded: c.downloadBytes, total: c.downloadBytes });
    }
    this.toolsInstalled = true;
    return this.components();
  }

  private components(): ComponentStatus[] {
    const installed = this.toolsInstalled;
    return [
      {
        id: 'yt_dlp',
        name: 'yt-dlp',
        version: '2026.08.19',
        license: 'Unlicense',
        downloadBytes: 17_840_399,
        installed,
        bundled: false,
      },
      {
        id: 'ffmpeg',
        name: 'FFmpeg',
        version: 'n8.1.2 (LGPL)',
        license: 'LGPL-3.0-or-later',
        downloadBytes: 70_835_150,
        installed,
        bundled: false,
      },
    ];
  }

  subscribe(listener: (event: BackendEvent) => void) {
    this.listeners.add(listener);
    this.schedule();
    this.ensureTimer();
    return () => {
      this.listeners.delete(listener);
      if (this.listeners.size === 0) this.stopTimer();
    };
  }

  // ------------------------------------------------------------ internals

  private open() {
    return [...this.tasks.values()]
      .filter((t) => t.state !== 'completed' && t.state !== 'canceled')
      .sort((a, b) => a.position - b.position);
  }

  private get(id: string) {
    const t = this.tasks.get(id);
    if (!t) throw new Error(`task ${id} not found`);
    return t;
  }

  private transition(id: string, to: TaskState) {
    const t = this.get(id);
    if (!TRANSITIONS[t.state].includes(to)) {
      throw new Error(`invalid task transition from ${t.state} to ${to}`);
    }
    t.state = to;
    t.updatedAt = Date.now();
    if (to === 'completed') t.completedAt = t.updatedAt;
    this.emitTask(t);
  }

  private schedule() {
    const running = this.open().filter((t) => t.state === 'downloading').length;
    let free = this.settings.limits.maxDownloads - running;
    for (const t of this.open()) {
      if (free <= 0) break;
      if (t.state === 'queued' || t.state === 'waiting') {
        if (t.state === 'queued') this.transition(t.id, 'waiting');
        this.transition(t.id, 'downloading');
        free--;
      }
    }
    this.ensureTimer();
  }

  private tick = () => {
    const now = Date.now();
    const seconds = (now - this.lastTick) / 1000;
    this.lastTick = now;
    for (const t of this.open()) {
      if (t.state !== 'downloading') continue;
      const total = t.totalBytes ?? 0;
      t.downloadedBytes = Math.min(total, t.downloadedBytes + t.speedMb * MB * seconds);
      const bytesPerSec = t.speedMb * MB;
      this.emit({
        type: 'progress',
        payload: {
          id: t.id,
          downloaded: t.downloadedBytes,
          total: t.totalBytes,
          bytesPerSec,
          supportsResume: t.supportsResume,
          etaSecs: Math.ceil((total - t.downloadedBytes) / bytesPerSec),
        },
      });
      if (t.downloadedBytes >= total) {
        t.finalPath = `${t.destDir}\\${t.fileName}`;
        this.transition(t.id, 'completed');
        this.addHistory(t, 'completed', null);
      }
    }
    this.schedule();
    if (!this.open().some((t) => t.state === 'downloading')) this.stopTimer();
  };

  private ensureTimer() {
    if (this.timer || this.listeners.size === 0) return;
    if (!this.open().some((t) => t.state === 'downloading')) return;
    this.lastTick = Date.now();
    this.timer = setInterval(this.tick, this.settings.limits.progressInterval);
  }

  private stopTimer() {
    clearInterval(this.timer);
    this.timer = undefined;
  }

  private restartTimer() {
    this.stopTimer();
    this.ensureTimer();
  }

  private addHistory(t: MockTask, status: HistoryEntry['status'], reason: string | null) {
    const entry: HistoryEntry = {
      id: Date.now() + ++seq,
      taskId: t.id,
      url: t.url,
      title: t.title,
      sourceHost: t.sourceHost,
      formatLabel: t.formatLabel,
      totalBytes: t.totalBytes,
      doneBytes: t.downloadedBytes,
      status,
      reason,
      finalPath: t.finalPath,
      finishedAt: Date.now(),
    };
    this.history = [entry, ...this.history];
    this.emit({ type: 'history', payload: entry });
  }

  private emitTask(t: MockTask) {
    this.emit({ type: 'task', payload: strip(t) });
  }

  private emit(event: BackendEvent) {
    for (const listener of this.listeners) listener(event);
  }
}

const BROWSER_START: BrowserSnapshot = {
  url: '',
  title: '',
  loading: false,
  canGoBack: false,
  canGoForward: false,
  startPage: true,
  sheet: false,
  media: [],
  streamPlayer: false,
};

const BROWSER_DEMO: BrowserSnapshot = {
  url: 'https://studio.blender.org/films/sprite-fright/',
  title: 'Sprite Fright — Blender Studio',
  loading: false,
  canGoBack: true,
  canGoForward: false,
  startPage: false,
  sheet: false,
  media: [
    {
      kind: 'video',
      url: 'https://video.blender.org/sprite-fright.mp4',
      host: 'video.blender.org',
      name: 'sprite-fright.mp4',
      sizeBytes: 372 * MB,
      via: 'page',
    },
    {
      kind: 'video',
      url: 'https://video.blender.org/sprite-fright-trailer.mp4',
      host: 'video.blender.org',
      name: 'sprite-fright-trailer.mp4',
      sizeBytes: null,
      via: 'network',
    },
  ],
  streamPlayer: false,
};

function strip(task: MockTask): TaskRecord {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { speedMb, ...record } = task;
  return { ...record };
}

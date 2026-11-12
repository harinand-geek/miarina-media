// In-browser stand-in for the Rust backend (UI preview and tests). It follows
// the same contract: validated transitions, bounded concurrency, throttled
// progress events. It never touches the file system or the network.

import { checkLink } from '../services/link';
import type {
  AnalyzeResult,
  AppScreenRequest,
  BackendEvent,
  BackendSettings,
  BrowserAction,
  BrowserSnapshot,
  BrowserTab,
  BrowserTabKind,
  ComponentStatus,
  Favorite,
  GroupBy,
  HistoryEntry,
  InstallProgress,
  LibraryOverview,
  Limits,
  MediaGroup,
  Playlist,
  PlaylistImport,
  PlaylistSummary,
  MediaPage,
  MediaQuery,
  MediaRecord,
  MediaTags,
  ResourceMode,
  StartRequest,
  StorageUsage,
  TaskRecord,
  TaskState,
  Visit,
  YtDlpUpdate,
} from '../services/types';
import { ANALYZED, DOWNLOADS, HISTORY, LIBRARY, NO_MEDIA_HOSTS } from './fixtures';

const sizeBytes = (size: string) =>
  Math.round(
    parseFloat(size) * (size.includes('GB') ? 1024 ** 3 : size.includes('KB') ? 1024 : 1024 ** 2),
  );

/** Library rows built from the design fixtures. */
const same = (a: string | null | undefined, b: string) =>
  !!a && a.localeCompare(b, undefined, { sensitivity: 'accent' }) === 0;
const folderOf = (path: string) => path.slice(0, Math.max(0, path.search(/[\\/][^\\/]*$/)));

/** Fictitious tags for the audio fixtures (Musopen, NASA). */
const MOCK_TAGS: Record<string, Partial<MediaRecord>> = {
  'Gymnopédie No. 1 — Satie': {
    artist: 'Erik Satie',
    album: 'Musopen Piano',
    albumArtist: 'Musopen',
    year: 2012,
    genre: 'Classique',
    trackNo: 1,
  },
  'Clair de Lune — Debussy': {
    artist: 'Claude Debussy',
    album: 'Musopen Piano',
    albumArtist: 'Musopen',
    year: 2012,
    genre: 'Classique',
    trackNo: 2,
  },
  'Voyager Golden Record — Sounds of Earth': {
    artist: 'NASA',
    album: 'Voyager Golden Record',
    year: 1977,
    trackNo: 1,
  },
};

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
      ...MOCK_TAGS[item.title],
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
  waiting: ['downloading', 'paused', 'failed', 'canceled'],
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
  private tagExtras = new Map<number, { comment: string | null; lyrics: string | null }>();
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
        thumbnail: null,
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
      thumbnail: request.thumbnail ?? null,
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

  async restart(id: string) {
    const t = this.get(id);
    t.downloadedBytes = 0;
    this.transition(id, t.state === 'paused' ? 'waiting' : 'queued');
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
      `${m.title} ${m.sourceHost ?? ''} ${m.artist ?? ''} ${m.album ?? ''}`
        .toLowerCase()
        .normalize('NFD')
        .replace(/\p{Diacritic}/gu, '');
    const matches = this.library.filter(
      (m) =>
        !m.missing &&
        (!query.kind || m.kind === query.kind) &&
        (!query.album || same(m.album, query.album)) &&
        (!query.artist || same(m.artist, query.artist) || same(m.albumArtist, query.artist)) &&
        (!query.folder || folderOf(m.path).startsWith(query.folder)) &&
        (!query.favorites || m.favorite) &&
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
    const byTrack = (a: MediaRecord, b: MediaRecord) =>
      (a.discNo ?? 1) - (b.discNo ?? 1) || (a.trackNo ?? 9999) - (b.trackNo ?? 9999);
    const sorted = [...matches].sort(query.album ? byTrack : compare[query.sort]);
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

  async libraryTags(id: number): Promise<MediaTags> {
    const m = await this.libraryGet(id);
    return {
      title: m.title,
      artist: m.artist ?? null,
      album: m.album ?? null,
      albumArtist: m.albumArtist ?? null,
      year: m.year ?? null,
      genre: m.genre ?? null,
      trackNo: m.trackNo ?? null,
      discNo: m.discNo ?? null,
      comment: this.tagExtras.get(id)?.comment ?? null,
      lyrics: this.tagExtras.get(id)?.lyrics ?? null,
    };
  }

  async libraryUpdateTags(id: number, tags: MediaTags, writeToFile: boolean) {
    const m = await this.libraryGet(id);
    if (writeToFile && m.kind === 'video') {
      throw new Error('Tags cannot be written into this file type; they were not saved.');
    }
    const clean = (v: string | null) => (v?.trim() ? v.trim() : null);
    const updated: MediaRecord = {
      ...m,
      title: clean(tags.title) ?? m.title,
      artist: clean(tags.artist),
      album: clean(tags.album),
      albumArtist: clean(tags.albumArtist),
      year: tags.year,
      genre: clean(tags.genre),
      trackNo: tags.trackNo,
      discNo: tags.discNo,
      modifiedAt: Date.now(),
    };
    this.tagExtras.set(id, { comment: clean(tags.comment), lyrics: clean(tags.lyrics) });
    this.library = this.library.map((x) => (x.id === id ? updated : x));
    this.libraryChanged();
    return updated;
  }

  // ------------------------------------------------- favorites, playlists

  private lists: { id: number; name: string; ids: number[]; updatedAt: number }[] = [];
  private nextList = 1;

  private summary(list: { id: number; name: string; ids: number[]; updatedAt: number }) {
    const items = list.ids
      .map((id) => this.library.find((m) => m.id === id))
      .filter((m): m is MediaRecord => !!m);
    return {
      id: list.id,
      name: list.name,
      count: items.length,
      durationSecs: items.reduce((acc, m) => acc + (m.durationSecs ?? 0), 0),
      covers: items.flatMap((m) => (m.thumbnail ? [m.thumbnail] : [])).slice(0, 4),
      updatedAt: list.updatedAt,
    };
  }

  private list(id: number) {
    const list = this.lists.find((l) => l.id === id);
    if (!list) throw new Error('This playlist no longer exists.');
    return list;
  }

  private touch(list: { updatedAt: number }) {
    list.updatedAt = Date.now() + this.nextList;
  }

  // ------------------------------------------------------------- covers

  private coverSeq = 0;

  private setCover(id: number, thumbnail: string | null) {
    const m = this.library.find((x) => x.id === id);
    if (!m) throw new Error('This item is no longer in the library.');
    const updated: MediaRecord = { ...m, thumbnail, coverCustom: true };
    this.library = this.library.map((x) => (x.id === id ? updated : x));
    this.libraryChanged();
    return { ...updated };
  }

  /** The mock "picks" a picture without a dialog. */
  async libraryCoverPick(id: number) {
    return this.setCover(id, `mock://covers/${id}-${++this.coverSeq}.jpg`);
  }

  async libraryCoverSource(id: number) {
    if (!(await this.libraryHasSourceCover(id))) throw new Error('the source gave no thumbnail');
    return this.setCover(id, `mock://covers/${id}-${++this.coverSeq}.jpg`);
  }

  async libraryCoverFrame(id: number, atSecs: number) {
    const m = await this.libraryGet(id);
    if (m.kind !== 'video') throw new Error('only videos have frames');
    return this.setCover(id, `mock://covers/${id}-${++this.coverSeq}-${Math.round(atSecs)}s.jpg`);
  }

  async libraryCoverRemove(id: number) {
    return this.setCover(id, null);
  }

  async libraryHasSourceCover(id: number) {
    return !!this.library.find((m) => m.id === id)?.sourceUrl;
  }

  async librarySetFavorite(id: number, favorite: boolean) {
    const item = await this.libraryGet(id);
    const updated = { ...item, favorite };
    this.library = this.library.map((m) => (m.id === id ? updated : m));
    return { ...updated };
  }

  async playlists(): Promise<PlaylistSummary[]> {
    return [...this.lists].sort((a, b) => b.updatedAt - a.updatedAt).map((l) => this.summary(l));
  }

  async playlistGet(id: number): Promise<Playlist> {
    const list = this.list(id);
    const items = list.ids
      .map((i) => this.library.find((m) => m.id === i))
      .filter((m): m is MediaRecord => !!m)
      .map((m) => ({ ...m }));
    return { id, name: list.name, items };
  }

  async playlistCreate(name: string, ids: number[]) {
    const clean = name.trim();
    if (!clean) throw new Error('A playlist needs a name.');
    const list = {
      id: this.nextList++,
      name: clean.slice(0, 120),
      ids: ids.filter((id) => this.library.some((m) => m.id === id)),
      updatedAt: 0,
    };
    this.touch(list);
    this.lists.push(list);
    return this.summary(list);
  }

  async playlistRename(id: number, name: string) {
    const list = this.list(id);
    if (!name.trim()) throw new Error('A playlist needs a name.');
    list.name = name.trim().slice(0, 120);
    this.touch(list);
  }

  async playlistDelete(id: number) {
    this.list(id);
    this.lists = this.lists.filter((l) => l.id !== id);
  }

  async playlistAdd(id: number, ids: number[]) {
    const list = this.list(id);
    list.ids.push(...ids.filter((i) => this.library.some((m) => m.id === i)));
    this.touch(list);
  }

  async playlistRemove(id: number, index: number) {
    const list = this.list(id);
    list.ids.splice(index, 1);
    this.touch(list);
  }

  async playlistMove(id: number, from: number, to: number) {
    const list = this.list(id);
    const [item] = list.ids.splice(from, 1);
    if (item !== undefined) list.ids.splice(to, 0, item);
    this.touch(list);
  }

  /** Preview: pretends an M3U listed the audio items and one unknown file. */
  async playlistImport(): Promise<PlaylistImport> {
    const ids = this.library.filter((m) => m.kind === 'audio').map((m) => m.id);
    const playlist = await this.playlistCreate('Imported', ids);
    return { playlist, added: ids.length, skipped: 1 };
  }

  async playlistExport(id: number) {
    return ['C:', 'Users', 'Rina', 'Music', `${this.list(id).name}.m3u8`].join('\\');
  }

  async libraryGroups(by: GroupBy): Promise<MediaGroup[]> {
    const groups = new Map<string, MediaGroup & { albums: Set<string> }>();
    for (const m of this.library) {
      if (m.missing || m.kind !== 'audio') continue;
      const name = by === 'album' ? m.album : by === 'artist' ? m.artist : folderOf(m.path);
      if (!name) continue;
      const key = name.toLowerCase();
      const g = groups.get(key) ?? {
        name,
        detail: null,
        count: 0,
        durationSecs: 0,
        year: null,
        thumbnail: null,
        albums: new Set<string>(),
      };
      g.count += 1;
      g.durationSecs += m.durationSecs ?? 0;
      g.year = Math.max(g.year ?? 0, m.year ?? 0) || null;
      if (by === 'album') g.detail = m.albumArtist ?? m.artist ?? g.detail;
      if (m.album) g.albums.add(m.album.toLowerCase());
      if (by === 'artist') g.detail = String(g.albums.size);
      groups.set(key, g);
    }
    return [...groups.values()]
      .map((g): MediaGroup => ({
        name: g.name,
        detail: g.detail,
        count: g.count,
        durationSecs: g.durationSecs,
        year: g.year,
        thumbnail: g.thumbnail,
      }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  async libraryRemove(id: number) {
    await this.libraryGet(id);
    this.library = this.library.filter((m) => m.id !== id);
    this.libraryChanged();
  }

  async libraryDelete(id: number) {
    await this.libraryGet(id);
    this.library = this.library.filter((m) => m.id !== id);
    this.libraryChanged();
  }

  async libraryReveal() {
    throw new Error('Showing files is only available in the desktop app.');
  }

  async libraryShare() {}

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
    // Same rule as `resolve_address` in Rust: an address opens the page,
    // anything else is searched.
    const text = address.trim();
    if (!text) throw new Error('Type an address or what you are looking for');
    const bare =
      !text.includes('://') && !/\s/.test(text) && /^[^/?#]*\.[a-z]{2,}([/?#:]|$)/i.test(text);
    if (!text.includes('://') && !bare) {
      const url = `https://www.google.com/search?q=${encodeURIComponent(text)}`;
      this.setBrowser({
        ...BROWSER_START,
        startPage: false,
        url,
        title: `${text} - Google Search`,
      });
      return url;
    }
    const link = await checkLink(bare ? `https://${text}` : text);
    if (!link.ok) throw new Error('Only web pages (http, https) can be opened');
    this.setBrowser({ ...BROWSER_DEMO, url: link.url });
    return link.url;
  }

  async browserNav(action: BrowserAction) {
    if (action === 'home') this.setBrowser({ ...BROWSER_START });
  }

  // Tabs and history (Windows): the mock keeps one snapshot per tab.
  private tabs: { id: number; state: BrowserSnapshot; kind: BrowserTabKind }[] = [];
  private activeTab = 0;
  private nextTab = 0;
  private visits: Visit[] = [];

  private tabList(): BrowserTab[] {
    return this.tabs.map((t) => {
      const state = t.id === this.activeTab ? this.browser : t.state;
      return {
        id: t.id,
        kind: t.kind === 'history' ? 'history' : state.startPage ? 'start' : 'web',
        title: state.title,
        url: state.url,
        media: state.media.length,
        loading: state.loading,
        active: t.id === this.activeTab,
      };
    });
  }

  private ensureTabs() {
    if (this.tabs.length) return;
    this.tabs.push({ id: ++this.nextTab, state: this.browser, kind: 'start' });
    this.activeTab = this.nextTab;
  }

  async browserTabNew(options: { kind?: 'history'; address?: string } = {}) {
    this.ensureTabs();
    if (options.kind === 'history') {
      const existing = this.tabs.find((t) => t.kind === 'history');
      if (existing) {
        await this.browserTabSelect({ id: existing.id });
        return existing.id;
      }
    }
    if (this.tabs.length >= 12) {
      throw Object.assign(new Error('At most 12 tabs can be open'), { code: 'too_many_tabs' });
    }
    this.tabs.find((t) => t.id === this.activeTab)!.state = this.browser;
    const id = ++this.nextTab;
    this.tabs.push({ id, state: { ...BROWSER_START }, kind: options.kind ?? 'start' });
    this.activeTab = id;
    this.setBrowser({ ...BROWSER_START });
    if (options.address) await this.browserNavigate(options.address);
    return id;
  }

  async browserTabSelect(target: { id?: number; step?: number }) {
    this.ensureTabs();
    const at = this.tabs.findIndex((t) => t.id === this.activeTab);
    const next =
      target.id ?? this.tabs[(at + (target.step ?? 0) + this.tabs.length) % this.tabs.length]!.id;
    const tab = this.tabs.find((t) => t.id === next);
    if (!tab) throw new Error('This tab is closed');
    this.tabs[at]!.state = this.browser;
    this.activeTab = next;
    this.setBrowser(tab.state);
  }

  async browserTabClose(id: number) {
    this.ensureTabs();
    const at = this.tabs.findIndex((t) => t.id === id);
    if (at < 0) return;
    this.tabs.splice(at, 1);
    if (!this.tabs.length)
      this.tabs.push({ id: ++this.nextTab, state: { ...BROWSER_START }, kind: 'start' });
    if (id === this.activeTab) {
      const next = this.tabs[Math.min(at, this.tabs.length - 1)]!;
      this.activeTab = next.id;
      this.setBrowser(next.state);
    } else {
      this.setBrowser(this.browser);
    }
  }

  async browserHistory(query: string) {
    const q = query.trim().toLowerCase();
    return this.visits.filter(
      (v) => !q || v.title.toLowerCase().includes(q) || v.url.toLowerCase().includes(q),
    );
  }

  async browserHistoryDelete(id: number) {
    this.visits = this.visits.filter((v) => v.id !== id);
  }

  async browserHistoryClear() {
    const n = this.visits.length;
    this.visits = [];
    return n;
  }

  /** Test helper: pages visited earlier. */
  seedVisits(visits: Visit[]) {
    this.visits = visits;
  }

  async browserState() {
    this.ensureTabs();
    const tab = this.tabs.find((t) => t.id === this.activeTab);
    const state: BrowserSnapshot = {
      ...this.browser,
      kind: tab?.kind === 'history' ? 'history' : this.browser.startPage ? 'start' : 'web',
      tabs: this.tabList(),
    };
    // The floating button gesture is reported once (as on Android).
    if (state.fab) this.browser = { ...state, fab: null };
    return state;
  }

  async browserSheet(open: boolean) {
    this.setBrowser({ ...this.browser, sheet: open && !this.browser.startPage });
  }

  async browserFabSize() {}

  async browserFrame() {
    return null;
  }

  private favorites: Favorite[] = [];

  // Opening files: the preview "opens" the first video of the library.
  async libraryOpenFiles() {
    return this.library.filter((m) => m.kind === 'video').slice(0, 1);
  }

  async libraryImportFolder() {
    return { found: 3, added: 0, restored: 0 };
  }

  onOpened() {
    return () => {};
  }

  // The preview has no libVLC: the WebView player is used.
  async nativePlayerStatus() {
    return { available: false, version: null, reason: 'preview' };
  }

  async nativePlayerOpen() {}

  async nativePlayerControl() {}

  async nativePlayerVolume() {}

  async nativePlayerAddSubtitle() {
    return false;
  }

  async nativePlayerFrame() {}

  onNativePlayerState() {
    return () => {};
  }

  onNativePlayerTracks() {
    return () => {};
  }

  onNativePlayerClick() {
    return () => {};
  }

  async browserFavorites() {
    return this.favorites;
  }

  async browserFavoriteToggle(url: string, title: string) {
    this.favorites = this.favorites.some((f) => f.url === url)
      ? this.favorites.filter((f) => f.url !== url)
      : [{ url, title: title || url }, ...this.favorites];
    return this.favorites;
  }

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
    const tab = this.tabs.find((t) => t.id === this.activeTab);
    if (tab && !next.startPage) {
      tab.kind = 'web';
      if (!this.visits.some((v) => v.url === next.url)) {
        this.visits.unshift({
          id: this.visits.length + 1,
          url: next.url,
          title: next.title,
          visitedAt: Date.now(),
        });
      }
    }
    for (const listener of this.browserListeners) listener(next);
  }

  private libraryChanged() {
    for (const listener of this.libraryListeners) listener();
  }

  async updateYtDlp(): Promise<YtDlpUpdate> {
    return { status: 'up_to_date', version: '2026.08.19', checkedAt: Date.now() };
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
      {
        id: 'quickjs',
        name: 'QuickJS-NG',
        version: '0.17.0',
        license: 'MIT',
        downloadBytes: 2_151_363,
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

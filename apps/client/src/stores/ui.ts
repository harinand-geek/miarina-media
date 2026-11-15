import { create } from 'zustand';
import type { GroupBy, MediaRecord } from '../services/types';

export type Screen =
  | 'home'
  | 'analysis'
  | 'downloads'
  | 'library'
  | 'player'
  | 'now'
  | 'history'
  | 'browser'
  | 'settings'
  | 'torrents';

/** Windows v2 navigation B: "Get" (download) and "Play" (listen & watch) spaces. */
export type Space = 'get' | 'play';
/** Library views of the Play space (playlists and favorites: COM-06, later). */
export type PlaylistDialog =
  /** New playlist, filled with `ids` (empty, or the play queue). */
  | { kind: 'create'; ids: number[] }
  | { kind: 'rename'; id: number; name: string }
  /** Choose a playlist (or a new one) for `ids`. */
  | { kind: 'add'; ids: number[] };

export type LibraryView =
  'tracks' | 'albums' | 'artists' | 'folders' | 'playlists' | 'favorites' | 'videos';

/** An album, artist or folder opened from its grid. */
export interface LibraryGroup {
  by: GroupBy;
  name: string;
}

const PLAY_SCREENS: Screen[] = ['library', 'player', 'now'];
const GET_SCREENS: Screen[] = ['home', 'analysis', 'downloads', 'browser', 'torrents', 'history'];

export function spaceOf(screen: Screen, current: Space): Space {
  if (PLAY_SCREENS.includes(screen)) return 'play';
  if (GET_SCREENS.includes(screen)) return 'get';
  return current;
}

export interface Toast {
  id: number;
  message: string;
  tone: 'success' | 'error';
  action?: { label: string; run: () => void };
}

export interface ConfirmRequest {
  title: string;
  body: string;
  confirmLabel: string;
  onConfirm: () => void;
}

const MAX_TOASTS = 2;
let toastSeq = 0;

export interface AnalysisChoice {
  url: string;
  label: string;
  kind: 'video' | 'audio';
}

interface UiState {
  screen: Screen;
  space: Space;
  libraryView: LibraryView;
  libraryGroup: LibraryGroup | null;
  /** Opened playlist (Playlists view), or null for the list. */
  openPlaylist: number | null;
  /** Entry open in the tag editor (COM-07). */
  tagEditor: MediaRecord | null;
  /** Right panel of "Now playing". */
  nowPanel: 'queue' | 'sound';
  sidebarCollapsed: boolean;
  playerFullscreen: boolean;
  toasts: Toast[];
  confirm: ConfirmRequest | null;
  /** Desktop "Remove or delete" dialog target (COM-10). */
  removal: MediaRecord | null;
  /** Playlist dialogs (COM-06): name a new one, rename, or add entries. */
  playlistDialog: PlaylistDialog | null;
  /** URL waiting to be analyzed (Home → Analysis, Android sheet). */
  pendingUrl: string;
  analysisTab: 'video' | 'audio' | 'subtitles';
  /** Android browser: the page's other media, offered as chips in the sheet (design M3). */
  analysisChoices: AnalysisChoice[];
  nowPlaying: MediaRecord | null;
  /** Android: full-screen player shown (otherwise the mini-player). */
  mobilePlayerExpanded: boolean;
  /** Search or address for the browser to open (Home field → browser). */
  browserRequest: string | null;
  librarySearchFocus: number;
  /** Windows title bar search: focus requests (Ctrl+K) and its open panel. */
  searchFocus: number;
  searchOpen: boolean;
  focusSearch: () => void;
  go: (screen: Screen) => void;
  toggleSidebar: () => void;
  analyze: (url: string, tab?: UiState['analysisTab']) => void;
  /** Analyzes one of the media found on a page; `choices` are all of them. */
  analyzeChoice: (url: string, choices?: AnalysisChoice[]) => void;
  /** Shows the browser and opens `text` there (searched unless it is an address). */
  openInBrowser: (text: string | null) => void;
  setAnalysisTab: (tab: UiState['analysisTab']) => void;
  play: (item: MediaRecord | null) => void;
  focusLibrarySearch: () => void;
  pushToast: (toast: Omit<Toast, 'id'>) => void;
  dismissToast: (id: number) => void;
  askConfirm: (request: ConfirmRequest) => void;
  askRemoval: (media: MediaRecord | null) => void;
  closeConfirm: () => void;
}

export const useUi = create<UiState>((set) => ({
  // Decision 0006 (Windows too): the app opens on the player side, Music › Tracks.
  screen: 'library',
  space: 'play',
  libraryView: 'tracks',
  libraryGroup: null,
  openPlaylist: null,
  tagEditor: null,
  nowPanel: 'queue',
  sidebarCollapsed: false,
  playerFullscreen: false,
  toasts: [],
  confirm: null,
  removal: null,
  playlistDialog: null,
  pendingUrl: '',
  analysisTab: 'video',
  analysisChoices: [],
  nowPlaying: null,
  mobilePlayerExpanded: false,
  browserRequest: null,
  librarySearchFocus: 0,
  searchFocus: 0,
  searchOpen: false,
  focusSearch: () => set((s) => ({ searchFocus: s.searchFocus + 1 })),
  go: (screen) =>
    set((s) => ({
      screen,
      confirm: null,
      removal: null,
      tagEditor: null,
      playlistDialog: null,
      space: spaceOf(screen, s.space),
    })),
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  analyze: (url, tab) =>
    set((s) => ({
      screen: 'analysis',
      space: 'get',
      pendingUrl: url,
      analysisTab: tab ?? s.analysisTab,
      analysisChoices: [],
    })),
  analyzeChoice: (url, choices) =>
    set((s) => ({
      screen: 'analysis',
      space: 'get',
      pendingUrl: url,
      analysisChoices: choices ?? s.analysisChoices,
    })),
  openInBrowser: (browserRequest) =>
    set((s) => ({
      browserRequest,
      screen: browserRequest ? 'browser' : s.screen,
      space: browserRequest ? 'get' : s.space,
    })),
  setAnalysisTab: (analysisTab) => set({ analysisTab }),
  play: (nowPlaying) => set({ nowPlaying, mobilePlayerExpanded: nowPlaying !== null }),
  focusLibrarySearch: () =>
    set((s) => ({
      screen: 'library',
      space: 'play',
      librarySearchFocus: s.librarySearchFocus + 1,
    })),
  pushToast: (toast) =>
    set((s) => ({ toasts: [...s.toasts, { ...toast, id: ++toastSeq }].slice(-MAX_TOASTS) })),
  dismissToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
  askConfirm: (confirm) => set({ confirm }),
  askRemoval: (removal) => set({ removal }),
  closeConfirm: () => set({ confirm: null }),
}));

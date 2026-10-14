import { create } from 'zustand';
import type { LibraryItem } from '../services/types';

export type Screen =
  'home' | 'analysis' | 'downloads' | 'library' | 'player' | 'history' | 'browser' | 'settings';

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

interface UiState {
  screen: Screen;
  sidebarCollapsed: boolean;
  toasts: Toast[];
  confirm: ConfirmRequest | null;
  /** URL waiting to be analyzed (Home → Analysis, Android sheet). */
  pendingUrl: string;
  analysisTab: 'video' | 'audio' | 'subtitles';
  nowPlaying: LibraryItem | null;
  librarySearchFocus: number;
  go: (screen: Screen) => void;
  toggleSidebar: () => void;
  analyze: (url: string, tab?: UiState['analysisTab']) => void;
  setAnalysisTab: (tab: UiState['analysisTab']) => void;
  play: (item: LibraryItem | null) => void;
  focusLibrarySearch: () => void;
  pushToast: (toast: Omit<Toast, 'id'>) => void;
  dismissToast: (id: number) => void;
  askConfirm: (request: ConfirmRequest) => void;
  closeConfirm: () => void;
}

export const useUi = create<UiState>((set) => ({
  screen: 'home',
  sidebarCollapsed: false,
  toasts: [],
  confirm: null,
  pendingUrl: '',
  analysisTab: 'video',
  nowPlaying: null,
  librarySearchFocus: 0,
  go: (screen) => set({ screen, confirm: null }),
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  analyze: (url, tab) =>
    set((s) => ({ screen: 'analysis', pendingUrl: url, analysisTab: tab ?? s.analysisTab })),
  setAnalysisTab: (analysisTab) => set({ analysisTab }),
  play: (nowPlaying) => set({ nowPlaying }),
  focusLibrarySearch: () =>
    set((s) => ({ screen: 'library', librarySearchFocus: s.librarySearchFocus + 1 })),
  pushToast: (toast) =>
    set((s) => ({ toasts: [...s.toasts, { ...toast, id: ++toastSeq }].slice(-MAX_TOASTS) })),
  dismissToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
  askConfirm: (confirm) => set({ confirm }),
  closeConfirm: () => set({ confirm: null }),
}));

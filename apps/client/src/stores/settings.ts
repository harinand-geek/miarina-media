import { create } from 'zustand';
import { mockLimits } from '../dev/mockBackend';
import { backend } from '../services/backend';
import type { BackendSettings, Limits, ResourceMode } from '../services/types';
import type { Lang } from '../i18n';
import { useUi } from './ui';

const LANG_KEY = 'mm:lang';

/** English until every screen reads the catalog (CDC UX-01: no mixed screens by default). */
function initialLang(): Lang {
  try {
    const saved = localStorage.getItem(LANG_KEY);
    if (saved === 'fr' || saved === 'en') return saved;
  } catch {
    // Storage unavailable: keep the default.
  }
  return 'en';
}

export type { ResourceMode } from '../services/types';
export type ThemePref = 'dark' | 'light' | 'system';
export type Density = 'comfortable' | 'compact';

interface SettingsState {
  // Persisted by the backend (SQLite) and applied by the Rust scheduler.
  downloadDir: string;
  /** Separate audio folder (Android shared `Music/Miarina`), if any. */
  audioDownloadDir: string | null;
  resourceMode: ResourceMode;
  concurrency: number;
  /** Limits the backend actually applies for the current mode. */
  limits: Limits;
  loaded: boolean;
  /** Interface language (persisted locally). */
  lang: Lang;
  // UI preferences (not persisted yet).
  theme: ThemePref;
  density: Density;
  reduceMotion: boolean;
  /** Android destination: internal storage or SD card (SAF in Phase 4). */
  androidStore: 'int' | 'sd';
  toggles: {
    launchAtStartup: boolean;
    closeToTray: boolean;
    detectCopiedLinks: boolean;
    subfolderPerSource: boolean;
    hardwareAcceleration: boolean;
    wifiOnlyLargeFiles: boolean;
    progressNotifications: boolean;
  };
  load: () => Promise<void>;
  setResourceMode: (mode: ResourceMode) => void;
  setConcurrency: (n: number) => void;
  pickDownloadDir: () => void;
  setTheme: (theme: ThemePref) => void;
  setLang: (lang: Lang) => void;
  setDensity: (density: Density) => void;
  setReduceMotion: (on: boolean) => void;
  setAndroidStore: (store: 'int' | 'sd') => void;
  toggle: (key: keyof SettingsState['toggles']) => void;
}

export const MIN_CONCURRENCY = 1;
export const MAX_CONCURRENCY = 8;

const fromBackend = (s: BackendSettings) => ({
  downloadDir: s.downloadDir,
  audioDownloadDir: s.audioDownloadDir ?? null,
  resourceMode: s.resourceMode,
  concurrency: s.concurrency,
  limits: s.limits,
  loaded: true,
});

function report(error: unknown) {
  useUi.getState().pushToast({
    tone: 'error',
    message: error instanceof Error ? error.message : String(error),
  });
}

export const useSettings = create<SettingsState>((set, get) => ({
  downloadDir: '',
  audioDownloadDir: null,
  resourceMode: 'balanced',
  concurrency: 3,
  limits: mockLimits('balanced', 3),
  loaded: false,
  lang: initialLang(),
  theme: 'dark',
  density: 'comfortable',
  reduceMotion: false,
  androidStore: 'int',
  toggles: {
    launchAtStartup: true,
    closeToTray: true,
    detectCopiedLinks: true,
    subfolderPerSource: false,
    hardwareAcceleration: true,
    wifiOnlyLargeFiles: true,
    progressNotifications: true,
  },

  load: async () => {
    try {
      set(fromBackend(await backend.getSettings()));
    } catch (e) {
      report(e);
    }
  },
  setResourceMode: (mode) => {
    // Optimistic: the backend answer replaces it with the applied limits.
    set({ resourceMode: mode, limits: mockLimits(mode, get().concurrency) });
    backend
      .setResourceMode(mode)
      .then((s) => set(fromBackend(s)))
      .catch(report);
  },
  setConcurrency: (n) => {
    const concurrency = Math.min(MAX_CONCURRENCY, Math.max(MIN_CONCURRENCY, n));
    set({ concurrency, limits: mockLimits(get().resourceMode, concurrency) });
    backend
      .setConcurrency(concurrency)
      .then((s) => set(fromBackend(s)))
      .catch(report);
  },
  pickDownloadDir: () => {
    backend
      .pickDownloadDir()
      .then((s) => {
        if (s) set(fromBackend(s));
      })
      .catch(report);
  },
  setTheme: (theme) => set({ theme }),
  setLang: (lang) => {
    try {
      localStorage.setItem(LANG_KEY, lang);
    } catch {
      // Not persisted: applies to this session only.
    }
    set({ lang });
  },
  setDensity: (density) => set({ density }),
  setReduceMotion: (reduceMotion) => set({ reduceMotion }),
  setAndroidStore: (androidStore) => set({ androidStore }),
  toggle: (key) => set((s) => ({ toggles: { ...s.toggles, [key]: !s.toggles[key] } })),
}));

/** Simultaneous downloads actually allowed by the backend. */
export const effectiveConcurrency = (s: Pick<SettingsState, 'limits'>) => s.limits.maxDownloads;

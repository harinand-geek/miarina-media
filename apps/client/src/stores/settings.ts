import { create } from 'zustand';

export type ThemePref = 'dark' | 'light' | 'system';
export type Density = 'comfortable' | 'compact';
export type ResourceMode = 'eco' | 'balanced' | 'performance';

export interface ResourceProfile {
  /** Hard cap on simultaneous downloads; `null` means "user setting". */
  maxDownloads: number | null;
  /** Progress refresh interval, in ms. */
  progressIntervalMs: number;
  reducedMotion: boolean;
}

/**
 * Effects of each mode, mirrored from docs/architecture.md §8. In Phase 1
 * they drive the mock scheduler and the UI; Phase 2 moves them to the Rust
 * resource-manager crate.
 */
export const RESOURCE_PROFILES: Record<ResourceMode, ResourceProfile> = {
  eco: { maxDownloads: 1, progressIntervalMs: 2000, reducedMotion: true },
  balanced: { maxDownloads: 3, progressIntervalMs: 1000, reducedMotion: false },
  performance: { maxDownloads: null, progressIntervalMs: 1000, reducedMotion: false },
};

interface SettingsState {
  theme: ThemePref;
  density: Density;
  reduceMotion: boolean;
  resourceMode: ResourceMode;
  concurrency: number;
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
  setTheme: (theme: ThemePref) => void;
  setDensity: (density: Density) => void;
  setReduceMotion: (on: boolean) => void;
  setResourceMode: (mode: ResourceMode) => void;
  setConcurrency: (n: number) => void;
  setAndroidStore: (store: 'int' | 'sd') => void;
  toggle: (key: keyof SettingsState['toggles']) => void;
}

export const MIN_CONCURRENCY = 1;
export const MAX_CONCURRENCY = 8;

export const useSettings = create<SettingsState>((set) => ({
  theme: 'dark',
  density: 'comfortable',
  reduceMotion: false,
  resourceMode: 'balanced',
  concurrency: 3,
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
  setTheme: (theme) => set({ theme }),
  setDensity: (density) => set({ density }),
  setReduceMotion: (reduceMotion) => set({ reduceMotion }),
  setResourceMode: (resourceMode) => set({ resourceMode }),
  setConcurrency: (n) =>
    set({ concurrency: Math.min(MAX_CONCURRENCY, Math.max(MIN_CONCURRENCY, n)) }),
  setAndroidStore: (androidStore) => set({ androidStore }),
  toggle: (key) => set((s) => ({ toggles: { ...s.toggles, [key]: !s.toggles[key] } })),
}));

/** Simultaneous downloads actually allowed: the user value bounded by the mode. */
export function effectiveConcurrency(s: Pick<SettingsState, 'resourceMode' | 'concurrency'>) {
  const cap = RESOURCE_PROFILES[s.resourceMode].maxDownloads;
  return cap === null ? s.concurrency : Math.min(cap, s.concurrency);
}

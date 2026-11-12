import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';
import { inTauri } from '../../services/platform';
import { t } from '../../i18n';
import { useUi } from '../../stores/ui';
import { version } from '../../../package.json';
interface Release {
  version: string;
  notes: string;
  size: number;
}
export type UpdateChannel = 'stable' | 'beta';
export interface UpdatePrefs {
  channel: UpdateChannel;
  autoDownload: boolean;
}
interface Status {
  installed: string;
  release: Release | null;
  ready: boolean;
  downloaded: number;
  downloading: boolean;
}
type Phase = 'idle' | 'checking' | 'available' | 'downloading' | 'ready' | 'installing';
interface State {
  phase: Phase;
  release: Release | null;
  error: string;
  checked: boolean;
  /** Version actually running, as the backend reports it. */
  installed: string;
  /** Bytes already on disk (resumable after a cancel, a failure or a restart). */
  downloaded: number;
  prefs: UpdatePrefs;
  /** After launch: a ready or partial download from an earlier session. */
  restore: () => Promise<void>;
  check: (notify?: boolean) => Promise<void>;
  download: () => Promise<void>;
  cancel: () => Promise<void>;
  install: () => Promise<void>;
  setPrefs: (prefs: Partial<UpdatePrefs>) => Promise<void>;
}
const codeOf = (e: unknown) => (typeof e === 'object' && e && 'code' in e ? String(e.code) : '');
const message = (e: unknown) => {
  if (codeOf(e) === 'update_converting') return t('updConverting');
  if (codeOf(e) === 'update_network') return t('updNetwork');
  return typeof e === 'object' && e && 'message' in e ? String(e.message) : String(e);
};
const BUSY: Phase[] = ['checking', 'downloading', 'ready', 'installing'];

export const useUpdates = create<State>((set, get) => ({
  phase: 'idle',
  release: null,
  error: '',
  checked: false,
  installed: version,
  downloaded: 0,
  prefs: { channel: 'stable', autoDownload: false },
  restore: async () => {
    if (!inTauri()) return;
    try {
      const [status, prefs] = await Promise.all([
        invoke<Status>('app_update_status'),
        invoke<UpdatePrefs>('app_update_prefs'),
      ]);
      set({ prefs, installed: status.installed });
      if (!status.release || get().phase !== 'idle') return;
      set({
        release: status.release,
        downloaded: status.downloaded,
        phase: status.ready ? 'ready' : status.downloading ? 'downloading' : 'available',
      });
    } catch {
      // Nothing restored: the next check starts from scratch.
    }
  },
  check: async (notify = false) => {
    if (!inTauri() || BUSY.includes(get().phase)) return;
    set({ phase: 'checking', error: '' });
    try {
      const release = await invoke<Release | null>('app_update_check');
      const known = get().release;
      set({
        release,
        phase: release ? 'available' : 'idle',
        checked: true,
        // Bytes of another version cannot be resumed.
        downloaded: release && known?.version === release.version ? get().downloaded : 0,
      });
      if (!release) return;
      // UPD-05: only when enabled and on an unmetered network; installing
      // still waits for the user.
      if (await invoke<boolean>('app_update_auto_allowed').catch(() => false)) {
        void get().download();
        return;
      }
      if (notify)
        useUi.getState().pushToast({
          tone: 'success',
          message: t('updAvailable', { v: release.version }),
          action: { label: t('view'), run: () => useUi.getState().go('settings') },
        });
    } catch (e) {
      set({ phase: get().release ? 'available' : 'idle', error: message(e) });
    }
  },
  download: async () => {
    if (get().phase !== 'available') return;
    set({ phase: 'downloading', error: '' });
    try {
      const release = await invoke<Release>('app_update_download');
      set({ release, phase: 'ready', downloaded: release.size });
    } catch (e) {
      const progress = await invoke<number>('app_update_progress').catch(() => get().downloaded);
      set({
        phase: 'available',
        downloaded: progress,
        error: codeOf(e) === 'update_canceled' ? '' : message(e),
      });
    }
  },
  cancel: async () => {
    if (get().phase !== 'downloading') return;
    await invoke('app_update_cancel').catch(() => {});
  },
  install: async () => {
    if (get().phase !== 'ready') return;
    set({ phase: 'installing', error: '' });
    try {
      await invoke('app_update_install');
      set({ phase: 'ready' });
    } catch (e) {
      // The file may have been removed if it no longer matched.
      const status = await invoke<Status>('app_update_status').catch(() => null);
      set({
        phase: status && !status.ready ? (status.release ? 'available' : 'idle') : 'ready',
        error: message(e),
      });
    }
  },
  setPrefs: async (change) => {
    const prefs = { ...get().prefs, ...change };
    set({ prefs });
    if (!inTauri()) return;
    try {
      set({ prefs: await invoke<UpdatePrefs>('app_update_set_prefs', { prefs }) });
    } catch (e) {
      set({ error: message(e) });
    }
  },
}));

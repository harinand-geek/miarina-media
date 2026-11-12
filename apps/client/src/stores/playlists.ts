import { create } from 'zustand';
import { t } from '../i18n';
import { backend } from '../services/backend';
import type { Playlist, PlaylistSummary } from '../services/types';
import { useUi } from './ui';

/**
 * Playlists (CDC COM-06, COM-11): stored in SQLite by the backend; this
 * store keeps the list and the opened playlist.
 */
interface PlaylistsState {
  list: PlaylistSummary[];
  ready: boolean;
  /** The opened playlist, with its entries. */
  current: Playlist | null;
  load: () => Promise<void>;
  open: (id: number | null) => Promise<void>;
  create: (name: string, ids?: number[]) => Promise<PlaylistSummary | null>;
  rename: (id: number, name: string) => Promise<boolean>;
  remove: (id: number) => Promise<boolean>;
  add: (id: number, ids: number[]) => Promise<boolean>;
  removeAt: (id: number, index: number) => Promise<void>;
  move: (id: number, from: number, to: number) => Promise<void>;
  importM3u: () => Promise<void>;
  exportM3u: (id: number) => Promise<void>;
}

function report(e: unknown) {
  useUi
    .getState()
    .pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });
}

const toast = (message: string) => useUi.getState().pushToast({ tone: 'success', message });

export const usePlaylists = create<PlaylistsState>((set, get) => {
  /** Reloads the list and, if open, the current playlist. */
  const reload = async () => {
    const list = await backend.playlists();
    const open = get().current;
    const current = open ? await backend.playlistGet(open.id).catch(() => null) : null;
    set({ list, current, ready: true });
  };
  const run = async (action: () => Promise<unknown>) => {
    try {
      await action();
      await reload();
      return true;
    } catch (e) {
      report(e);
      return false;
    }
  };

  return {
    list: [],
    ready: false,
    current: null,

    load: () => reload().catch(report),

    open: async (id) => {
      if (id === null) {
        set({ current: null });
        return;
      }
      try {
        set({ current: await backend.playlistGet(id) });
      } catch (e) {
        report(e);
        set({ current: null });
      }
    },

    create: async (name, ids = []) => {
      try {
        const created = await backend.playlistCreate(name, ids);
        await reload();
        toast(t('playlistCreated', { name: created.name }));
        return created;
      } catch (e) {
        report(e);
        return null;
      }
    },

    rename: (id, name) => run(() => backend.playlistRename(id, name)),

    remove: async (id) => {
      if (get().current?.id === id) set({ current: null });
      return run(() => backend.playlistDelete(id));
    },

    add: async (id, ids) => {
      const ok = await run(() => backend.playlistAdd(id, ids));
      const name = get().list.find((p) => p.id === id)?.name ?? '';
      if (ok) toast(t('addedToPlaylist', { name }));
      return ok;
    },

    removeAt: async (id, index) => {
      await run(() => backend.playlistRemove(id, index));
    },

    move: async (id, from, to) => {
      // Shown at once; the stored order follows.
      const current = get().current;
      if (current?.id === id) {
        const items = [...current.items];
        const [item] = items.splice(from, 1);
        if (item) items.splice(to, 0, item);
        set({ current: { ...current, items } });
      }
      await run(() => backend.playlistMove(id, from, to));
    },

    importM3u: async () => {
      try {
        const result = await backend.playlistImport();
        if (!result) return;
        await reload();
        toast(
          result.skipped
            ? t('m3uImportedSkipped', {
                name: result.playlist.name,
                n: result.added,
                skipped: result.skipped,
              })
            : t('m3uImported', { name: result.playlist.name, n: result.added }),
        );
      } catch (e) {
        report(e);
      }
    },

    exportM3u: async (id) => {
      try {
        const path = await backend.playlistExport(id);
        if (path) toast(t('m3uExported', { path }));
      } catch (e) {
        report(e);
      }
    },
  };
});

import { create } from 'zustand';
import { backend } from '../services/backend';
import type { LibraryOverview, MediaKind, MediaRecord, MediaSort } from '../services/types';
import { usePlayer } from './player';
import { useUi } from './ui';

// Mirror of the SQLite library. Search, filters and sorting run in Rust
// (FTS5); the store only keeps the current result and the overview.

interface LibraryState {
  search: string;
  kind: MediaKind | null;
  sort: MediaSort;
  items: MediaRecord[];
  total: number;
  overview: LibraryOverview | null;
  /** Last added items, unaffected by search and filters (Home). */
  recent: MediaRecord[];
  ready: boolean;
  init: () => () => void;
  refresh: () => Promise<void>;
  setSearch: (search: string) => void;
  setKind: (kind: MediaKind | null) => void;
  setSort: (sort: MediaSort) => void;
  rename: (id: number, title: string) => Promise<boolean>;
  remove: (id: number) => Promise<boolean>;
}

const REFRESH_DEBOUNCE_MS = 300;
const SEARCH_DEBOUNCE_MS = 150;
let requestSeq = 0;
let timer: ReturnType<typeof setTimeout> | undefined;

function report(error: unknown) {
  useUi.getState().pushToast({
    tone: 'error',
    message: error instanceof Error ? error.message : String(error),
  });
}

export const useLibrary = create<LibraryState>((set, get) => {
  const schedule = (delay: number) => {
    clearTimeout(timer);
    timer = setTimeout(() => void get().refresh(), delay);
  };

  return {
    search: '',
    kind: null,
    sort: 'added',
    items: [],
    total: 0,
    overview: null,
    recent: [],
    ready: false,

    init: () => {
      void get().refresh();
      return backend.onLibraryChanged(() => schedule(REFRESH_DEBOUNCE_MS));
    },

    refresh: async () => {
      const seq = ++requestSeq;
      const { search, kind, sort } = get();
      try {
        const [page, overview, recent] = await Promise.all([
          backend.libraryQuery({ search, kind, sort }),
          backend.libraryOverview(),
          backend.libraryQuery({ search: '', kind: null, sort: 'added', limit: 4 }),
        ]);
        // A newer query was sent meanwhile: drop this answer.
        if (seq !== requestSeq) return;
        set({ items: page.items, total: page.total, overview, recent: recent.items, ready: true });
      } catch (e) {
        if (seq === requestSeq) report(e);
      }
    },

    setSearch: (search) => {
      set({ search });
      schedule(SEARCH_DEBOUNCE_MS);
    },
    setKind: (kind) => {
      set({ kind });
      void get().refresh();
    },
    setSort: (sort) => {
      set({ sort });
      void get().refresh();
    },

    rename: async (id, title) => {
      try {
        await backend.libraryRename(id, title);
        await get().refresh();
        return true;
      } catch (e) {
        report(e);
        return false;
      }
    },
    remove: async (id) => {
      try {
        await backend.libraryDelete(id);
        if (useUi.getState().nowPlaying?.id === id) useUi.getState().play(null);
        usePlayer.getState().forget(id);
        await get().refresh();
        return true;
      } catch (e) {
        report(e);
        return false;
      }
    },
  };
});

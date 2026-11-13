import { create } from 'zustand';
import { t } from '../i18n';
import { backend } from '../services/backend';
import type {
  GroupBy,
  LibraryOverview,
  MediaKind,
  MediaRecord,
  MediaSort,
  MediaTags,
} from '../services/types';
import { usePlayer } from './player';
import { useUi } from './ui';

// Mirror of the SQLite library. Search, filters and sorting run in Rust
// (FTS5); the store only keeps the current result and the overview.

interface LibraryState {
  search: string;
  kind: MediaKind | null;
  sort: MediaSort;
  /** Tracks of one album / artist / folder. */
  group: { by: GroupBy; name: string } | null;
  /** Favorites only (COM-06). */
  favorites: boolean;
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
  /** Sets kind and group together (one query). */
  show: (
    kind: MediaKind | null,
    group: { by: GroupBy; name: string } | null,
    favorites?: boolean,
  ) => void;
  /** Marks or unmarks a favorite; lists and the player follow. */
  toggleFavorite: (media: MediaRecord) => Promise<void>;
  rename: (id: number, title: string) => Promise<boolean>;
  /** Deletes the file from disk. */
  remove: (id: number) => Promise<boolean>;
  /** Saves edited tags (and writes them into the file when asked). */
  updateTags: (id: number, tags: MediaTags, writeToFile: boolean) => Promise<boolean>;
  /** Removes from the library only; the file stays on disk. */
  removeFromLibrary: (id: number) => Promise<boolean>;
  /** Changes the entry's cover (COM-07); `null` if canceled or refused. */
  setCover: (id: number, cover: CoverChoice) => Promise<MediaRecord | null>;
}

export type CoverChoice =
  { from: 'image' } | { from: 'source' } | { from: 'frame'; atSecs: number } | { from: 'none' };

const REFRESH_DEBOUNCE_MS = 300;
const SEARCH_DEBOUNCE_MS = 150;
let requestSeq = 0;
let timer: ReturnType<typeof setTimeout> | undefined;

const codeOf = (e: unknown) => (typeof e === 'object' && e && 'code' in e ? String(e.code) : '');

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
    group: null,
    favorites: false,
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
      const { search, kind, sort, group, favorites } = get();
      try {
        const [page, overview, recent] = await Promise.all([
          backend.libraryQuery({
            search,
            kind,
            sort,
            album: group?.by === 'album' ? group.name : null,
            artist: group?.by === 'artist' ? group.name : null,
            folder: group?.by === 'folder' ? group.name : null,
            favorites,
          }),
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
    show: (kind, group, favorites = false) => {
      const current = get();
      if (
        current.kind === kind &&
        current.group?.by === group?.by &&
        current.group?.name === group?.name &&
        current.favorites === favorites
      )
        return;
      set({ kind, group, favorites });
      void get().refresh();
    },

    toggleFavorite: async (media) => {
      try {
        const updated = await backend.librarySetFavorite(media.id, !media.favorite);
        set((s) => ({
          items:
            s.favorites && !updated.favorite
              ? s.items.filter((m) => m.id !== updated.id)
              : s.items.map((m) => (m.id === updated.id ? updated : m)),
          total: s.favorites && !updated.favorite ? Math.max(0, s.total - 1) : s.total,
        }));
        usePlayer.getState().refreshMedia(updated);
      } catch (e) {
        report(e);
      }
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
    updateTags: async (id, tags, writeToFile) => {
      try {
        const updated = await backend.libraryUpdateTags(id, tags, writeToFile);
        usePlayer.getState().refreshMedia(updated);
        await get().refresh();
        return true;
      } catch (e) {
        report(e);
        return false;
      }
    },
    setCover: async (id, cover) => {
      try {
        const updated =
          cover.from === 'image'
            ? await backend.libraryCoverPick(id)
            : cover.from === 'source'
              ? await backend.libraryCoverSource(id)
              : cover.from === 'frame'
                ? await backend.libraryCoverFrame(id, cover.atSecs)
                : await backend.libraryCoverRemove(id);
        if (!updated) return null;
        set((s) => ({ items: s.items.map((m) => (m.id === updated.id ? updated : m)) }));
        usePlayer.getState().refreshMedia(updated);
        return updated;
      } catch (e) {
        report(e);
        return null;
      }
    },
    removeFromLibrary: async (id) => {
      try {
        await backend.libraryRemove(id);
        if (useUi.getState().nowPlaying?.id === id) useUi.getState().play(null);
        usePlayer.getState().forget(id);
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
        report(codeOf(e) === 'delete_not_allowed' ? new Error(t('deleteNotAllowed')) : e);
        return false;
      }
    },
  };
});

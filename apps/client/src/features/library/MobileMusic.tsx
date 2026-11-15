import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { flyLogoFromSplash, takeLaunch } from '../../app/launch';
import { Icon } from '../../components/Icon';
import { Logo } from '../../components/Logo';
import { useUpdates } from '../settings/useUpdates';
import { LocalThumb } from '../../components/LocalThumb';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import { useT, type MessageKey, type Translate } from '../../i18n';
import { backend } from '../../services/backend';
import type { GroupBy, MediaGroup, MediaRecord, MediaSort } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import { useUi } from '../../stores/ui';
import { DeviceMediaCard } from './DeviceMediaCard';
import { BrandHeader, CollapsingHeader, LibraryCard, PillTabs } from './LibraryCard';
import { durationLabel } from './format';
import { MediaThumb } from './MediaThumb';
import type { AutoList } from './autoLists';
import { AutoListPage, PlaylistPage, PlaylistsTab } from './MobilePlaylists';
import { useGroups } from './useGroups';
import { useMobileMediaSheet } from './useMobileMediaSheet';

type MusicView = 'tracks' | 'playlists' | 'albums' | 'artists' | 'folders' | 'favorites';

const VIEWS: { id: MusicView; label: MessageKey; by?: GroupBy }[] = [
  { id: 'tracks', label: 'songs' },
  { id: 'playlists', label: 'playlists' },
  { id: 'folders', label: 'folders', by: 'folder' },
  { id: 'artists', label: 'artists', by: 'artist' },
  { id: 'albums', label: 'albums', by: 'album' },
  { id: 'favorites', label: 'favorites' },
];

const SORTS: Record<MediaSort, MessageKey> = {
  added: 'sortAdded',
  title: 'sortTitle',
  size: 'sortSize',
  duration: 'sortDuration',
};

const shuffled = <T,>(items: T[]) => {
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
};

const tracksLabel = (n: number, t: Translate) => (n === 1 ? t('oneSong') : t('songsCount', { n }));
const lastSegment = (path: string) => path.split(/[\\/]/).filter(Boolean).pop() ?? path;

/** Plays `items` from `start` with the rest as the Android queue. */
function playList(items: MediaRecord[], start: MediaRecord | undefined, source: string | null) {
  if (start) useMobilePlayback.getState().start(start, items, source);
}

/**
 * Android v2 Music (screens 05, 15, 16): tracks, albums, artists, folders.
 * First tab and launch screen since decision 0006, so it carries the logo
 * (end of the splash) and the way to Settings.
 */
export function MobileMusic({
  onOpenSettings,
  onSearch,
  onGetMusic,
}: {
  onOpenSettings: () => void;
  /** Opens the shared search (library, YouTube, links). */
  onSearch: () => void;
  /** Empty library: go to the Downloads tab. */
  onGetMusic: () => void;
}) {
  const t = useT();
  // Cold start only: the splash logo lands here, once (design_handoff_splash).
  const [launch] = useState(() => takeLaunch('home'));
  const logoRef = useRef<HTMLSpanElement>(null);
  useLayoutEffect(() => {
    if (launch && logoRef.current) flyLogoFromSplash(logoRef.current, 26);
  }, [launch]);
  const updateWaiting = useUpdates((s) => s.phase === 'available' || s.phase === 'ready');
  const [view, setView] = useState<MusicView>('tracks');
  const [opened, setOpened] = useState<{ by: GroupBy; name: string } | null>(null);
  const [playlist, setPlaylist] = useState<number | null>(null);
  const [auto, setAuto] = useState<AutoList | null>(null);
  const [scroller, setScroller] = useState<HTMLDivElement | null>(null);
  const by = VIEWS.find((v) => v.id === view)?.by ?? null;

  useEffect(() => {
    useLibrary.getState().show('audio', opened, view === 'favorites');
  }, [opened, view]);

  if (auto) {
    return (
      <div className="relative flex flex-1 flex-col overflow-auto">
        <AutoListPage list={auto} onBack={() => setAuto(null)} />
      </div>
    );
  }

  if (playlist !== null) {
    return (
      <div className="relative flex flex-1 flex-col overflow-auto">
        <PlaylistPage id={playlist} onBack={() => setPlaylist(null)} />
      </div>
    );
  }

  if (opened) {
    return (
      <div ref={setScroller} className="relative flex flex-1 flex-col overflow-auto pb-4">
        <GroupPage group={opened} onBack={() => setOpened(null)} scroller={scroller} />
      </div>
    );
  }

  return (
    <div ref={setScroller} className="relative flex flex-1 flex-col overflow-auto">
      {/* Lark-like: scrolling down keeps only the tabs, scrolling up brings the header back. */}
      <CollapsingHeader
        scroller={scroller}
        header={
          <BrandHeader title={t('tabMusic')} logoRef={logoRef} logo={<Logo size={28} />}>
            <button
              type="button"
              aria-label={t('mSearch')}
              onClick={onSearch}
              className="grid h-11 w-11 place-items-center"
            >
              <Icon name="search" size={25} />
            </button>
            <button
              type="button"
              aria-label={
                updateWaiting ? `${t('settings')} — ${t('updateAvailable')}` : t('settings')
              }
              onClick={onOpenSettings}
              className="relative grid h-11 w-11 place-items-center"
            >
              <Icon name="settings" size={25} />
              {updateWaiting && (
                <span className="absolute right-2.5 top-2.5 h-2 w-2 rounded-full bg-accent" />
              )}
            </button>
          </BrandHeader>
        }
        bar={
          <PillTabs
            label={t('tabMusic')}
            items={VIEWS.map((v) => ({ id: v.id, label: t(v.label) }))}
            value={view}
            onChange={setView}
          />
        }
      />
      <div key={view} className="flex flex-1 animate-screen-in flex-col px-4 pt-2">
        {view === 'playlists' ? (
          <PlaylistsTab
            onFavorites={() => setView('favorites')}
            onOpen={setPlaylist}
            onAuto={setAuto}
          />
        ) : by ? (
          <Groups by={by} onOpen={(name) => setOpened({ by, name })} scroller={scroller} />
        ) : (
          <Tracks scroller={scroller} favorites={view === 'favorites'} onGetMusic={onGetMusic} />
        )}
      </div>
    </div>
  );
}

function Tracks({
  scroller,
  favorites,
  onGetMusic,
}: {
  scroller: HTMLDivElement | null;
  favorites: boolean;
  onGetMusic: () => void;
}) {
  const t = useT();
  const { items, sort, ready, search } = useLibrary();
  const synced = useLibrary(
    (s) => s.kind === 'audio' && s.group === null && s.favorites === favorites,
  );
  const list = synced ? items : [];
  const source = favorites ? t('favorites') : t('songs');

  return (
    <>
      {!favorites && <DeviceMediaCard />}
      {/* No shuffle button here: shuffle lives in the player (as in Lark). */}
      <div className="flex items-center gap-2.5 pb-1">
        <span className="flex-1 text-[13px] text-muted">{tracksLabel(list.length, t)}</span>
        <Menu
          label={t('sort')}
          trigger={({ open, toggle, id }) => (
            <button
              type="button"
              aria-haspopup="menu"
              aria-expanded={open}
              aria-controls={id}
              onClick={toggle}
              className="flex h-9 items-center gap-1 text-[13px] font-semibold text-muted"
            >
              <Icon name="sort" size={18} />
              {t(SORTS[sort])}
            </button>
          )}
          items={(Object.keys(SORTS) as MediaSort[]).map((key) => ({
            label: t(SORTS[key]),
            selected: key === sort,
            onSelect: () => useLibrary.getState().setSort(key),
          }))}
        />
      </div>
      {ready && synced && list.length === 0 && !search.trim() && !favorites ? (
        // Nothing to listen to: one tap to the Downloads tab (decision 0006),
        // no automatic jump.
        <div className="flex flex-col items-center gap-2 px-6 py-10 text-center">
          <Icon name="library_music" size={40} className="text-faint-icon" />
          <span className="text-[15px] font-bold">{t('musicEmptyTitle')}</span>
          <span className="text-[13.5px] text-muted">{t('musicEmptyBody')}</span>
          <button
            type="button"
            onClick={onGetMusic}
            className="mt-2 flex h-11 items-center gap-2 rounded-full bg-accent px-5 text-[14px] font-extrabold text-accent-ink"
          >
            <Icon name="download" size={20} />
            {t('musicEmptyAction')}
          </button>
        </div>
      ) : (
        ready &&
        synced &&
        list.length === 0 && (
          <p className="py-10 text-center text-[13.5px] text-muted">
            {search.trim() ? (
              t('noMatch', { q: search.trim() })
            ) : (
              <>
                <span className="block text-[15px] font-bold text-fg">
                  {t('favoritesEmptyTitle')}
                </span>
                {t('favoritesEmptyBody')}
              </>
            )}
          </p>
        )
      )}
      <TrackList items={list} scroller={scroller} source={source} />
    </>
  );
}

/** 64 dp rows; the playing track is coral with an equalizer over its cover. */
function TrackList({
  items,
  scroller,
  numbered = false,
  secondary = 'artist',
  source,
}: {
  items: MediaRecord[];
  scroller: HTMLDivElement | null;
  /** "Playing from" label of the queue. */
  source: string;
  numbered?: boolean;
  /** Second line: the artist, or the album on an artist page. */
  secondary?: 'artist' | 'album';
}) {
  const t = useT();
  const currentId = useUi((s) => s.nowPlaying?.id);
  const actionsSheet = useMobileMediaSheet();
  return (
    <>
      <VirtualGrid
        label={t('songs')}
        items={items}
        scrollRef={{ current: scroller }}
        columns={1}
        columnGap={0}
        rowGap={0}
        rowHeight={() => (numbered ? 56 : 72)}
        getKey={(m) => String(m.id)}
        renderItem={(m) => {
          const on = m.id === currentId;
          return (
            <div className={`flex items-center gap-3.5 ${numbered ? 'h-14' : 'h-[72px]'}`}>
              <button
                type="button"
                onClick={() => playList(items, m, source)}
                onContextMenu={(e) => {
                  e.preventDefault();
                  actionsSheet.open(m);
                }}
                aria-label={t('playTitle', { title: m.title })}
                className="flex min-w-0 flex-1 items-center gap-3 rounded-[16px] text-left transition-transform duration-150 active:scale-[0.98]"
              >
                {numbered ? (
                  <span
                    className={`w-5 text-right font-mono text-[12px] ${on ? 'text-coral-strong' : 'text-muted'}`}
                  >
                    {on ? '▶' : (m.trackNo ?? '·')}
                  </span>
                ) : (
                  <MediaThumb media={m} className="h-14 w-14 rounded-[14px]">
                    {on && (
                      <span className="absolute inset-0 grid place-items-center rounded-[14px] bg-[rgb(16_24_32/0.6)] text-coral-strong">
                        <Icon name="equalizer" size={26} />
                      </span>
                    )}
                  </MediaThumb>
                )}
                <span className="flex min-w-0 flex-1 flex-col gap-1">
                  <span
                    className={`truncate text-[15.5px] font-bold ${on ? 'text-coral-strong' : ''}`}
                  >
                    {m.title}
                  </span>
                  <span className="truncate text-[13px] text-muted">
                    {[secondary === 'album' ? m.album : m.artist, durationLabel(m.durationSecs)]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                </span>
                {m.favorite && (
                  <Icon name="favorite" size={20} fill className="shrink-0 text-coral-hover" />
                )}
              </button>
              <button
                type="button"
                aria-label={t('moreActions')}
                onClick={() => actionsSheet.open(m)}
                className="grid h-12 w-10 shrink-0 place-items-center text-muted"
              >
                <Icon name="more_vert" size={22} />
              </button>
            </div>
          );
        }}
      />
      {actionsSheet.sheet}
    </>
  );
}

function Groups({
  by,
  onOpen,
  scroller,
}: {
  by: GroupBy;
  onOpen: (name: string) => void;
  scroller: HTMLDivElement | null;
}) {
  const t = useT();
  const groups = useGroups(by);
  if (groups === null) return null;
  if (groups instanceof Error)
    return <p className="py-10 text-center text-[13.5px] text-danger">{groups.message}</p>;
  if (groups.length === 0) {
    return (
      <p className="py-10 text-center text-[13.5px] text-muted">
        {by === 'album' ? t('noAlbums') : by === 'artist' ? t('noArtists') : t('noFolders')}
      </p>
    );
  }
  const count = (
    <div className="flex items-center justify-between pb-3 text-[13px] text-muted">
      <span>
        {by === 'album'
          ? groups.length === 1
            ? t('oneAlbum')
            : t('albumsCount', { n: groups.length })
          : `${groups.length}`}
      </span>
      {by === 'folder' ? (
        <button
          type="button"
          disabled
          aria-label={t('importFolderPlanned')}
          title={t('importFolderPlanned')}
          className="flex h-8 items-center gap-1.5 rounded-full bg-surface px-3 font-semibold opacity-50"
        >
          <Icon name="create_new_folder" size={18} />
          {t('planned')}
        </button>
      ) : (
        <span className="flex items-center gap-1 font-semibold">
          <Icon name="sort" size={18} />
          {t('sortAZ')}
        </span>
      )}
    </div>
  );

  // Lark-like cards in one column (decision 0006): cover, name, details, count.
  return (
    <>
      {count}
      <VirtualGrid
        label={by === 'album' ? t('albums') : by === 'artist' ? t('artists') : t('folders')}
        items={groups}
        scrollRef={{ current: scroller }}
        columns={1}
        columnGap={0}
        rowGap={12}
        rowHeight={() => 100}
        getKey={(g) => g.name}
        renderItem={(g) => <GroupCard group={g} by={by} onOpen={() => onOpen(g.name)} />}
      />
    </>
  );
}

function GroupCard({ group, by, onOpen }: { group: MediaGroup; by: GroupBy; onOpen: () => void }) {
  const t = useT();
  const albums = Number(group.detail ?? 0);
  const length = group.durationSecs > 0 ? durationLabel(group.durationSecs) : null;
  const cover =
    by === 'folder' ? (
      <span className="grid h-full w-full place-items-center rounded-[18px] bg-accent-subtle text-chip-text">
        <Icon name="folder" size={40} fill />
      </span>
    ) : (
      <LocalThumb
        path={group.thumbnail}
        kind="audio"
        className={`h-full w-full ${by === 'artist' ? 'rounded-full' : 'rounded-[18px]'}`}
      >
        {by === 'artist' && !group.thumbnail && (
          <Icon name="person" size={36} className="relative text-faint-icon" />
        )}
      </LocalThumb>
    );
  const lines =
    by === 'album'
      ? [group.detail, [group.year, length].filter(Boolean).join(' · ')]
      : by === 'artist'
        ? [albums === 1 ? t('oneAlbum') : t('albumsCount', { n: albums }), length]
        : [group.name, length];
  return (
    <LibraryCard
      cover={cover}
      title={by === 'folder' ? lastSegment(group.name) : group.name}
      label={group.name}
      lines={lines}
      count={group.count}
      onOpen={onOpen}
      action={
        by === 'album'
          ? {
              icon: <Icon name="play_arrow" size={24} fill />,
              label: t('playTitle', { title: group.name }),
              run: () =>
                void backend
                  .libraryQuery({ search: '', kind: 'audio', sort: 'added', album: group.name })
                  .then((page) =>
                    playList(page.items, page.items[0], t('sourceAlbum', { name: group.name })),
                  )
                  .catch(() => {}),
            }
          : undefined
      }
    />
  );
}

/** Artist page (screen 16), also used for an album or a folder. */
function GroupPage({
  group,
  onBack,
  scroller,
}: {
  group: { by: GroupBy; name: string };
  onBack: () => void;
  scroller: HTMLDivElement | null;
}) {
  const t = useT();
  const { items } = useLibrary();
  const synced = useLibrary((s) => s.group?.by === group.by && s.group?.name === group.name);
  const list = useMemo(() => (synced ? items : []), [synced, items]);
  const total = list.reduce((sum, m) => sum + (m.durationSecs ?? 0), 0);
  const albums = useMemo(() => {
    const map = new Map<
      string,
      { name: string; year: number | null; count: number; cover: MediaRecord }
    >();
    for (const m of list) {
      if (!m.album) continue;
      const key = m.album.toLowerCase();
      const a = map.get(key) ?? { name: m.album, year: m.year ?? null, count: 0, cover: m };
      a.count += 1;
      map.set(key, a);
    }
    return [...map.values()];
  }, [list]);
  const back: MessageKey =
    group.by === 'album' ? 'albums' : group.by === 'artist' ? 'artists' : 'folders';
  const title = group.by === 'folder' ? lastSegment(group.name) : group.name;
  const source = t(
    group.by === 'album' ? 'sourceAlbum' : group.by === 'artist' ? 'sourceArtist' : 'sourceFolder',
    { name: title },
  );
  const stats = [
    group.by === 'artist' &&
      (albums.length === 1 ? t('oneAlbum') : t('albumsCount', { n: albums.length })),
    tracksLabel(list.length, t),
    total > 0 && durationLabel(total),
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <>
      <div className="flex h-14 shrink-0 items-center gap-1 px-2">
        <button
          type="button"
          aria-label={t('back')}
          onClick={onBack}
          className="grid h-12 w-12 place-items-center"
        >
          <Icon name="arrow_back" size={24} />
        </button>
        <span className="flex-1 text-[13px] font-semibold text-muted">{t(back)}</span>
      </div>
      <div className="flex flex-col gap-4 px-4">
        <div className="flex items-center gap-4">
          {group.by === 'album' && list[0] ? (
            <MediaThumb media={list[0]} className="h-28 w-28 shrink-0 rounded-xl" />
          ) : (
            <span
              className={`hatch grid h-28 w-28 shrink-0 place-items-center ${group.by === 'artist' ? 'rounded-full' : 'rounded-xl'}`}
            >
              <Icon
                name={group.by === 'artist' ? 'person' : 'folder'}
                size={44}
                className="text-faint-icon"
              />
            </span>
          )}
          <div className="flex min-w-0 flex-1 flex-col gap-1">
            <h1 className="m-0 break-words text-[24px] font-extrabold leading-7 tracking-[-0.01em]">
              {title}
            </h1>
            <span className="text-[13px] text-muted">{stats}</span>
          </div>
        </div>
        <div className="flex gap-2.5">
          <button
            type="button"
            disabled={!list.length}
            onClick={() => playList(list, list[0], source)}
            className="flex h-12 flex-1 items-center justify-center gap-2 rounded-full bg-coral text-[14.5px] font-extrabold text-coral-ink disabled:opacity-50"
          >
            <Icon name="play_arrow" size={22} fill />
            {t('playAll')}
          </button>
          <button
            type="button"
            disabled={!list.length}
            onClick={() => {
              const order = shuffled(list);
              playList(order, order[0], source);
            }}
            className="flex h-12 flex-1 items-center justify-center gap-2 rounded-full border border-line-strong bg-surface2 text-[14px] font-semibold disabled:opacity-50"
          >
            <Icon name="shuffle" size={20} />
            {t('shuffle')}
          </button>
        </div>
        {group.by === 'artist' && albums.length > 0 && (
          <>
            <h2 className="m-0 text-[15px] font-bold">{t('albums')}</h2>
            <div className="-mx-4 flex gap-3 overflow-x-auto px-4 [scrollbar-width:none]">
              {albums.map((a) => (
                <div key={a.name} className="flex w-28 shrink-0 flex-col gap-1.5">
                  <MediaThumb media={a.cover} className="aspect-square w-full rounded-[10px]" />
                  <span className="truncate text-[13px] font-bold">{a.name}</span>
                  <span className="font-mono text-[11.5px] text-muted">
                    {[a.year, a.count].filter(Boolean).join(' · ')}
                  </span>
                </div>
              ))}
            </div>
          </>
        )}
        <h2 className="m-0 text-[15px] font-bold">{t('songs')}</h2>
        <TrackList
          items={list}
          scroller={scroller}
          numbered={group.by === 'album'}
          secondary={group.by === 'artist' ? 'album' : 'artist'}
          source={source}
        />
      </div>
    </>
  );
}

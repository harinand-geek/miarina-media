import { useEffect, useMemo, useState } from 'react';
import { Icon } from '../../components/Icon';
import { LocalThumb } from '../../components/LocalThumb';
import { Menu } from '../../components/Menu';
import { VirtualGrid } from '../../components/VirtualGrid';
import { useT, type MessageKey, type Translate } from '../../i18n';
import { backend } from '../../services/backend';
import type { GroupBy, MediaGroup, MediaRecord, MediaSort } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { durationLabel } from './format';
import { MediaThumb } from './MediaThumb';
import { useGroups } from './useGroups';
import { useMobileMediaSheet } from './useMobileMediaSheet';

type MusicView = 'tracks' | 'playlists' | 'albums' | 'artists' | 'folders' | 'favorites';

const VIEWS: { id: MusicView; label: MessageKey; by?: GroupBy; planned?: boolean }[] = [
  { id: 'tracks', label: 'tracks' },
  { id: 'playlists', label: 'playlists', planned: true },
  { id: 'albums', label: 'albums', by: 'album' },
  { id: 'artists', label: 'artists', by: 'artist' },
  { id: 'folders', label: 'folders', by: 'folder' },
  { id: 'favorites', label: 'favorites', planned: true },
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

const tracksLabel = (n: number, t: Translate) => (n === 1 ? t('oneTrack') : t('tracksCount', { n }));
const lastSegment = (path: string) => path.split(/[\\/]/).filter(Boolean).pop() ?? path;

/** Plays `items` from `start` with the rest as the Android queue. */
function playList(items: MediaRecord[], start: MediaRecord | undefined) {
  if (start) useUi.getState().play(start, items);
}

/** Android v2 Music (screens 05, 15, 16): tracks, albums, artists, folders. */
export function MobileMusic() {
  const t = useT();
  const [view, setView] = useState<MusicView>('tracks');
  const [opened, setOpened] = useState<{ by: GroupBy; name: string } | null>(null);
  const [searching, setSearching] = useState(false);
  const [scroller, setScroller] = useState<HTMLDivElement | null>(null);
  const { search, setSearch } = useLibrary();
  const by = VIEWS.find((v) => v.id === view)?.by ?? null;

  useEffect(() => {
    useLibrary.getState().show('audio', opened);
  }, [opened]);

  if (opened) {
    return (
      <div ref={setScroller} className="relative flex flex-1 flex-col overflow-auto pb-4">
        <GroupPage group={opened} onBack={() => setOpened(null)} scroller={scroller} />
      </div>
    );
  }

  return (
    <div ref={setScroller} className="relative flex flex-1 flex-col overflow-auto">
      <div className="flex shrink-0 flex-col gap-2.5 px-4 pt-1">
        <div className="flex h-12 items-center gap-1">
          <h1 className="m-0 flex-1 text-[22px] font-extrabold tracking-[-0.01em]">
            {t('tabMusic')}
          </h1>
          <button
            type="button"
            aria-label={t('mSearch')}
            aria-pressed={searching}
            onClick={() => setSearching((s) => !s)}
            className="grid h-11 w-11 place-items-center"
          >
            <Icon name="search" size={24} />
          </button>
          <button
            type="button"
            disabled
            aria-label={t('importFolderPlanned')}
            title={t('importFolderPlanned')}
            className="grid h-11 w-11 place-items-center opacity-40"
          >
            <Icon name="create_new_folder" size={24} />
          </button>
        </div>
        {searching && (
          <label className="flex h-12 items-center gap-2.5 rounded-3xl bg-surface px-4">
            <Icon name="search" size={20} className="text-muted" />
            <input
              type="search"
              autoFocus
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t('librarySearch')}
              aria-label={t('librarySearch')}
              className="min-w-0 flex-1 bg-transparent text-[15px] font-medium text-fg outline-none focus-visible:outline-none"
            />
          </label>
        )}
        <div
          role="tablist"
          aria-label={t('tabMusic')}
          className="-mx-4 flex gap-[22px] overflow-x-auto border-b border-divider px-4 [scrollbar-width:none]"
        >
          {VIEWS.map((v) => (
            <button
              key={v.id}
              type="button"
              role="tab"
              aria-selected={view === v.id}
              disabled={v.planned}
              title={v.planned ? t('plannedHint') : undefined}
              onClick={() => setView(v.id)}
              className={`-mb-px shrink-0 border-b-2 py-2.5 text-[14px] disabled:opacity-45 ${
                view === v.id
                  ? 'border-coral font-bold text-fg'
                  : 'border-transparent font-semibold text-muted'
              }`}
            >
              {t(v.label)}
            </button>
          ))}
        </div>
      </div>
      <div className="flex flex-1 flex-col px-4 pt-3.5">
        {by ? (
          <Groups by={by} onOpen={(name) => setOpened({ by, name })} scroller={scroller} />
        ) : (
          <Tracks scroller={scroller} />
        )}
      </div>
    </div>
  );
}

function Tracks({ scroller }: { scroller: HTMLDivElement | null }) {
  const t = useT();
  const { items, sort, ready, search } = useLibrary();
  const synced = useLibrary((s) => s.kind === 'audio' && s.group === null);
  const list = synced ? items : [];

  return (
    <>
      <div className="flex items-center gap-2.5 pb-1">
        <button
          type="button"
          disabled={!list.length}
          onClick={() => {
            const order = shuffled(list);
            playList(order, order[0]);
          }}
          className="flex h-10 items-center gap-2 rounded-full bg-coral pl-3 pr-4 text-[14px] font-extrabold text-coral-ink disabled:opacity-50"
        >
          <Icon name="shuffle" size={20} />
          {t('shufflePlay')}
        </button>
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
      {ready && synced && list.length === 0 && (
        <p className="py-10 text-center text-[13.5px] text-muted">
          {search.trim() ? t('noMatch', { q: search.trim() }) : t('emptyLibBody')}
        </p>
      )}
      <TrackList items={list} scroller={scroller} />
    </>
  );
}

/** 64 dp rows; the playing track is coral with an equalizer over its cover. */
function TrackList({
  items,
  scroller,
  numbered = false,
  secondary = 'artist',
}: {
  items: MediaRecord[];
  scroller: HTMLDivElement | null;
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
        label={t('tracks')}
        items={items}
        scrollRef={{ current: scroller }}
        columns={1}
        columnGap={0}
        rowGap={0}
        rowHeight={() => (numbered ? 56 : 64)}
        getKey={(m) => String(m.id)}
        renderItem={(m) => {
          const on = m.id === currentId;
          return (
            <div className={`flex items-center gap-3 ${numbered ? 'h-14' : 'h-16'}`}>
              <button
                type="button"
                onClick={() => playList(items, m)}
                onContextMenu={(e) => {
                  e.preventDefault();
                  actionsSheet.open(m);
                }}
                aria-label={t('playTitle', { title: m.title })}
                className="flex min-w-0 flex-1 items-center gap-3 text-left"
              >
                {numbered ? (
                  <span
                    className={`w-5 text-right font-mono text-[12px] ${on ? 'text-coral-strong' : 'text-muted'}`}
                  >
                    {on ? '▶' : (m.trackNo ?? '·')}
                  </span>
                ) : (
                  <MediaThumb media={m} className="h-12 w-12 rounded-lg">
                    {on && (
                      <span className="absolute inset-0 grid place-items-center rounded-lg bg-[rgb(16_24_32/0.6)] text-coral-strong">
                        <Icon name="equalizer" size={24} />
                      </span>
                    )}
                  </MediaThumb>
                )}
                <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span
                    className={`truncate text-[14.5px] font-bold ${on ? 'text-coral-strong' : ''}`}
                  >
                    {m.title}
                  </span>
                  <span className="truncate text-[12.5px] text-muted">
                    {[secondary === 'album' ? m.album : m.artist, durationLabel(m.durationSecs)]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                </span>
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
    <div className="flex items-center justify-between pb-3.5 text-[13px] text-muted">
      <span>
        {by === 'album'
          ? groups.length === 1
            ? t('oneAlbum')
            : t('albumsCount', { n: groups.length })
          : `${groups.length}`}
      </span>
      <span className="flex items-center gap-1 font-semibold">
        <Icon name="sort" size={18} />
        {t('sortAZ')}
      </span>
    </div>
  );

  if (by === 'folder') {
    return (
      <>
        {count}
        <ul aria-label={t('folders')} className="m-0 flex list-none flex-col gap-2 p-0">
          {groups.map((g) => (
            <li key={g.name}>
              <button
                type="button"
                onClick={() => onOpen(g.name)}
                className="flex min-h-16 w-full items-center gap-3 rounded-xl bg-surface px-3.5 text-left active:bg-surface2"
              >
                <Icon name="folder" size={24} className="text-muted" />
                <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span className="truncate text-[14.5px] font-bold">{lastSegment(g.name)}</span>
                  <span className="truncate font-mono text-[11.5px] text-muted">{g.name}</span>
                </span>
                <span className="text-[12.5px] text-muted">{g.count}</span>
              </button>
            </li>
          ))}
        </ul>
      </>
    );
  }

  const round = by === 'artist';
  return (
    <>
      {count}
      <VirtualGrid
        label={by === 'album' ? t('albums') : t('artists')}
        items={groups}
        scrollRef={{ current: scroller }}
        columns={2}
        columnGap={12}
        rowGap={16}
        rowHeight={(w) => w + 8 + 40}
        getKey={(g) => g.name}
        renderItem={(g) => (
          <GroupCard group={g} round={round} onOpen={() => onOpen(g.name)} by={by} />
        )}
      />
    </>
  );
}

function GroupCard({
  group,
  round,
  by,
  onOpen,
}: {
  group: MediaGroup;
  round: boolean;
  by: GroupBy;
  onOpen: () => void;
}) {
  const t = useT();
  const albums = Number(group.detail ?? 0);
  return (
    <div className={`flex flex-col gap-2 ${round ? 'items-center text-center' : ''}`}>
      <div className="relative w-full">
        <button type="button" onClick={onOpen} aria-label={group.name} className="block w-full">
          <LocalThumb
            path={round ? null : group.thumbnail}
            kind="audio"
            className={`aspect-square w-full ${round ? 'rounded-full' : 'rounded-xl'}`}
          >
            {round && <Icon name="person" size={44} className="relative text-faint-icon" />}
          </LocalThumb>
        </button>
        {by === 'album' && (
          <button
            type="button"
            aria-label={t('playTitle', { title: group.name })}
            onClick={() =>
              void backend
                .libraryQuery({ search: '', kind: 'audio', sort: 'added', album: group.name })
                .then((page) => playList(page.items, page.items[0]))
                .catch(() => {})
            }
            className="absolute bottom-2 right-2 grid h-9 w-9 place-items-center rounded-full bg-[rgb(16_24_32/0.85)] text-coral-strong"
          >
            <Icon name="play_arrow" size={22} fill />
          </button>
        )}
      </div>
      <span className={`flex w-full flex-col gap-px ${round ? 'items-center' : ''}`}>
        <span className="w-full truncate text-[14px] font-bold">{group.name}</span>
        <span className="w-full truncate text-[12.5px] text-muted">
          {by === 'album'
            ? `${group.detail ?? '—'} · ${tracksLabel(group.count, t)}`
            : `${albums === 1 ? t('oneAlbum') : t('albumsCount', { n: albums })} · ${tracksLabel(group.count, t)}`}
        </span>
      </span>
    </div>
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
    const map = new Map<string, { name: string; year: number | null; count: number; cover: MediaRecord }>();
    for (const m of list) {
      if (!m.album) continue;
      const key = m.album.toLowerCase();
      const a = map.get(key) ?? { name: m.album, year: m.year ?? null, count: 0, cover: m };
      a.count += 1;
      map.set(key, a);
    }
    return [...map.values()];
  }, [list]);
  const back: MessageKey = group.by === 'album' ? 'albums' : group.by === 'artist' ? 'artists' : 'folders';
  const title = group.by === 'folder' ? lastSegment(group.name) : group.name;
  const stats = [
    group.by === 'artist' && (albums.length === 1 ? t('oneAlbum') : t('albumsCount', { n: albums.length })),
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
              <Icon name={group.by === 'artist' ? 'person' : 'folder'} size={44} className="text-faint-icon" />
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
            onClick={() => playList(list, list[0])}
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
              playList(order, order[0]);
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
        <h2 className="m-0 text-[15px] font-bold">{t('tracks')}</h2>
        <TrackList
          items={list}
          scroller={scroller}
          numbered={group.by === 'album'}
          secondary={group.by === 'artist' ? 'album' : 'artist'}
        />
      </div>
    </>
  );
}

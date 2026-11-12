import { useEffect, useState, type KeyboardEvent, type MouseEvent, type RefObject } from 'react';
import { EmptyState } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { LocalThumb } from '../../components/LocalThumb';
import { useT } from '../../i18n';
import type { MediaRecord, PlaylistSummary } from '../../services/types';
import { usePlayer } from '../../stores/player';
import { usePlaylists } from '../../stores/playlists';
import { useUi } from '../../stores/ui';
import { playFrom } from '../../app/navigation';
import { durationLabel } from './format';
import { MediaContextMenu, RenameDialog, type MenuTarget } from './MediaActions';
import { TracksTable } from './TracksTable';
import { useMediaActions } from './useMediaActions';

const SECONDARY =
  'flex h-[34px] items-center gap-1.5 rounded-sm border border-line-strong bg-surface2 px-3 text-[12.5px] font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50';

/** Windows v2 Library › Playlists (COM-06, COM-11). */
export function PlaylistsView({ scrollRef }: { scrollRef: RefObject<HTMLDivElement | null> }) {
  const openId = useUi((s) => s.openPlaylist);
  useEffect(() => {
    void usePlaylists.getState().load();
  }, []);
  useEffect(() => {
    void usePlaylists.getState().open(openId);
  }, [openId]);
  return openId === null ? <PlaylistGrid /> : <PlaylistDetail scrollRef={scrollRef} />;
}

function PlaylistGrid() {
  const t = useT();
  const list = usePlaylists((s) => s.list);
  const ready = usePlaylists((s) => s.ready);
  return (
    <>
      <div className="flex items-center gap-3">
        <h1 className="m-0 flex-1 text-title-lg font-extrabold tracking-[-0.02em]">
          {t('playlists')}
        </h1>
        <button
          type="button"
          onClick={() => void usePlaylists.getState().importM3u()}
          className={SECONDARY}
        >
          <Icon name="file_open" size={17} />
          {t('importM3u')}
        </button>
      </div>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(180px,1fr))] gap-x-[18px] gap-y-[22px]">
        <button
          type="button"
          onClick={() => useUi.setState({ playlistDialog: { kind: 'create', ids: [] } })}
          className="flex aspect-square flex-col items-center justify-center gap-2 rounded-lg border-[1.5px] border-dashed border-line-strong text-[13px] font-bold text-muted hover:border-accent hover:text-fg"
        >
          <Icon name="add" size={30} />
          {t('newPlaylist')}
        </button>
        {list.map((p) => (
          <PlaylistCard key={p.id} playlist={p} />
        ))}
      </div>
      {ready && list.length === 0 && (
        <p className="m-0 text-[13px] text-muted">{t('playlistsEmpty')}</p>
      )}
    </>
  );
}

function PlaylistCard({ playlist }: { playlist: PlaylistSummary }) {
  const t = useT();
  const cells = [0, 1, 2, 3];
  return (
    <button
      type="button"
      onClick={() => useUi.setState({ openPlaylist: playlist.id })}
      className="group flex min-w-0 flex-col gap-2 text-left"
    >
      <span className="grid aspect-square w-full grid-cols-2 gap-0.5 overflow-hidden rounded-lg border border-line group-hover:outline-2 group-hover:outline-offset-2 group-hover:outline-accent">
        {cells.map((i) => (
          <LocalThumb key={i} path={playlist.covers[i]} kind="audio" className="h-full w-full" />
        ))}
      </span>
      <span className="truncate text-[13.5px] font-bold">{playlist.name}</span>
      <span className="-mt-1 text-[12px] text-muted">
        {t('tracksCount', { n: playlist.count })}
        {playlist.durationSecs > 0 && ` · ${durationLabel(playlist.durationSecs)}`}
      </span>
    </button>
  );
}

function PlaylistDetail({ scrollRef }: { scrollRef: RefObject<HTMLDivElement | null> }) {
  const t = useT();
  const current = usePlaylists((s) => s.current);
  const [menu, setMenu] = useState<(MenuTarget & { index: number }) | null>(null);
  const [renaming, setRenaming] = useState<MediaRecord | null>(null);
  const actions = useMediaActions();
  if (!current) return null;
  const items = current.items;
  const playable = items.filter((m) => !m.missing);
  const store = usePlaylists.getState();

  const playAll = (shuffle: boolean) => {
    const first = shuffle ? playable[Math.floor(Math.random() * playable.length)] : playable[0];
    if (!first) return;
    playFrom(first, playable);
    if (shuffle) usePlayer.getState().setShuffle(true);
  };
  const indexOf = (m: MediaRecord, hint?: number) => hint ?? items.findIndex((x) => x === m);
  const handlers = (m: MediaRecord) => ({
    onContextMenu: (e: MouseEvent) => {
      e.preventDefault();
      setMenu({ media: m, x: e.clientX, y: e.clientY, index: indexOf(m) });
    },
    onKeyDown: (e: KeyboardEvent<HTMLElement>) => {
      const index = indexOf(m);
      if (e.altKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
        e.preventDefault();
        const to = index + (e.key === 'ArrowUp' ? -1 : 1);
        if (to >= 0 && to < items.length) void store.move(current.id, index, to);
      } else if (e.key === 'Delete') {
        e.preventDefault();
        void store.removeAt(current.id, index);
      } else if (e.key === 'ContextMenu' || (e.shiftKey && e.key === 'F10')) {
        e.preventDefault();
        const rect = e.currentTarget.getBoundingClientRect();
        setMenu({ media: m, x: rect.left + 16, y: rect.top + 16, index });
      }
    },
  });

  return (
    <>
      <button
        type="button"
        onClick={() => useUi.setState({ openPlaylist: null })}
        className="-mb-2 flex items-center gap-1.5 self-start text-[13px] font-semibold text-muted hover:text-fg"
      >
        <Icon name="arrow_back" size={18} />
        {t('back')}
      </button>
      <div className="flex flex-wrap items-center gap-2.5">
        <h1 className="m-0 flex min-w-0 flex-1 items-baseline gap-2.5 text-title-lg font-extrabold tracking-[-0.02em]">
          <span className="truncate">{current.name}</span>
          <span className="font-mono text-[13px] font-medium text-muted">{items.length}</span>
        </h1>
        <button
          type="button"
          disabled={!playable.length}
          onClick={() => playAll(false)}
          className="flex h-9 items-center gap-1.5 rounded-sm bg-coral px-3.5 text-[13px] font-bold text-coral-ink enabled:hover:bg-coral-hover disabled:opacity-50"
        >
          <Icon name="play_arrow" size={18} fill />
          {t('playAll')}
        </button>
        <button
          type="button"
          disabled={!playable.length}
          onClick={() => playAll(true)}
          className={SECONDARY}
        >
          <Icon name="shuffle" size={17} />
          {t('shufflePlay')}
        </button>
        <button
          type="button"
          onClick={() =>
            useUi.setState({
              playlistDialog: { kind: 'rename', id: current.id, name: current.name },
            })
          }
          className={SECONDARY}
        >
          <Icon name="drive_file_rename_outline" size={17} />
          {t('rename')}
        </button>
        <button
          type="button"
          onClick={() => void store.exportM3u(current.id)}
          className={SECONDARY}
        >
          <Icon name="ios_share" size={17} />
          {t('exportM3u')}
        </button>
        <button
          type="button"
          onClick={() =>
            useUi.getState().askConfirm({
              title: t('deletePlaylistTitle', { name: current.name }),
              body: t('deletePlaylistBody'),
              confirmLabel: t('deletePlaylist'),
              onConfirm: () => {
                useUi.setState({ openPlaylist: null });
                void store.remove(current.id);
              },
            })
          }
          className={`${SECONDARY} !text-danger`}
        >
          <Icon name="delete" size={17} />
          {t('deletePlaylist')}
        </button>
      </div>

      {items.length === 0 ? (
        <EmptyState icon="queue_music" title={t('playlistEmptyTitle')}>
          {t('playlistEmptyBody')}
        </EmptyState>
      ) : (
        <TracksTable
          items={items}
          scrollRef={scrollRef}
          onPlay={(m) => actions.open(m, playable)}
          onEditTags={(m) => useUi.setState({ tagEditor: m })}
          onMore={(m, e) => setMenu({ media: m, x: e.clientX, y: e.clientY, index: indexOf(m) })}
          handlers={handlers}
          positionKeys
        />
      )}
      <p className="m-0 text-[12px] text-muted">{t('playlistNote')}</p>

      {menu && (
        <MediaContextMenu
          target={menu}
          onClose={() => setMenu(null)}
          onRename={setRenaming}
          extra={[
            {
              icon: 'arrow_upward',
              label: t('moveUp'),
              key: 'Alt ↑',
              disabled: menu.index <= 0,
              run: () => void store.move(current.id, menu.index, menu.index - 1),
            },
            {
              icon: 'arrow_downward',
              label: t('moveDown'),
              key: 'Alt ↓',
              disabled: menu.index >= items.length - 1,
              run: () => void store.move(current.id, menu.index, menu.index + 1),
            },
            {
              icon: 'playlist_remove',
              label: t('removeFromPlaylist'),
              key: 'Del',
              run: () => void store.removeAt(current.id, menu.index),
            },
          ]}
        />
      )}
      {renaming && <RenameDialog media={renaming} onClose={() => setRenaming(null)} />}
    </>
  );
}

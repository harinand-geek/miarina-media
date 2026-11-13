import { useEffect, useState } from 'react';
import { Icon } from '../../components/Icon';
import { LocalThumb } from '../../components/LocalThumb';
import { Menu } from '../../components/Menu';
import { BottomSheet } from '../../components/Overlay';
import { useT, type Translate } from '../../i18n';
import type { MediaRecord, PlaylistSummary } from '../../services/types';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import { usePlaylists } from '../../stores/playlists';
import { useUi } from '../../stores/ui';
import { durationLabel } from './format';
import { MediaThumb } from './MediaThumb';

const songs = (n: number, t: Translate) => (n === 1 ? t('oneSong') : t('songsCount', { n }));

const shuffled = <T,>(items: T[]) => {
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
};

/** Plays the playable entries of a playlist from `start` (missing files are skipped). */
function play(items: MediaRecord[], start: MediaRecord | undefined, source: string) {
  const playable = items.filter((m) => !m.missing);
  const first = start && !start.missing ? start : playable[0];
  if (first) useMobilePlayback.getState().start(first, playable, source);
}

/** 2 × 2 mosaic of the first covers (screen 06). */
function Mosaic({ covers, className }: { covers: string[]; className: string }) {
  if (covers.length < 2) {
    return <LocalThumb path={covers[0]} kind="audio" className={className} />;
  }
  return (
    <span className={`grid grid-cols-2 grid-rows-2 overflow-hidden ${className}`}>
      {[0, 1, 2, 3].map((i) => (
        <LocalThumb key={i} path={covers[i]} kind="audio" className="h-full w-full" />
      ))}
    </span>
  );
}

const newPlaylist = () => useUi.setState({ playlistDialog: { kind: 'create', ids: [] } });

/**
 * Android v2 Music › Playlists (screen 06, COM-06): automatic tiles, the
 * user's playlists, a new playlist. Recent / most played and M3U stay
 * planned on Android.
 */
export function PlaylistsTab({
  onFavorites,
  onOpen,
}: {
  onFavorites: () => void;
  onOpen: (id: number) => void;
}) {
  const t = useT();
  const { list, ready } = usePlaylists();

  useEffect(() => {
    void usePlaylists.getState().load();
  }, []);

  const auto = [
    { icon: 'favorite', label: t('favorites'), run: onFavorites },
    { icon: 'history', label: t('recentPlays') },
    { icon: 'trending_up', label: t('mostPlayed') },
  ];

  return (
    <div className="flex flex-col gap-4 pb-4">
      <div className="grid grid-cols-3 gap-2.5">
        {auto.map((a) => (
          <button
            key={a.label}
            type="button"
            disabled={!a.run}
            onClick={a.run}
            aria-label={a.run ? a.label : t('plannedNamed', { name: a.label })}
            className={`relative flex h-[88px] flex-col justify-between rounded-[14px] p-3 text-left ${
              a.run ? 'bg-coral-subtle' : 'bg-surface'
            }`}
          >
            <Icon
              name={a.icon}
              size={24}
              fill={!!a.run}
              className={a.run ? 'text-coral-strong' : 'text-faint'}
            />
            <span className={`text-[13.5px] font-bold ${a.run ? '' : 'text-faint'}`}>
              {a.label}
            </span>
            {!a.run && (
              <span className="absolute right-2 top-2 rounded-xs bg-planned-ink px-1 py-px font-mono text-[9px] font-bold text-planned">
                {t('planned')}
              </span>
            )}
          </button>
        ))}
      </div>

      <div className="flex items-center gap-2">
        <h2 className="m-0 flex-1 text-[15px] font-bold">{t('myPlaylists', { n: list.length })}</h2>
        <button
          type="button"
          disabled
          aria-label={t('m3uPlanned')}
          title={t('m3uPlanned')}
          className="h-9 rounded-full border border-line-strong px-3 font-mono text-[12px] font-bold text-muted opacity-45"
        >
          M3U
        </button>
      </div>

      <ul aria-label={t('playlists')} className="m-0 flex list-none flex-col gap-1 p-0">
        <li>
          <button
            type="button"
            onClick={newPlaylist}
            className="flex h-16 w-full items-center gap-3 text-left"
          >
            <span className="grid h-14 w-14 place-items-center rounded-[10px] border-2 border-dashed border-faint-icon text-muted">
              <Icon name="add" size={26} />
            </span>
            <span className="text-[14.5px] font-bold">{t('newPlaylist')}</span>
          </button>
        </li>
        {list.map((p) => (
          <PlaylistRow key={p.id} playlist={p} onOpen={() => onOpen(p.id)} />
        ))}
      </ul>
      {ready && list.length === 0 && (
        <p className="m-0 py-4 text-center text-[13.5px] text-muted">{t('playlistsEmptyMobile')}</p>
      )}
    </div>
  );
}

function PlaylistRow({ playlist, onOpen }: { playlist: PlaylistSummary; onOpen: () => void }) {
  const t = useT();
  return (
    <li>
      <button
        type="button"
        onClick={onOpen}
        className="flex h-16 w-full items-center gap-3 text-left"
      >
        <Mosaic covers={playlist.covers} className="h-14 w-14 shrink-0 rounded-[10px]" />
        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
          <span className="truncate text-[14.5px] font-bold">{playlist.name}</span>
          <span className="truncate text-[12.5px] text-muted">
            {[
              songs(playlist.count, t),
              playlist.durationSecs > 0 && durationLabel(playlist.durationSecs),
            ]
              .filter(Boolean)
              .join(' · ')}
          </span>
        </span>
        <Icon name="chevron_right" size={22} className="text-muted" />
      </button>
    </li>
  );
}

/** A playlist (screen 06 → list): play, shuffle, entries, rename, delete. */
export function PlaylistPage({ id, onBack }: { id: number; onBack: () => void }) {
  const t = useT();
  const current = usePlaylists((s) => (s.current?.id === id ? s.current : null));
  const summary = usePlaylists((s) => s.list.find((p) => p.id === id));
  const currentId = useUi((s) => s.nowPlaying?.id);
  const [confirm, setConfirm] = useState(false);

  useEffect(() => {
    void usePlaylists.getState().open(id);
    return () => void usePlaylists.getState().open(null);
  }, [id]);

  const items = current?.items ?? [];
  const name = current?.name ?? summary?.name ?? '';
  const playable = items.filter((m) => !m.missing);
  const total = playable.reduce((sum, m) => sum + (m.durationSecs ?? 0), 0);
  const source = t('sourcePlaylist', { name });

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
        <span className="flex-1 text-[13px] font-semibold text-muted">{t('playlists')}</span>
        <Menu
          label={t('playlistActions')}
          trigger={({ open, toggle, id: menuId }) => (
            <button
              type="button"
              aria-label={t('playlistActions')}
              aria-haspopup="menu"
              aria-expanded={open}
              aria-controls={menuId}
              onClick={toggle}
              className="grid h-12 w-12 place-items-center"
            >
              <Icon name="more_vert" size={24} />
            </button>
          )}
          items={[
            {
              label: t('rename'),
              icon: 'drive_file_rename_outline',
              onSelect: () => useUi.setState({ playlistDialog: { kind: 'rename', id, name } }),
            },
            {
              label: t('deletePlaylist'),
              icon: 'delete',
              danger: true,
              onSelect: () => setConfirm(true),
            },
          ]}
        />
      </div>
      <div className="flex flex-col gap-4 px-4 pb-4">
        <div className="flex items-center gap-4">
          <Mosaic covers={summary?.covers ?? []} className="h-28 w-28 shrink-0 rounded-xl" />
          <div className="flex min-w-0 flex-1 flex-col gap-1">
            <h1 className="m-0 break-words text-[24px] font-extrabold leading-7 tracking-[-0.01em]">
              {name}
            </h1>
            <span className="text-[13px] text-muted">
              {[songs(items.length, t), total > 0 && durationLabel(total)]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </div>
        </div>
        <div className="flex gap-2.5">
          <button
            type="button"
            disabled={!playable.length}
            onClick={() => play(items, undefined, source)}
            className="flex h-12 flex-1 items-center justify-center gap-2 rounded-full bg-coral text-[14.5px] font-extrabold text-coral-ink disabled:opacity-50"
          >
            <Icon name="play_arrow" size={22} fill />
            {t('playAll')}
          </button>
          <button
            type="button"
            disabled={!playable.length}
            onClick={() => {
              const order = shuffled(playable);
              play(order, order[0], source);
            }}
            className="flex h-12 flex-1 items-center justify-center gap-2 rounded-full border border-line-strong bg-surface2 text-[14px] font-semibold disabled:opacity-50"
          >
            <Icon name="shuffle" size={20} />
            {t('shuffle')}
          </button>
        </div>
        {current && items.length === 0 && (
          <div className="flex flex-col items-center gap-1 py-8 text-center">
            <span className="text-[15px] font-bold">{t('playlistEmptyTitle')}</span>
            <span className="text-[13px] text-muted">{t('playlistEmptyBody')}</span>
          </div>
        )}
        <ol aria-label={name} className="m-0 flex list-none flex-col p-0">
          {items.map((m, i) => {
            const on = m.id === currentId;
            return (
              <li
                key={`${i}-${m.id}`}
                className={`flex h-16 items-center gap-3 ${m.missing ? 'opacity-[.72]' : ''}`}
              >
                <button
                  type="button"
                  disabled={m.missing}
                  onClick={() => play(items, m, source)}
                  aria-label={t('playTitle', { title: m.title })}
                  className="flex min-w-0 flex-1 items-center gap-3 text-left"
                >
                  <MediaThumb media={m} className="h-12 w-12 rounded-lg">
                    {on && (
                      <span className="absolute inset-0 grid place-items-center rounded-lg bg-[rgb(16_24_32/0.6)] text-coral-strong">
                        <Icon name="equalizer" size={24} />
                      </span>
                    )}
                  </MediaThumb>
                  <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span
                      className={`truncate text-[14.5px] font-bold ${on ? 'text-coral-strong' : ''}`}
                    >
                      {m.title}
                    </span>
                    {m.missing ? (
                      <span className="flex items-center gap-1 text-[12.5px] text-warn">
                        <Icon name="folder_off" size={16} />
                        {t('fileNotFound')}
                      </span>
                    ) : (
                      <span className="truncate text-[12.5px] text-muted">
                        {[m.artist, durationLabel(m.durationSecs)].filter(Boolean).join(' · ')}
                      </span>
                    )}
                  </span>
                </button>
                <button
                  type="button"
                  aria-label={`${t('removeFromPlaylist')} : ${m.title}`}
                  onClick={() => void usePlaylists.getState().removeAt(id, i)}
                  className="grid h-12 w-10 shrink-0 place-items-center text-muted"
                >
                  <Icon name="close" size={20} />
                </button>
              </li>
            );
          })}
        </ol>
      </div>
      <BottomSheet
        open={confirm}
        onClose={() => setConfirm(false)}
        label={t('deletePlaylistTitle', { name })}
      >
        <h2 className="m-0 text-[19px] font-extrabold">{t('deletePlaylistTitle', { name })}</h2>
        <p className="m-0 text-[14px] text-muted">{t('deletePlaylistBody')}</p>
        <div className="flex gap-2.5">
          <button
            type="button"
            autoFocus
            onClick={() => setConfirm(false)}
            className="h-[52px] flex-1 rounded-full border border-line-strong bg-surface2 text-[14.5px] font-semibold"
          >
            {t('cancel')}
          </button>
          <button
            type="button"
            onClick={() => {
              setConfirm(false);
              void usePlaylists
                .getState()
                .remove(id)
                .then((ok) => ok && onBack());
            }}
            className="h-[52px] flex-1 rounded-full bg-danger text-[14.5px] font-extrabold text-white"
          >
            {t('deletePlaylist')}
          </button>
        </div>
      </BottomSheet>
    </>
  );
}

import { useEffect, useState } from 'react';
import { EmptyState } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { LocalThumb } from '../../components/LocalThumb';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { GroupBy, MediaGroup } from '../../services/types';
import { openGroup } from '../../app/navigation';
import { durationLabel } from './format';

/** Albums, artists or folders of the music library (Windows v2, L06). */
export function GroupsView({ by }: { by: GroupBy }) {
  const t = useT();
  const groups = useGroups(by);
  const tracks = (n: number) => (n === 1 ? t('oneTrack') : t('tracksCount', { n }));
  const albums = (n: number) => (n === 1 ? t('oneAlbum') : t('albumsCount', { n }));

  if (groups === null) return null;
  if (groups instanceof Error) {
    return <EmptyState icon="error">{groups.message}</EmptyState>;
  }
  if (groups.length === 0) {
    return (
      <EmptyState icon={by === 'album' ? 'album' : by === 'artist' ? 'person' : 'folder'}>
        {by === 'album' ? t('noAlbums') : by === 'artist' ? t('noArtists') : t('noFolders')}
      </EmptyState>
    );
  }

  if (by === 'folder') {
    return (
      <div className="flex flex-col gap-3">
        <ul aria-label={t('folders')} className="m-0 flex list-none flex-col gap-2 p-0">
          {groups.map((g) => (
            <li key={g.name}>
              <button
                type="button"
                onClick={() => openGroup({ by, name: g.name })}
                className="flex w-full items-center gap-3.5 rounded-lg border border-line bg-surface px-4 py-3 text-left hover:bg-surface2"
              >
                <Icon name="folder" className="text-muted" />
                <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <span className="truncate font-mono text-[12.5px]" title={g.name}>
                    {g.name}
                  </span>
                  <span className="text-[12px] text-muted">
                    {tracks(g.count)} · {durationLabel(g.durationSecs)}
                  </span>
                </span>
                <Icon name="chevron_right" className="text-faint" />
              </button>
            </li>
          ))}
        </ul>
        <p className="m-0 text-[12px] text-muted">{t('folderNote')}</p>
      </div>
    );
  }

  const round = by === 'artist';
  return (
    <ul
      aria-label={by === 'album' ? t('albums') : t('artists')}
      className="m-0 grid list-none grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-x-4 gap-y-5 p-0"
    >
      {groups.map((g) => (
        <li key={g.name}>
          <button
            type="button"
            onClick={() => openGroup({ by, name: g.name })}
            className={`group flex w-full flex-col gap-2 text-left ${round ? 'items-center text-center' : ''}`}
          >
            <LocalThumb
              path={round ? null : g.thumbnail}
              kind="audio"
              className={`aspect-square w-full border border-line group-hover:outline-2 group-hover:outline-offset-2 group-hover:outline-accent ${
                round ? 'rounded-full' : 'rounded-md'
              }`}
            >
              {round && <Icon name="person" size={48} className="relative text-faint" />}
            </LocalThumb>
            <span className="w-full truncate text-[13.5px] font-bold">{g.name}</span>
            <span className="-mt-1.5 w-full truncate text-[12px] text-muted">
              {by === 'album'
                ? t('albumTracks', { artist: g.detail ?? '—', tracks: tracks(g.count) })
                : t('artistAlbums', { albums: albums(Number(g.detail ?? 0)), tracks: tracks(g.count) })}
            </span>
          </button>
        </li>
      ))}
    </ul>
  );
}

function useGroups(by: GroupBy) {
  const [state, setState] = useState<{ by: GroupBy; groups: MediaGroup[] | Error } | null>(null);
  useEffect(() => {
    let alive = true;
    const load = () =>
      backend
        .libraryGroups(by)
        .then((groups) => alive && setState({ by, groups }))
        .catch((e: unknown) => alive && setState({ by, groups: e instanceof Error ? e : new Error(String(e)) }));
    void load();
    const stop = backend.onLibraryChanged(() => void load());
    return () => {
      alive = false;
      stop();
    };
  }, [by]);
  return state?.by === by ? state.groups : null;
}

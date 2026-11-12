import { useState, type KeyboardEvent, type MouseEvent, type RefObject } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { IconButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { isActive, usePlayer } from '../../stores/player';
import { durationLabel } from './format';

const COLUMNS = 'grid-cols-[44px_minmax(0,2fr)_minmax(0,1.3fr)_minmax(0,1.3fr)_64px_104px]';

interface Handlers {
  onContextMenu: (e: MouseEvent) => void;
  onKeyDown: (e: KeyboardEvent<HTMLElement>) => void;
}

/** Windows v2 Tracks table (52 px rows); the playing track is coral. */
export function TracksTable({
  items,
  scrollRef,
  onPlay,
  onEditTags,
  onMore,
  handlers,
  showTrackNo = false,
  positionKeys = false,
}: {
  items: MediaRecord[];
  scrollRef: RefObject<HTMLDivElement | null>;
  onPlay: (m: MediaRecord) => void;
  onEditTags: (m: MediaRecord) => void;
  onMore: (m: MediaRecord, e: MouseEvent) => void;
  handlers: (m: MediaRecord) => Handlers;
  /** Album view: the first column shows the track number. */
  showTrackNo?: boolean;
  /** Playlists may list a media twice: rows are keyed by position. */
  positionKeys?: boolean;
}) {
  const t = useT();
  const currentId = usePlayer((s) => s.media?.id);
  const playing = usePlayer((s) => isActive(s.state));
  const [body, setBody] = useState<HTMLDivElement | null>(null);
  // eslint-disable-next-line react-hooks/incompatible-library -- TanStack Virtual is not memoizable; the React Compiler is not used here.
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => 52,
    overscan: 8,
    scrollMargin: body?.offsetTop ?? 0,
  });

  return (
    <div
      role="table"
      aria-label={t('tracks')}
      className="overflow-hidden rounded-lg border border-line"
    >
      <div
        role="row"
        className={`grid ${COLUMNS} h-9 items-center gap-4 bg-row px-3 text-[11.5px] font-bold uppercase tracking-[0.04em] text-faint`}
      >
        <span role="columnheader" />
        <span role="columnheader">{t('colTitle')}</span>
        <span role="columnheader">{t('colArtist')}</span>
        <span role="columnheader">{t('colAlbum')}</span>
        <span role="columnheader" className="text-right">
          {t('colDuration')}
        </span>
        <span role="columnheader" />
      </div>
      <div ref={setBody} className="relative" style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map((row) => {
          const m = items[row.index]!;
          const on = m.id === currentId;
          const { onContextMenu, onKeyDown } = handlers(m);
          return (
            <div
              key={positionKeys ? `${row.index}:${m.id}` : m.id}
              role="row"
              tabIndex={0}
              aria-current={on ? 'true' : undefined}
              onDoubleClick={() => onPlay(m)}
              onContextMenu={onContextMenu}
              onKeyDown={(e) => {
                if (e.key === 'Enter') onPlay(m);
                else onKeyDown(e);
              }}
              className={`group absolute left-0 top-0 grid w-full ${COLUMNS} h-[52px] items-center gap-4 border-t border-line px-3 text-[13px] hover:bg-surface ${
                on ? 'bg-surface' : ''
              }`}
              style={{ transform: `translateY(${row.start - virtualizer.options.scrollMargin}px)` }}
            >
              <span role="cell" className="grid place-items-center">
                {showTrackNo && !on ? (
                  <span className="font-mono text-[12px] text-muted group-hover:hidden">
                    {m.trackNo ?? '—'}
                  </span>
                ) : null}
                <button
                  type="button"
                  tabIndex={-1}
                  aria-label={t('playTitle', { title: m.title })}
                  onClick={() => (on ? usePlayer.getState().toggle() : onPlay(m))}
                  className={`h-8 w-8 place-items-center rounded-full ${
                    showTrackNo && !on ? 'hidden group-hover:grid' : 'grid'
                  } ${on ? 'bg-coral text-coral-ink' : 'bg-surface2 text-fg hover:bg-coral-subtle hover:text-coral-strong'}`}
                >
                  <Icon name={on && playing ? 'pause' : 'play_arrow'} size={20} fill />
                </button>
              </span>
              <span
                role="cell"
                className={`truncate font-bold ${on ? 'text-coral-strong' : ''}`}
                title={m.title}
              >
                {m.title}
              </span>
              <span role="cell" className="truncate text-muted">
                {m.artist ?? '—'}
              </span>
              <span role="cell" className="truncate text-muted">
                {m.album ?? '—'}
              </span>
              <span role="cell" className="text-right font-mono text-[12px] text-muted tabular">
                {durationLabel(m.durationSecs)}
              </span>
              <span role="cell" className="flex justify-end">
                <IconButton
                  icon="favorite"
                  fill={!!m.favorite}
                  label={
                    m.favorite
                      ? t('unfavorite', { title: m.title })
                      : t('favorite', { title: m.title })
                  }
                  aria-pressed={!!m.favorite}
                  size={32}
                  tabIndex={-1}
                  onClick={() => void useLibrary.getState().toggleFavorite(m)}
                  className={
                    m.favorite
                      ? '!text-coral'
                      : 'opacity-0 group-focus-within:opacity-100 group-hover:opacity-100'
                  }
                />
                <IconButton
                  icon="edit_note"
                  label={t('editTags')}
                  size={32}
                  tabIndex={-1}
                  onClick={() => onEditTags(m)}
                  className="opacity-0 group-focus-within:opacity-100 group-hover:opacity-100"
                />
                <IconButton
                  icon="more_horiz"
                  label={t('moreActions')}
                  size={32}
                  tabIndex={-1}
                  onClick={(e) => onMore(m, e)}
                />
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

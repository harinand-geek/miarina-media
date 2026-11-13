import { Icon } from '../../components/Icon';
import { BottomSheet } from '../../components/Overlay';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { qualityLabel } from './format';
import { useMediaActions } from './useMediaActions';

/**
 * Android actions for a library file (⋮ buttons, long press on a tile).
 * Not in the design handoff: composed from the bottom sheet and the mobile
 * row metrics of the design system (documented in design-implementation-map).
 */
export function MobileMediaSheet({
  media,
  onClose,
  onRename,
  inPlayer,
}: {
  media: MediaRecord;
  onClose: () => void;
  onRename: (media: MediaRecord) => void;
  inPlayer: boolean;
}) {
  const t = useT();
  const actions = useMediaActions();
  const items = [
    !inPlayer && { icon: 'play_arrow', label: t('play'), run: () => actions.open(media) },
    media.kind === 'audio' && {
      icon: 'favorite',
      label: media.favorite ? t('removeFavorite') : t('addFavorite'),
      run: () => void useLibrary.getState().toggleFavorite(media),
    },
    media.kind === 'audio' && {
      icon: 'playlist_add',
      label: t('addToPlaylist'),
      run: () => useUi.setState({ playlistDialog: { kind: 'add', ids: [media.id] } }),
    },
    { icon: 'share', label: t('share'), run: () => actions.share(media) },
    { icon: 'open_in_new', label: t('openWith'), run: () => actions.openWith(media) },
    media.sourceUrl && {
      icon: 'content_copy',
      label: t('copySourceLink'),
      run: () => actions.copyLink(media),
    },
    // The player covers the screen: renaming and deleting happen from the lists.
    !inPlayer && {
      icon: 'drive_file_rename_outline',
      label: t('rename'),
      run: () => onRename(media),
    },
    !inPlayer && {
      icon: 'delete',
      label: t('removeOrDelete'),
      run: () => actions.askDelete(media),
      danger: true,
    },
  ].filter(Boolean) as { icon: string; label: string; run: () => void; danger?: boolean }[];

  return (
    <BottomSheet open onClose={onClose} label={`Actions for ${media.title}`}>
      <div className="flex flex-col gap-0.5 px-1">
        <span className="truncate text-[16px] font-bold">{media.title}</span>
        <span className="text-[12.5px] text-muted">
          {qualityLabel(media)} · {formatBytes(media.sizeBytes)}
        </span>
      </div>
      <div className="flex flex-col">
        {items.map((item) => (
          <button
            key={item.label}
            type="button"
            onClick={() => {
              onClose();
              item.run();
            }}
            className={`flex h-14 items-center gap-4 rounded-[10px] px-2 text-left text-[15px] active:bg-surface2 ${
              item.danger ? 'text-danger' : 'text-fg'
            }`}
          >
            <Icon name={item.icon} size={24} className={item.danger ? '' : 'text-muted'} />
            {item.label}
          </button>
        ))}
      </div>
    </BottomSheet>
  );
}

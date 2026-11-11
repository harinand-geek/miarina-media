import { backend } from '../../services/backend';
import { detectPlatform } from '../../services/platform';
import type { MediaRecord } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { playFrom } from '../../app/navigation';

/** Library actions shared by the grid, the list and keyboard shortcuts. */
const desktop = detectPlatform() !== 'android';

export function useMediaActions() {
  const play = useUi((s) => s.play);
  const go = useUi((s) => s.go);
  const pushToast = useUi((s) => s.pushToast);
  const askConfirm = useUi((s) => s.askConfirm);
  const remove = useLibrary((s) => s.remove);

  const report = (e: unknown) =>
    pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });

  return {
    /**
     * Desktop: plays through the shared engine, with the visible list of the
     * same kind as the play queue. Android keeps its own player sheet.
     */
    open: (media: MediaRecord, list?: MediaRecord[]) => {
      if (desktop) {
        playFrom(media, list?.filter((m) => m.kind === media.kind && !m.missing));
        return;
      }
      play(media);
      go('player');
    },
    reveal: (media: MediaRecord) => void backend.libraryReveal(media.id).catch(report),
    /** Android: share sheet / "Open with" chooser. */
    share: (media: MediaRecord) => void backend.libraryShare(media.id).catch(report),
    openWith: (media: MediaRecord) => void backend.libraryOpenExternal(media.id).catch(report),
    copyLink: (media: MediaRecord) => {
      if (!media.sourceUrl) {
        pushToast({ tone: 'error', message: 'This file has no source link.' });
        return;
      }
      navigator.clipboard
        ?.writeText(media.sourceUrl)
        .then(() => pushToast({ tone: 'success', message: 'Source link copied' }))
        .catch(report);
    },
    askDelete: (media: MediaRecord) =>
      askConfirm({
        title: 'Delete this file?',
        body: `“${media.title}” will be removed from your library and deleted from disk.`,
        confirmLabel: 'Delete file',
        onConfirm: () => void remove(media.id),
      }),
  };
}

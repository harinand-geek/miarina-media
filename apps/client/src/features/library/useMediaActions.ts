import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';

/** Library actions shared by the grid, the list and keyboard shortcuts. */
export function useMediaActions() {
  const play = useUi((s) => s.play);
  const go = useUi((s) => s.go);
  const pushToast = useUi((s) => s.pushToast);
  const askConfirm = useUi((s) => s.askConfirm);
  const remove = useLibrary((s) => s.remove);

  const report = (e: unknown) =>
    pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });

  return {
    open: (media: MediaRecord) => {
      play(media);
      go('player');
    },
    reveal: (media: MediaRecord) => void backend.libraryReveal(media.id).catch(report),
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

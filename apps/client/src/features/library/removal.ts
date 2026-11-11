import type { Translate } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { detectPlatform } from '../../services/platform';
import { useUi } from '../../stores/ui';

/** Runs the "Remove or delete" choice (COM-10) and confirms it with a toast. */
export async function applyRemoval(media: MediaRecord, deleteFile: boolean, t: Translate) {
  useUi.getState().askRemoval(null);
  const library = useLibrary.getState();
  const done = deleteFile
    ? await library.remove(media.id)
    : await library.removeFromLibrary(media.id);
  if (done) {
    useUi.getState().pushToast({
      tone: 'success',
      // Desktop deletion goes to the Recycle Bin; Android deletes for good.
      message: deleteFile
        ? t(detectPlatform() === 'android' ? 'deleteDone' : 'trashDone')
        : t('removeDone'),
    });
  }
}

/** Android shared storage paths read better without the volume prefix. */
export const displayPath = (path: string) => path.replace(/^\/storage\/emulated\/\d+\//, '');

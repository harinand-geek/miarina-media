import { t } from '../../i18n';
import { backend } from '../../services/backend';
import type { FolderImport, MediaRecord } from '../../services/types';
import { usePlayer } from '../../stores/player';
import { useUi } from '../../stores/ui';

/** Plays opened files: video on the player, audio on "Now playing". */
export function playOpened(media: MediaRecord[]) {
  const first = media[0];
  if (!first) return;
  usePlayer.getState().playMedia(first, media);
  useUi.setState({ screen: first.kind === 'video' ? 'player' : 'now', space: 'play' });
}

export function reportImport(result: FolderImport) {
  const added = result.added + result.restored;
  useUi.getState().pushToast({
    tone: 'success',
    message:
      added > 0 ? t('folderImported', { n: added }) : t('folderNothingNew', { n: result.found }),
  });
}

const fail = (e: unknown) =>
  useUi
    .getState()
    .pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });

/** WIN-04: media files picked in the system dialog. */
export async function openFiles() {
  try {
    playOpened(await backend.libraryOpenFiles());
  } catch (e) {
    fail(e);
  }
}

/** "Import a folder" (Windows v2 library). */
export async function importFolder() {
  try {
    const result = await backend.libraryImportFolder();
    if (result) reportImport(result);
  } catch (e) {
    fail(e);
  }
}

/** Files or folders dropped on the window (handled by Rust). */
export function listenForDrops() {
  return backend.onOpened(({ media, folders }) => {
    if (media.length) playOpened(media);
    for (const folder of folders) reportImport(folder);
    if (!media.length && !folders.length) {
      useUi.getState().pushToast({ tone: 'error', message: t('dropNothing') });
    }
  });
}

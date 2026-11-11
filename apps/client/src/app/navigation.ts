import { useLibrary } from '../stores/library';
import { usePlayer } from '../stores/player';
import { useUi, type LibraryView, type Screen } from '../stores/ui';
import type { MediaRecord } from '../services/types';

/** Video plays on the video screen; audio on "Now playing". */
export const playerScreenFor = (media: MediaRecord | null): Screen =>
  media?.kind === 'video' ? 'player' : 'now';

/** Opens a sidebar section (the browser is a screen of the main window too). */
export function openSection(id: Screen) {
  if (id === 'player' || id === 'now') {
    useUi.getState().go(playerScreenFor(usePlayer.getState().media));
    return;
  }
  if (id === 'library') {
    openLibrary(useUi.getState().libraryView);
    return;
  }
  useUi.getState().go(id);
}

/** Play space: Tracks list audio, Videos lists video. */
export function openLibrary(view: LibraryView) {
  useUi.setState({ libraryView: view });
  useUi.getState().go('library');
  const kind = view === 'videos' ? 'video' : 'audio';
  if (useLibrary.getState().kind !== kind) useLibrary.getState().setKind(kind);
}

/** Plays `media` with `queue` as the play queue and shows its player. */
export function playFrom(media: MediaRecord, queue?: MediaRecord[]) {
  usePlayer.getState().playMedia(media, queue);
  useUi.getState().go(playerScreenFor(media));
}

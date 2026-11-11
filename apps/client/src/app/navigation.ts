import { useLibrary } from '../stores/library';
import { usePlayer } from '../stores/player';
import { useUi, type LibraryGroup, type LibraryView, type Screen } from '../stores/ui';
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

/** Play space: music views list audio, Videos lists video. */
export function openLibrary(view: LibraryView) {
  useUi.setState({ libraryView: view, libraryGroup: null });
  useUi.getState().go('library');
  useLibrary.getState().show(view === 'videos' ? 'video' : 'audio', null);
}

/** Tracks of one album, artist or folder. */
export function openGroup(group: LibraryGroup) {
  useUi.setState({ libraryGroup: group });
  useLibrary.getState().show('audio', group);
}

/** Plays `media` with `queue` as the play queue and shows its player. */
export function playFrom(media: MediaRecord, queue?: MediaRecord[]) {
  usePlayer.getState().playMedia(media, queue);
  useUi.getState().go(playerScreenFor(media));
}

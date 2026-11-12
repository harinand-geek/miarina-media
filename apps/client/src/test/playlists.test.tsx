import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { backend, resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { usePlaylists } from '../stores/playlists';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeAll(async () => {
  await Promise.all([
    import('../features/library/LibraryScreen'),
    import('../features/player/NowPlayingScreen'),
  ]);
});

beforeEach(async () => {
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  usePlaylists.setState(usePlaylists.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  stop = useLibrary.getState().init();
  await waitFor(() => expect(useLibrary.getState().ready).toBe(true));
});

afterEach(() => stop());

const openView = async (view: 'tracks' | 'favorites' | 'playlists') => {
  useUi.setState({ screen: 'library', space: 'play', libraryView: view });
  render(<DesktopShell />);
};

const row = (title: string) =>
  screen.getAllByRole('row').find((r) => r.textContent?.includes(title))!;

describe('favorites (COM-06)', () => {
  it('marks a track with the heart and lists it under Favorites', async () => {
    const user = userEvent.setup();
    await openView('tracks');
    await waitFor(() => expect(useLibrary.getState().items.length).toBe(3));
    const title = useLibrary.getState().items[0]!.title;
    await user.click(within(row(title)).getByRole('button', { name: `Add ${title} to favorites` }));
    expect(
      await within(row(title)).findByRole('button', { name: `Remove ${title} from favorites` }),
    ).toHaveAttribute('aria-pressed', 'true');

    await user.click(screen.getByRole('button', { name: /^favoriteFavorites$|Favorites$/ }));
    await waitFor(() => expect(useLibrary.getState().items.map((m) => m.title)).toEqual([title]));
    await user.click(
      within(row(title)).getByRole('button', { name: `Remove ${title} from favorites` }),
    );
    expect(await screen.findByText('No favorites yet')).toBeInTheDocument();
  });
});

describe('playlists (COM-06, COM-11)', () => {
  it('creates a playlist, adds tracks, reorders and removes them', async () => {
    const user = userEvent.setup();
    const [a, b] = (await backend.libraryQuery({ search: '', kind: 'audio', sort: 'title' })).items;
    await openView('playlists');
    await user.click(await screen.findByRole('button', { name: /New playlist/ }));
    await user.type(screen.getByRole('textbox', { name: 'Playlist name' }), 'Matin calme');
    await user.click(screen.getByRole('button', { name: 'Create' }));
    expect(await screen.findByText('Playlist “Matin calme” created')).toBeInTheDocument();

    const list = usePlaylists.getState().list[0]!;
    await usePlaylists.getState().add(list.id, [a!.id, b!.id]);
    await user.click(screen.getByRole('button', { name: /Matin calme/ }));
    expect(await screen.findByRole('heading', { name: /Matin calme/ })).toBeInTheDocument();
    await waitFor(() => expect(usePlaylists.getState().current?.items.length).toBe(2));

    // Alt + ↓ moves the first entry down; Del removes it from the playlist only.
    row(a!.title).focus();
    await user.keyboard('{Alt>}{ArrowDown}{/Alt}');
    await waitFor(() =>
      expect(usePlaylists.getState().current?.items.map((m) => m.id)).toEqual([b!.id, a!.id]),
    );
    row(a!.title).focus();
    await user.keyboard('{Delete}');
    await waitFor(() =>
      expect(usePlaylists.getState().current?.items.map((m) => m.id)).toEqual([b!.id]),
    );
    expect(useLibrary.getState().items.some((m) => m.id === a!.id)).toBe(true);

    await user.click(screen.getByRole('button', { name: /Export M3U/ }));
    expect(await screen.findByText(/Playlist exported: .*Matin calme\.m3u8/)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /Delete playlist/ }));
    await user.click(
      within(screen.getByRole('alertdialog')).getByRole('button', { name: 'Delete playlist' }),
    );
    await waitFor(() => expect(usePlaylists.getState().list).toEqual([]));
  });

  it('adds a track from its menu and imports an M3U file', async () => {
    const user = userEvent.setup();
    await usePlaylists.getState().create('Soir');
    await openView('tracks');
    await waitFor(() => expect(useLibrary.getState().items.length).toBe(3));
    const title = useLibrary.getState().items[0]!.title;
    await user.click(within(row(title)).getByRole('button', { name: 'More actions' }));
    await user.click(screen.getByRole('menuitem', { name: /Add to playlist/ }));
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByRole('radio', { name: /Soir/ })).toHaveAttribute(
      'aria-checked',
      'true',
    );
    await user.click(within(dialog).getByRole('button', { name: 'Add' }));
    expect(await screen.findByText('Added to “Soir”')).toBeInTheDocument();

    await usePlaylists.getState().importM3u();
    expect(
      await screen.findByText(/“Imported” imported · 3 tracks, 1 not in the library/),
    ).toBeInTheDocument();
  });

  it('saves the play queue as a playlist from Now playing', async () => {
    const user = userEvent.setup();
    const tracks = (await backend.libraryQuery({ search: '', kind: 'audio', sort: 'title' })).items;
    usePlayer.getState().playMedia(tracks[0]!, tracks);
    useUi.setState({ screen: 'now', space: 'play' });
    render(<DesktopShell />);
    await user.click(await screen.findByRole('button', { name: /Save as playlist/ }));
    expect(screen.getByText('With the 3 tracks of the play queue.')).toBeInTheDocument();
    await user.type(screen.getByRole('textbox', { name: 'Playlist name' }), 'File du jour');
    await user.click(screen.getByRole('button', { name: 'Create' }));
    await waitFor(() => expect(usePlaylists.getState().list[0]?.count).toBe(3));
  });
});

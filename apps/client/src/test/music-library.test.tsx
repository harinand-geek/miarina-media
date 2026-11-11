import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { tagsFromFileName } from '../features/library/tagNames';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { useSettings } from '../stores/settings';
import { useUi, type LibraryView } from '../stores/ui';

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
  useSettings.setState(useSettings.getInitialState(), true);
  stop = useLibrary.getState().init();
  await waitFor(() => expect(useLibrary.getState().ready).toBe(true));
});

afterEach(() => stop());

function openView(view: LibraryView) {
  useUi.setState({ screen: 'library', space: 'play', libraryView: view });
  render(<DesktopShell />);
}

describe('music library (L06)', () => {
  it('lists albums and opens one in track order, then plays it all', async () => {
    const user = userEvent.setup();
    openView('albums');
    const albums = await screen.findByRole('list', { name: 'Albums' }, { timeout: 3000 });
    expect(within(albums).getByText('Musopen Piano')).toBeInTheDocument();
    expect(within(albums).getByText('Musopen · 2 tracks')).toBeInTheDocument();

    await user.click(within(albums).getByText('Musopen Piano'));
    expect(await screen.findByRole('heading', { name: /Musopen Piano/ })).toBeInTheDocument();
    await waitFor(() =>
      expect(useLibrary.getState().items.map((m) => m.title)).toEqual([
        'Gymnopédie No. 1 — Satie',
        'Clair de Lune — Debussy',
      ]),
    );
    await user.click(screen.getByRole('button', { name: 'Back' }));
    await user.click(
      within(await screen.findByRole('list', { name: 'Albums' })).getByText('Musopen Piano'),
    );
    await user.click(await screen.findByRole('button', { name: /Play all/ }));
    expect(usePlayer.getState().media?.title).toBe('Gymnopédie No. 1 — Satie');
    expect(usePlayer.getState().queue).toHaveLength(2);
    expect(useUi.getState().screen).toBe('now');
  });

  it('groups artists and folders', async () => {
    const user = userEvent.setup();
    openView('artists');
    const artists = await screen.findByRole('list', { name: 'Artists' }, { timeout: 3000 });
    expect(within(artists).getByText('Erik Satie')).toBeInTheDocument();
    expect(within(artists).getByText('NASA')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Folders' }));
    const folders = await screen.findByRole('list', { name: 'Folders' });
    expect(within(folders).getByText('C:\\Users\\Rina\\Videos\\Miarina')).toBeInTheDocument();
    expect(within(folders).getByText(/3 tracks/)).toBeInTheDocument();
  });

  it('edits tags of a track and writes them to the file', async () => {
    const user = userEvent.setup();
    openView('tracks');
    const table = await screen.findByRole('table', { name: 'Tracks' }, { timeout: 3000 });
    const row = within(table)
      .getAllByRole('row')
      .find((r) => r.textContent?.includes('Clair de Lune'))!;
    await user.click(within(row).getByRole('button', { name: 'Edit tags' }));

    const dialog = await screen.findByRole('dialog', { name: 'Edit tags' });
    const artist = within(dialog).getByRole('textbox', { name: 'Artist' });
    await waitFor(() => expect(artist).toHaveValue('Claude Debussy'));
    await user.clear(artist);
    await user.type(artist, 'C. Debussy');
    expect(artist.className).toContain('border-accent');
    expect(within(dialog).getByRole('checkbox', { name: /Also write to the file/ })).toBeChecked();

    const year = within(dialog).getByRole('textbox', { name: 'Year' });
    await user.clear(year);
    await user.type(year, '20x');
    expect(within(dialog).getByRole('button', { name: 'Save' })).toBeDisabled();
    await user.clear(year);
    await user.type(year, '1905');

    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Tags written to the file.')).toBeInTheDocument();
    await waitFor(() =>
      expect(
        useLibrary.getState().items.find((m) => m.title === 'Clair de Lune — Debussy')?.artist,
      ).toBe('C. Debussy'),
    );
  });

  it('keeps video tags in the library only', async () => {
    const user = userEvent.setup();
    openView('videos');
    const grid = await screen.findByRole('list', { name: /Library items/ }, { timeout: 3000 });
    await user.pointer({ keys: '[MouseRight]', target: within(grid).getAllByRole('button')[0]! });
    await user.click(screen.getByRole('menuitem', { name: /Edit tags/ }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit tags' });
    expect(
      within(dialog).getByText('This format keeps its tags in the Miarina library only.'),
    ).toBeInTheDocument();
    expect(within(dialog).queryByRole('checkbox')).toBeNull();
    expect(within(dialog).getByRole('textbox', { name: 'Director / author' })).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(
      await screen.findByText('Tags saved in the library. File unchanged.'),
    ).toBeInTheDocument();
  });
});

describe('tags from a file name', () => {
  it('reads track number, artist and title', () => {
    expect(tagsFromFileName('C:\\M\\03 - Tsiory - Rivotra.mp3')).toEqual({
      trackNo: '3',
      artist: 'Tsiory',
      title: 'Rivotra',
    });
    expect(tagsFromFileName('/sdcard/Music/Ankorabe_Sound - Hira vaovao.flac')).toEqual({
      artist: 'Ankorabe Sound',
      title: 'Hira vaovao',
    });
    expect(tagsFromFileName('C:\\M\\07 Lalana.mp3')).toEqual({ title: 'Lalana' });
  });
});

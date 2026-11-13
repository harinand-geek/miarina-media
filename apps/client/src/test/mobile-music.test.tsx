import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { useMobilePlayback } from '../stores/mobilePlayback';
import { usePlaylists } from '../stores/playlists';
import { autoListIds } from '../features/library/autoLists';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  localStorage.clear();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  usePlaylists.setState(usePlaylists.getInitialState(), true);
  stop = useLibrary.getState().init();
  await waitFor(() => expect(useLibrary.getState().ready).toBe(true));
});

afterEach(() => stop());

async function openTab(name: RegExp) {
  const user = userEvent.setup();
  render(<MobileShell />);
  await user.click(
    within(screen.getByRole('navigation', { name: 'Main' })).getByRole('button', { name }),
  );
  return user;
}

describe('Android v2 Music', () => {
  it('lists tracks with a shuffle that fills the queue', async () => {
    const user = await openTab(/Music/);
    const tabs = screen.getByRole('tablist', { name: 'Music' });
    expect(within(tabs).getByRole('tab', { name: 'Songs' })).toHaveAttribute(
      'aria-selected',
      'true',
    );
    expect(within(tabs).getByRole('tab', { name: 'Playlists' })).toBeEnabled();
    expect(within(tabs).getByRole('tab', { name: 'Favorites' })).toBeEnabled();
    expect(await screen.findByText('3 songs')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Shuffle play' }));
    expect(useMobilePlayback.getState().queue).toHaveLength(3);
    expect(useUi.getState().nowPlaying).not.toBeNull();
  });

  it('opens an artist page and plays everything in order, then the next track', async () => {
    const user = await openTab(/Music/);
    await user.click(screen.getByRole('tab', { name: 'Artists' }));
    await user.click(await screen.findByRole('button', { name: 'Erik Satie' }));
    expect(await screen.findByRole('heading', { name: 'Erik Satie' })).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText(/1 album · 1 song/)).toBeInTheDocument());

    await user.click(screen.getByRole('button', { name: 'Back' }));
    await user.click(screen.getByRole('tab', { name: 'Albums' }));
    await user.click(await screen.findByRole('button', { name: 'Musopen Piano' }));
    await waitFor(() => expect(useLibrary.getState().items.map((m) => m.trackNo)).toEqual([1, 2]));
    await user.click(screen.getByRole('button', { name: /Play all/ }));
    expect(useUi.getState().nowPlaying?.title).toBe('Gymnopédie No. 1 — Satie');
    expect(useMobilePlayback.getState().queue.map((m) => m.trackNo)).toEqual([1, 2]);

    // The mini-player offers the next track of the queue.
    act(() => useUi.setState({ mobilePlayerExpanded: false }));
    const mini = screen.getByRole('region', { name: 'Now playing' });
    await user.click(within(mini).getByRole('button', { name: 'Next' }));
    expect(useUi.getState().nowPlaying?.title).toBe('Clair de Lune — Debussy');
    expect(
      within(screen.getByRole('region', { name: 'Now playing' })).getByRole('button', {
        name: 'Next',
      }),
    ).toBeDisabled();
  });

  it('plays an album straight from its cover', async () => {
    const user = await openTab(/Music/);
    await user.click(screen.getByRole('tab', { name: 'Albums' }));
    await user.click(await screen.findByRole('button', { name: 'Play Voyager Golden Record' }));
    await waitFor(() =>
      expect(useUi.getState().nowPlaying?.title).toBe('Voyager Golden Record — Sounds of Earth'),
    );
  });
});

describe('Android v2 Music › Favorites and Playlists', () => {
  it('marks a favorite from the ⋮ sheet and lists it in Favorites', async () => {
    const user = await openTab(/Music/);
    expect(await screen.findByText('3 songs')).toBeInTheDocument();
    await user.click(screen.getAllByRole('button', { name: 'More actions' })[0]!);
    await user.click(screen.getByRole('button', { name: 'Add to favorites' }));
    await waitFor(() =>
      expect(useLibrary.getState().items.filter((m) => m.favorite)).toHaveLength(1),
    );

    await user.click(screen.getByRole('tab', { name: 'Favorites' }));
    expect(await screen.findByText('1 song')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'More actions' }));
    await user.click(screen.getByRole('button', { name: 'Remove from favorites' }));
    expect(await screen.findByText('No favorites yet')).toBeInTheDocument();
  });

  it('creates a playlist, adds a song, plays it, removes it and deletes the playlist', async () => {
    const user = await openTab(/Music/);
    expect(await screen.findByText('3 songs')).toBeInTheDocument();
    await user.click(screen.getByRole('tab', { name: 'Playlists' }));
    await user.click(await screen.findByRole('button', { name: 'New playlist' }));
    let dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByRole('textbox', { name: 'Playlist name' }), 'Road');
    await user.click(within(dialog).getByRole('button', { name: 'Create' }));
    expect(await screen.findByText('My playlists · 1')).toBeInTheDocument();

    await user.click(screen.getByRole('tab', { name: 'Songs' }));
    await user.click((await screen.findAllByRole('button', { name: 'More actions' }))[0]!);
    await user.click(screen.getByRole('button', { name: 'Add to playlist…' }));
    dialog = await screen.findByRole('dialog');
    await waitFor(() =>
      expect(within(dialog).getByRole('radio', { name: /Road/ })).toHaveAttribute(
        'aria-checked',
        'true',
      ),
    );
    await user.click(within(dialog).getByRole('button', { name: 'Add' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());

    await user.click(screen.getByRole('tab', { name: 'Playlists' }));
    await user.click(await screen.findByRole('button', { name: /Road/ }));
    expect(await screen.findByRole('heading', { name: 'Road' })).toBeInTheDocument();
    await user.click(await screen.findByRole('button', { name: /Play all/ }));
    expect(useMobilePlayback.getState().queue).toHaveLength(1);
    act(() => useUi.setState({ mobilePlayerExpanded: false }));

    await user.click(screen.getByRole('button', { name: /^Remove from playlist/ }));
    expect(await screen.findByText('Empty playlist')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Playlist actions' }));
    await user.click(screen.getByRole('menuitem', { name: /Delete playlist/ }));
    const sheet = screen.getByRole('dialog', { name: 'Delete “Road”?' });
    await user.click(within(sheet).getByRole('button', { name: 'Delete playlist' }));
    expect(await screen.findByText('My playlists · 0')).toBeInTheDocument();
  });

  it('saves the play queue as a playlist', async () => {
    const user = await openTab(/Music/);
    expect(await screen.findByText('3 songs')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Shuffle play' }));
    await user.click(await screen.findByRole('button', { name: /Queue/ }));
    await user.click(screen.getByRole('button', { name: 'Save as playlist' }));
    const dialog = screen.getByRole('dialog', { name: 'New playlist' });
    await user.type(within(dialog).getByRole('textbox', { name: 'Playlist name' }), 'Mix');
    await user.click(within(dialog).getByRole('button', { name: 'Create' }));
    await waitFor(() => expect(usePlaylists.getState().list[0]?.count).toBe(3));
  });
});

describe('Android v2 Music › Recent and Most played', () => {
  it('lists the songs of the play history, most played first', async () => {
    const songs = useLibrary.getState().items.filter((m) => m.kind === 'audio');
    const [a, b] = [songs[0]!, songs[1]!];
    const entry = (m: typeof a, at: number) => ({
      id: m.id,
      title: m.title,
      kind: 'audio',
      at,
      position: 0,
      duration: 0,
    });
    // Newest first: b once (latest), then a twice.
    localStorage.setItem(
      'mm:playHistory:v1',
      JSON.stringify([entry(b, 3), entry(a, 2), entry(a, 1)]),
    );
    expect(autoListIds(JSON.parse(localStorage.getItem('mm:playHistory:v1')!), 'recent')).toEqual([
      b.id,
      a.id,
    ]);

    const user = await openTab(/Music/);
    await user.click(screen.getByRole('tab', { name: 'Playlists' }));
    await user.click(screen.getByRole('button', { name: 'Most played' }));
    const list = await screen.findByRole('list', { name: 'Most played' });
    await waitFor(() => expect(within(list).getAllByRole('button')).toHaveLength(2));
    expect(within(list).getAllByRole('button')[0]).toHaveAccessibleName(`Play ${a.title}`);
    expect(within(list).getByText(/2 plays/)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Back' }));
    await user.click(screen.getByRole('button', { name: 'Recent' }));
    const recent = await screen.findByRole('list', { name: 'Recent' });
    await waitFor(() =>
      expect(within(recent).getAllByRole('button')[0]).toHaveAccessibleName(`Play ${b.title}`),
    );
    await user.click(screen.getByRole('button', { name: /Play all/ }));
    expect(useMobilePlayback.getState().queue.map((m) => m.id)).toEqual([b.id, a.id]);
  });

  it('says when nothing was played yet', async () => {
    const user = await openTab(/Music/);
    await user.click(screen.getByRole('tab', { name: 'Playlists' }));
    await user.click(screen.getByRole('button', { name: 'Recent' }));
    expect(await screen.findByText(/Nothing played yet/)).toBeInTheDocument();
  });
});

describe('Android v2 Videos', () => {
  it('filters videos in progress and shows the resume bar', async () => {
    const video = useLibrary.getState().items.find((m) => m.kind === 'video')!;
    localStorage.setItem(`mm:position:${video.id}`, '30');
    const user = await openTab(/Videos/);
    const filters = await screen.findByRole('radiogroup', { name: 'Videos' });
    expect(within(filters).getByRole('radio', { name: /All · 9/ })).toBeChecked();
    await user.click(within(filters).getByRole('radio', { name: 'In progress · 1' }));
    const grid = screen.getByRole('list', { name: 'Videos' });
    expect(within(grid).getByText(video.title)).toBeInTheDocument();
    expect(within(grid).getAllByRole('button', { name: /^Play / })).toHaveLength(1);
  });
});

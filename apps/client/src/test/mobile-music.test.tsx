import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { useMobilePlayback } from '../stores/mobilePlayback';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  localStorage.clear();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
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
    expect(within(tabs).getByRole('tab', { name: 'Playlists' })).toBeDisabled();
    expect(within(tabs).getByRole('tab', { name: 'Favorites' })).toBeDisabled();
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

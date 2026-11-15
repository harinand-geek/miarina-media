import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { backend, resetMockBackend } from '../services/backend';
import type { MediaRecord } from '../services/types';
import { useDownloads } from '../stores/downloads';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

const track = (id: number): MediaRecord =>
  ({
    id,
    title: `Hira ${id}`,
    kind: 'audio',
    path: `C:\\Music\\Ankorabe\\hira-${id}.mp3`,
    durationSecs: 240,
    sizeBytes: 1000,
    sourceHost: null,
    thumbnail: null,
  }) as MediaRecord;

// Lazy screens: load their modules once so the first test does not race the
// cold import under a busy parallel run (findBy* waits 1 s).
beforeAll(async () => {
  await Promise.all([
    import('../features/library/LibraryScreen'),
    import('../features/player/PlayerScreen'),
    import('../features/player/NowPlayingScreen'),
  ]);
});

beforeEach(() => {
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('Windows v2 shell — navigation B', () => {
  it('opens on Play (decision 0006) and switches between the Play and Get spaces', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    const spaces = screen.getByRole('radiogroup', { name: 'Space' });
    // Listening first: Play is the first space and the launch screen.
    expect(
      within(spaces)
        .getAllByRole('radio')
        .map((r) => r.textContent),
    ).toEqual(['library_musicPlay', 'downloadGet']);
    expect(within(spaces).getByRole('radio', { name: 'Play' })).toBeChecked();
    expect(await screen.findByRole('heading', { name: /Tracks/ })).toBeInTheDocument();

    await user.click(within(spaces).getByRole('radio', { name: 'Get' }));
    expect(screen.getByRole('button', { name: 'Torrents' })).toBeInTheDocument();

    await user.click(within(spaces).getByRole('radio', { name: 'Play' }));
    expect(await screen.findByRole('heading', { name: /Tracks/ })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Torrents' })).toBeNull();
    // Playlists and Favorites are real now (COM-06).
    expect(screen.getByRole('button', { name: /Playlists/ })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'Albums' })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'Videos' })).toBeEnabled();
  });

  it('reads the French catalog', () => {
    useSettings.setState({ lang: 'fr' });
    useUi.setState({ screen: 'home', space: 'get' });
    render(<DesktopShell />);
    const spaces = screen.getByRole('radiogroup', { name: 'Espace' });
    expect(within(spaces).getByRole('radio', { name: 'Obtenir' })).toBeInTheDocument();
    expect(within(spaces).getByRole('radio', { name: 'Écouter' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Accueil' })).toBeInTheDocument();
    expect(screen.getByRole('searchbox', { name: 'Musique, vidéo ou lien' })).toBeInTheDocument();
  });

  it('shows the offline banner from the network status', () => {
    const online = vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(false);
    render(<DesktopShell />);
    expect(screen.getByText("You're offline.")).toBeInTheDocument();
    online.mockReturnValue(true);
    act(() => {
      window.dispatchEvent(new Event('online'));
    });
    expect(screen.queryByText("You're offline.")).toBeNull();
  });
});

describe('Windows title bar search (decision 0006)', () => {
  it('opens on Ctrl+K with the sites, then finds local media before the web', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    await user.keyboard('{Control>}k{/Control}');
    const field = screen.getByRole('searchbox', { name: 'Music, video or link' });
    expect(field).toHaveFocus();
    const sites = screen.getByRole('list', { name: 'Sites' });
    expect(within(sites).getByRole('button', { name: 'YouTube' })).toBeInTheDocument();

    const page = await backend.libraryQuery({ search: '', kind: 'audio', sort: 'added' });
    const track = page.items[0]!;
    await user.type(field, track.title);
    const local = await screen.findByRole('region', { name: 'On this computer' });
    await user.click(within(local).getByRole('button', { name: `Play ${track.title}` }));
    expect(usePlayer.getState().media?.id).toBe(track.id);
    expect(screen.queryByRole('list', { name: 'Sites' })).toBeNull();
  });

  it('searches YouTube in the built-in browser on Enter when nothing is local', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    await user.click(screen.getByRole('searchbox', { name: 'Music, video or link' }));
    await user.type(
      screen.getByRole('searchbox', { name: 'Music, video or link' }),
      'zz no such song',
    );
    await screen.findByText(
      'Nothing on this computer for “zz no such song”. Enter searches YouTube.',
    );
    const asked: string[] = [];
    const stop = useUi.subscribe((s) => s.browserRequest && asked.push(s.browserRequest));
    await user.keyboard('{Enter}');
    stop();
    expect(asked).toContain('https://www.youtube.com/results?search_query=zz%20no%20such%20song');
    expect(useUi.getState().screen).toBe('browser');
  });
});

describe('Windows v2 shell — mini-player and Now playing (COM-05)', () => {
  it('keeps one playback across screens and expands without reloading', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'home', space: 'get' });
    render(<DesktopShell />);
    act(() => usePlayer.getState().playMedia(track(1), [track(1), track(2)]));
    const mini = await screen.findByRole('region', { name: 'Now playing' });
    expect(within(mini).getByText('Hira 1')).toBeInTheDocument();
    expect(within(mini).getByText('Ankorabe')).toBeInTheDocument();
    const instance = usePlayer.getState().instance;
    await waitFor(() => expect(usePlayer.getState().state).toBe('playing'));

    await user.click(screen.getByRole('button', { name: /^Downloads/ }));
    expect(screen.getByRole('region', { name: 'Now playing' })).toBeInTheDocument();
    expect(usePlayer.getState().instance).toBe(instance);

    await user.click(within(mini).getAllByRole('button', { name: 'Expand' })[0]!);
    expect(await screen.findByRole('heading', { name: 'Hira 1' })).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Now playing' })).toBeNull();
    expect(usePlayer.getState().instance).toBe(instance);
    expect(usePlayer.getState().state).toBe('playing');
  });

  it('toggles playback with Space outside text fields', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    act(() => usePlayer.getState().playMedia(track(1)));
    await waitFor(() => expect(usePlayer.getState().state).toBe('playing'));
    await user.keyboard(' ');
    expect(usePlayer.getState().state).toBe('paused');
  });

  it('clears the queue but keeps the current media and files', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'now' });
    render(<DesktopShell />);
    act(() => usePlayer.getState().playMedia(track(2), [track(1), track(2), track(3)]));
    const queue = await screen.findByRole('list', { name: 'Queue' });
    expect(within(queue).getAllByRole('listitem')).toHaveLength(3);
    await user.click(screen.getByRole('button', { name: 'Clear queue' }));
    expect(
      within(screen.getByRole('list', { name: 'Queue' })).getAllByRole('listitem'),
    ).toHaveLength(1);
    expect(usePlayer.getState().media?.id).toBe(2);
    expect(screen.getByText('Queue cleared. No file deleted.')).toBeInTheDocument();
  });

  it('sets speed and sleep timer from the Sound panel', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'now', nowPanel: 'sound' });
    render(<DesktopShell />);
    act(() => usePlayer.getState().playMedia(track(1)));
    await user.click(await screen.findByRole('radio', { name: '1.5×' }));
    expect(usePlayer.getState().rate).toBe(1.5);
    await user.click(screen.getByRole('radio', { name: 'End of track' }));
    expect(screen.getByText('Stops after “Hira 1”. Miarina stays open.')).toBeInTheDocument();
  });
});

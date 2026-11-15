import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { failureReason } from '../features/downloads/status';
import { recentPlays } from '../features/player/recentPlays';
import { t } from '../i18n';
import { backend, resetMockBackend } from '../services/backend';
import { useUpdates } from '../features/settings/useUpdates';
import { useDownloads } from '../stores/downloads';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stopEvents: () => void = () => {};

// Lazy screens: load them once so a busy parallel run does not time out.
beforeAll(async () => {
  await Promise.all([
    import('../features/library/LibraryScreen'),
    import('../features/history/HistoryScreen'),
    import('../features/settings/SettingsScreen'),
  ]);
});

beforeEach(async () => {
  localStorage.clear();
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  useUpdates.setState(useUpdates.getInitialState(), true);
  await useSettings.getState().load();
  stopEvents = useDownloads.getState().init();
  await waitFor(() => expect(useDownloads.getState().ready).toBe(true));
});

afterEach(() => stopEvents());

describe('Windows v2 Home', () => {
  // Home tests start there (the app itself opens on Play, decision 0006).
  beforeEach(() => useUi.setState({ screen: 'home', space: 'get' }));

  it('continues unfinished media the user played last', async () => {
    const user = userEvent.setup();
    // Sintel (mock id 2, 14:48) was left at 5:00; Big Buck Bunny was finished.
    const play = (id: number, title: string, at: number) => ({
      id,
      title,
      kind: 'video',
      at,
      position: 0,
      duration: 0,
    });
    localStorage.setItem(
      'mm:playHistory:v1',
      JSON.stringify([play(2, 'Sintel', 2000), play(1, 'Big Buck Bunny', 1000)]),
    );
    localStorage.setItem('mm:position:2', '300');
    render(<DesktopShell />);

    const section = await screen.findByRole('region', { name: 'Continue' });
    const card = await within(section).findByRole('button', { name: 'Play Sintel' });
    expect(card).toHaveTextContent('10 min left');
    expect(within(section).queryByRole('button', { name: 'Play Big Buck Bunny' })).toBeNull();

    await user.click(card);
    expect(usePlayer.getState().media?.title).toBe('Sintel');
  });

  it('keeps unfinished features marked as planned', () => {
    render(<DesktopShell />);
    expect(screen.getByRole('button', { name: /Batch links/ })).toBeDisabled();
    expect(screen.getByRole('button', { name: /Torrent \/ magnet/ })).toBeEnabled();
  });

  it('remembers media that actually started playing', () => {
    act(() => {
      usePlayer.setState({
        media: { id: 42, title: 'Clip', kind: 'video' } as never,
        state: 'playing',
      });
    });
    expect(recentPlays()[0]).toBe(42);
  });
});

describe('Windows v2 Downloads', () => {
  it('lists active, finished and failed downloads in separate tabs', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'downloads' });
    render(<DesktopShell />);
    const lists = screen.getByRole('radiogroup', { name: 'Download lists' });

    expect(screen.getByText('Tears of Steel')).toBeInTheDocument();
    await user.click(within(lists).getByRole('radio', { name: /^Done/ }));
    expect(screen.getByText('Big Buck Bunny')).toBeInTheDocument();
    expect(screen.queryByText('Tears of Steel')).toBeNull();

    await user.click(within(lists).getByRole('radio', { name: /^Failed/ }));
    expect(screen.getByText('Live streams are not supported')).toBeInTheDocument();
  });

  it('shows conversion as its own step (DL-06)', () => {
    const tasks = useDownloads.getState().tasks;
    useDownloads.setState({
      tasks: {
        ...tasks,
        d3: { ...tasks.d3!, state: 'processing', fileName: 'Apollo 11.mp3' },
      },
    });
    useUi.setState({ screen: 'downloads' });
    render(<DesktopShell />);
    expect(screen.getByText('Converting to MP3')).toBeInTheDocument();
    expect(screen.getByText('step 2/2 · ffmpeg')).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: 'Cannot pause while preparing the file' }),
    ).toBeDisabled();
  });

  it('says when downloads wait for the network (PAR-04)', () => {
    // No network: nothing transfers, every started task waits for it.
    const offline = Object.values(useDownloads.getState().tasks).map((x) =>
      x.state === 'downloading'
        ? {
            ...x,
            state: 'waiting' as const,
            retry: { inSecs: 0, reason: 'network', at: Date.now(), offline: true },
          }
        : x,
    );
    useDownloads.setState({ tasks: Object.fromEntries(offline.map((x) => [x.id, x])) });
    const waiting = offline.filter((x) => x.retry?.offline).length;
    useUi.setState({ screen: 'downloads' });
    render(<DesktopShell />);
    // On the row and in the sidebar card.
    expect(screen.getAllByText('Paused · offline').length).toBe(waiting + 1);
  });

  it('explains disk and folder failures and offers to start over (DL-04)', async () => {
    const user = userEvent.setup();
    const restart = vi.spyOn(backend, 'restart');
    const tasks = useDownloads.getState().tasks;
    useDownloads.setState({
      tasks: {
        ...tasks,
        d3: {
          ...tasks.d3!,
          state: 'failed',
          errorCode: 'access_denied',
          supportsResume: true,
          downloadedBytes: 1000,
          totalBytes: 4000,
        },
      },
    });
    useUi.setState({ screen: 'downloads' });
    render(<DesktopShell />);
    await user.click(screen.getByRole('radio', { name: /^Failed/ }));
    expect(screen.getByText('Failed · folder not writable')).toBeInTheDocument();
    expect(
      screen.getByText('resumes at 25 % · choose another folder in Settings'),
    ).toBeInTheDocument();
    const title = tasks.d3!.title;
    await user.click(
      screen.getByRole('button', { name: `Start ${title} over from the beginning` }),
    );
    expect(restart).toHaveBeenCalledWith('d3');
    restart.mockRestore();
  });

  it('words known engine failures in the user language', () => {
    expect(failureReason('not enough free space (1 bytes needed, 0 available)', t)).toBe(
      'Not enough disk space for this file',
    );
    expect(failureReason('the destination folder cannot be written to', t)).toBe(
      'Destination folder is not writable',
    );
    expect(failureReason('Live streams are not supported', t)).toBe(
      'Live streams are not supported',
    );
  });
});

describe('Windows v2 History', () => {
  it('shows downloads by day, then plays, and clears only the play history', async () => {
    const user = userEvent.setup();
    localStorage.setItem(
      'mm:playHistory:v1',
      JSON.stringify([
        { id: 2, title: 'Sintel', kind: 'video', at: Date.now(), position: 300, duration: 888 },
      ]),
    );
    useUi.setState({ screen: 'history' });
    render(<DesktopShell />);

    expect(await screen.findByRole('region', { name: 'Today' })).toBeInTheDocument();
    expect(screen.getByText('Failed · Live streams are not supported')).toBeInTheDocument();

    await user.click(screen.getByRole('radio', { name: 'Plays' }));
    const row = screen.getByRole('button', { name: 'Play Sintel' });
    expect(row).toHaveTextContent('stopped at 5:00');

    await user.click(screen.getByRole('button', { name: 'Clear history' }));
    await user.click(
      within(screen.getByRole('alertdialog', { name: 'Clear play history?' })).getByRole('button', {
        name: 'Clear history',
      }),
    );
    expect(screen.getByText('What you play appears here.')).toBeInTheDocument();
    expect(useDownloads.getState().history.length).toBeGreaterThan(0);
  });

  it('notes where playback stopped and keeps one entry per play', () => {
    const media = { id: 7, title: 'Song', kind: 'audio', durationSecs: 200 } as never;
    act(() => usePlayer.setState({ media, state: 'playing', position: 0 }));
    act(() => usePlayer.setState({ state: 'paused', position: 42 }));
    act(() => usePlayer.setState({ state: 'playing' }));
    const entries = JSON.parse(localStorage.getItem('mm:playHistory:v1')!) as {
      id: number;
      position: number;
    }[];
    expect(entries.filter((e) => e.id === 7)).toHaveLength(1);
    expect(entries[0]!.position).toBe(42);
  });
});

describe('Windows v2 Settings', () => {
  it('shows the update card states of the mockup', async () => {
    const user = userEvent.setup();
    const release = { version: '0.1.8', notes: '- Faster library', size: 75_600_000 };
    useUpdates.setState({ phase: 'downloading', release, downloaded: 0, error: '' });
    useUi.setState({ screen: 'settings' });
    render(<DesktopShell />);
    const sections = await screen.findByRole('navigation', { name: 'Settings sections' });
    await user.click(within(sections).getByRole('button', { name: /Updates/ }));
    expect(screen.getByText('Downloading 0.1.8…')).toBeInTheDocument();
    expect(screen.getByText(/verified at the end/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument();
    expect(screen.getByRole('radiogroup', { name: 'Channel' })).toBeInTheDocument();
    expect(screen.getByRole('switch', { name: 'Download automatically' })).not.toBeChecked();

    // Interrupted earlier: the bytes on disk are resumed.
    act(() => useUpdates.setState({ phase: 'available', downloaded: 30_000_000 }));
    expect(screen.getByRole('button', { name: 'Resume download' })).toBeInTheDocument();
    expect(screen.getByText(/already downloaded/)).toBeInTheDocument();

    // Ready: what installing would interrupt is said before the click.
    act(() => useUpdates.setState({ phase: 'ready', downloaded: release.size }));
    expect(screen.getByText('Signature and SHA-256 verified')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Install now' })).toBeEnabled();
    await user.click(screen.getByRole('button', { name: 'Later' }));
    expect(useUpdates.getState().phase).toBe('ready');

    // A conversion would be lost: installing waits for it.
    const tasks = useDownloads.getState().tasks;
    const first = Object.values(tasks)[0]!;
    act(() =>
      useDownloads.setState({ tasks: { ...tasks, [first.id]: { ...first, state: 'processing' } } }),
    );
    expect(screen.getByText(/A conversion is running/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Install now' })).toBeDisabled();
  });

  it('marks unbuilt settings as planned instead of faking them', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'settings' });
    render(<DesktopShell />);
    const sections = await screen.findByRole('navigation', { name: 'Settings sections' });

    // General: tray, startup and clipboard watching do not exist yet.
    expect(screen.getByText('Launch at startup')).toBeInTheDocument();
    expect(screen.queryByRole('switch')).toBeNull();
    expect(screen.getAllByText('PLANNED').length).toBeGreaterThanOrEqual(3);

    await user.click(within(sections).getByRole('button', { name: /Updates/ }));
    expect(screen.getByRole('button', { name: 'Check for updates' })).toBeInTheDocument();

    await user.click(within(sections).getByRole('button', { name: /Playback/ }));
    expect(screen.getByRole('switch', { name: 'Resume where I left off' })).toBeChecked();

    await user.click(within(sections).getByRole('button', { name: /Language/ }));
    await user.click(screen.getByRole('radio', { name: 'Français' }));
    expect(useSettings.getState().lang).toBe('fr');
    expect(await screen.findByRole('heading', { name: 'Réglages' })).toBeInTheDocument();
  });
});

describe('UX-01: French everywhere', () => {
  it('shows link feedback, confirmations and progress in French', async () => {
    const user = userEvent.setup();
    useSettings.getState().setLang('fr');
    useUi.setState({ screen: 'home', space: 'get' });
    render(<DesktopShell />);
    await user.click(screen.getByRole('button', { name: 'Analyser' }));
    expect(screen.getByRole('status')).toHaveTextContent('Collez un lien à analyser.');

    act(() => useUi.getState().go('downloads'));
    expect(
      await screen.findByRole('progressbar', { name: /^Tears of Steel, 60 %/ }),
    ).toBeInTheDocument();
    await user.click(screen.getAllByRole('button', { name: /^Annuler / })[0]!);
    const dialog = screen.getByRole('alertdialog', { name: 'Annuler le téléchargement ?' });
    expect(within(dialog).getByRole('button', { name: 'Conserver' })).toHaveFocus();
    useSettings.getState().setLang('en');
  });
});

import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { recentPlays } from '../features/player/recentPlays';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stopEvents: () => void = () => {};

beforeEach(async () => {
  localStorage.clear();
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  await useSettings.getState().load();
  stopEvents = useDownloads.getState().init();
  await waitFor(() => expect(useDownloads.getState().ready).toBe(true));
});

afterEach(() => stopEvents());

describe('Windows v2 Home', () => {
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

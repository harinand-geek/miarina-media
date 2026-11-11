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
    localStorage.setItem('mm:recentPlays:v1', JSON.stringify([2, 1]));
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
      usePlayer.setState({ media: { id: 42 } as never, state: 'playing' });
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

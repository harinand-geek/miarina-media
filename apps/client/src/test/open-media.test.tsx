import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { backend, resetMockBackend } from '../services/backend';
import type { OpenedMedia } from '../services/types';
import { useLibrary } from '../stores/library';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeAll(async () => {
  await Promise.all([
    import('../features/library/LibraryScreen'),
    import('../features/player/PlayerScreen'),
  ]);
});

beforeEach(async () => {
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState(useUi.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  stop = useLibrary.getState().init();
  await waitFor(() => expect(useLibrary.getState().ready).toBe(true));
});

afterEach(() => stop());

describe('opening media from outside the library (WIN-04)', () => {
  it('imports a folder from the library header', async () => {
    const user = userEvent.setup();
    const imported = vi
      .spyOn(backend, 'libraryImportFolder')
      .mockResolvedValue({ found: 4, added: 3, restored: 0 });
    useUi.setState({ screen: 'library', space: 'play', libraryView: 'videos' });
    render(<DesktopShell />);
    await user.click(await screen.findByRole('button', { name: /Import a folder/ }));
    expect(imported).toHaveBeenCalled();
    expect(await screen.findByText('3 media added to the library')).toBeInTheDocument();
  });

  it('opens files from the empty player and plays them', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'player', space: 'play' });
    render(<DesktopShell />);
    await user.click(await screen.findByRole('button', { name: 'Open files…' }));
    await waitFor(() => expect(usePlayer.getState().media?.kind).toBe('video'));
    expect(useUi.getState().screen).toBe('player');
  });

  it('plays dropped files and reports dropped folders', async () => {
    let onOpened: (o: OpenedMedia) => void = () => {};
    vi.spyOn(backend, 'onOpened').mockImplementation((cb) => {
      onOpened = cb;
      return () => {};
    });
    render(<DesktopShell />);
    const audio = useLibrary.getState().items.find((m) => m.kind === 'audio')!;
    act(() => onOpened({ media: [audio], folders: [{ found: 2, added: 0, restored: 0 }] }));
    expect(usePlayer.getState().media?.id).toBe(audio.id);
    expect(useUi.getState().screen).toBe('now');
    expect(
      await screen.findByText('Nothing new: 2 media already in the library'),
    ).toBeInTheDocument();
    act(() => onOpened({ media: [], folders: [] }));
    expect(await screen.findByText('No supported audio or video file')).toBeInTheDocument();
  });
});

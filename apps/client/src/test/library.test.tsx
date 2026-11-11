import { act, render, renderHook, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { durationLabel, qualityLabel, formatLabel } from '../features/library/format';
import { usePlayback } from '../features/player/usePlayback';
import { backend, resetMockBackend } from '../services/backend';
import type { MediaRecord } from '../services/types';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { resetPlayerForTests, usePlayer } from '../stores/player';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

// Lazy screens: load their modules once so the first test does not race the
// cold import under a busy parallel run (findBy* waits 1 s).
beforeAll(async () => {
  await Promise.all([
    import('../features/library/LibraryScreen'),
    import('../features/player/PlayerScreen'),
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

async function openLibrary(view: 'tracks' | 'videos' = 'videos') {
  useUi.setState({ screen: 'library', space: 'play', libraryView: view });
  render(<DesktopShell />);
  const heading = await screen.findByRole('heading', { name: view === 'videos' ? /Videos/ : /Tracks/ });
  await waitFor(() =>
    expect(
      useLibrary.getState().items.every((m) => m.kind === (view === 'videos' ? 'video' : 'audio')),
    ).toBe(true),
  );
  return heading;
}

describe('library screen', () => {
  it('searches through the backend with prefixes and diacritics', async () => {
    const user = userEvent.setup();
    await openLibrary('tracks');
    await waitFor(() => expect(useLibrary.getState().total).toBe(3));
    await user.type(screen.getByRole('searchbox', { name: 'Title, artist, album, folder' }), 'gymno');
    await waitFor(() =>
      expect(useLibrary.getState().items.map((m) => m.title)).toEqual(['Gymnopédie No. 1 — Satie']),
    );
  });

  it('lists audio under Tracks and video under Videos (navigation B)', async () => {
    const user = userEvent.setup();
    await openLibrary('tracks');
    await waitFor(() => expect(useLibrary.getState().total).toBe(3));
    await user.click(screen.getByRole('button', { name: 'Videos' }));
    expect(await screen.findByRole('heading', { name: /Videos/ })).toBeInTheDocument();
    await waitFor(() =>
      expect(useLibrary.getState().items.every((m) => m.kind === 'video')).toBe(true),
    );
    expect(useLibrary.getState().total).toBe(9);
  });

  it('renames with F2 and deletes after confirmation', async () => {
    const user = userEvent.setup();
    await openLibrary();
    const list = await screen.findByRole('list', { name: /Library items/ });
    const first = within(list).getAllByRole('button')[0]!;
    const title = useLibrary.getState().items[0]!.title;

    first.focus();
    await user.keyboard('{F2}');
    const input = screen.getByRole('textbox', { name: 'New name' });
    await user.clear(input);
    await user.type(input, 'Renamed clip{Enter}');
    await waitFor(() =>
      expect(useLibrary.getState().items.some((m) => m.title === 'Renamed clip')).toBe(true),
    );
    expect(useLibrary.getState().items.some((m) => m.title === title)).toBe(false);

    const renamed = within(screen.getByRole('list', { name: /Library items/ })).getAllByRole(
      'button',
    )[0]!;
    renamed.focus();
    await user.keyboard('{Delete}');
    const dialog = screen.getByRole('dialog', { name: '« Renamed clip »' });
    expect(within(dialog).getByRole('button', { name: 'Cancel' })).toHaveFocus();
    // Removing (keeping the file) is the default choice (COM-10).
    expect(within(dialog).getByRole('radio', { name: /Remove from library/ })).toBeChecked();
    // Windows deletion goes to the Recycle Bin (`trash`): the text says so.
    expect(within(dialog).getByText(/goes to the Recycle Bin/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('radio', { name: /Delete the file from disk/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Delete file' }));
    await waitFor(() => expect(useLibrary.getState().total).toBe(8));
    expect(await screen.findByText('File moved to the Recycle Bin.')).toBeInTheDocument();
  });

  it('removes from the library without deleting the file (COM-10)', async () => {
    const user = userEvent.setup();
    await openLibrary();
    const remove = vi.spyOn(backend, 'libraryRemove');
    const del = vi.spyOn(backend, 'libraryDelete');
    const list = await screen.findByRole('list', { name: /Library items/ });
    const first = within(list).getAllByRole('button')[0]!;
    first.focus();
    await user.keyboard('{Delete}');
    const dialog = screen.getByRole('dialog');
    await user.keyboard('{Escape}');
    expect(dialog).not.toBeInTheDocument();
    expect(useLibrary.getState().total).toBe(9);

    first.focus();
    await user.keyboard('{Delete}');
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(useLibrary.getState().total).toBe(8));
    expect(remove).toHaveBeenCalledOnce();
    expect(del).not.toHaveBeenCalled();
    expect(
      await screen.findByText('Removed from library. The file stays on disk.'),
    ).toBeInTheDocument();
  });

  it('opens the design context menu on right click', async () => {
    const user = userEvent.setup();
    await openLibrary();
    const list = await screen.findByRole('list', { name: /Library items/ });
    await user.pointer({ keys: '[MouseRight]', target: within(list).getAllByRole('button')[0]! });
    const menu = screen.getByRole('menu');
    expect(
      within(menu)
        .getAllByRole('menuitem')
        .map((i) => i.textContent?.replace(/(Enter|Ctrl [EC]|F2|Del)$/, '')),
    ).toEqual([
      'play_arrowPlay',
      'folder_openShow in folder',
      'content_copyCopy source link',
      'drive_file_rename_outlineRename',
      'edit_noteEdit tags',
      'deleteRemove or delete…',
    ]);
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('menu')).not.toBeInTheDocument();
  });

  it('plays an item and resumes from the saved position', async () => {
    const user = userEvent.setup();
    await openLibrary();
    const item = useLibrary.getState().items[0]!;
    localStorage.setItem(`mm:position:${item.id}`, '42');
    const list = await screen.findByRole('list', { name: /Library items/ });
    await user.click(within(list).getAllByRole('button')[0]!);
    expect(await screen.findByRole('slider', { name: 'Playback position' })).toHaveAttribute(
      'aria-valuenow',
      '42',
    );
    // The visible list became the play queue.
    expect(usePlayer.getState().queue.map((m) => m.id)).toEqual(
      useLibrary.getState().items.map((m) => m.id),
    );
    await act(() => Promise.resolve());
    localStorage.clear();
  });
});

describe('playback', () => {
  it('starts an element that loaded its metadata before the ref attached', () => {
    const item = useLibrary.getState().items[0]!;
    localStorage.setItem(`mm:position:${item.id}`, '42');
    const url = vi.spyOn(backend, 'mediaUrl').mockReturnValue('asset://clip');
    const { result } = renderHook(() => usePlayback(item));
    const el = document.createElement('video');
    Object.defineProperty(el, 'readyState', { value: HTMLMediaElement.HAVE_METADATA });
    Object.defineProperty(el, 'duration', { value: 100 });
    const play = vi.spyOn(el, 'play').mockResolvedValue();

    act(() => result.current.attachMedia(el));

    expect(play).toHaveBeenCalledOnce();
    expect(el.currentTime).toBe(42);
    url.mockRestore();
    localStorage.clear();
  });
});

describe('library labels', () => {
  const media = (patch: Partial<MediaRecord>): MediaRecord => ({
    id: 1,
    path: 'C:\\V\\clip.mp4',
    title: 'clip',
    kind: 'video',
    sourceHost: null,
    sourceUrl: null,
    taskId: null,
    sizeBytes: 1,
    durationSecs: null,
    width: null,
    height: null,
    videoCodec: null,
    audioCodec: null,
    container: null,
    thumbnail: null,
    probed: false,
    missing: false,
    addedAt: 0,
    modifiedAt: 0,
    ...patch,
  });

  it('formats durations, qualities and codecs', () => {
    expect(durationLabel(596)).toBe('9:56');
    expect(durationLabel(5744)).toBe('1:35:44');
    expect(durationLabel(null)).toBe('—');
    expect(qualityLabel(media({ height: 1080 }))).toBe('1080p');
    expect(qualityLabel(media({ height: 2160 }))).toBe('4K');
    expect(qualityLabel(media({ kind: 'audio', audioCodec: 'flac' }))).toBe('FLAC');
    expect(qualityLabel(media({}))).toBe('…');
    expect(formatLabel(media({ videoCodec: 'h264', audioCodec: 'aac' }))).toBe('MP4 · H.264 · AAC');
  });
});

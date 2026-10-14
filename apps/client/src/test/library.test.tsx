import { act, render, renderHook, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { durationLabel, qualityLabel, formatLabel } from '../features/library/format';
import { usePlayback } from '../features/player/usePlayback';
import { backend, resetMockBackend } from '../services/backend';
import type { MediaRecord } from '../services/types';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  stop = useLibrary.getState().init();
  await waitFor(() => expect(useLibrary.getState().ready).toBe(true));
});

afterEach(() => stop());

async function openLibrary() {
  useUi.setState({ screen: 'library' });
  render(<DesktopShell />);
  return screen.findByRole('heading', { name: 'Library' });
}

describe('library screen', () => {
  it('searches through the backend with prefixes and diacritics', async () => {
    const user = userEvent.setup();
    await openLibrary();
    expect(useLibrary.getState().total).toBe(12);
    await user.type(screen.getByRole('searchbox', { name: 'Search titles' }), 'gymno');
    await waitFor(() =>
      expect(useLibrary.getState().items.map((m) => m.title)).toEqual(['Gymnopédie No. 1 — Satie']),
    );
  });

  it('filters by kind with real counts', async () => {
    const user = userEvent.setup();
    await openLibrary();
    await user.click(screen.getByRole('button', { name: /Audio/ }));
    await waitFor(() =>
      expect(useLibrary.getState().items.every((m) => m.kind === 'audio')).toBe(true),
    );
    expect(useLibrary.getState().total).toBe(3);
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
    const dialog = screen.getByRole('alertdialog', { name: 'Delete this file?' });
    expect(within(dialog).getByRole('button', { name: 'Keep' })).toHaveFocus();
    await user.click(within(dialog).getByRole('button', { name: 'Delete file' }));
    await waitFor(() => expect(useLibrary.getState().total).toBe(11));
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
      'deleteDelete file',
    ]);
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('menu')).not.toBeInTheDocument();
  });

  it('plays an item and resumes from the saved position', async () => {
    const user = userEvent.setup();
    const item = useLibrary.getState().items[0]!;
    localStorage.setItem(`mm:position:${item.id}`, '42');
    await openLibrary();
    const list = await screen.findByRole('list', { name: /Library items/ });
    await user.click(within(list).getAllByRole('button')[0]!);
    expect(await screen.findByRole('slider', { name: 'Seek' })).toHaveAttribute(
      'aria-valuenow',
      '42',
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

import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { backend, resetMockBackend } from '../services/backend';
import type { MediaRecord } from '../services/types';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useMobilePlayback } from '../stores/mobilePlayback';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};
let tracks: MediaRecord[] = [];

beforeEach(async () => {
  resetMockBackend();
  localStorage.clear();
  useUi.setState(useUi.getInitialState(), true);
  useMobilePlayback.setState({ repeat: 'off', shuffle: false, unshuffled: null, rate: 1, sleep: { mode: 'off' } });
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  stop = useLibrary.getState().init();
  await waitFor(() => expect(useLibrary.getState().ready).toBe(true));
  tracks = useLibrary.getState().items.filter((m) => m.kind === 'audio');
});

afterEach(() => stop());

function openPlayer() {
  render(<MobileShell />);
  act(() => useMobilePlayback.getState().start(tracks[0]!, tracks, 'Album · Musopen Piano'));
  return screen.getByRole('dialog', { name: `Now playing: ${tracks[0]!.title}` });
}

describe('Android v2 Now playing (07)', () => {
  it('shows where playback comes from and the transport', async () => {
    const user = userEvent.setup();
    const player = openPlayer();
    expect(within(player).getByText('PLAYING FROM')).toBeInTheDocument();
    expect(within(player).getByText('Album · Musopen Piano')).toBeInTheDocument();
    await user.click(within(player).getByRole('button', { name: 'Next' }));
    expect(useUi.getState().nowPlaying?.id).toBe(tracks[1]!.id);
    // A new track mounts a new player (one engine per media).
    const next = screen.getByRole('dialog', { name: `Now playing: ${tracks[1]!.title}` });
    await user.click(within(next).getByRole('button', { name: 'Repeat off' }));
    expect(useMobilePlayback.getState().repeat).toBe('all');
    await user.click(within(next).getByRole('button', { name: 'Shuffle' }));
    expect(useMobilePlayback.getState().shuffle).toBe(true);
  });

  it('manages the queue in its sheet (08)', async () => {
    const user = userEvent.setup();
    const player = openPlayer();
    await user.click(within(player).getByRole('button', { name: `Queue · ${tracks.length}` }));
    const sheet = screen.getByRole('dialog', { name: 'Play queue' });
    const list = within(sheet).getByRole('list', { name: 'Play queue' });
    expect(within(list).getAllByRole('listitem')).toHaveLength(tracks.length);
    await user.click(
      within(sheet).getByRole('button', { name: `Remove from queue : ${tracks[2]!.title}` }),
    );
    expect(useMobilePlayback.getState().queue).toHaveLength(tracks.length - 1);
    within(sheet)
      .getByRole('button', { name: `Move ${tracks[1]!.title}` })
      .focus();
    await user.keyboard('{ArrowUp}');
    expect(useMobilePlayback.getState().queue[0]!.id).toBe(tracks[1]!.id);
    await user.click(within(sheet).getByRole('button', { name: /Clear/ }));
    expect(useMobilePlayback.getState().queue.map((m) => m.id)).toEqual([tracks[0]!.id]);
    expect(within(sheet).getByText('Clearing the queue deletes no file.')).toBeInTheDocument();
  });

  it('sets speed and sleep timer in the sound sheet (09)', async () => {
    const user = userEvent.setup();
    const player = openPlayer();
    await user.click(within(player).getByRole('button', { name: /^Speed/ }));
    const sheet = screen.getByRole('dialog', { name: 'Sound' });
    expect(within(sheet).getByRole('switch', { name: 'Turn the equalizer on' })).toBeInTheDocument();
    await user.click(within(sheet).getByRole('radio', { name: '1.25×' }));
    expect(useMobilePlayback.getState().rate).toBe(1.25);
    expect(localStorage.getItem('mm:mobile:rate')).toBe('1.25');
    await user.click(within(sheet).getByRole('radio', { name: '30 min' }));
    expect(within(sheet).getByText(/Music stops in (29:5\d|30:00)\. The app stays open\./)).toBeInTheDocument();
    expect(within(player).getByRole('button', { name: '30 min' })).toBeInTheDocument();
  });

  it('shows local lyrics only (AND-15)', async () => {
    const user = userEvent.setup();
    const tags = await backend.libraryTags(tracks[0]!.id);
    await backend.libraryUpdateTags(tracks[0]!.id, { ...tags, lyrics: 'Tononkira voalohany' }, false);
    const player = openPlayer();
    await user.click(within(player).getByRole('button', { name: 'Lyrics' }));
    const sheet = screen.getByRole('dialog', { name: 'Lyrics' });
    expect(await within(sheet).findByText('Tononkira voalohany')).toBeInTheDocument();
  });
});

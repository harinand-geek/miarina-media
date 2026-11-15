import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { resetMockBackend } from '../services/backend';
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

const nav = () => screen.getByRole('navigation', { name: 'Main' });

describe('Android v2 shell', () => {
  it('splits the library into Music and Videos tabs', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(within(nav()).getByRole('button', { name: /Music/ }));
    expect(screen.getByRole('heading', { name: 'Music' })).toBeInTheDocument();
    await waitFor(() =>
      expect(useLibrary.getState().items.every((m) => m.kind === 'audio')).toBe(true),
    );
    await user.click(within(nav()).getByRole('button', { name: /Videos/ }));
    expect(screen.getByRole('heading', { name: 'Videos' })).toBeInTheDocument();
    await waitFor(() =>
      expect(useLibrary.getState().items.every((m) => m.kind === 'video')).toBe(true),
    );
  });

  it('reads the French catalog for the tabs', () => {
    useSettings.setState({ lang: 'fr' });
    render(<MobileShell />);
    const labels = within(screen.getByRole('navigation', { name: 'Navigation principale' }))
      .getAllByRole('button')
      .map((b) => b.textContent?.replace(/^[a-z_]+/, '').replace(/\d+$/, ''));
    expect(labels).toEqual(['Musique', 'Vidéos', 'Téléch.']);
  });

  it('minimizes the player into the mini-player without stopping it', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    const media = useLibrary.getState().items.find((m) => m.kind === 'audio')!;
    act(() => useUi.getState().play(media));

    const player = screen.getByRole('dialog', { name: `Now playing: ${media.title}` });
    await user.click(within(player).getByRole('button', { name: 'Minimize player' }));
    expect(player).not.toBeVisible();
    expect(useUi.getState().nowPlaying?.id).toBe(media.id);

    const mini = screen.getByRole('region', { name: 'Now playing' });
    expect(within(mini).getByText(media.title)).toBeInTheDocument();
    expect(within(mini).getByRole('button', { name: /^Next/ })).toBeDisabled();

    // Same player element: the engine was never unmounted.
    await user.click(within(mini).getByRole('button', { name: /Open player/ }));
    expect(screen.getByRole('dialog', { name: `Now playing: ${media.title}` })).toBe(player);
    expect(player).toBeVisible();
    expect(screen.queryByRole('region', { name: 'Now playing' })).toBeNull();
  });

  it('minimizes the player when it is dragged down, and ignores a small move', () => {
    render(<MobileShell />);
    const media = useLibrary.getState().items.find((m) => m.kind === 'audio')!;
    act(() => useUi.getState().play(media));
    const player = screen.getByRole('dialog', { name: `Now playing: ${media.title}` });
    const bar = within(player).getByRole('button', { name: 'Minimize player' }).parentElement!;

    // Under the slop: a tap, not a drag.
    fireEvent.pointerDown(bar, { button: 0, pointerId: 1, clientY: 100 });
    fireEvent.pointerMove(bar, { pointerId: 1, clientY: 104 });
    fireEvent.pointerUp(bar, { pointerId: 1, clientY: 104 });
    expect(player).toBeVisible();

    fireEvent.pointerDown(bar, { button: 0, pointerId: 2, clientY: 100 });
    fireEvent.pointerMove(bar, { pointerId: 2, clientY: 180 });
    fireEvent.pointerMove(bar, { pointerId: 2, clientY: 400 });
    fireEvent.pointerUp(bar, { pointerId: 2, clientY: 400 });
    expect(player).not.toBeVisible();
    expect(useUi.getState().nowPlaying?.id).toBe(media.id);
    expect(screen.getByRole('region', { name: 'Now playing' })).toBeInTheDocument();

    // Vice versa: swiping the mini-player up opens the full player again.
    const mini = screen.getByRole('region', { name: 'Now playing' });
    fireEvent.pointerDown(mini, { button: 0, pointerId: 3, clientY: 700 });
    fireEvent.pointerMove(mini, { pointerId: 3, clientY: 640 });
    expect(player).toBeVisible();
  });

  it('hides the mini-player with the browser and keeps playing', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    const media = useLibrary.getState().items[0]!;
    act(() => {
      useUi.getState().play(media);
      useUi.setState({ mobilePlayerExpanded: false });
    });
    expect(screen.getByRole('region', { name: 'Now playing' })).toBeInTheDocument();
    await user.click(within(nav()).getByRole('button', { name: /Downloads/ }));
    await user.click(screen.getByRole('button', { name: 'Browser' }));
    expect(screen.queryByRole('region', { name: 'Now playing' })).toBeNull();
    expect(useUi.getState().nowPlaying?.id).toBe(media.id);
  });
});

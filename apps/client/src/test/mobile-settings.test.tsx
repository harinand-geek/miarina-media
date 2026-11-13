import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { savedPosition } from '../features/player/usePlayback';
import { useUpdates } from '../features/settings/useUpdates';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  localStorage.clear();
  useUi.setState(useUi.getInitialState(), true);
  useUpdates.setState(useUpdates.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState({ ...useSettings.getInitialState(), resumePlayback: true }, true);
  await useSettings.getState().load();
  stop = useDownloads.getState().init();
  await waitFor(() => expect(useDownloads.getState().ready).toBe(true));
});

afterEach(() => stop());

async function openSettings() {
  const user = userEvent.setup();
  render(<MobileShell />);
  await user.click(screen.getByRole('button', { name: /^Settings/ }));
  return user;
}

describe('Android v2 Settings (12)', () => {
  it('offers a verified update without forcing it and names active downloads', async () => {
    useUpdates.setState({
      phase: 'ready',
      release: { version: '0.1.8', notes: '', size: 134_637_158 },
    });
    const user = await openSettings();
    const card = screen.getByRole('region', { name: '0.1.8 is ready' });
    expect(within(card).getByText('Signature and SHA-256 verified')).toBeInTheDocument();
    expect(
      within(card).getByText(/active download\(s\): interrupted during the install/),
    ).toBeInTheDocument();
    expect(within(card).getByRole('button', { name: 'Install now' })).toBeEnabled();
    await user.click(within(card).getByRole('button', { name: 'Later' }));
    expect(screen.queryByRole('region', { name: '0.1.8 is ready' })).toBeNull();
    expect(screen.getByRole('button', { name: 'Check for updates' })).toBeInTheDocument();
  });

  it('switches the resource mode and describes its real limits', async () => {
    const user = await openSettings();
    const modes = screen.getByRole('radiogroup', { name: 'PERFORMANCE' });
    await user.click(within(modes).getByRole('radio', { name: /Eco/ }));
    expect(useSettings.getState().resourceMode).toBe('eco');
    expect(screen.getByText(/1 simultaneous download\(s\)/)).toBeInTheDocument();
  });

  it('turns resume off for real and keeps future features planned', async () => {
    localStorage.setItem('mm:position:1', '42');
    const user = await openSettings();
    expect(savedPosition(1)).toBe(42);
    await user.click(screen.getByRole('switch', { name: 'Resume where I left off' }));
    expect(savedPosition(1)).toBe(0);
    expect(localStorage.getItem('mm:position:1')).toBe('42');
    const playback = screen.getByRole('region', { name: 'PLAYBACK' });
    // Gestures (L07) and headset pause are real, gapless is always on; only
    // crossfade stays planned (AND-12, off by default).
    expect(within(playback).getAllByText('PLANNED')).toHaveLength(1);
    expect(within(playback).getByText('ON')).toBeInTheDocument();
    const gestures = within(playback).getByRole('switch', { name: 'Video gestures' });
    expect(gestures).toBeChecked();
    await user.click(gestures);
    expect(useSettings.getState().videoGestures).toBe(false);
    expect(localStorage.getItem('mm:gestures')).toBe('0');
    const headset = within(playback).getByRole('switch', {
      name: 'Pause when headphones are unplugged',
    });
    expect(headset).toBeChecked();
    await user.click(headset);
    expect(useSettings.getState().headsetPause).toBe(false);
    expect(localStorage.getItem('mm:headset')).toBe('0');
  });

  it('switches the language from Settings', async () => {
    const user = await openSettings();
    await user.click(screen.getByRole('button', { name: /Language/ }));
    expect(useSettings.getState().lang).toBe('fr');
    expect(screen.getByRole('heading', { name: 'Réglages' })).toBeInTheDocument();
  });
});

import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { DeviceMediaCard } from '../features/library/DeviceMediaCard';
import { resetDeviceMediaCard } from '../features/library/deviceMediaSession';
import { backend, resetMockBackend } from '../services/backend';
import type { DeviceAccess } from '../services/types';
import { useSettings } from '../stores/settings';

const state = (audio: string, video = audio): DeviceAccess => ({ audio, video });

beforeEach(() => {
  resetMockBackend();
  useSettings.setState(useSettings.getInitialState(), true);
  resetDeviceMediaCard();
});

afterEach(() => vi.restoreAllMocks());

describe('Phone media access (AND-06)', () => {
  it('stays hidden on desktop and once access is granted', async () => {
    const access = vi.spyOn(backend, 'deviceMediaAccess');
    const sync = vi.spyOn(backend, 'deviceMediaSync');
    const { unmount } = render(<DeviceMediaCard />);
    await waitFor(() => expect(access).toHaveBeenCalled());
    expect(screen.queryByRole('region', { name: 'Music on this phone' })).toBeNull();
    unmount();

    access.mockResolvedValue(state('granted'));
    render(<DeviceMediaCard />);
    await waitFor(() => expect(access).toHaveBeenCalledTimes(2));
    expect(screen.queryByRole('region', { name: 'Music on this phone' })).toBeNull();
    // Indexed at startup a moment ago: no second sync.
    expect(sync).not.toHaveBeenCalled();
  });

  it('syncs again when Music opens long after the last sync', async () => {
    resetDeviceMediaCard(0);
    vi.spyOn(backend, 'deviceMediaAccess').mockResolvedValue(state('granted'));
    const sync = vi.spyOn(backend, 'deviceMediaSync').mockResolvedValue(state('granted'));
    render(<DeviceMediaCard />);
    await waitFor(() => expect(sync).toHaveBeenCalledTimes(1));
  });

  it('asks only on a tap, then disappears when granted', async () => {
    const user = userEvent.setup();
    vi.spyOn(backend, 'deviceMediaAccess').mockResolvedValue(state('prompt'));
    const request = vi.spyOn(backend, 'deviceMediaRequest').mockResolvedValue(state('granted'));
    render(<DeviceMediaCard />);
    const card = await screen.findByRole('region', { name: 'Music on this phone' });
    expect(card).toHaveTextContent('Read only');
    expect(request).not.toHaveBeenCalled();

    await user.click(screen.getByRole('button', { name: 'Allow access' }));
    expect(request).toHaveBeenCalledTimes(1);
    await waitFor(() =>
      expect(screen.queryByRole('region', { name: 'Music on this phone' })).toBeNull(),
    );
  });

  it('after a refusal, opens the settings and checks again on return', async () => {
    const user = userEvent.setup();
    resetDeviceMediaCard(0);
    const access = vi.spyOn(backend, 'deviceMediaAccess').mockResolvedValue(state('denied'));
    const settings = vi.spyOn(backend, 'deviceMediaSettings').mockResolvedValue();
    const request = vi.spyOn(backend, 'deviceMediaRequest');
    const sync = vi.spyOn(backend, 'deviceMediaSync').mockResolvedValue(state('granted'));
    render(<DeviceMediaCard />);
    expect(await screen.findByText(/Access denied/)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Open settings' }));
    expect(settings).toHaveBeenCalledTimes(1);
    expect(request).not.toHaveBeenCalled();

    access.mockResolvedValue(state('granted'));
    await act(async () => {
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await waitFor(() => expect(sync).toHaveBeenCalledTimes(1));
    expect(screen.queryByRole('region', { name: 'Music on this phone' })).toBeNull();
  });

  it('can be put off for the session and shows failures', async () => {
    const user = userEvent.setup();
    vi.spyOn(backend, 'deviceMediaAccess').mockResolvedValue(state('prompt'));
    vi.spyOn(backend, 'deviceMediaRequest').mockRejectedValue(new Error('media index unavailable'));
    const { unmount } = render(<DeviceMediaCard />);
    await user.click(await screen.findByRole('button', { name: 'Allow access' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Could not read the music on this phone: media index unavailable',
    );

    await user.click(screen.getByRole('button', { name: 'Not now' }));
    expect(screen.queryByRole('region', { name: 'Music on this phone' })).toBeNull();
    unmount();
    render(<DeviceMediaCard />);
    await act(async () => {});
    expect(screen.queryByRole('region', { name: 'Music on this phone' })).toBeNull();
  });
});

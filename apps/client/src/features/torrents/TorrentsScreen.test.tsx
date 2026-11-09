import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, expect, it, vi } from 'vitest';
import TorrentsScreen from './TorrentsScreen';
import { torrents } from '../../services/torrents';

vi.mock('../../services/platform', () => ({ inTauri: () => true }));
vi.mock('../../services/torrents', () => ({
  torrents: {
    list: vi.fn(),
    enable: vi.fn(),
    disable: vi.fn(),
    preview: vi.fn(),
    start: vi.fn(),
    action: vi.fn(),
    limits: vi.fn(),
  },
}));
beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(torrents.list).mockResolvedValue({
    enabled: true,
    rows: [],
    downloadLimit: 0,
    uploadLimit: 0,
  });
});
it('inspects a magnet before starting and sends only selected files', async () => {
  vi.mocked(torrents.preview).mockResolvedValue({
    hash: 'abc',
    name: 'Local fixture',
    files: [
      { index: 0, path: 'a.bin', size: 10 },
      { index: 1, path: 'b.bin', size: 20 },
    ],
  });
  const user = userEvent.setup();
  render(<TorrentsScreen />);
  await user.type(
    await screen.findByRole('textbox', { name: 'Magnet link' }),
    'magnet:?xt=urn:btih:abc',
  );
  await user.click(screen.getByRole('button', { name: 'Inspect link' }));
  await screen.findByText('Local fixture');
  expect(torrents.start).not.toHaveBeenCalled();
  await user.click(screen.getByRole('checkbox', { name: /a.bin/ }));
  await user.click(screen.getByRole('button', { name: 'Start download' }));
  await waitFor(() => expect(torrents.start).toHaveBeenCalledWith('abc', [1], false));
});
it('requires explicit session activation and displays activation failures', async () => {
  vi.mocked(torrents.list).mockResolvedValue({
    enabled: false,
    rows: [],
    downloadLimit: 0,
    uploadLimit: 0,
  });
  vi.mocked(torrents.enable).mockRejectedValue({ message: 'Session unavailable' });
  const user = userEvent.setup();
  render(<TorrentsScreen />);
  expect(torrents.enable).not.toHaveBeenCalled();
  await user.click(await screen.findByRole('button', { name: 'Enable torrent session' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Session unavailable');
});

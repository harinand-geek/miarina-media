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
it('preserves the other persisted rate limit when editing one field', async () => {
  vi.mocked(torrents.list).mockResolvedValue({
    enabled: true,
    rows: [],
    downloadLimit: 102400,
    uploadLimit: 51200,
  });
  const user = userEvent.setup();
  render(<TorrentsScreen />);
  await screen.findByRole('textbox', { name: 'Magnet link' });
  const download = await screen.findByRole('spinbutton', { name: /Download limit/ });
  expect(download).toHaveValue(100);
  expect(screen.getByRole('spinbutton', { name: /Upload limit/ })).toHaveValue(50);
  await user.clear(download);
  await user.type(download, '200{Enter}');
  await waitFor(() => expect(torrents.limits).toHaveBeenCalledWith(204800, 51200));
});
it('offers resume for an errored torrent', async () => {
  vi.mocked(torrents.list).mockResolvedValue({
    enabled: true,
    downloadLimit: 0,
    uploadLimit: 0,
    rows: [
      {
        hash: 'abc',
        name: 'Broken transfer',
        folder: 'test',
        phase: 'error',
        done: 0,
        total: 100,
        uploaded: 0,
        downSpeed: 0,
        upSpeed: 0,
        peers: 0,
      },
    ],
  });
  const user = userEvent.setup();
  render(<TorrentsScreen />);
  await user.click(await screen.findByRole('button', { name: 'Resume' }));
  await waitFor(() => expect(torrents.action).toHaveBeenCalledWith('abc', 'resume'));
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
  await user.click(await screen.findByRole('button', { name: 'Enable session' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Session unavailable');
});
it('shows sharing after completion and stops it on request (TOR-03)', async () => {
  vi.mocked(torrents.list).mockResolvedValue({
    enabled: true,
    downloadLimit: 0,
    uploadLimit: 0,
    rows: [
      {
        hash: 'done',
        name: 'Finished set',
        folder: 'test',
        phase: 'finished',
        done: 100,
        total: 100,
        uploaded: 80,
        downSpeed: 0,
        upSpeed: 2048,
        peers: 3,
      },
    ],
  });
  const user = userEvent.setup();
  render(<TorrentsScreen />);
  expect(await screen.findByText('Session on · sharing')).toBeInTheDocument();
  expect(screen.getByText('0.8')).toBeInTheDocument();
  await user.click(screen.getByRole('button', { name: 'Stop sharing' }));
  await waitFor(() => expect(torrents.action).toHaveBeenCalledWith('done', 'pause'));
  // Targets that do not exist yet are not offered as working settings.
  expect(screen.getByText('Target ratio')).toBeInTheDocument();
  expect(screen.getAllByText('PLANNED').length).toBe(2);
});

import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { backend, resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { resetPlayerForTests } from '../stores/player';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

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

afterEach(() => {
  stop();
  vi.restoreAllMocks();
});

const firstItem = () => useLibrary.getState().items[0]!;

describe('Android v2 sheet: remove or delete (COM-10)', () => {
  it('removes by default and keeps the file', async () => {
    const user = userEvent.setup();
    const remove = vi.spyOn(backend, 'libraryRemove');
    const del = vi.spyOn(backend, 'libraryDelete');
    render(<MobileShell />);
    const media = firstItem();
    act(() => useUi.getState().askRemoval(media));

    const sheet = screen.getByRole('dialog', { name: `Remove “${media.title}”?` });
    expect(within(sheet).getByRole('button', { name: 'Cancel' })).toHaveFocus();
    expect(within(sheet).getByRole('radio', { name: /Remove from library/ })).toBeChecked();
    await user.click(within(sheet).getByRole('button', { name: 'Remove' }));

    await waitFor(() => expect(remove).toHaveBeenCalledWith(media.id));
    expect(del).not.toHaveBeenCalled();
    expect(
      await screen.findByText('Removed from library. The file stays on disk.'),
    ).toBeInTheDocument();
  });

  it('names the file before an explicit, permanent deletion', async () => {
    const user = userEvent.setup();
    const del = vi.spyOn(backend, 'libraryDelete');
    render(<MobileShell />);
    const media = firstItem();
    act(() => useUi.getState().askRemoval(media));

    const sheet = screen.getByRole('dialog');
    await user.click(within(sheet).getByRole('radio', { name: /Delete the file from the device/ }));
    expect(within(sheet).getByText(/Permanent\. This file will be erased/)).toBeInTheDocument();
    expect(
      within(sheet).getByText((text) => text.startsWith(media.path) && text.includes(' · ')),
    ).toBeInTheDocument();
    await user.click(within(sheet).getByRole('button', { name: 'Delete file' }));
    await waitFor(() => expect(del).toHaveBeenCalledWith(media.id));
  });

  it('closes on Cancel without touching the library', async () => {
    const user = userEvent.setup();
    const remove = vi.spyOn(backend, 'libraryRemove');
    render(<MobileShell />);
    act(() => useUi.getState().askRemoval(firstItem()));
    await user.click(screen.getByRole('button', { name: 'Cancel' }));
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(remove).not.toHaveBeenCalled();
  });
});

import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, expect, it, vi } from 'vitest';
import { invoke } from '@tauri-apps/api/core';
import { BrowserExtension } from './BrowserExtension';
import { useUi } from '../../stores/ui';

vi.mock('@tauri-apps/api/core', () => ({ invoke: vi.fn() }));
vi.mock('../../services/platform', () => ({ inTauri: () => true }));
beforeEach(() => {
  vi.resetAllMocks();
  useUi.setState(useUi.getInitialState(), true);
  vi.mocked(invoke).mockImplementation(async (command) =>
    command === 'browser_inbox' ? [{ id: '123-1', url: 'https://example.com/video' }] : undefined,
  );
});
it('keeps received links for review and analyzes only after a click', async () => {
  const user = userEvent.setup();
  render(<BrowserExtension />);
  await screen.findByText('https://example.com/video');
  // Nothing is analyzed before the click.
  expect(useUi.getState().screen).not.toBe('analysis');
  await user.click(screen.getByRole('button', { name: 'Analyze' }));
  expect(useUi.getState().pendingUrl).toBe('https://example.com/video');
  expect(invoke).not.toHaveBeenCalledWith('browser_inbox_dismiss', expect.anything());
});
it('requires an exact extension ID before registration', async () => {
  const user = userEvent.setup();
  render(<BrowserExtension />);
  expect(screen.getByRole('button', { name: 'Connect' })).toBeDisabled();
  await user.type(screen.getByRole('textbox', { name: 'Extension ID' }), 'a'.repeat(32));
  await user.click(screen.getByRole('button', { name: 'Connect' }));
  await waitFor(() =>
    expect(invoke).toHaveBeenCalledWith('browser_bridge_register', {
      browser: 'chrome',
      extensionId: 'a'.repeat(32),
      enabled: true,
    }),
  );
});

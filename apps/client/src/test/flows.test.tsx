import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { MobileShell } from '../app/MobileShell';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stopEvents: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  await useSettings.getState().load();
  stopEvents = useDownloads.getState().init();
  await waitFor(() => expect(useDownloads.getState().ready).toBe(true));
});

afterEach(() => stopEvents());

describe('Windows shell', () => {
  it('navigates with the sidebar and Ctrl+1…7 shortcuts', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    expect(screen.getByRole('heading', { name: 'Download from a link' })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /Downloads/ }));
    expect(screen.getByRole('heading', { name: 'Downloads' })).toBeInTheDocument();

    await user.keyboard('{Control>}5{/Control}');
    expect(await screen.findByRole('heading', { name: 'History' })).toBeInTheDocument();

    await user.keyboard('{Control>}6{/Control}');
    expect(await screen.findByText(/built-in browser is a concept/)).toBeInTheDocument();
  });

  it('toggles the sidebar with Ctrl+B', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    expect(screen.getByRole('button', { name: 'Collapse sidebar' })).toBeInTheDocument();
    await user.keyboard('{Control>}b{/Control}');
    expect(screen.getByRole('button', { name: 'Expand sidebar' })).toBeInTheDocument();
  });

  it('shows the design error for an incomplete link and stays on Home', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    await user.type(screen.getByRole('textbox', { name: 'Media link' }), 'mango.blender');
    await user.click(screen.getByRole('button', { name: 'Analyze' }));
    expect(screen.getByRole('alert')).toHaveTextContent('This doesn’t look like a complete link');
    expect(screen.getByRole('textbox', { name: 'Media link' })).toHaveAttribute(
      'aria-invalid',
      'true',
    );
    expect(useUi.getState().screen).toBe('home');
  });

  it('analyzes a link, lists formats and starts a download', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    render(<DesktopShell />);
    await user.type(
      screen.getByRole('textbox', { name: 'Media link' }),
      'https://mango.blender.org/download/{Enter}',
    );
    expect(screen.getByText('Reading available formats…')).toBeInTheDocument();

    await act(() => vi.advanceTimersByTimeAsync(1000));
    expect(screen.getByRole('heading', { name: 'Tears of Steel' })).toBeInTheDocument();
    const quality = screen.getByRole('radiogroup', { name: 'Quality' });
    expect(within(quality).getByRole('radio', { checked: true })).toHaveTextContent('1080p');

    await user.click(within(quality).getByRole('radio', { name: /720p/ }));
    await user.click(screen.getByRole('button', { name: 'Download' }));
    expect(await screen.findByRole('heading', { name: 'Downloads' })).toBeInTheDocument();
    expect(await screen.findByText('Tears of Steel (720p)')).toBeInTheDocument();
    vi.useRealTimers();
  });

  it('reports sources without downloadable media', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    render(<DesktopShell />);
    await user.type(
      screen.getByRole('textbox', { name: 'Media link' }),
      'https://www.nasa.gov/live{Enter}',
    );
    await act(() => vi.advanceTimersByTimeAsync(1000));
    expect(screen.getByText('No downloadable media found')).toBeInTheDocument();
    expect(screen.getByText('live streams are not supported')).toBeInTheDocument();
    vi.useRealTimers();
  });

  it('asks before downloading the media tools, then analyzes', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    render(<DesktopShell />);
    await user.type(
      screen.getByRole('textbox', { name: 'Media link' }),
      'https://needs-tools.test/watch{Enter}',
    );
    await act(() => vi.advanceTimersByTimeAsync(1000));
    expect(screen.getByText('This page needs the media tools')).toBeInTheDocument();
    // Nothing is downloaded without an explicit click.
    await user.click(screen.getByRole('button', { name: /Download tools/ }));
    await act(() => vi.advanceTimersByTimeAsync(1000));
    expect(await screen.findByRole('heading', { name: 'Tears of Steel' })).toBeInTheDocument();
    vi.useRealTimers();
  });

  it('confirms before canceling a download; Esc keeps it', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'downloads' });
    render(<DesktopShell />);
    const count = () => Object.keys(useDownloads.getState().tasks).length;
    const before = count();

    await user.click(screen.getAllByRole('button', { name: 'Cancel' })[0]!);
    const dialog = screen.getByRole('alertdialog', { name: 'Cancel this download?' });
    expect(within(dialog).getByRole('button', { name: 'Keep' })).toHaveFocus();

    await user.keyboard('{Escape}');
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
    expect(count()).toBe(before);

    await user.click(screen.getAllByRole('button', { name: 'Cancel' })[0]!);
    await user.click(screen.getByRole('button', { name: 'Cancel download' }));
    await waitFor(() => expect(count()).toBe(before - 1));
  });

  it('exposes download progress to assistive technology', () => {
    useUi.setState({ screen: 'downloads' });
    render(<DesktopShell />);
    const bar = screen.getByRole('progressbar', { name: /^Tears of Steel, 60 percent/ });
    expect(bar).toHaveAttribute('aria-valuenow', '62');
  });

  it('switches resource mode in Settings › Performance', async () => {
    const user = userEvent.setup();
    useUi.setState({ screen: 'settings' });
    render(<DesktopShell />);
    await user.click(await screen.findByRole('button', { name: 'Performance' }));
    await user.click(screen.getByRole('radio', { name: 'Eco' }));
    expect(useSettings.getState().resourceMode).toBe('eco');
    expect(screen.getByRole('switch', { name: 'Reduce motion' })).toBeChecked();
  });
});

describe('Android shell', () => {
  it('uses bottom navigation, not the desktop sidebar', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    expect(screen.queryByRole('button', { name: 'Collapse sidebar' })).not.toBeInTheDocument();
    const nav = screen.getByRole('navigation', { name: 'Main' });
    expect(within(nav).getAllByRole('button')).toHaveLength(4);
    await user.click(within(nav).getByRole('button', { name: /Downloads/ }));
    expect(screen.getByRole('heading', { name: 'Downloads' })).toBeInTheDocument();
  });

  it('opens the analysis as a bottom sheet', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    render(<MobileShell />);
    await user.type(screen.getByLabelText('Paste a link'), 'https://mango.blender.org/download/');
    await user.click(screen.getByRole('button', { name: 'Analyze link' }));
    await act(() => vi.advanceTimersByTimeAsync(1000));
    const sheet = screen.getByRole('dialog', { name: 'Analyze link' });
    expect(within(sheet).getByRole('button', { name: /Download · 372 MB/ })).toBeInTheDocument();
    vi.useRealTimers();
  });
});

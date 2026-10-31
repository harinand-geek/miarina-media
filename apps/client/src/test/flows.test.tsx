import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { DesktopShell } from '../app/DesktopShell';
import { MobileShell } from '../app/MobileShell';
import type { MockBackend } from '../dev/mockBackend';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';
import type { MediaRecord } from '../services/types';

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
  it('hides app navigation in player fullscreen and restores it on Escape', async () => {
    const user = userEvent.setup();
    useUi.setState({
      screen: 'player',
      nowPlaying: {
        id: 999,
        title: 'Fullscreen test',
        kind: 'audio',
        path: '/test.mp3',
        durationSecs: 120,
        sizeBytes: 1000,
      } as MediaRecord,
    });
    render(<DesktopShell />);
    await user.click(await screen.findByRole('button', { name: 'Fullscreen (F)' }));
    expect(screen.queryByRole('button', { name: 'Collapse sidebar' })).toBeNull();
    expect(useUi.getState().playerFullscreen).toBe(true);
    await user.keyboard('{Escape}');
    expect(await screen.findByRole('button', { name: 'Collapse sidebar' })).toBeInTheDocument();
    expect(useUi.getState().playerFullscreen).toBe(false);
    await user.click(screen.getByRole('button', { name: 'Fullscreen (F)' }));
    act(() => useUi.getState().go('home'));
    expect(
      await screen.findByRole('heading', { name: 'Download from a link' }),
    ).toBeInTheDocument();
    expect(useUi.getState().playerFullscreen).toBe(false);
  });
  it('navigates with the sidebar and Ctrl+1…7 shortcuts', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    expect(screen.getByRole('heading', { name: 'Download from a link' })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /Downloads/ }));
    expect(screen.getByRole('heading', { name: 'Downloads' })).toBeInTheDocument();

    await user.keyboard('{Control>}5{/Control}');
    expect(await screen.findByRole('heading', { name: 'History' })).toBeInTheDocument();

    await user.keyboard('{Control>}6{/Control}');
    // The browser is a screen of the main window (same as on Android).
    expect(
      await screen.findByRole('heading', { name: 'Search or open a web page' }),
    ).toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: 'Browser' })).toBeInTheDocument();
  });

  it('toggles the sidebar with Ctrl+B', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    expect(screen.getByRole('button', { name: 'Collapse sidebar' })).toBeInTheDocument();
    await user.keyboard('{Control>}b{/Control}');
    expect(screen.getByRole('button', { name: 'Expand sidebar' })).toBeInTheDocument();
  });

  it('hints instead of warning when the link field is empty', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    await user.click(screen.getByRole('button', { name: 'Analyze' }));
    expect(screen.getByRole('status')).toHaveTextContent('Paste a link to analyze.');
    expect(screen.queryByRole('alert')).toBeNull();
    expect(screen.getByRole('textbox', { name: 'Media link' })).toHaveAttribute(
      'aria-invalid',
      'false',
    );
    expect(useUi.getState().screen).toBe('home');
  });

  it('searches words that are not a link in the built-in browser', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    await user.type(screen.getByRole('textbox', { name: 'Media link' }), 'big buck bunny');
    await user.click(screen.getByRole('button', { name: 'Analyze' }));
    await waitFor(() => expect(useUi.getState().screen).toBe('browser'));
    expect(await screen.findByText('www.google.com')).toBeInTheDocument();
  });

  it('browser: a page can be added to favorites and opened from the start page', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    await user.keyboard('{Control>}6{/Control}');
    await user.click(await screen.findByRole('button', { name: 'Search or type a web address' }));
    await user.type(
      screen.getByRole('textbox', { name: 'Search or type a web address' }),
      'studio.blender.org{Enter}',
    );
    await user.click(await screen.findByRole('button', { name: 'Add to favorites' }));
    expect(
      await screen.findByRole('button', { name: 'Remove from favorites' }),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Start page' }));
    const list = await screen.findByRole('list', { name: 'Favorites' });
    expect(list).toHaveTextContent('Sprite Fright');
  });

  it('offers to add the missing https:// and analyzes the fixed link', async () => {
    const user = userEvent.setup();
    render(<DesktopShell />);
    const field = screen.getByRole('textbox', { name: 'Media link' });
    await user.type(field, 'mango.blender.org/download/');
    await user.click(screen.getByRole('button', { name: 'Analyze' }));
    expect(screen.getByRole('alert')).toHaveTextContent('This link is missing “https://”.');
    await user.click(screen.getByRole('button', { name: /Add https/ }));
    expect(field).toHaveValue('https://mango.blender.org/download/');
    expect(useUi.getState().screen).toBe('analysis');
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
  it('allows canceling an active download after confirmation', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(
      within(screen.getByRole('navigation', { name: 'Main' })).getByRole('button', {
        name: /Downloads/,
      }),
    );
    const count = () => Object.keys(useDownloads.getState().tasks).length;
    const before = count();
    await user.click(screen.getAllByRole('button', { name: /^Cancel / })[0]!);
    const dialog = screen.getByRole('alertdialog', { name: 'Cancel download?' });
    expect(count()).toBe(before);
    await user.click(within(dialog).getByRole('button', { name: 'Cancel download' }));
    await waitFor(() => expect(count()).toBe(before - 1));
  });

  it('uses bottom navigation, not the desktop sidebar', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    expect(screen.queryByRole('button', { name: 'Collapse sidebar' })).not.toBeInTheDocument();
    const nav = screen.getByRole('navigation', { name: 'Main' });
    expect(within(nav).getAllByRole('button')).toHaveLength(4);
    await user.click(within(nav).getByRole('button', { name: /Downloads/ }));
    expect(screen.getByRole('heading', { name: 'Downloads' })).toBeInTheDocument();
  });

  it('follows the M5 navigation: Browser tab, Settings from Home', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    const nav = screen.getByRole('navigation', { name: 'Main' });
    expect(
      within(nav)
        .getAllByRole('button')
        // Labels only: the Downloads badge adds a count.
        .map((b) => b.textContent?.replace(/\d+/g, '')),
    ).toEqual(['homeHome', 'travel_exploreBrowser', 'downloadDownloads', 'video_libraryLibrary']);
    await user.click(within(nav).getByRole('button', { name: /Browser/ }));
    // Design M1: the browser bar replaces the main navigation.
    expect(screen.getByRole('heading', { name: 'Search or open a web page' })).toBeInTheDocument();
    expect(nav).not.toBeVisible();
    await user.click(screen.getByRole('button', { name: 'Back to Miarina Media' }));
    expect(nav).toBeVisible();
    await user.click(screen.getByRole('button', { name: 'Settings' }));
    expect(screen.getByRole('heading', { name: 'Settings' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Back' }));
    expect(screen.queryByRole('heading', { name: 'Settings' })).not.toBeInTheDocument();
  });

  it('browser: page media open the format sheet with one chip per media (M1, M3)', async () => {
    const mock = resetMockBackend() as MockBackend;
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(screen.getByRole('button', { name: /Browser/ }));
    await user.click(screen.getByRole('button', { name: 'Search or type a web address' }));
    await user.type(
      screen.getByRole('textbox', { name: 'Search or type a web address' }),
      'studio.blender.org{Enter}',
    );
    const chip = await screen.findByRole('button', { name: /Download media found on this page/ });
    expect(screen.getByText('studio.blender.org')).toBeInTheDocument();

    // The native floating button reports a tap through the page state.
    act(() => mock.showBrowserDemo({ fab: 'tap' }));
    const sheet = await screen.findByRole('dialog', { name: 'Analyze link' }, { timeout: 2000 });
    const chips = within(sheet).getAllByRole('radio', { checked: true });
    expect(chips[0]).toHaveTextContent('sprite-fright.mp4');
    expect(
      within(within(sheet).getByRole('radiogroup', { name: 'Media on this page' })).getAllByRole(
        'radio',
      ).length,
    ).toBeGreaterThan(1);
    expect(chip).toBeInTheDocument();
  });

  it('browser: an address that is not a web page is refused', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(screen.getByRole('button', { name: /Browser/ }));
    await user.click(screen.getByRole('button', { name: 'Search or type a web address' }));
    await user.type(
      screen.getByRole('textbox', { name: 'Search or type a web address' }),
      'ftp://example.org{Enter}',
    );
    expect(await screen.findByRole('alert')).toHaveTextContent('Only web pages');
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

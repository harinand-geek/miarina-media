import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { ConfirmDialog } from '../components/Overlay';
import type { MockBackend } from '../dev/mockBackend';
import { DesktopBrowser } from '../features/browser/DesktopBrowser';
import { resetMockBackend } from '../services/backend';
import { useUi } from '../stores/ui';

let mock: MockBackend;

beforeEach(() => {
  mock = resetMockBackend() as MockBackend;
  useUi.setState(useUi.getInitialState(), true);
});

const tabs = () =>
  within(screen.getByRole('tablist', { name: 'Browser tabs' })).getAllByRole('tab');

describe('Windows browser tabs (NAV-02)', () => {
  it('opens, names, switches and closes tabs', async () => {
    const user = userEvent.setup();
    render(<DesktopBrowser covered={false} />);
    await waitFor(() => expect(tabs()).toHaveLength(1));
    expect(tabs()[0]).toHaveTextContent('New tab');

    // A page in the first tab: its title and media badge show on the tab.
    await user.click(screen.getByRole('button', { name: 'Search or type a web address' }));
    await user.type(
      screen.getByRole('textbox', { name: 'Search or type a web address' }),
      'studio.blender.org{Enter}',
    );
    await waitFor(() => expect(tabs()[0]).toHaveTextContent('Sprite Fright'));
    expect(
      screen.getByRole('button', { name: /Download media found on this page/ }),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'New tab (Ctrl T)' }));
    await waitFor(() => expect(tabs()).toHaveLength(2));
    expect(tabs()[1]).toHaveAttribute('aria-selected', 'true');

    await user.click(tabs()[0]!);
    await waitFor(() => expect(tabs()[0]).toHaveAttribute('aria-selected', 'true'));
    expect(
      screen.getByRole('button', { name: /Address: https:\/\/studio\.blender\.org/ }),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /Close tab Sprite Fright/ }));
    await waitFor(() => expect(tabs()).toHaveLength(1));
    expect(tabs()[0]).toHaveAttribute('aria-selected', 'true');
    expect(tabs()[0]).toHaveTextContent('New tab');
  });

  it('opens a tab with Ctrl+T while the app has focus', async () => {
    const user = userEvent.setup();
    render(<DesktopBrowser covered={false} />);
    await waitFor(() => expect(tabs()).toHaveLength(1));
    await user.click(screen.getByRole('button', { name: 'Start page' }));
    await user.keyboard('{Control>}t{/Control}');
    await waitFor(() => expect(tabs()).toHaveLength(2));
  });
});

describe('Windows browser history (NAV-03)', () => {
  it('lists visited pages by day, searches, removes and clears them', async () => {
    const user = userEvent.setup();
    const now = Date.now();
    mock.seedVisits([
      { id: 2, url: 'https://archive.org/details/concerts', title: 'Concerts', visitedAt: now },
      {
        id: 1,
        url: 'https://commons.wikimedia.org/wiki/Sintel',
        title: 'Sintel',
        visitedAt: now - 60_000,
      },
    ]);
    render(
      <>
        <DesktopBrowser covered={false} />
        <ConfirmDialog />
      </>,
    );
    await user.click(await screen.findByRole('button', { name: 'History' }));
    const today = await screen.findByRole('region', { name: 'Today' });
    expect(within(today).getByText('Concerts')).toBeInTheDocument();
    expect(within(today).getByText('Sintel')).toBeInTheDocument();
    await waitFor(() => expect(tabs().some((t) => t.textContent?.includes('History'))).toBe(true));

    await user.type(screen.getByRole('searchbox', { name: 'Search visited pages' }), 'wikimedia');
    await waitFor(() => expect(screen.queryByText('Concerts')).toBeNull());
    await user.clear(screen.getByRole('searchbox', { name: 'Search visited pages' }));
    await screen.findByText('Concerts');

    await user.click(screen.getByRole('button', { name: 'Remove Concerts from history' }));
    expect(screen.queryByText('Concerts')).toBeNull();

    await user.click(screen.getByRole('button', { name: /Clear history/ }));
    await user.click(
      within(screen.getByRole('alertdialog')).getByRole('button', { name: 'Clear history' }),
    );
    expect(await screen.findByText('Pages you visit appear here.')).toBeInTheDocument();
    expect(screen.getByText(/Clearing it deletes no file or download/)).toBeInTheDocument();
  });

  it('shows favorites in the same tab', async () => {
    const user = userEvent.setup();
    await mock.browserFavoriteToggle('https://archive.org/', 'Internet Archive');
    render(<DesktopBrowser covered={false} />);
    await user.click(await screen.findByRole('button', { name: 'Favorites' }));
    expect(await screen.findByRole('radio', { name: 'Favorites' })).toHaveAttribute(
      'aria-checked',
      'true',
    );
    expect(screen.getByText('Internet Archive')).toBeInTheDocument();
    await user.click(
      screen.getByRole('button', { name: 'Remove Internet Archive from favorites' }),
    );
    expect(
      await screen.findByText('Star a page in the address bar to add it to favorites.'),
    ).toBeInTheDocument();
  });
});

describe('Windows browser tab budget (NAV-02)', () => {
  it('says so when every tab is already open', async () => {
    const user = userEvent.setup();
    render(<DesktopBrowser covered={false} />);
    await waitFor(() => expect(tabs()).toHaveLength(1));
    for (let i = 1; i < 12; i++) await mock.browserTabNew();
    await waitFor(() => expect(tabs()).toHaveLength(12));
    await user.click(screen.getByRole('button', { name: 'New tab (Ctrl T)' }));
    expect(useUi.getState().toasts.at(-1)?.message).toBe(
      'At most 12 tabs: close one to open another.',
    );
    expect(tabs()).toHaveLength(12);
  });
});

import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import type { MockBackend } from '../dev/mockBackend';
import { BrowserChrome } from '../features/browser/BrowserChrome';
import { BrowserOverlay } from '../features/browser/BrowserOverlay';
import { candidates, mainCandidate, splitAddress } from '../features/browser/candidates';
import { resetMockBackend } from '../services/backend';
import type { BrowserSnapshot } from '../services/types';
import { useDownloads } from '../stores/downloads';

let mock: MockBackend;

beforeEach(() => {
  mock = resetMockBackend() as MockBackend;
  useDownloads.setState(useDownloads.getInitialState(), true);
});

const page = (patch: Partial<BrowserSnapshot>): BrowserSnapshot => ({
  url: 'https://site.org/watch?v=1',
  title: 'A film',
  loading: false,
  canGoBack: false,
  canGoForward: false,
  startPage: false,
  sheet: false,
  media: [],
  streamPlayer: false,
  ...patch,
});

describe('browser candidates', () => {
  it('offers the page itself first when it streams through MSE', () => {
    const list = candidates(
      page({
        streamPlayer: true,
        media: [
          {
            kind: 'audio',
            url: 'https://cdn.site.org/theme.mp3',
            host: 'cdn.site.org',
            name: 'theme%20song.mp3',
            sizeBytes: 3_000_000,
            via: 'network',
          },
        ],
      }),
    );
    expect(list.map((c) => [c.kind, c.title])).toEqual([
      ['page', 'A film'],
      ['audio', 'theme song.mp3'],
    ]);
    expect(mainCandidate(list)?.kind).toBe('page');
  });

  it('pre-selects the first video otherwise', () => {
    const list = candidates(
      page({
        media: [
          {
            kind: 'audio',
            url: 'https://a.org/a.mp3',
            host: 'a.org',
            name: 'a.mp3',
            sizeBytes: null,
            via: 'page',
          },
          {
            kind: 'video',
            url: 'https://a.org/v.mp4',
            host: 'a.org',
            name: 'v.mp4',
            sizeBytes: null,
            via: 'page',
          },
        ],
      }),
    );
    expect(mainCandidate(list)?.url).toBe('https://a.org/v.mp4');
    expect(candidates(page({}))).toEqual([]);
  });

  it('splits the address for display', () => {
    expect(splitAddress('https://studio.blender.org/films/x/?a=1')).toEqual({
      host: 'studio.blender.org',
      rest: '/films/x/?a=1',
      secure: true,
    });
    expect(splitAddress('http://a.org/').secure).toBe(false);
  });
});

describe('browser chrome', () => {
  it('starts on the start page with the address focused, then navigates', async () => {
    const user = userEvent.setup();
    render(<BrowserChrome />);
    expect(await screen.findByText('Search or open a web page')).toBeInTheDocument();
    expect(screen.getByRole('list', { name: 'Shortcuts' })).toHaveTextContent('YouTube');
    const address = screen.getByRole('textbox', { name: 'Address' });
    await waitFor(() => expect(address).toHaveFocus());

    // Text that is not an address is searched.
    await user.type(address, 'cats{Enter}');
    await waitFor(() => expect(screen.queryByText('Search or open a web page')).toBeNull());
    expect(screen.queryByRole('alert')).toBeNull();

    await user.clear(address);
    await user.type(address, 'studio.blender.org/films/sprite-fright/{Enter}');
    expect(await screen.findByRole('button', { name: /2 media/ })).toBeInTheDocument();
    expect(screen.queryByText('Search or open a web page')).not.toBeInTheDocument();
    expect(screen.getByRole('tab')).toHaveTextContent('Sprite Fright — Blender Studio');
  });
});

describe('browser overlay', () => {
  it('stays empty when nothing is detected', async () => {
    const { container } = render(<BrowserOverlay />);
    act(() => mock.showBrowserDemo({ media: [] }));
    await waitFor(() => expect(container).toBeEmptyDOMElement());
  });

  it('opens the sheet from the button and queues the selected media', async () => {
    const user = userEvent.setup();
    render(<BrowserOverlay />);
    act(() => mock.showBrowserDemo());
    await user.click(await screen.findByRole('button', { name: 'Choose media and format' }));

    const sheet = await screen.findByRole('dialog', { name: 'Download from this page' });
    const items = within(sheet).getAllByRole('checkbox');
    expect(items.map((i) => (i as HTMLInputElement).checked)).toEqual([true, false]);
    // Formats come from the analysis of the selected item.
    await within(sheet).findByRole('radiogroup', { name: 'Quality' }, { timeout: 3000 });

    await user.click(within(sheet).getByRole('button', { name: /^Download/ }));
    await waitFor(() => expect(Object.keys(useDownloads.getState().tasks)).toHaveLength(1));
    // The sheet closes; the button now tracks the download.
    expect(await screen.findByRole('button', { name: /Downloading/ })).toBeInTheDocument();
  });
});

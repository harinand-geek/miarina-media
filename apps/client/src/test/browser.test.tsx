import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import type { MockBackend } from '../dev/mockBackend';
import { BrowserChrome } from '../features/browser/BrowserChrome';
import { BrowserOverlay } from '../features/browser/BrowserOverlay';
import {
  candidates,
  distinctLabels,
  mainCandidate,
  splitAddress,
} from '../features/browser/candidates';
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
  it('pre-selects the best sized copy up to 1080p, not a huge original', () => {
    const video = (name: string) => ({
      kind: 'video' as const,
      url: `https://upload.wikimedia.org/${name}`,
      host: 'upload.wikimedia.org',
      name,
      sizeBytes: null,
      via: 'page' as const,
    });
    const list = candidates(
      page({
        media: [
          video('Film_4K.webm'),
          video('Film_4K.webm.480p.vp9.webm'),
          video('Film_4K.webm.1080p.vp9.webm'),
          video('Film_4K.webm.2160p.vp9.webm'),
        ],
      }),
    );
    expect(mainCandidate(list)?.title).toBe('Film_4K.webm.1080p.vp9.webm');
    expect(mainCandidate(candidates(page({ media: [video('a.mp4')] })))?.title).toBe('a.mp4');
  });

  it('names variants of one file by what differs', () => {
    expect(
      distinctLabels([
        'Big_Buck_Bunny_4K.webm',
        'Big_Buck_Bunny_4K.webm.480p.vp9.webm',
        'Big_Buck_Bunny_4K.webm.720p.vp9.webm',
      ]),
    ).toEqual(['Big_Buck_Bunny_4K.webm', '480p.vp9.webm', '720p.vp9.webm']);
    expect(distinctLabels(['film.mp4', 'film-trailer.mp4'])).toEqual([
      'film.mp4',
      'film-trailer.mp4',
    ]);
    expect(distinctLabels(['a.mp4', 'b.mp4'])).toEqual(['a.mp4', 'b.mp4']);
  });

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

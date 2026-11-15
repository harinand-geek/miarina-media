import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { useUpdates } from '../features/settings/useUpdates';
import { backend, resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useMobilePlayback } from '../stores/mobilePlayback';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  localStorage.clear();
  useUi.setState(useUi.getInitialState(), true);
  useUpdates.setState(useUpdates.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState(useSettings.getInitialState(), true);
  stop = useDownloads.getState().init();
  await waitFor(() => expect(useDownloads.getState().ready).toBe(true));
});

afterEach(() => stop());

const nav = () => screen.getByRole('navigation', { name: 'Main' });

describe('Android player first (decision 0006)', () => {
  it('opens on Music and keeps Downloads as the last tab', () => {
    render(<MobileShell />);
    expect(screen.getByRole('heading', { name: 'Music' })).toBeInTheDocument();
    const tabs = within(nav()).getAllByRole('button');
    expect(tabs.at(-1)).toHaveAccessibleName(/Downloads/);
    expect(within(nav()).queryByRole('button', { name: /Browser/ })).toBeNull();
  });

  it('puts the link card on Downloads, in French, with Playlist planned', async () => {
    const user = userEvent.setup();
    useSettings.setState({ lang: 'fr' });
    render(<MobileShell />);
    await user.click(
      within(screen.getByRole('navigation', { name: 'Navigation principale' })).getByRole(
        'button',
        { name: /Téléch/ },
      ),
    );
    expect(screen.getByLabelText('Coller un lien')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Analyser le lien' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Playlist (prévu)' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Audio seul' })).toBeEnabled();
  });

  it('flags an update on the Settings button of Music', () => {
    useUpdates.setState({ phase: 'available' });
    render(<MobileShell />);
    expect(screen.getByRole('button', { name: 'Settings — Update available' })).toBeInTheDocument();
  });

  it('offers Downloads when there is no music, without jumping there', async () => {
    const user = userEvent.setup();
    const page = await backend.libraryQuery({
      search: '',
      kind: 'audio',
      sort: 'added',
      limit: 500,
    });
    for (const m of page.items) await backend.libraryRemove(m.id);
    render(<MobileShell />);
    const go = await screen.findByRole('button', { name: 'Download music' });
    expect(screen.getByRole('heading', { name: 'Music' })).toBeInTheDocument();
    await user.click(go);
    expect(screen.getByRole('heading', { name: 'Downloads' })).toBeInTheDocument();
  });

  it('continues started videos on top of Videos, with the carousel as queue', async () => {
    const user = userEvent.setup();
    const page = await backend.libraryQuery({ search: '', kind: 'video', sort: 'added' });
    const started = page.items[2]!;
    localStorage.setItem(`mm:position:${started.id}`, '30');
    render(<MobileShell />);
    await user.click(within(nav()).getByRole('button', { name: /Videos/ }));
    const section = await screen.findByRole('region', { name: 'Continue watching' });
    expect(within(section).getByText(started.title)).toBeInTheDocument();
    expect(within(section).getByText(/^0:30 \/ /)).toBeInTheDocument();
    await user.click(within(section).getByRole('button', { name: `Play ${started.title}` }));
    expect(useUi.getState().nowPlaying?.id).toBe(started.id);
    expect(useMobilePlayback.getState().source).toBe('Continue watching');
  });
});

describe('Android search (decision 0006)', () => {
  it('shows sites first and opens one in the hidden browser', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(screen.getByRole('button', { name: 'Search' }));
    const sites = screen.getByRole('list', { name: 'Sites' });
    await user.click(within(sites).getByRole('button', { name: 'YouTube' }));
    expect(screen.getByRole('navigation', { name: 'Browser' })).toBeInTheDocument();
    // Back to Miarina returns to the tab the search came from.
    await user.click(screen.getByRole('button', { name: 'Back to Miarina Media' }));
    expect(screen.getByRole('heading', { name: 'Music' })).toBeInTheDocument();
  });

  it('finds local media first, and offers YouTube and the web', async () => {
    const user = userEvent.setup();
    const page = await backend.libraryQuery({ search: '', kind: 'audio', sort: 'added' });
    const track = page.items[0]!;
    render(<MobileShell />);
    await user.click(screen.getByRole('button', { name: 'Search' }));
    await user.type(screen.getByRole('searchbox', { name: 'Music, video or link' }), track.title);
    const local = await screen.findByRole('region', { name: 'On this phone' });
    await user.click(within(local).getByRole('button', { name: `Play ${track.title}` }));
    expect(useUi.getState().nowPlaying?.id).toBe(track.id);
    expect(
      screen.getByRole('button', { name: `Search “${track.title}” on YouTube` }),
    ).toBeInTheDocument();
  });

  it('searches YouTube on Enter when nothing is on the phone', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(screen.getByRole('button', { name: 'Search' }));
    const field = screen.getByRole('searchbox', { name: 'Music, video or link' });
    await user.type(field, 'zz no such song');
    await screen.findByText('Nothing on this phone for “zz no such song”.');
    const asked: string[] = [];
    const unsub = useUi.subscribe((s) => s.browserRequest && asked.push(s.browserRequest));
    await user.type(field, '{Enter}');
    unsub();
    expect(asked).toContain('https://m.youtube.com/results?search_query=zz%20no%20such%20song');
    expect(screen.getByRole('navigation', { name: 'Browser' })).toBeInTheDocument();
  });

  it('analyzes a pasted link', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(screen.getByRole('button', { name: 'Search' }));
    await user.type(
      screen.getByRole('searchbox', { name: 'Music, video or link' }),
      'https://mango.blender.org/download/',
    );
    await user.click(screen.getByRole('button', { name: 'Analyze link' }));
    await act(async () => {});
    await waitFor(() => expect(useUi.getState().screen).toBe('analysis'));
  });
});

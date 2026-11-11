import { render, screen, waitFor, within } from '@testing-library/react';
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

describe('Android v2 Home (01)', () => {
  it('reads the French catalog and marks Playlist as planned', () => {
    useSettings.setState({ lang: 'fr' });
    render(<MobileShell />);
    expect(screen.getByLabelText('Coller un lien')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Analyser le lien' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Playlist (prévu)' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Audio seul' })).toBeEnabled();
  });

  it('opens the browser from the quick actions and flags an update on Settings', async () => {
    const user = userEvent.setup();
    useUpdates.setState({ phase: 'available' });
    render(<MobileShell />);
    expect(
      screen.getByRole('button', { name: 'Settings — Update available' }),
    ).toBeInTheDocument();
    const quick = screen
      .getAllByRole('button', { name: 'Browser' })
      .find((b) => !b.closest('nav'))!;
    await user.click(quick);
    expect(screen.getByRole('heading', { name: 'Search or open a web page' })).toBeInTheDocument();
  });

  it('continues started media first, with the carousel as queue', async () => {
    const user = userEvent.setup();
    const page = await backend.libraryQuery({ search: '', kind: 'video', sort: 'added' });
    const started = page.items[2]!;
    localStorage.setItem(`mm:position:${started.id}`, '30');
    render(<MobileShell />);
    const section = await screen.findByRole('region', { name: 'Continue watching' });
    expect(within(section).getByText(started.title)).toBeInTheDocument();
    expect(within(section).getByText(/^0:30 \/ /)).toBeInTheDocument();
    await user.click(within(section).getByRole('button', { name: `Play ${started.title}` }));
    expect(useUi.getState().nowPlaying?.id).toBe(started.id);
    expect(useMobilePlayback.getState().source).toBe('Continue watching');
  });
});

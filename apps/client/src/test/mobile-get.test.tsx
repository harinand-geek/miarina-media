import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MobileShell } from '../app/MobileShell';
import { resetMockBackend } from '../services/backend';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';

let stop: () => void = () => {};

beforeEach(async () => {
  resetMockBackend();
  useUi.setState(useUi.getInitialState(), true);
  useDownloads.setState(useDownloads.getInitialState(), true);
  useLibrary.setState(useLibrary.getInitialState(), true);
  useSettings.setState({ ...useSettings.getInitialState(), lang: 'fr' }, true);
  stop = useDownloads.getState().init();
  await waitFor(() => expect(useDownloads.getState().ready).toBe(true));
});

afterEach(() => {
  stop();
  vi.useRealTimers();
});

const nav = () => screen.getByRole('navigation', { name: 'Navigation principale' });

describe('Android v2 Downloads (04)', () => {
  it('shows three lists and states in words with an icon', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(within(nav()).getByRole('button', { name: /Téléch/ }));
    expect(screen.getByRole('heading', { name: 'Téléchargements' })).toBeInTheDocument();
    const lists = screen.getByRole('radiogroup', { name: 'Listes de téléchargements' });
    expect(within(lists).getByRole('radio', { name: /^En cours · \d+$/ })).toBeChecked();
    expect(within(lists).getByRole('radio', { name: /^Terminés · \d+$/ })).toBeInTheDocument();
    expect(within(lists).getByRole('radio', { name: /^Échecs · \d+$/ })).toBeInTheDocument();
    expect(screen.getAllByText(/^(Téléchargement|Démarrage…)$/).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('button', { name: /^Annuler / }).length).toBeGreaterThan(0);
    await user.click(within(lists).getByRole('radio', { name: /^Terminés/ }));
    expect(screen.getAllByText('Terminé').length).toBeGreaterThan(0);
  });
});

describe('Android v2 formats sheet (03)', () => {
  it('offers video and audio, plans subtitles and can queue', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const start = vi.spyOn(useDownloads.getState(), 'start');
    render(<MobileShell />);
    await user.click(within(nav()).getByRole('button', { name: /Téléch/ }));
    await user.type(screen.getByLabelText('Coller un lien'), 'https://mango.blender.org/download/');
    await user.click(screen.getByRole('button', { name: 'Analyser le lien' }));
    // While the link is read, the sheet says what happens and for how long.
    expect(screen.getByText('Préparation de votre fichier')).toBeInTheDocument();
    expect(screen.getByText('Lecture du lien sur mango.blender.org…')).toBeInTheDocument();
    expect(screen.getByText('ASTUCE')).toBeInTheDocument();
    await act(() => vi.advanceTimersByTimeAsync(1000));
    const sheet = screen.getByRole('dialog', { name: 'Analyser le lien' });
    const types = within(sheet).getByRole('radiogroup', { name: 'Type de format' });
    expect(within(types).getByRole('radio', { name: 'Vidéo' })).toBeChecked();
    expect(within(types).getByRole('radio', { name: 'Sous-titres' })).toBeDisabled();
    expect(within(sheet).getByRole('button', { name: /Télécharger · 372 MB/ })).toBeInTheDocument();
    await user.click(within(types).getByRole('radio', { name: 'Audio seul' }));
    expect(within(types).getByRole('radio', { name: 'Audio seul' })).toBeChecked();
    expect(within(sheet).getByText('Enregistrer dans')).toBeInTheDocument();
    await user.click(within(sheet).getByRole('button', { name: 'À la file' }));
    await waitFor(() =>
      expect(start).toHaveBeenCalledWith(
        expect.objectContaining({ startNow: false, kind: 'audio' }),
      ),
    );
  });
});

describe('Android v2 browser (02)', () => {
  it('speaks French and keeps the way back to Miarina', async () => {
    const user = userEvent.setup();
    render(<MobileShell />);
    await user.click(within(nav()).getByRole('button', { name: /Téléch/ }));
    await user.click(screen.getByRole('button', { name: 'Navigateur' }));
    expect(
      screen.getByRole('heading', { name: 'Rechercher ou ouvrir une page web' }),
    ).toBeInTheDocument();
    const bar = screen.getByRole('navigation', { name: 'Navigateur' });
    expect(within(bar).getByRole('button', { name: 'Favoris' })).toBeEnabled();
    await user.click(within(bar).getByRole('button', { name: 'Retour à Miarina Media' }));
    expect(nav()).toBeVisible();
  });
});

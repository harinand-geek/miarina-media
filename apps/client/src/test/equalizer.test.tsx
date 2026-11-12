import { fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { EQ_PRESETS, useEqualizer } from '../features/player/equalizer';
import { resetMockBackend } from '../services/backend';
import type { MediaRecord } from '../services/types';
import { bindEngine, resetPlayerForTests, usePlayer, type PlayerEngine } from '../stores/player';
import { useUi } from '../stores/ui';

let NowPlayingScreen: typeof import('../features/player/NowPlayingScreen').default;

beforeAll(async () => {
  NowPlayingScreen = (await import('../features/player/NowPlayingScreen')).default;
});

const song = {
  id: 3,
  title: 'Gymnopédie',
  kind: 'audio',
  path: 'C:\\M\\g.flac',
  durationSecs: 200,
} as MediaRecord;

const engine = (native: boolean): PlayerEngine => ({
  native,
  load: vi.fn(),
  play: vi.fn(),
  pause: vi.fn(),
  seek: vi.fn(),
  setVolume: vi.fn(),
  setRate: vi.fn(),
  stop: vi.fn(),
  ...(native ? { setEqualizer: vi.fn() } : {}),
});

beforeEach(() => {
  localStorage.clear();
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState({ ...useUi.getInitialState(), nowPanel: 'sound' }, true);
  useEqualizer.setState({ enabled: false, preset: 'flat', gains: [...EQ_PRESETS.flat] });
});

describe('equalizer (Windows v2 screen 6)', () => {
  it('applies presets and bands through libVLC and remembers them', async () => {
    const user = userEvent.setup();
    const native = engine(true);
    bindEngine(native);
    usePlayer.getState().playMedia(song, [song]);
    render(<NowPlayingScreen />);

    expect(screen.getByText('EQ off')).toBeInTheDocument();
    await user.click(screen.getByRole('switch', { name: 'Turn the equalizer on' }));
    expect(native.setEqualizer).toHaveBeenLastCalledWith(EQ_PRESETS.flat);

    const presets = screen.getByRole('radiogroup', { name: 'Equalizer presets' });
    await user.click(within(presets).getByRole('radio', { name: 'Rock' }));
    expect(native.setEqualizer).toHaveBeenLastCalledWith(EQ_PRESETS.rock);
    expect(screen.getByText('Equalizer · Rock')).toBeInTheDocument();

    const low = screen.getByRole('slider', { name: '60 Hz band' });
    fireEvent.change(low, { target: { value: '9' } });
    expect(useEqualizer.getState().preset).toBe('custom');
    expect(useEqualizer.getState().gains[0]).toBe(9);
    expect(native.setEqualizer).toHaveBeenLastCalledWith([9, ...EQ_PRESETS.rock.slice(1)]);
    expect(screen.getByText('Equalizer · Custom')).toBeInTheDocument();
    expect(JSON.parse(localStorage.getItem('mm:eq:v1')!)).toMatchObject({
      enabled: true,
      preset: 'custom',
    });

    await user.click(screen.getByRole('switch', { name: 'Turn the equalizer on' }));
    expect(native.setEqualizer).toHaveBeenLastCalledWith(null);
  });

  it('explains why it cannot be used with the WebView player', () => {
    bindEngine(engine(false));
    usePlayer.getState().playMedia(song, [song]);
    render(<NowPlayingScreen />);
    expect(screen.getByRole('switch', { name: 'Turn the equalizer on' })).toBeDisabled();
    expect(screen.getByText(/needs the built-in playback engine/)).toBeInTheDocument();
  });
});

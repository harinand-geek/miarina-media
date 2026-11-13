import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { fireEvent } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const native = vi.hoisted(() => ({
  on: true,
  supported: true as boolean | null,
  calls: [] as { enabled: boolean; gains: number[] }[],
}));

vi.mock('../services/nativePlayer', async (original) => {
  const real = await original<typeof import('../services/nativePlayer')>();
  return {
    ...real,
    nativePlayback: () => native.on,
    nativePlayer: {
      ...real.nativePlayer,
      equalizer: async (enabled: boolean, gains: number[]) => {
        native.calls.push({ enabled, gains: [...gains] });
        return native.supported;
      },
    },
  };
});

import { EQ_PRESETS, useEqualizer } from '../features/player/equalizer';
import { MobileEqualizer } from '../features/player/MobileEqualizer';
import { useSettings } from '../stores/settings';

beforeEach(() => {
  localStorage.clear();
  useSettings.setState(useSettings.getInitialState(), true);
  useEqualizer.setState({
    enabled: false,
    preset: 'flat',
    gains: [...EQ_PRESETS.flat],
    supported: null,
  });
  native.on = true;
  native.supported = true;
  native.calls = [];
});

describe('Android equalizer (AND-10)', () => {
  it('turns on, applies presets and bands to the playback service, and is kept', async () => {
    const user = userEvent.setup();
    render(<MobileEqualizer />);
    // Opening asks the service, which reports support.
    await waitFor(() => expect(native.calls).toHaveLength(1));
    await waitFor(() => expect(useEqualizer.getState().supported).toBe(true));

    await user.click(screen.getByRole('switch', { name: 'Turn the equalizer on' }));
    expect(native.calls.at(-1)?.enabled).toBe(true);

    const presets = screen.getByRole('radiogroup', { name: 'Equalizer presets' });
    await user.click(within(presets).getByRole('radio', { name: 'Bass' }));
    expect(native.calls.at(-1)).toEqual({ enabled: true, gains: EQ_PRESETS.bass });
    expect(within(presets).getByRole('radio', { name: 'Bass' })).toHaveAttribute(
      'aria-checked',
      'true',
    );

    fireEvent.change(screen.getByRole('slider', { name: '9k Hz band' }), {
      target: { value: '6' },
    });
    expect(native.calls.at(-1)?.gains[4]).toBe(6);
    expect(within(presets).getByRole('radio', { name: 'Custom' })).toHaveAttribute(
      'aria-checked',
      'true',
    );
    expect(JSON.parse(localStorage.getItem('mm:eq:v1')!)).toMatchObject({
      enabled: true,
      preset: 'custom',
    });

    await user.click(screen.getByRole('button', { name: 'Reset' }));
    expect(native.calls.at(-1)).toEqual({ enabled: true, gains: EQ_PRESETS.flat });
  });

  it('explains when the device has no equalizer', async () => {
    native.supported = false;
    render(<MobileEqualizer />);
    expect(await screen.findByText(/This device offers no equalizer/)).toBeInTheDocument();
    expect(screen.queryByRole('switch')).toBeNull();
  });

  it('uses French band labels with a decimal comma', async () => {
    act(() => useSettings.setState({ lang: 'fr' }));
    render(<MobileEqualizer />);
    expect(await screen.findByRole('slider', { name: 'Bande 3,6k Hz' })).toBeDisabled();
  });
});

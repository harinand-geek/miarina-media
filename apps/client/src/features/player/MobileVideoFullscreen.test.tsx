import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const native = vi.hoisted(() => ({
  fullscreen: vi.fn(() => Promise.resolve()),
  tracks: vi.fn(() =>
    Promise.resolve({
      audio: [
        { id: '1:0', label: 'Français', language: 'fr', codec: 'AAC 2.0', selected: true },
        { id: '1:1', label: 'English', language: 'en', codec: 'AAC 2.0', selected: false },
      ],
      text: [{ id: '2:0', label: null, language: 'fr', codec: 'SRT', selected: false }],
      textOff: true,
      video: 'H.264 1080p',
      sound: 'AAC 2.0',
    }),
  ),
  selectTrack: vi.fn(() => Promise.resolve()),
  pickSubtitle: vi.fn(() => Promise.resolve({ added: false })),
  level: vi.fn(() => Promise.resolve(0.5)),
  pip: vi.fn((enter: boolean) => Promise.resolve(!enter)),
  onPip: vi.fn(() => Promise.resolve({ unregister: () => Promise.resolve() })),
}));
vi.mock('../../services/nativePlayer', () => ({
  nativePlayer: native,
  nativePlayback: () => true,
}));

import { MobileVideoFullscreen } from './MobileVideoFullscreen';
import type { MediaRecord } from '../../services/types';

const item = {
  id: 7,
  title: 'mkv multipistes',
  kind: 'video',
  path: 'C:/v/mkv multipistes.mkv',
  container: 'mkv',
} as unknown as MediaRecord;

function controls() {
  return { time: 30, duration: 600, playing: true, rate: 1, toggle: vi.fn(), seek: vi.fn() };
}

beforeEach(() => {
  vi.clearAllMocks();
});
afterEach(() => {
  vi.useRealTimers();
});

describe('Android fullscreen video (screen 13)', () => {
  it('goes native fullscreen with a transparent page, and back on exit', async () => {
    const view = render(<MobileVideoFullscreen item={item} p={controls()} onExit={() => {}} />);
    expect(native.fullscreen).toHaveBeenCalledWith(true, true);
    expect(document.documentElement.dataset.videoFullscreen).toBe('');
    expect(
      await screen.findByText(
        /H\.264 1080p · AAC 2\.0 · 2 pistes|H\.264 1080p · AAC 2\.0 · 2 tracks/,
      ),
    ).toBeInTheDocument();
    view.unmount();
    expect(document.documentElement.dataset.videoFullscreen).toBeUndefined();
    expect(native.fullscreen).toHaveBeenLastCalledWith(false);
  });

  it('rotates between landscape and portrait', async () => {
    render(<MobileVideoFullscreen item={item} p={controls()} onExit={() => {}} />);
    fireEvent.click(screen.getByRole('button', { name: /Pivoter|Rotate/ }));
    expect(native.fullscreen).toHaveBeenLastCalledWith(true, false);
  });

  it('seeks ±10 s with a double tap and hides the controls with a single tap', () => {
    const p = controls();
    render(<MobileVideoFullscreen item={item} p={p} onExit={() => {}} />);
    const layer = screen.getByTestId('video-fullscreen').firstElementChild as HTMLElement;
    vi.spyOn(layer, 'getBoundingClientRect').mockReturnValue({
      left: 0,
      top: 0,
      width: 800,
      height: 400,
    } as DOMRect);
    const tap = (x: number) => {
      fireEvent.pointerDown(layer, { clientX: x, clientY: 200 });
      fireEvent.pointerUp(layer, { clientX: x, clientY: 200 });
    };
    const exit = () =>
      screen.queryByRole('button', { name: /Quitter le plein écran|Exit fullscreen/ });
    vi.useFakeTimers({ toFake: ['Date'] });
    tap(700);
    tap(700);
    expect(p.seek).toHaveBeenCalledWith(40);
    // The first tap of the pair hid the controls; a later single tap shows them.
    expect(exit()).toBeNull();
    vi.setSystemTime(Date.now() + 1000);
    tap(100);
    expect(exit()).not.toBeNull();
  });

  it('locks the controls behind a single button', () => {
    render(<MobileVideoFullscreen item={item} p={controls()} onExit={() => {}} />);
    fireEvent.click(
      screen.getByRole('button', { name: /Verrouiller les commandes|Lock the controls/ }),
    );
    expect(screen.queryByRole('button', { name: /Pivoter|Rotate/ })).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: /Déverrouiller|Unlock/ }));
    expect(screen.getByRole('button', { name: /Pivoter|Rotate/ })).toBeInTheDocument();
  });

  it('lists the real tracks and switches them', async () => {
    render(<MobileVideoFullscreen item={item} p={controls()} onExit={() => {}} />);
    await act(async () => {});
    fireEvent.click(screen.getByRole('button', { name: /^(Pistes|Tracks)/, expanded: false }));
    const panel = screen.getByRole('complementary');
    fireEvent.click(within(panel).getByRole('button', { name: /English/ }));
    expect(native.selectTrack).toHaveBeenCalledWith('audio', '1:1');
    fireEvent.click(within(panel).getByRole('button', { name: /^(fr|FR)/ }));
    expect(native.selectTrack).toHaveBeenCalledWith('text', '2:0');
    expect(within(panel).getByRole('button', { name: /SRT \/ VTT/ })).toBeInTheDocument();
  });
});

import { act, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { PlayerHost } from '../features/player/PlayerHost';
import { createNativeEngine, reportOf } from '../features/player/nativeEngine';
import { backend, resetMockBackend } from '../services/backend';
import type {
  MediaRecord,
  NativePlayerStateEvent,
  NativePlayerTracksEvent,
} from '../services/types';
import { bindEngine, resetPlayerForTests, usePlayer, type PlayerEngine } from '../stores/player';
import { useUi } from '../stores/ui';

let PlayerScreen: typeof import('../features/player/PlayerScreen').default;

beforeAll(async () => {
  PlayerScreen = (await import('../features/player/PlayerScreen')).default;
});

beforeEach(() => {
  resetMockBackend();
  resetPlayerForTests();
  useUi.setState(useUi.getInitialState(), true);
});

const video = {
  id: 7,
  title: 'Sintel',
  kind: 'video',
  path: 'C:\\Videos\\Sintel.mkv',
  durationSecs: 888,
} as MediaRecord;

const event = (patch: Partial<NativePlayerStateEvent>): NativePlayerStateEvent => ({
  instance: 1,
  state: 'playing',
  position: 3,
  duration: 888,
  error: null,
  ...patch,
});

describe('native engine reports (WIN-02)', () => {
  it('maps libVLC states, telling unreadable files from formats', () => {
    expect(reportOf(event({ state: 'loading' }))?.state).toBe('buffering');
    expect(reportOf(event({}))).toEqual({
      position: 3,
      duration: 888,
      state: 'playing',
      error: null,
    });
    expect(reportOf(event({ state: 'error', error: 'read' }))).toEqual({
      state: 'error',
      error: { kind: 'read' },
    });
    expect(reportOf(event({ state: 'error', error: 'unsupported' }))?.error).toEqual({
      kind: 'unsupported',
    });
    expect(reportOf(event({ state: 'idle' }))).toBeNull();
  });

  it('keeps events of the current file only and lists real tracks', () => {
    let onState: (e: NativePlayerStateEvent) => void = () => {};
    let onTracks: (e: NativePlayerTracksEvent) => void = () => {};
    vi.spyOn(backend, 'onNativePlayerState').mockImplementation((cb) => {
      onState = cb;
      return () => {};
    });
    vi.spyOn(backend, 'onNativePlayerTracks').mockImplementation((cb) => {
      onTracks = cb;
      return () => {};
    });
    const open = vi.spyOn(backend, 'nativePlayerOpen');
    const native = createNativeEngine();
    bindEngine(native.engine);
    expect(usePlayer.getState().nativeVideo).toBe(true);

    usePlayer.getState().playMedia(video, [video]);
    const instance = usePlayer.getState().instance;
    expect(open).toHaveBeenCalledWith(7, 0, true, instance);

    act(() => onState(event({ instance: instance - 1, position: 99 })));
    expect(usePlayer.getState().position).toBe(0);
    act(() => onState(event({ instance, position: 12 })));
    expect(usePlayer.getState()).toMatchObject({ state: 'playing', position: 12 });

    act(() =>
      onTracks({
        instance,
        audio: [
          { id: -1, name: 'Disable' },
          { id: 1, name: 'Français - [French]' },
        ],
        subtitles: [
          { id: -1, name: 'Disable' },
          { id: 3, name: 'Track 1 - [French]' },
        ],
        audioId: 1,
        subtitleId: -1,
        subtitleDelay: 0,
      }),
    );
    expect(usePlayer.getState().tracks?.audio).toEqual([{ id: 1, name: 'Français - [French]' }]);
    expect(usePlayer.getState().tracks?.subtitles).toHaveLength(1);
    native.dispose();
  });
});

describe('tracks panel (WIN-05, WIN-06)', () => {
  it('changes audio track, subtitles and delay through the engine', async () => {
    const user = userEvent.setup();
    const engine: PlayerEngine = {
      native: true,
      load: vi.fn(),
      play: vi.fn(),
      pause: vi.fn(),
      seek: vi.fn(),
      setVolume: vi.fn(),
      setRate: vi.fn(),
      stop: vi.fn(),
      setAudioTrack: vi.fn(),
      setSubtitle: vi.fn(),
      addSubtitle: vi.fn(async () => true),
      setSubtitleDelay: vi.fn(),
    };
    bindEngine(engine);
    usePlayer.getState().playMedia(video, [video]);
    usePlayer.setState({
      state: 'playing',
      tracks: {
        audio: [
          { id: 1, name: 'Français - [French]' },
          { id: 2, name: 'English - [English]' },
        ],
        subtitles: [{ id: 3, name: 'Track 1 - [French]' }],
        audioId: 1,
        subtitleId: 3,
        subtitleDelay: 0,
      },
    });
    render(<PlayerScreen />);

    // The title sits above the native picture, not over it.
    expect(screen.getAllByText('Sintel')[0]).toBeVisible();
    await user.click(screen.getByRole('button', { name: 'Audio tracks and subtitles' }));
    const panel = screen.getByRole('region', { name: 'Tracks' });
    const audio = within(panel).getByRole('radiogroup', { name: 'Audio' });
    expect(within(audio).getByRole('radio', { name: 'Français - [French]' })).toHaveAttribute(
      'aria-checked',
      'true',
    );
    await user.click(within(audio).getByRole('radio', { name: 'English - [English]' }));
    expect(engine.setAudioTrack).toHaveBeenCalledWith(2);

    const subs = within(panel).getByRole('radiogroup', { name: 'Subtitles' });
    await user.click(within(subs).getByRole('radio', { name: 'Off' }));
    expect(engine.setSubtitle).toHaveBeenCalledWith(-1);

    expect(within(panel).getByRole('button', { name: 'Reset the delay' })).toBeDisabled();
    await user.click(within(panel).getByRole('button', { name: /Subtitles later/ }));
    await user.click(within(panel).getByRole('button', { name: /Subtitles later/ }));
    expect(engine.setSubtitleDelay).toHaveBeenLastCalledWith(200);
    expect(within(panel).getByText('+0.2 s')).toBeInTheDocument();

    await user.click(within(panel).getByRole('button', { name: 'Add a subtitle file…' }));
    expect(engine.addSubtitle).toHaveBeenCalled();
    expect(useUi.getState().toasts.at(-1)?.message).toBe('Subtitles added');
  });

  it('says why tracks are not offered with the WebView engine', () => {
    usePlayer.getState().playMedia(video, [video]);
    render(<PlayerScreen />);
    expect(
      screen.getByRole('button', {
        name: 'Audio tracks and subtitles: built-in video engine unavailable',
      }),
    ).toBeDisabled();
  });
});

it('hides native video while search results are open and restores it on close', () => {
  const frame = vi.spyOn(backend, 'nativePlayerFrame').mockResolvedValue(undefined);
  const surface = document.createElement('div');
  vi.spyOn(surface, 'getBoundingClientRect').mockReturnValue({
    left: 0,
    top: 40,
    width: 800,
    height: 450,
  } as DOMRect);
  usePlayer.setState({ media: video, nativeVideo: true, surface, state: 'playing' });
  const { unmount } = render(<PlayerHost />);
  act(() => usePlayer.setState({ nativeVideo: true }));
  expect(frame).toHaveBeenLastCalledWith({ x: 0, y: 40, width: 800, height: 450 }, true);
  act(() => useUi.setState({ searchOpen: true }));
  expect(frame).toHaveBeenLastCalledWith({ x: 0, y: 0, width: 0, height: 0 }, false);
  expect(usePlayer.getState().state).toBe('playing');
  act(() => useUi.setState({ searchOpen: false }));
  expect(frame).toHaveBeenLastCalledWith({ x: 0, y: 40, width: 800, height: 450 }, true);
  unmount();
});

it('hides fullscreen chrome after inactivity and restores it on native mouse motion', () => {
  vi.useFakeTimers();
  let notify: (kind: 'click' | 'dblclick' | 'move') => void = () => {};
  vi.spyOn(backend, 'onNativePlayerClick').mockImplementation((cb) => {
    notify = cb;
    return () => {};
  });
  usePlayer.setState({
    media: video,
    queue: [video],
    index: 0,
    nativeVideo: true,
    state: 'playing',
  });
  useUi.setState({ playerFullscreen: true });
  const { unmount } = render(<PlayerScreen />);
  const slider = screen.getByRole('slider', { name: 'Playback position' });
  expect(slider).toBeVisible();
  act(() => vi.advanceTimersByTime(2600));
  expect(slider).not.toBeVisible();
  act(() => notify('move'));
  expect(slider).toBeVisible();
  unmount();
  vi.useRealTimers();
});

import { invoke } from '@tauri-apps/api/core';
import { detectPlatform, inTauri } from './platform';

/**
 * Android only: Media3 playback (`NativePlayerPlugin.kt`), driven by the
 * React player screen. The WebView cannot stream local files on Android.
 */
export const nativePlayback = (): boolean => inTauri() && detectPlatform() === 'android';

/** `player::PlayerStatus` (Rust). */
export interface NativePlayerStatus {
  open: boolean;
  positionMs: number;
  /** -1 while unknown. */
  durationMs: number;
  bufferedMs: number;
  playing: boolean;
  ended: boolean;
  rate: number;
  error?: string | null;
  /** Queue position and library id of the current item. */
  index?: number | null;
  mediaId?: number | null;
}

export interface SurfaceRect {
  x: number;
  y: number;
  width: number;
  height: number;
  visible: boolean;
}

export const nativePlayer = {
  /**
   * Opens a play queue (library ids) at `index`; resolves `true` when that
   * item is a video. The native service then moves through the queue itself.
   */
  open: (ids: number[], index: number, positionSecs: number) =>
    invoke<boolean>('player_open', { ids, index, positionSecs }),
  /** Reorders the queue around the current item without interrupting it. */
  setQueue: (ids: number[], currentIndex: number) =>
    invoke<void>('player_queue', { ids, currentIndex }),
  skip: (index: number) => invoke<void>('player_skip', { index }),
  setRepeat: (mode: 'off' | 'all' | 'one') => invoke<void>('player_repeat', { mode }),
  status: () => invoke<NativePlayerStatus>('player_status'),
  play: () => invoke<void>('player_play'),
  pause: () => invoke<void>('player_pause'),
  seek: (positionSecs: number) => invoke<void>('player_seek', { positionSecs }),
  setRate: (rate: number) => invoke<void>('player_rate', { rate }),
  setSurface: (rect: SurfaceRect) => invoke<void>('player_surface', { rect }),
  close: () => invoke<NativePlayerStatus>('player_close'),
};

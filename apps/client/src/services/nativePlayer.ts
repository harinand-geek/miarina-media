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
}

export interface SurfaceRect {
  x: number;
  y: number;
  width: number;
  height: number;
  visible: boolean;
}

export const nativePlayer = {
  /** Opens a library entry by id; resolves `true` for video. */
  open: (id: number, positionSecs: number) => invoke<boolean>('player_open', { id, positionSecs }),
  status: () => invoke<NativePlayerStatus>('player_status'),
  play: () => invoke<void>('player_play'),
  pause: () => invoke<void>('player_pause'),
  seek: (positionSecs: number) => invoke<void>('player_seek', { positionSecs }),
  setRate: (rate: number) => invoke<void>('player_rate', { rate }),
  setSurface: (rect: SurfaceRect) => invoke<void>('player_surface', { rect }),
  close: () => invoke<NativePlayerStatus>('player_close'),
};

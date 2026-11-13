import { addPluginListener, invoke, type PluginListener } from '@tauri-apps/api/core';
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

/** AND-13: a track of the current file (`id` = "group:track"). */
export interface NativeTrack {
  id: string;
  label: string | null;
  language: string | null;
  codec: string | null;
  selected: boolean;
}

export interface NativeTracks {
  audio: NativeTrack[];
  text: NativeTrack[];
  textOff: boolean;
  /** e.g. "H.264 1080p" */
  video: string | null;
  /** e.g. "AAC 2.0" */
  sound: string | null;
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
  /** AND-07: immersive fullscreen (landscape unless `landscape` is false). */
  fullscreen: (on: boolean, landscape = true) =>
    invoke<void>('player_fullscreen', { on, landscape }),
  tracks: () => invoke<NativeTracks>('player_tracks'),
  /** `id: null` turns subtitles off. */
  selectTrack: (kind: 'audio' | 'text', id: string | null) =>
    invoke<void>('player_select_track', { kind, id }),
  /** System file picker; `added: false` when canceled. */
  pickSubtitle: () => invoke<{ added: boolean; name?: string }>('player_pick_subtitle'),
  /** Brightness (this window) or media volume, 0..1; no value reads it. */
  level: (kind: 'brightness' | 'volume', value?: number) =>
    invoke<number>('player_level', { kind, value: value ?? null }),
  /** AND-08: enters picture-in-picture (`enter`) or asks if it is supported. */
  pip: (enter: boolean) => invoke<boolean>('player_pip', { enter }),
  /** Picture-in-picture entered / left. */
  onPip: (handler: (active: boolean) => void): Promise<PluginListener> =>
    addPluginListener<{ active: boolean }>('native-player', 'pip', (e) => handler(e.active)),
};

import { invoke } from '@tauri-apps/api/core';
import { createTorrentsMock } from '../dev/torrentsMock';
import { inTauri } from './platform';

export interface TorrentPreview {
  hash: string;
  name: string;
  files: { index: number; path: string; size: number }[];
}
export interface TorrentRow {
  hash: string;
  name: string;
  folder: string;
  phase: string;
  done: number;
  total: number;
  uploaded: number;
  downSpeed: number;
  upSpeed: number;
  peers: number;
}
export interface TorrentSnapshot {
  enabled: boolean;
  rows: TorrentRow[];
  downloadLimit: number;
  uploadLimit: number;
}
const native = {
  list: () => invoke<TorrentSnapshot>('torrents_list'),
  enable: () => invoke<void>('torrents_enable'),
  disable: () => invoke<void>('torrents_disable'),
  preview: (magnet: string | null) => invoke<TorrentPreview | null>('torrents_preview', { magnet }),
  start: (hash: string, files: number[], sequential: boolean) =>
    invoke<void>('torrents_start', { hash, files, sequential }),
  action: (hash: string, action: 'pause' | 'resume' | 'remove' | 'reveal') =>
    invoke<void>('torrents_action', { hash, action }),
  limits: (download: number, upload: number) =>
    invoke<void>('torrents_limits', { download, upload }),
};

/** Tauri commands; sample data in the browser preview (development only). */
export const torrents: typeof native =
  !inTauri() && import.meta.env.DEV && import.meta.env.MODE !== 'test'
    ? createTorrentsMock()
    : native;

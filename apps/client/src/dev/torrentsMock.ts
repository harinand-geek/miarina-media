import type { TorrentPreview, TorrentSnapshot } from '../services/torrents';

const MB = 1024 * 1024;

/** Browser preview only (no Tauri): sample torrents to review the screen. */
export function createTorrentsMock() {
  let snapshot: TorrentSnapshot = {
    enabled: true,
    downloadLimit: 0,
    uploadLimit: 512 * 1024,
    rows: [
      {
        hash: 'p1',
        name: 'Blender Open Movies — collection',
        folder: 'Blender Open Movies',
        phase: 'downloading',
        done: 1490 * MB,
        total: 3174 * MB,
        uploaded: 120 * MB,
        downSpeed: 4.2 * MB,
        upSpeed: 310 * 1024,
        peers: 18,
      },
      {
        hash: 'p2',
        name: 'Sintel 4K — source files',
        folder: 'Sintel',
        phase: 'finished',
        done: 5837 * MB,
        total: 5837 * MB,
        uploaded: 4670 * MB,
        downSpeed: 0,
        upSpeed: 1.2 * MB,
        peers: 6,
      },
    ],
  };
  const preview: TorrentPreview = {
    hash: 'p3',
    name: 'Creative Commons music sampler',
    files: [
      { index: 0, path: 'sampler/01 - Opening.flac', size: 31 * MB },
      { index: 1, path: 'sampler/02 - Morning.flac', size: 28 * MB },
      { index: 2, path: 'sampler/cover.jpg', size: 2 * MB },
    ],
  };
  return {
    list: async () => snapshot,
    enable: async () => {
      snapshot = { ...snapshot, enabled: true };
    },
    disable: async () => {
      snapshot = { ...snapshot, enabled: false };
    },
    preview: async () => preview,
    start: async () => {},
    action: async (hash: string, action: 'pause' | 'resume' | 'remove' | 'reveal') => {
      if (action === 'reveal') return;
      snapshot = {
        ...snapshot,
        rows:
          action === 'remove'
            ? snapshot.rows.filter((r) => r.hash !== hash)
            : snapshot.rows.map((r) =>
                r.hash === hash
                  ? { ...r, phase: action === 'pause' ? 'paused' : 'downloading' }
                  : r,
              ),
      };
    },
    limits: async (download: number, upload: number) => {
      snapshot = { ...snapshot, downloadLimit: download, uploadLimit: upload };
    },
  };
}

// Development fixtures copied from the Claude Design prototypes. They back
// the mock backend (browser preview and tests) and the library screens until
// the media library lands in Phase 3. Never used by the Tauri backend.

import type { HistoryEntry, LibraryItem, MediaInfo, MediaKind, TaskState } from '../services/types';

const lib = (
  id: string,
  title: string,
  source: string,
  kind: LibraryItem['kind'],
  duration: string,
  size: string,
  quality: string,
  addedAgo?: string,
): LibraryItem => {
  const parts = duration.split(':').map(Number);
  const durationSec = parts.reduce((acc, n) => acc * 60 + n, 0);
  return { id, title, source, kind, duration, durationSec, size, quality, addedAgo };
};

export const LIBRARY: LibraryItem[] = [
  lib('l1', 'Big Buck Bunny', 'Blender Foundation', 'video', '9:56', '356 MB', '1080p', '2 h ago'),
  lib('l2', 'Sintel', 'Blender Foundation', 'video', '14:48', '612 MB', '1080p', 'Yesterday'),
  lib(
    'l3',
    'Voyager Golden Record — Sounds of Earth',
    'NASA',
    'audio',
    '12:30',
    '28 MB',
    'MP3 320',
    'Yesterday',
  ),
  lib('l4', 'Artemis I Launch Highlights', 'NASA', 'video', '4:32', '188 MB', '1080p', 'Oct 10'),
  lib('l5', 'Cosmos Laundromat', 'Blender Studio', 'video', '12:10', '540 MB', '1080p'),
  lib('l6', 'Spring', 'Blender Studio', 'video', '7:44', '402 MB', '1440p'),
  lib(
    'l7',
    'Night of the Living Dead (1968)',
    'Internet Archive',
    'video',
    '1:35:44',
    '1.4 GB',
    '720p',
  ),
  lib('l8', 'Gymnopédie No. 1 — Satie', 'Musopen', 'audio', '3:24', '31 MB', 'FLAC'),
  lib(
    'l9',
    'Agent 327: Operation Barbershop',
    'Blender Studio',
    'video',
    '3:51',
    '210 MB',
    '1080p',
  ),
  lib('l10', 'Clair de Lune — Debussy', 'Musopen', 'audio', '5:02', '46 MB', 'FLAC'),
  lib('l11', 'Elephants Dream', 'Blender Foundation', 'video', '10:53', '318 MB', '1080p'),
  lib('l12', 'Hubble: 30 Years in Orbit', 'NASA', 'video', '6:18', '264 MB', '4K'),
];

export const LIBRARY_STATS = {
  items: 214,
  totalSize: '42.5 GB',
  video: { count: 186, size: '41.6 GB', share: 16.3 },
  audio: { count: 28, size: '0.9 GB', share: 0.4 },
  otherShare: 38,
  drive: 'Drive C: 140 GB free of 256 GB',
};

export const ANALYZED: Omit<MediaInfo, 'url' | 'host'> = {
  engine: 'ytdlp',
  title: 'Tears of Steel',
  subtitle: 'Blender Open Movie · 5 video, 4 audio, 3 subtitle tracks found',
  publisher: 'Blender Foundation',
  duration: '12:14',
  released: '26 Sep 2012',
  license: 'CC BY 3.0',
  formats: {
    video: [
      {
        id: '2160',
        quality: '2160p · 4K',
        detail: 'WebM · VP9 · 24 fps',
        size: '1.12 GB',
        extension: 'webm',
        tag: 'Best quality',
      },
      {
        id: '1440',
        quality: '1440p',
        detail: 'WebM · VP9 · 24 fps',
        size: '684 MB',
        extension: 'webm',
      },
      {
        id: '1080',
        quality: '1080p',
        detail: 'MP4 · H.264 · 24 fps',
        size: '372 MB',
        extension: 'mp4',
        tag: 'Recommended',
      },
      {
        id: '720',
        quality: '720p',
        detail: 'MP4 · H.264 · 24 fps',
        size: '198 MB',
        extension: 'mp4',
      },
      {
        id: '480',
        quality: '480p',
        detail: 'MP4 · H.264 · 24 fps',
        size: '96 MB',
        extension: 'mp4',
      },
    ],
    audio: [
      {
        id: 'flac',
        quality: 'FLAC',
        detail: 'Lossless · 48 kHz · stereo',
        size: '92 MB',
        extension: 'flac',
      },
      {
        id: 'mp3',
        quality: 'MP3 · 320 kbps',
        detail: 'Converted · 44.1 kHz',
        size: '29 MB',
        extension: 'mp3',
        tag: 'Recommended',
      },
      {
        id: 'm4a',
        quality: 'M4A · 256 kbps',
        detail: 'AAC · original track',
        size: '23 MB',
        extension: 'm4a',
      },
      {
        id: 'opus',
        quality: 'Opus · 160 kbps',
        detail: 'Original track',
        size: '14 MB',
        extension: 'opus',
      },
    ],
    subtitles: [
      { id: 'en', quality: 'English', detail: 'SRT · original', size: '18 KB', extension: 'srt' },
      { id: 'fr', quality: 'Français', detail: 'SRT · community', size: '19 KB', extension: 'srt' },
      { id: 'es', quality: 'Español', detail: 'SRT · community', size: '19 KB', extension: 'srt' },
    ],
  },
};

/** Hosts the mock backend reports as "No downloadable media found". */
export const NO_MEDIA_HOSTS = ['nasa.gov'];

/** Compact seeds turned into TaskRecords by the mock backend. */
export interface TaskSeed {
  id: string;
  title: string;
  host: string;
  kind: MediaKind;
  format: string;
  mb: number;
  percent: number;
  /** Simulated throughput in MB/s. */
  speed: number;
  state: TaskState;
}

export const DOWNLOADS: TaskSeed[] = [
  {
    id: 'd1',
    title: 'Tears of Steel',
    host: 'mango.blender.org',
    kind: 'video',
    format: 'MP4 · 2160p',
    mb: 1150,
    percent: 62,
    speed: 10.3,
    state: 'downloading',
  },
  {
    id: 'd2',
    title: 'Charge',
    host: 'studio.blender.org',
    kind: 'video',
    format: 'MP4 · 1080p',
    mb: 230,
    percent: 28,
    speed: 3.2,
    state: 'downloading',
  },
  {
    id: 'd3',
    title: 'Apollo 11 Mission Audio — Day 1',
    host: 'archive.org',
    kind: 'audio',
    format: 'MP3 · 320 kbps',
    mb: 84,
    percent: 41,
    speed: 1.7,
    state: 'paused',
  },
  {
    id: 'q1',
    title: 'Spring',
    host: 'studio.blender.org',
    kind: 'video',
    format: 'MP4 · 1440p',
    mb: 402,
    percent: 0,
    speed: 6,
    state: 'queued',
  },
  {
    id: 'q2',
    title: 'Elephants Dream',
    host: 'orange.blender.org',
    kind: 'video',
    format: 'MP4 · 1080p',
    mb: 318,
    percent: 0,
    speed: 5,
    state: 'queued',
  },
  {
    id: 'q3',
    title: 'Clair de Lune — Debussy',
    host: 'musopen.org',
    kind: 'audio',
    format: 'FLAC',
    mb: 46,
    percent: 0,
    speed: 2,
    state: 'queued',
  },
];

const MIN = 60_000;
const MB = 1024 * 1024;

const at = (daysAgo: number, hh: number, mm: number) => {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  d.setHours(hh, mm, 0, 0);
  return d.getTime();
};

const entry = (
  id: number,
  finishedAt: number,
  title: string,
  sourceHost: string,
  formatLabel: string,
  totalMb: number | null,
  doneMb: number,
  status: HistoryEntry['status'],
  reason: string | null = null,
): HistoryEntry => ({
  id,
  taskId: `h${id}`,
  url: `https://${sourceHost}/`,
  title,
  sourceHost,
  formatLabel,
  totalBytes: totalMb === null ? null : totalMb * MB,
  doneBytes: doneMb * MB,
  status,
  reason,
  finalPath: null,
  finishedAt,
});

export const HISTORY: HistoryEntry[] = [
  entry(
    7,
    Date.now() - 20 * MIN,
    'Big Buck Bunny',
    'peach.blender.org',
    'MP4 · 1080p',
    356,
    356,
    'completed',
  ),
  entry(
    6,
    Date.now() - 95 * MIN,
    'Live stream — Mission Control',
    'nasa.gov',
    '—',
    null,
    0,
    'failed',
    'Live streams are not supported',
  ),
  entry(
    5,
    Date.now() - 300 * MIN,
    'Gymnopédie No. 1 — Satie',
    'musopen.org',
    'FLAC',
    31,
    31,
    'completed',
  ),
  entry(4, at(1, 21, 10), 'Sintel', 'durian.blender.org', 'MP4 · 1080p', 612, 612, 'completed'),
  entry(
    3,
    at(1, 20, 52),
    'Elephants Dream (2160p)',
    'orange.blender.org',
    'WebM · 2160p',
    1331,
    402,
    'canceled',
  ),
  entry(
    2,
    at(1, 18, 30),
    'Voyager Golden Record — Sounds of Earth',
    'archive.org',
    'MP3 · 320 kbps',
    28,
    28,
    'completed',
  ),
  entry(
    1,
    at(3, 16, 2),
    'Artemis I Launch Highlights',
    'nasa.gov',
    'MP4 · 1080p',
    188,
    188,
    'completed',
  ),
];

export const STORAGE = {
  drive: 'Drive C:',
  used: '116 GB used of 256 GB',
  libraryShare: 16.6,
  otherShare: 28.7,
  library: 'Miarina library 42.5 GB',
  other: 'Other 73.5 GB',
  thumbnailCache: '412 MB',
  tempFiles: '1.2 GB from unfinished downloads',
  libraryPath: 'C:\\Users\\Rina\\Videos\\Miarina',
};

export const ANDROID_STORES = [
  {
    id: 'int',
    icon: 'smartphone',
    label: 'Internal storage',
    path: '/Download/Miarina',
    used: 71,
    free: '36.8 GB free of 128 GB',
  },
  {
    id: 'sd',
    icon: 'sd_card',
    label: 'SD card',
    path: '/SD/Miarina',
    used: 22,
    free: '49.6 GB free of 64 GB',
  },
] as const;

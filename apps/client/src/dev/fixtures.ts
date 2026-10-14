// Development fixtures copied from the Claude Design prototypes.
// Phase 1 only: they back the mock backend and must not reach production
// flows once the Rust backend lands (Phase 2).

import type {
  DownloadTask,
  HistoryGroup,
  LibraryItem,
  MediaInfo,
  QueueItem,
} from '../services/types';

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
        tag: 'Best quality',
      },
      { id: '1440', quality: '1440p', detail: 'WebM · VP9 · 24 fps', size: '684 MB' },
      {
        id: '1080',
        quality: '1080p',
        detail: 'MP4 · H.264 · 24 fps',
        size: '372 MB',
        tag: 'Recommended',
      },
      { id: '720', quality: '720p', detail: 'MP4 · H.264 · 24 fps', size: '198 MB' },
      { id: '480', quality: '480p', detail: 'MP4 · H.264 · 24 fps', size: '96 MB' },
    ],
    audio: [
      { id: 'flac', quality: 'FLAC', detail: 'Lossless · 48 kHz · stereo', size: '92 MB' },
      {
        id: 'mp3',
        quality: 'MP3 · 320 kbps',
        detail: 'Converted · 44.1 kHz',
        size: '29 MB',
        tag: 'Recommended',
      },
      { id: 'm4a', quality: 'M4A · 256 kbps', detail: 'AAC · original track', size: '23 MB' },
      { id: 'opus', quality: 'Opus · 160 kbps', detail: 'Original track', size: '14 MB' },
    ],
    subtitles: [
      { id: 'en', quality: 'English', detail: 'SRT · original', size: '18 KB' },
      { id: 'fr', quality: 'Français', detail: 'SRT · community', size: '19 KB' },
      { id: 'es', quality: 'Español', detail: 'SRT · community', size: '19 KB' },
    ],
  },
};

/** Hosts the mock backend reports as "No downloadable media found". */
export const NO_MEDIA_HOSTS = ['nasa.gov'];

export const DOWNLOADS: DownloadTask[] = [
  {
    id: 'd1',
    title: 'Tears of Steel',
    source: 'mango.blender.org',
    kind: 'video',
    format: 'MP4 · 2160p',
    totalMb: 1150,
    percent: 62,
    rate: 0.9,
    status: 'downloading',
  },
  {
    id: 'd2',
    title: 'Charge',
    source: 'studio.blender.org',
    kind: 'video',
    format: 'MP4 · 1080p',
    totalMb: 230,
    percent: 28,
    rate: 1.4,
    status: 'downloading',
  },
  {
    id: 'd3',
    title: 'Apollo 11 Mission Audio — Day 1',
    source: 'archive.org',
    kind: 'audio',
    format: 'MP3 · 320 kbps',
    totalMb: 84,
    percent: 41,
    rate: 2,
    status: 'paused',
  },
];

export const QUEUE: QueueItem[] = [
  { id: 'q1', title: 'Spring', kind: 'video', format: 'MP4 · 1440p', size: '402 MB' },
  { id: 'q2', title: 'Elephants Dream', kind: 'video', format: 'MP4 · 1080p', size: '318 MB' },
  { id: 'q3', title: 'Clair de Lune — Debussy', kind: 'audio', format: 'FLAC', size: '46 MB' },
];

export const HISTORY: HistoryGroup[] = [
  {
    day: 'Today',
    entries: [
      {
        id: 'h1',
        time: '14:22',
        title: 'Big Buck Bunny',
        source: 'peach.blender.org',
        format: 'MP4 · 1080p',
        size: '356 MB',
        status: 'Completed',
      },
      {
        id: 'h2',
        time: '13:05',
        title: 'Live stream — Mission Control',
        source: 'nasa.gov',
        format: '—',
        size: '—',
        status: 'Failed',
        reason: 'Live streams are not supported',
      },
      {
        id: 'h3',
        time: '09:41',
        title: 'Gymnopédie No. 1 — Satie',
        source: 'musopen.org',
        format: 'FLAC',
        size: '31 MB',
        status: 'Completed',
      },
    ],
  },
  {
    day: 'Yesterday',
    entries: [
      {
        id: 'h4',
        time: '21:10',
        title: 'Sintel',
        source: 'durian.blender.org',
        format: 'MP4 · 1080p',
        size: '612 MB',
        status: 'Completed',
      },
      {
        id: 'h5',
        time: '20:52',
        title: 'Elephants Dream (2160p)',
        source: 'orange.blender.org',
        format: 'WebM · 2160p',
        size: '402 MB of 1.3 GB',
        status: 'Cancelled',
      },
      {
        id: 'h6',
        time: '18:30',
        title: 'Voyager Golden Record — Sounds of Earth',
        source: 'archive.org',
        format: 'MP3 · 320 kbps',
        size: '28 MB',
        status: 'Completed',
      },
    ],
  },
  {
    day: 'Saturday, 10 October',
    entries: [
      {
        id: 'h7',
        time: '16:02',
        title: 'Artemis I Launch Highlights',
        source: 'nasa.gov',
        format: 'MP4 · 1080p',
        size: '188 MB',
        status: 'Completed',
      },
    ],
  },
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

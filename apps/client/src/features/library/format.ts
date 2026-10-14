import { detectPlatform } from '../../services/platform';
import type { MediaRecord, MediaSort } from '../../services/types';

/** Android has no ffprobe: metadata never arrives, so nothing is "pending". */
const PROBES = detectPlatform() !== 'android';

export const SORT_LABELS: Record<MediaSort, string> = {
  added: 'Date added',
  title: 'Title',
  size: 'Size',
  duration: 'Length',
};

/** `596` → `9:56`, `5744` → `1:35:44`. */
export function durationLabel(secs: number | null | undefined) {
  if (secs === null || secs === undefined || !Number.isFinite(secs)) return '—';
  const s = Math.max(0, Math.round(secs));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${ss}` : `${m}:${ss}`;
}

const AUDIO_CODECS: Record<string, string> = {
  mp3: 'MP3',
  flac: 'FLAC',
  aac: 'AAC',
  opus: 'Opus',
  vorbis: 'Vorbis',
  alac: 'ALAC',
};

/** Badge shown on thumbnails: "1080p", "4K", "FLAC"… */
export function qualityLabel(m: MediaRecord) {
  if (m.kind === 'video') {
    const h = m.height;
    if (!h) return m.probed || !PROBES ? 'Video' : '…';
    return h >= 2160 ? '4K' : `${h}p`;
  }
  return (m.audioCodec && AUDIO_CODECS[m.audioCodec]) ?? m.audioCodec?.toUpperCase() ?? 'Audio';
}

const VIDEO_CODECS: Record<string, string> = {
  h264: 'H.264',
  hevc: 'HEVC',
  vp9: 'VP9',
  vp8: 'VP8',
  av1: 'AV1',
  mpeg4: 'MPEG-4',
};

/** "MP4 · H.264 · AAC" from probed codecs. */
export function formatLabel(m: MediaRecord) {
  const container = m.path.split('.').pop()?.toUpperCase();
  const parts = [container];
  if (m.videoCodec) parts.push(VIDEO_CODECS[m.videoCodec] ?? m.videoCodec.toUpperCase());
  if (m.audioCodec) parts.push(AUDIO_CODECS[m.audioCodec] ?? m.audioCodec.toUpperCase());
  return parts.filter(Boolean).join(' · ');
}

export function folderOf(path: string) {
  const i = Math.max(path.lastIndexOf('\\'), path.lastIndexOf('/'));
  return i > 0 ? path.slice(0, i) : path;
}

/** "2 h ago", "Yesterday", "10 Oct". */
export function addedLabel(ts: number, now = Date.now()) {
  const minutes = Math.round((now - ts) / 60_000);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  if (hours < 48) return 'Yesterday';
  return new Date(ts).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

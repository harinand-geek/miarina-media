import { formatMb } from '../../stores/downloads';
import type { DownloadTask } from '../../services/types';

export function speedMbps(task: DownloadTask) {
  return (task.totalMb * task.rate) / 100;
}

export function etaLabel(task: DownloadTask) {
  const seconds = Math.ceil((100 - task.percent) / task.rate);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

export function doneLabel(task: DownloadTask) {
  return `${formatMb((task.totalMb * task.percent) / 100)} of ${formatMb(task.totalMb)}`;
}

/** Status text: state is always carried by words, never by color alone. */
export function statusLabel(task: DownloadTask) {
  switch (task.status) {
    case 'completed':
      return 'Completed';
    case 'paused':
      return 'Paused';
    case 'waiting_wifi':
      return 'Waiting for Wi-Fi';
    case 'downloading':
      return `${speedMbps(task).toFixed(1)} MB/s · ${etaLabel(task)} left`;
  }
}

export function statusTone(task: DownloadTask) {
  if (task.status === 'completed') return 'text-accent-strong';
  if (task.status === 'paused' || task.status === 'waiting_wifi') return 'text-warn';
  return 'text-muted';
}

/** Screen reader label, e.g. "Tears of Steel, 62 percent, 1 minute left". */
export function progressAriaLabel(task: DownloadTask) {
  const percent = Math.floor(task.percent / 10) * 10; // live updates every 10 %
  if (task.status !== 'downloading')
    return `${task.title}, ${percent} percent, ${statusLabel(task)}`;
  const minutes = Math.max(1, Math.round((100 - task.percent) / task.rate / 60));
  return `${task.title}, ${percent} percent, ${minutes} minute${minutes > 1 ? 's' : ''} left`;
}

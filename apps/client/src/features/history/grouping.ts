import type { HistoryEntry } from '../../services/types';

function startOfDay(ts: number) {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** "Today", "Yesterday", then "Saturday, 10 October". */
export function dayLabel(ts: number, now = Date.now()) {
  const days = Math.round((startOfDay(now) - startOfDay(ts)) / 86_400_000);
  if (days === 0) return 'Today';
  if (days === 1) return 'Yesterday';
  const d = new Date(ts);
  const weekday = d.toLocaleDateString('en-GB', { weekday: 'long' });
  const month = d.toLocaleDateString('en-GB', { month: 'long' });
  return `${weekday}, ${d.getDate()} ${month}`;
}

export function groupByDay(entries: HistoryEntry[], now = Date.now()) {
  const groups: { day: string; entries: HistoryEntry[] }[] = [];
  for (const entry of [...entries].sort((a, b) => b.finishedAt - a.finishedAt)) {
    const day = dayLabel(entry.finishedAt, now);
    const last = groups[groups.length - 1];
    if (last?.day === day) last.entries.push(entry);
    else groups.push({ day, entries: [entry] });
  }
  return groups;
}

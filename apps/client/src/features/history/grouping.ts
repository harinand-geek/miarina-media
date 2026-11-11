import { translate, type Lang } from '../../i18n';

function startOfDay(ts: number) {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** "Today", "Yesterday", then "Saturday, 10 October" (FR: "samedi 10 octobre"). */
export function dayLabel(ts: number, now = Date.now(), lang: Lang = 'en') {
  const days = Math.round((startOfDay(now) - startOfDay(ts)) / 86_400_000);
  if (days === 0) return translate(lang, 'today');
  if (days === 1) return translate(lang, 'yesterday');
  const d = new Date(ts);
  if (lang === 'fr') {
    return d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  }
  const weekday = d.toLocaleDateString('en-GB', { weekday: 'long' });
  const month = d.toLocaleDateString('en-GB', { month: 'long' });
  return `${weekday}, ${d.getDate()} ${month}`;
}

/** Newest first, one group per day; `time` gives each item's timestamp. */
export function groupByDay<T>(
  items: T[],
  time: (item: T) => number,
  now = Date.now(),
  lang: Lang = 'en',
) {
  const groups: { day: string; entries: T[] }[] = [];
  for (const item of [...items].sort((a, b) => time(b) - time(a))) {
    const day = dayLabel(time(item), now, lang);
    const last = groups[groups.length - 1];
    if (last?.day === day) last.entries.push(item);
    else groups.push({ day, entries: [item] });
  }
  return groups;
}

import { describe, expect, it } from 'vitest';
import type { HistoryEntry } from '../../services/types';
import { dayLabel, groupByDay } from './grouping';

const now = new Date(2026, 9, 14, 12, 0).getTime();
const at = (day: number, hh: number) => new Date(2026, 9, day, hh, 0).getTime();

const entry = (id: number, finishedAt: number): HistoryEntry => ({
  id,
  taskId: `t${id}`,
  url: 'https://example.org/a.mp4',
  title: `Item ${id}`,
  sourceHost: 'example.org',
  formatLabel: 'MP4',
  totalBytes: null,
  doneBytes: 0,
  status: 'completed',
  reason: null,
  finalPath: null,
  finishedAt,
});

describe('history grouping', () => {
  it('labels days like the design', () => {
    expect(dayLabel(at(14, 9), now)).toBe('Today');
    expect(dayLabel(at(13, 23), now)).toBe('Yesterday');
    expect(dayLabel(at(10, 16), now)).toBe('Saturday, 10 October');
  });

  it('labels days in French', () => {
    expect(dayLabel(at(14, 9), now, 'fr')).toBe('Aujourd’hui');
    expect(dayLabel(at(13, 23), now, 'fr')).toBe('Hier');
    expect(dayLabel(at(10, 16), now, 'fr')).toBe('samedi 10 octobre');
  });

  it('groups newest first', () => {
    const groups = groupByDay(
      [entry(1, at(10, 16)), entry(2, at(14, 9)), entry(3, at(14, 11))],
      (e) => e.finishedAt,
      now,
    );
    expect(groups.map((g) => g.day)).toEqual(['Today', 'Saturday, 10 October']);
    expect(groups[0]!.entries.map((e) => e.id)).toEqual([3, 2]);
  });
});

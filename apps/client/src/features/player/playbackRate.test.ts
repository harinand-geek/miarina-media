import { describe, expect, it } from 'vitest';
import { formatRate, nextRate } from './playbackRate';

describe('playback rate', () => {
  it('formats rates like the design (1.0×)', () => {
    expect(formatRate(1)).toBe('1.0×');
    expect(formatRate(2)).toBe('2.0×');
    expect(formatRate(1.25)).toBe('1.25×');
    expect(formatRate(0.5)).toBe('0.5×');
  });

  it('cycles through the supported rates', () => {
    expect(nextRate(1)).toBe(1.25);
    expect(nextRate(2)).toBe(0.5);
  });
});

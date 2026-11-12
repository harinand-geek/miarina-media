import { describe, expect, it, vi } from 'vitest';
import { flyLogoFromSplash, motionReduced, takeLaunch } from './launch';

describe('cold start animation', () => {
  it('plays each part once per page load', () => {
    expect(takeLaunch('home')).toBe(true);
    expect(takeLaunch('home')).toBe(false);
    expect(takeLaunch('nav')).toBe(true);
    expect(takeLaunch('nav')).toBe(false);
  });

  it('does not move the logo when movement is reduced', () => {
    document.documentElement.dataset.motion = 'reduced';
    expect(motionReduced()).toBe(true);
    const el = document.createElement('span');
    const animate = vi.fn();
    Object.assign(el, { animate });
    flyLogoFromSplash(el, 26);
    expect(animate).not.toHaveBeenCalled();
    delete document.documentElement.dataset.motion;
  });

  it('moves the logo from the screen centre at the splash size', () => {
    const el = document.createElement('span');
    const animate = vi.fn();
    Object.assign(el, {
      animate,
      getBoundingClientRect: () => ({ left: 16, top: 51, width: 26, height: 26 }) as DOMRect,
    });
    vi.stubGlobal('matchMedia', () => ({ matches: false }));
    flyLogoFromSplash(el, 26);
    const [frames, timing] = animate.mock.calls[0]!;
    expect(frames[0].transform).toContain(`scale(${112 / 26})`);
    expect(frames[1].transform).toBe('none');
    expect(timing.duration).toBe(460);
    vi.unstubAllGlobals();
  });
});

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const script = readFileSync(resolve(process.cwd(), 'public/boot-slow.js'), 'utf8');
const run = () => new Function(script)();

function userAgent(value: string) {
  vi.spyOn(navigator, 'userAgent', 'get').mockReturnValue(value);
}

beforeEach(() => {
  vi.useFakeTimers();
  document.body.innerHTML = '<div id="root"></div>';
});
afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe('slow start notice (splash S5)', () => {
  it('appears on Android when the interface is not there after 2.5 s', () => {
    userAgent('Mozilla/5.0 (Linux; Android 15) Chrome/130 Mobile');
    vi.spyOn(navigator, 'language', 'get').mockReturnValue('fr-FR');
    run();
    vi.advanceTimersByTime(2400);
    expect(document.getElementById('root')!.childElementCount).toBe(0);
    vi.advanceTimersByTime(200);
    const root = document.getElementById('root')!;
    expect(root.textContent).toContain('Le démarrage prend plus de temps');
    expect(root.querySelector('button')!.textContent).toBe('Relancer');
  });

  it('stays out of the way once the interface has rendered', () => {
    userAgent('Mozilla/5.0 (Linux; Android 15) Chrome/130 Mobile');
    run();
    document.getElementById('root')!.innerHTML = '<main>app</main>';
    vi.advanceTimersByTime(3000);
    expect(document.getElementById('root')!.textContent).toBe('app');
  });

  it('does nothing on Windows', () => {
    userAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edg/157');
    run();
    vi.advanceTimersByTime(3000);
    expect(document.getElementById('root')!.childElementCount).toBe(0);
  });
});

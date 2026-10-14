import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// jsdom lacks these browser APIs used by the shell and virtualized lists.
if (!window.matchMedia) {
  window.matchMedia = (query: string) =>
    ({
      matches: false,
      media: query,
      onchange: null,
      addEventListener: () => {},
      removeEventListener: () => {},
      addListener: () => {},
      removeListener: () => {},
      dispatchEvent: () => false,
    }) as MediaQueryList;
}

if (!globalThis.ResizeObserver) {
  globalThis.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  };
}

afterEach(() => {
  cleanup();
});

// jsdom has no layout: give elements a size so virtualized lists render rows.
for (const [prop, value] of [
  ['offsetWidth', 1200],
  ['offsetHeight', 800],
  ['clientWidth', 1200],
  ['clientHeight', 800],
] as const) {
  Object.defineProperty(HTMLElement.prototype, prop, { configurable: true, get: () => value });
}

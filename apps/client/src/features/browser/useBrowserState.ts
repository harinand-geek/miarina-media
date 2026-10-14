import { useEffect, useState } from 'react';
import { backend } from '../../services/backend';
import type { BrowserSnapshot } from '../../services/types';

/** Browser state pushed by Rust; events win over the initial snapshot. */
export function useBrowserState() {
  const [state, setState] = useState<BrowserSnapshot | null>(null);
  useEffect(() => {
    let alive = true;
    const stop = backend.onBrowserState(setState);
    void backend.browserState().then((snapshot) => {
      if (alive) setState((current) => current ?? snapshot);
    });
    return () => {
      alive = false;
      stop();
    };
  }, []);
  return state;
}

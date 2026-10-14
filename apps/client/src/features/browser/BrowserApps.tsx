import { useEffect } from 'react';
import { useAppearance } from '../../hooks/useAppearance';
import { backend } from '../../services/backend';
import { useDownloads } from '../../stores/downloads';
import { useSettings } from '../../stores/settings';
import { BrowserChrome } from './BrowserChrome';
import { BrowserOverlay } from './BrowserOverlay';

/** Shortcuts while the toolbar has focus (the page's are caught in Rust). */
function onKeyDown(e: KeyboardEvent) {
  const key = e.key.toLowerCase();
  if (e.key === 'F5') {
    e.preventDefault();
    void backend.browserNav('reload');
  } else if (e.altKey && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) {
    e.preventDefault();
    void backend.browserNav(e.key === 'ArrowLeft' ? 'back' : 'forward');
  } else if (e.ctrlKey && e.shiftKey && key === 's') {
    e.preventDefault();
    void backend.browserSheet(true);
  }
}

/** Root of the `browser-ui` webview (title bar, toolbar, start page). */
export function BrowserUiApp() {
  useAppearance();
  useEffect(() => {
    void useSettings.getState().load();
    const stop = useDownloads.getState().init();
    document.addEventListener('keydown', onKeyDown);
    return () => {
      stop();
      document.removeEventListener('keydown', onKeyDown);
    };
  }, []);
  return <BrowserChrome />;
}

/** Root of the transparent `browser-overlay` webview. */
export function BrowserOverlayApp() {
  useAppearance();
  useEffect(() => {
    void useSettings.getState().load();
    return useDownloads.getState().init();
  }, []);
  return <BrowserOverlay />;
}

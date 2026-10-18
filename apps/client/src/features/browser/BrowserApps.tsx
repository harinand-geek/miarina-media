import { useEffect } from 'react';
import { useAppearance } from '../../hooks/useAppearance';
import { useDownloads } from '../../stores/downloads';
import { useSettings } from '../../stores/settings';
import { BrowserOverlay } from './BrowserOverlay';

/** Root of the transparent `browser-overlay` webview. */
export function BrowserOverlayApp() {
  useAppearance();
  useEffect(() => {
    void useSettings.getState().load();
    return useDownloads.getState().init();
  }, []);
  return <BrowserOverlay />;
}

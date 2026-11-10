import { UpdateMonitor } from '../features/settings/AppUpdates';
import { useEffect } from 'react';
import { useAppearance } from '../hooks/useAppearance';
import { backend } from '../services/backend';
import { detectPlatform } from '../services/platform';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { useUi } from '../stores/ui';
import { DesktopShell } from './DesktopShell';
import { MobileShell } from './MobileShell';

const platform = detectPlatform();

export function App() {
  useAppearance();

  useEffect(() => {
    void useSettings.getState().load();
    const stopDownloads = useDownloads.getState().init();
    const stopLibrary = useLibrary.getState().init();
    // The browser window asks to show Downloads or the Library.
    const stopNavigate = backend.onAppNavigate((screen) => useUi.getState().go(screen));
    return () => {
      stopDownloads();
      stopLibrary();
      stopNavigate();
    };
  }, []);

  return <><UpdateMonitor />{platform === 'android' ? <MobileShell /> : <DesktopShell />}</>;
}

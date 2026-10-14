import { useEffect } from 'react';
import { useAppearance } from '../hooks/useAppearance';
import { detectPlatform } from '../services/platform';
import { useDownloads } from '../stores/downloads';
import { useLibrary } from '../stores/library';
import { useSettings } from '../stores/settings';
import { DesktopShell } from './DesktopShell';
import { MobileShell } from './MobileShell';

const platform = detectPlatform();

export function App() {
  useAppearance();

  useEffect(() => {
    void useSettings.getState().load();
    const stopDownloads = useDownloads.getState().init();
    const stopLibrary = useLibrary.getState().init();
    return () => {
      stopDownloads();
      stopLibrary();
    };
  }, []);

  return platform === 'android' ? <MobileShell /> : <DesktopShell />;
}

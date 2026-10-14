import { useEffect } from 'react';
import { useAppearance } from '../hooks/useAppearance';
import { detectPlatform } from '../services/platform';
import { useDownloads } from '../stores/downloads';
import { useSettings } from '../stores/settings';
import { DesktopShell } from './DesktopShell';
import { MobileShell } from './MobileShell';

const platform = detectPlatform();

export function App() {
  useAppearance();

  useEffect(() => {
    void useSettings.getState().load();
    return useDownloads.getState().init();
  }, []);

  return platform === 'android' ? <MobileShell /> : <DesktopShell />;
}

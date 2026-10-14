import { useAppearance } from '../hooks/useAppearance';
import { useDownloadTicker } from '../hooks/useDownloadTicker';
import { detectPlatform } from '../services/platform';
import { DesktopShell } from './DesktopShell';
import { MobileShell } from './MobileShell';

const platform = detectPlatform();

export function App() {
  useAppearance();
  useDownloadTicker();
  return platform === 'android' ? <MobileShell /> : <DesktopShell />;
}

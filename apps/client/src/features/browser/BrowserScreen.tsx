import { useUi } from '../../stores/ui';
import { BrowserView } from './BrowserView';

/**
 * Windows browser: inside the main window, same screen as on Android
 * (design M1). The page is a child webview placed by Rust over the page
 * area; the floating button and format sheet (D2) are the overlay's.
 */
export default function BrowserScreen() {
  const go = useUi((s) => s.go);
  const confirmOpen = useUi((s) => s.confirm !== null);
  return (
    <BrowserView
      desktop
      covered={confirmOpen}
      onExit={() => go('home')}
      onOpenSettings={() => go('settings')}
      onShowDownloads={() => go('downloads')}
    />
  );
}

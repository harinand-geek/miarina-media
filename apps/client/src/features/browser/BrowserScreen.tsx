import { useUi } from '../../stores/ui';
import { DesktopBrowser } from './DesktopBrowser';

/**
 * Windows browser (Windows v2 screen 8): tabs and toolbar inside the main
 * window. Each tab's page is a child webview placed by Rust over the page
 * area; the floating button and format sheet (D2) are the overlay's.
 */
export default function BrowserScreen() {
  const confirmOpen = useUi((s) => s.confirm !== null);
  // The native page would hide the title bar search panel: step aside while it is open.
  const searchOpen = useUi((s) => s.searchOpen);
  return <DesktopBrowser covered={confirmOpen || searchOpen} />;
}

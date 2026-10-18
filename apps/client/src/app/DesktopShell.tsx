import { Suspense, lazy, useEffect, type ReactNode } from 'react';
import { ConfirmDialog } from '../components/Overlay';
import { ToastHost } from '../components/ToastHost';
import { HomeScreen } from '../features/home/HomeScreen';
import { AnalysisScreen } from '../features/analysis/AnalysisScreen';
import { DownloadsScreen } from '../features/downloads/DownloadsScreen';
import { useGlobalShortcuts } from '../hooks/useGlobalShortcuts';
import { useMediaQuery } from '../hooks/useMediaQuery';
import { useUi, type Screen } from '../stores/ui';
import { Sidebar } from './Sidebar';
import { TitleBar } from './TitleBar';

// Heavier, less frequent screens are loaded on demand.
const LibraryScreen = lazy(() => import('../features/library/LibraryScreen'));
const PlayerScreen = lazy(() => import('../features/player/PlayerScreen'));
const HistoryScreen = lazy(() => import('../features/history/HistoryScreen'));
const SettingsScreen = lazy(() => import('../features/settings/SettingsScreen'));
const BrowserScreen = lazy(() => import('../features/browser/BrowserScreen'));

const SCREENS: Record<Screen, () => ReactNode> = {
  home: () => <HomeScreen />,
  analysis: () => <AnalysisScreen />,
  downloads: () => <DownloadsScreen />,
  library: () => <LibraryScreen />,
  player: () => <PlayerScreen />,
  history: () => <HistoryScreen />,
  browser: () => <BrowserScreen />,
  settings: () => <SettingsScreen />,
};

export function DesktopShell() {
  const screen = useUi((s) => s.screen);
  const collapsed = useUi((s) => s.sidebarCollapsed);
  // Design §11: the sidebar auto-collapses to 64 px between 1024 and 1279.
  const narrow = useMediaQuery('(max-width: 1279px)');

  useEffect(() => {
    useUi.setState({ sidebarCollapsed: narrow });
  }, [narrow]);

  useGlobalShortcuts();

  return (
    <div className="flex h-full min-h-[640px] min-w-[960px] flex-col bg-bg">
      <TitleBar />
      <div className="flex min-h-0 flex-1">
        <Sidebar collapsed={collapsed} />
        <main className="relative flex min-w-0 flex-1 flex-col overflow-hidden">
          {/* Screen change: fade + 8 px rise of the content; nav never moves. */}
          <div key={screen} className="flex min-h-0 flex-1 animate-screen-in flex-col">
            <Suspense fallback={null}>{SCREENS[screen]()}</Suspense>
          </div>
          <ToastHost position={screen === 'browser' ? 'browser' : 'desktop'} />
          <ConfirmDialog />
        </main>
      </div>
    </div>
  );
}

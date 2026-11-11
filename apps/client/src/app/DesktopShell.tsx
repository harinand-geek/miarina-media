import { Suspense, lazy, useEffect, type ReactNode } from 'react';
import { ConfirmDialog } from '../components/Overlay';
import { Icon } from '../components/Icon';
import { ToastHost } from '../components/ToastHost';
import { HomeScreen } from '../features/home/HomeScreen';
import { AnalysisScreen } from '../features/analysis/AnalysisScreen';
import { DownloadsScreen } from '../features/downloads/DownloadsScreen';
import { MiniPlayer } from '../features/player/MiniPlayer';
import { PlayerHost } from '../features/player/PlayerHost';
import { useGlobalShortcuts } from '../hooks/useGlobalShortcuts';
import { useMediaQuery } from '../hooks/useMediaQuery';
import { useOnline } from '../hooks/useOnline';
import { t, useT } from '../i18n';
import { onSleepTimerEnded, usePlayer } from '../stores/player';
import { useUi, type Screen } from '../stores/ui';
import { Sidebar } from './Sidebar';
import { TitleBar } from './TitleBar';

// Heavier, less frequent screens are loaded on demand.
const LibraryScreen = lazy(() => import('../features/library/LibraryScreen'));
const PlayerScreen = lazy(() => import('../features/player/PlayerScreen'));
const NowPlayingScreen = lazy(() => import('../features/player/NowPlayingScreen'));
const HistoryScreen = lazy(() => import('../features/history/HistoryScreen'));
const SettingsScreen = lazy(() => import('../features/settings/SettingsScreen'));
const BrowserScreen = lazy(() => import('../features/browser/BrowserScreen'));
const TorrentsScreen = lazy(() => import('../features/torrents/TorrentsScreen'));

const SCREENS: Record<Screen, () => ReactNode> = {
  home: () => <HomeScreen />,
  analysis: () => <AnalysisScreen />,
  downloads: () => <DownloadsScreen />,
  library: () => <LibraryScreen />,
  player: () => <PlayerScreen />,
  now: () => <NowPlayingScreen />,
  history: () => <HistoryScreen />,
  browser: () => <BrowserScreen />,
  settings: () => <SettingsScreen />,
  torrents: () => <TorrentsScreen />,
};

/** The mini-player stays out of the full players and the browser (Windows v2). */
const NO_MINI_PLAYER: Screen[] = ['player', 'now', 'browser'];

function OfflineBanner() {
  const t = useT();
  return (
    <div
      role="status"
      className="flex h-9 shrink-0 items-center gap-2.5 border-b border-line bg-warn-subtle px-5 text-[13px]"
    >
      <Icon name="wifi_off" size={18} className="text-warn" />
      <span className="font-bold">{t('offTitle')}</span>
      <span className="truncate text-muted">{t('offBody')}</span>
    </div>
  );
}

export function DesktopShell() {
  const screen = useUi((s) => s.screen);
  const collapsed = useUi((s) => s.sidebarCollapsed);
  const fullscreen = useUi((s) => s.playerFullscreen && s.screen === 'player');
  const hasMedia = usePlayer((s) => s.media !== null);
  const online = useOnline();
  // Design §11: the sidebar auto-collapses to 64 px between 1024 and 1279.
  const narrow = useMediaQuery('(max-width: 1279px)');
  const showMini = hasMedia && !NO_MINI_PLAYER.includes(screen);

  useEffect(() => {
    useUi.setState({ sidebarCollapsed: narrow });
  }, [narrow]);

  useEffect(() => {
    onSleepTimerEnded(() =>
      useUi.getState().pushToast({ tone: 'success', message: t('sleepStopped') }),
    );
    return () => onSleepTimerEnded(null);
  }, []);

  useGlobalShortcuts();

  return (
    <div className="flex h-full min-h-[640px] min-w-[960px] flex-col bg-bg">
      {!fullscreen && <TitleBar />}
      {!fullscreen && !online && <OfflineBanner />}
      <div className="flex min-h-0 flex-1">
        {!fullscreen && <Sidebar collapsed={collapsed} />}
        <div className="relative flex min-w-0 flex-1 flex-col">
          <main className="relative flex min-h-0 flex-1 flex-col overflow-hidden">
            {/* One engine for the whole app: playback survives screen changes. */}
            <PlayerHost />
            {/* Screen change: fade + 8 px rise of the content; nav never moves. */}
            <div key={screen} className="relative flex min-h-0 flex-1 animate-screen-in flex-col">
              <Suspense fallback={null}>{SCREENS[screen]()}</Suspense>
            </div>
            <ConfirmDialog />
          </main>
          {showMini && <MiniPlayer />}
          <ToastHost
            position={screen === 'browser' ? 'browser' : showMini ? 'aboveMiniPlayer' : 'desktop'}
          />
        </div>
      </div>
    </div>
  );
}

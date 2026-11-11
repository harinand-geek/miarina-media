import { useCallback, useEffect, useMemo, useState } from 'react';
import { Icon } from '../components/Icon';
import { ConfirmDialog } from '../components/Overlay';
import { MobileRemoveSheet } from '../features/library/MobileRemoveSheet';
import { ToastHost } from '../components/ToastHost';
import { MobileHome } from '../features/home/MobileHome';
import { MobileDownloads } from '../features/downloads/MobileDownloads';
import { MobileMusic } from '../features/library/MobileMusic';
import { MobileVideos } from '../features/library/MobileVideos';
import { MobileSettings } from '../features/settings/MobileSettings';
import { BrowserView } from '../features/browser/BrowserView';
import { browserBack } from '../features/browser/browserBack';
import { useAndroidBack } from '../hooks/useAndroidBack';
import { useLaunchRequests } from '../hooks/useLaunchRequests';
import { backend } from '../services/backend';
import { AnalysisSheet } from '../features/analysis/AnalysisSheet';
import { StorageSheet } from '../features/analysis/StorageSheet';
import { MobilePlayer } from '../features/player/MobilePlayer';
import { summarize, useDownloads } from '../stores/downloads';
import { useT, type MessageKey } from '../i18n';
import { useUi } from '../stores/ui';

export type MobileTab = 'home' | 'browser' | 'downloads' | 'music' | 'videos';

/** Android v2: teal tabs get media, coral tabs play it. */
const TABS: { id: MobileTab; label: MessageKey; icon: string; play?: boolean }[] = [
  { id: 'home', label: 'tabHome', icon: 'home' },
  { id: 'browser', label: 'tabBrowser', icon: 'travel_explore' },
  { id: 'downloads', label: 'tabDownloads', icon: 'download' },
  { id: 'music', label: 'tabMusic', icon: 'library_music', play: true },
  { id: 'videos', label: 'tabVideos', icon: 'video_library', play: true },
];

/**
 * Android shell: bottom navigation (Home, Browser, Downloads, Library —
 * design M5), Settings as a full page from Home, bottom sheets for analysis
 * and storage, full-screen player (design "Miarina Media - Android").
 */
export function MobileShell() {
  const t = useT();
  const [tab, setTab] = useState<MobileTab>('home');
  const [miniSlot, setMiniSlot] = useState<HTMLDivElement | null>(null);
  const playerExpanded = useUi((s) => s.nowPlaying !== null && s.mobilePlayerExpanded);
  const [storageOpen, setStorageOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const nowPlaying = useUi((s) => s.nowPlaying);
  const closePlayer = useUi((s) => s.play);
  const sheetOpen = useUi((s) => s.screen === 'analysis');
  const confirmOpen = useUi((s) => s.confirm !== null);
  const removalOpen = useUi((s) => s.removal !== null);
  const pushToast = useUi((s) => s.pushToast);

  // Back closes the top panel, then goes back in the browser page, then
  // returns Home; on Home it leaves the app.
  // A minimized player keeps playing: Back never stops it.
  useAndroidBack(removalOpen || playerExpanded || settingsOpen || tab !== 'home', () => {
    if (removalOpen) useUi.getState().askRemoval(null);
    else if (playerExpanded) useUi.setState({ mobilePlayerExpanded: false });
    else if (settingsOpen) setSettingsOpen(false);
    else if (tab === 'browser' && !sheetOpen && browserBack.current?.()) return;
    else setTab('home');
  });
  // A link shared from another app opens its analysis on Home; a tapped
  // "Download complete" notification plays the file.
  const analyze = useUi((s) => s.analyze);
  const onLink = useCallback(
    (url: string) => {
      closePlayer(null);
      setSettingsOpen(false);
      setTab('home');
      analyze(url);
    },
    [analyze, closePlayer],
  );
  const onPlayTask = useCallback(
    (taskId: string) => {
      setSettingsOpen(false);
      void backend
        .libraryQuery({ search: '', kind: null, sort: 'added', limit: 200 })
        .then((page) => {
          const media = page.items.find((m) => m.taskId === taskId);
          if (!media) return;
          setTab(media.kind === 'audio' ? 'music' : 'videos');
          closePlayer(media);
        })
        .catch(() => {});
    },
    [closePlayer],
  );
  useLaunchRequests({ onLink, onPlayTask });
  // A search typed on Home opens in the browser tab.
  useEffect(
    () =>
      useUi.subscribe((s, prev) => {
        if (s.browserRequest && s.browserRequest !== prev.browserRequest) setTab('browser');
      }),
    [],
  );
  const tasks = useDownloads((s) => s.tasks);
  const activeCount = useMemo(() => summarize(tasks).openCount, [tasks]);

  return (
    <div className="relative flex h-full flex-col overflow-hidden bg-bg">
      <div key={tab} className="flex min-h-0 flex-1 animate-screen-in flex-col">
        {tab === 'home' && (
          <MobileHome onNavigate={setTab} onOpenSettings={() => setSettingsOpen(true)} />
        )}
        {tab === 'browser' && (
          <BrowserView
            covered={
              playerExpanded || settingsOpen || sheetOpen || storageOpen || confirmOpen || removalOpen
            }
            onExit={() => setTab('home')}
            onOpenSettings={() => setSettingsOpen(true)}
            onShowDownloads={() => setTab('downloads')}
          />
        )}
        {tab === 'downloads' && <MobileDownloads />}
        {tab === 'music' && <MobileMusic />}
        {tab === 'videos' && <MobileVideos />}
      </div>
      {settingsOpen && (
        <div className="absolute inset-0 z-30 flex animate-screen-in flex-col bg-bg">
          <MobileSettings
            onBack={() => setSettingsOpen(false)}
            onOpenStorage={() => setStorageOpen(true)}
          />
        </div>
      )}

      {/* The browser has its own bar (design M1); its Miarina button returns here. */}
      {/* Mini-player slot: hidden with the browser and settings (Android v2). */}
      {tab !== 'browser' && !settingsOpen && <div ref={setMiniSlot} className="shrink-0" />}

      <nav
        aria-label="Main"
        hidden={tab === 'browser'}
        className="flex h-[72px] shrink-0 border-t border-divider bg-sidebar px-1"
      >
        {TABS.map((item) => {
          const on = item.id === tab;
          return (
            <button
              key={item.id}
              type="button"
              aria-current={on ? 'page' : undefined}
              onClick={() => setTab(item.id)}
              className={`flex min-w-0 flex-1 flex-col items-center justify-center gap-1 text-[11.5px] ${
                on ? 'font-bold text-fg' : 'font-semibold text-muted'
              }`}
            >
              <span
                className={`relative grid h-8 w-14 place-items-center rounded-2xl transition-colors duration-200 ${
                  on ? (item.play ? 'bg-coral-subtle' : 'bg-accent-subtle') : ''
                }`}
              >
                <Icon
                  name={item.icon}
                  size={24}
                  fill={on}
                  className={on ? (item.play ? 'text-coral-strong' : 'text-chip-text') : 'text-muted'}
                />
                {item.id === 'downloads' && activeCount > 0 && (
                  <span className="absolute right-1.5 top-0 grid h-4 min-w-4 place-items-center rounded-lg bg-accent px-1 text-[10px] font-extrabold text-accent-ink">
                    {activeCount}
                  </span>
                )}
              </span>
              <span className="max-w-full truncate">{t(item.label)}</span>
            </button>
          );
        })}
      </nav>

      <AnalysisSheet
        onOpenStorage={() => setStorageOpen(true)}
        onStarted={() => {
          // From the browser, stay on the page (as in common mobile media apps).
          if (tab !== 'browser') setTab('downloads');
          else
            pushToast({
              tone: 'success',
              message: 'Download started',
              action: { label: 'View', run: () => setTab('downloads') },
            });
        }}
      />
      <StorageSheet open={storageOpen} onClose={() => setStorageOpen(false)} />
      {nowPlaying && <MobilePlayer key={nowPlaying.id} item={nowPlaying} miniSlot={miniSlot} />}
      <ToastHost position={tab === 'browser' ? 'browser' : 'mobile'} />
      <ConfirmDialog />
      <MobileRemoveSheet />
    </div>
  );
}

import { useCallback, useMemo, useState } from 'react';
import { Icon } from '../components/Icon';
import { ConfirmDialog } from '../components/Overlay';
import { ToastHost } from '../components/ToastHost';
import { MobileHome } from '../features/home/MobileHome';
import { MobileDownloads } from '../features/downloads/MobileDownloads';
import { MobileLibrary } from '../features/library/MobileLibrary';
import { MobileSettings } from '../features/settings/MobileSettings';
import { MobileBrowser } from '../features/browser/MobileBrowser';
import { browserBack } from '../features/browser/browserBack';
import { useAndroidBack } from '../hooks/useAndroidBack';
import { useLaunchRequests } from '../hooks/useLaunchRequests';
import { backend } from '../services/backend';
import { AnalysisSheet } from '../features/analysis/AnalysisSheet';
import { StorageSheet } from '../features/analysis/StorageSheet';
import { MobilePlayer } from '../features/player/MobilePlayer';
import { summarize, useDownloads } from '../stores/downloads';
import { useUi } from '../stores/ui';

export type MobileTab = 'home' | 'browser' | 'downloads' | 'library';

const TABS: { id: MobileTab; label: string; icon: string }[] = [
  { id: 'home', label: 'Home', icon: 'home' },
  { id: 'browser', label: 'Browser', icon: 'travel_explore' },
  { id: 'downloads', label: 'Downloads', icon: 'download' },
  { id: 'library', label: 'Library', icon: 'video_library' },
];

/**
 * Android shell: bottom navigation (Home, Browser, Downloads, Library —
 * design M5), Settings as a full page from Home, bottom sheets for analysis
 * and storage, full-screen player (design "Miarina Media - Android").
 */
export function MobileShell() {
  const [tab, setTab] = useState<MobileTab>('home');
  const [storageOpen, setStorageOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const nowPlaying = useUi((s) => s.nowPlaying);
  const closePlayer = useUi((s) => s.play);
  const sheetOpen = useUi((s) => s.screen === 'analysis');
  const confirmOpen = useUi((s) => s.confirm !== null);
  const pushToast = useUi((s) => s.pushToast);

  // Back closes the top panel, then goes back in the browser page, then
  // returns Home; on Home it leaves the app.
  useAndroidBack(!!nowPlaying || settingsOpen || tab !== 'home', () => {
    if (nowPlaying) closePlayer(null);
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
      setTab('library');
      void backend
        .libraryQuery({ search: '', kind: null, sort: 'added', limit: 200 })
        .then((page) => {
          const media = page.items.find((m) => m.taskId === taskId);
          if (media) closePlayer(media);
        })
        .catch(() => {});
    },
    [closePlayer],
  );
  useLaunchRequests({ onLink, onPlayTask });
  const tasks = useDownloads((s) => s.tasks);
  const activeCount = useMemo(() => summarize(tasks).openCount, [tasks]);

  return (
    <div className="relative flex h-full flex-col overflow-hidden bg-bg">
      <div key={tab} className="flex min-h-0 flex-1 animate-screen-in flex-col">
        {tab === 'home' && (
          <MobileHome onNavigate={setTab} onOpenSettings={() => setSettingsOpen(true)} />
        )}
        {tab === 'browser' && (
          <MobileBrowser
            covered={!!nowPlaying || settingsOpen || sheetOpen || storageOpen || confirmOpen}
            onExit={() => setTab('home')}
            onOpenSettings={() => setSettingsOpen(true)}
            onShowDownloads={() => setTab('downloads')}
          />
        )}
        {tab === 'downloads' && <MobileDownloads />}
        {tab === 'library' && <MobileLibrary />}
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
      <nav
        aria-label="Main"
        hidden={tab === 'browser'}
        className="flex h-20 shrink-0 border-t border-divider bg-sidebar px-2"
      >
        {TABS.map((t) => {
          const on = t.id === tab;
          return (
            <button
              key={t.id}
              type="button"
              aria-current={on ? 'page' : undefined}
              onClick={() => setTab(t.id)}
              className={`flex flex-1 flex-col items-center justify-center gap-1 text-[12px] font-semibold ${on ? 'text-fg' : 'text-muted'}`}
            >
              <span
                className={`relative grid h-8 w-[60px] place-items-center rounded-2xl transition-colors duration-200 ${on ? 'bg-accent-subtle' : ''}`}
              >
                <Icon
                  name={t.icon}
                  size={24}
                  fill={on}
                  className={on ? 'text-accent-strong' : 'text-muted'}
                />
                {t.id === 'downloads' && activeCount > 0 && (
                  <span className="absolute right-2.5 top-0 grid h-4 min-w-4 place-items-center rounded-lg bg-accent px-1 text-[10px] font-bold text-accent-ink">
                    {activeCount}
                  </span>
                )}
              </span>
              {t.label}
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
      {nowPlaying && <MobilePlayer item={nowPlaying} />}
      <ToastHost position={tab === 'browser' ? 'browser' : 'mobile'} />
      <ConfirmDialog />
    </div>
  );
}

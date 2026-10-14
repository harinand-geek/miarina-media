import { useMemo, useState } from 'react';
import { Icon } from '../components/Icon';
import { ConfirmDialog } from '../components/Overlay';
import { ToastHost } from '../components/ToastHost';
import { MobileHome } from '../features/home/MobileHome';
import { MobileDownloads } from '../features/downloads/MobileDownloads';
import { MobileLibrary } from '../features/library/MobileLibrary';
import { MobileSettings } from '../features/settings/MobileSettings';
import { AnalysisSheet } from '../features/analysis/AnalysisSheet';
import { StorageSheet } from '../features/analysis/StorageSheet';
import { MobilePlayer } from '../features/player/MobilePlayer';
import { summarize, useDownloads } from '../stores/downloads';
import { useUi } from '../stores/ui';

export type MobileTab = 'home' | 'downloads' | 'library' | 'settings';

const TABS: { id: MobileTab; label: string; icon: string }[] = [
  { id: 'home', label: 'Home', icon: 'home' },
  { id: 'downloads', label: 'Downloads', icon: 'download' },
  { id: 'library', label: 'Library', icon: 'video_library' },
  { id: 'settings', label: 'Settings', icon: 'settings' },
];

/**
 * Android shell: bottom navigation, bottom sheets for analysis and storage,
 * full-screen player (design "Miarina Media - Android").
 */
export function MobileShell() {
  const [tab, setTab] = useState<MobileTab>('home');
  const [storageOpen, setStorageOpen] = useState(false);
  const nowPlaying = useUi((s) => s.nowPlaying);
  const tasks = useDownloads((s) => s.tasks);
  const activeCount = useMemo(() => summarize(tasks).openCount, [tasks]);

  return (
    <div className="relative flex h-full flex-col overflow-hidden bg-bg">
      <div key={tab} className="flex min-h-0 flex-1 animate-screen-in flex-col">
        {tab === 'home' && <MobileHome onNavigate={setTab} />}
        {tab === 'downloads' && <MobileDownloads />}
        {tab === 'library' && <MobileLibrary />}
        {tab === 'settings' && <MobileSettings onOpenStorage={() => setStorageOpen(true)} />}
      </div>

      <nav aria-label="Main" className="flex h-20 shrink-0 border-t border-divider bg-sidebar px-2">
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
        onStarted={() => setTab('downloads')}
      />
      <StorageSheet open={storageOpen} onClose={() => setStorageOpen(false)} />
      {nowPlaying && <MobilePlayer item={nowPlaying} />}
      <ToastHost position="mobile" />
      <ConfirmDialog />
    </div>
  );
}

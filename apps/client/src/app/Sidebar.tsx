import { useMemo } from 'react';
import { Icon } from '../components/Icon';
import { Kbd } from '../components/Feedback';
import { ProgressBar } from '../components/ProgressBar';
import { useUpdates } from '../features/settings/useUpdates';
import { useT, type MessageKey } from '../i18n';
import { summarize, useDownloads } from '../stores/downloads';
import { isActive, usePlayer } from '../stores/player';
import { useUi, type LibraryView, type Screen, type Space } from '../stores/ui';
import { openLibrary, openSection } from './navigation';

interface NavItem {
  id: string;
  label: MessageKey;
  icon: string;
  /** Not available yet: shown, never presented as active (CDC UX-06). */
  planned?: boolean;
  go?: () => void;
}

const section = (id: Screen, label: MessageKey, icon: string): NavItem => ({
  id,
  label,
  icon,
  go: () => openSection(id),
});
const library = (view: LibraryView, label: MessageKey, icon: string): NavItem => ({
  id: `lib:${view}`,
  label,
  icon,
  go: () => openLibrary(view),
});

const GET: NavItem[] = [
  section('home', 'home', 'home'),
  section('downloads', 'downloads', 'download'),
  section('browser', 'browser', 'travel_explore'),
  section('torrents', 'torrents', 'hub'),
  section('history', 'history', 'history'),
];

const MUSIC: NavItem[] = [
  library('tracks', 'tracks', 'music_note'),
  library('albums', 'albums', 'album'),
  library('artists', 'artists', 'person'),
  library('folders', 'folders', 'folder'),
  library('playlists', 'playlists', 'queue_music'),
  library('favorites', 'favorites', 'favorite'),
];
const VIDEO: NavItem[] = [library('videos', 'videos', 'movie')];

/** Decision 0006: listening first, getting media second. */
const SPACES: { id: Space; label: MessageKey; icon: string; home: () => void }[] = [
  { id: 'play', label: 'spacePlay', icon: 'library_music', home: () => openLibrary('tracks') },
  { id: 'get', label: 'spaceGet', icon: 'download', home: () => openSection('home') },
];

export function Sidebar({ collapsed }: { collapsed: boolean }) {
  const t = useT();
  const screen = useUi((s) => s.screen);
  const space = useUi((s) => s.space);
  const libraryView = useUi((s) => s.libraryView);
  const toggle = useUi((s) => s.toggleSidebar);
  const tasks = useDownloads((s) => s.tasks);
  const summary = useMemo(() => summarize(tasks), [tasks]);
  const playing = usePlayer((s) => isActive(s.state));
  const updateWaiting = useUpdates((s) => s.phase === 'available' || s.phase === 'ready');

  const current =
    screen === 'analysis'
      ? 'home'
      : screen === 'library'
        ? `lib:${libraryView}`
        : screen === 'player'
          ? 'lib:videos'
          : screen;

  const renderItem = (item: NavItem, extra?: { badge?: string; live?: boolean }) => {
    const on = current === item.id;
    const label = t(item.label);
    const live = extra?.live;
    return (
      <button
        key={item.id}
        type="button"
        onClick={item.go}
        disabled={item.planned}
        title={item.planned ? `${label} — ${t('plannedHint')}` : label}
        aria-current={on ? 'page' : undefined}
        className={`flex h-10 shrink-0 items-center gap-3 overflow-hidden whitespace-nowrap rounded-full px-[14px] text-left text-[13.5px] font-semibold transition-colors duration-[80ms] enabled:hover:bg-surface/60 enabled:hover:text-fg disabled:opacity-55 ${
          on ? 'bg-surface text-fg' : 'text-muted'
        }`}
      >
        <Icon
          name={item.icon}
          fill={on || live}
          className={live ? 'text-coral' : on ? 'text-accent-strong' : ''}
        />
        {!collapsed && (
          <>
            <span className="flex-1">{label}</span>
            {item.planned && (
              <span className="rounded-xs border border-planned-border bg-planned-bg px-1 py-px font-mono text-[9.5px] font-bold text-warn">
                {t('planned')}
              </span>
            )}
            {extra?.badge && (
              <span
                className={`rounded-xs px-1.5 py-0.5 font-mono text-[11px] font-semibold ${
                  live ? 'bg-coral-subtle text-coral-strong' : 'bg-accent-subtle text-chip-text'
                }`}
              >
                {extra.badge}
              </span>
            )}
          </>
        )}
      </button>
    );
  };

  const groupHead = (label: MessageKey) =>
    !collapsed && (
      <span className="whitespace-nowrap px-[13px] pb-1.5 pt-2 text-[11px] font-bold uppercase tracking-[0.06em] text-faint">
        {t(label)}
      </span>
    );

  return (
    <nav
      aria-label={t('navLabel')}
      className="flex shrink-0 flex-col gap-0.5 overflow-hidden border-r border-divider bg-sidebar px-2.5 py-3 transition-[width] duration-200 ease-standard"
      style={{ width: collapsed ? 64 : 232 }}
    >
      <div
        role="radiogroup"
        aria-label={t('spaces')}
        className="mb-2.5 flex gap-0.5 rounded-full border border-line bg-bg p-[3px]"
      >
        {SPACES.map((sp) => {
          const on = space === sp.id;
          return (
            <button
              key={sp.id}
              type="button"
              role="radio"
              aria-checked={on}
              title={t(sp.label)}
              onClick={() => {
                useUi.setState({ space: sp.id });
                sp.home();
              }}
              className={`flex h-[34px] min-w-0 flex-1 items-center justify-center gap-[5px] overflow-hidden whitespace-nowrap rounded-full border px-1 text-[12px] font-bold transition-colors duration-150 ${
                on
                  ? 'border-line-strong bg-surface text-fg shadow-[0_1px_2px_rgba(0,0,0,0.12)]'
                  : 'border-transparent text-muted hover:text-fg'
              }`}
            >
              <Icon
                name={sp.icon}
                size={18}
                className={on ? (sp.id === 'play' ? 'text-coral' : 'text-accent-strong') : ''}
              />
              {!collapsed && <span>{t(sp.label)}</span>}
            </button>
          );
        })}
      </div>

      {space === 'get' ? (
        <div className="flex flex-col gap-0.5 pb-2.5">
          {GET.map((item) =>
            renderItem(item, {
              badge:
                item.id === 'downloads' && summary.openCount
                  ? String(summary.openCount)
                  : undefined,
            }),
          )}
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-0.5 pb-2.5">
            {groupHead('groupMusic')}
            {MUSIC.map((item) => renderItem(item))}
          </div>
          <div className="flex flex-col gap-0.5 pb-2.5">
            {groupHead('groupVideo')}
            {VIDEO.map((item) => renderItem(item))}
          </div>
          <div className="flex flex-col gap-0.5 pb-2.5">
            {renderItem(
              { id: 'now', label: 'nowPlaying', icon: 'graphic_eq', go: () => openSection('now') },
              { badge: playing ? '●' : undefined, live: true },
            )}
          </div>
        </>
      )}

      <div className="flex-1" />
      {!collapsed && (
        <button
          type="button"
          onClick={() => openSection('downloads')}
          className="mb-1.5 flex flex-col gap-2 rounded-[18px] border border-line bg-surface p-3.5 text-left"
        >
          <span className="flex w-full justify-between text-[12px]">
            <span className="font-bold">
              {summary.running.length
                ? t('sumRunning', { n: summary.running.length })
                : summary.offline
                  ? t('sumOffline')
                  : summary.active.length
                    ? t('sumPaused')
                    : t('sumIdle')}
            </span>
            <span className="font-mono text-accent-strong">
              {summary.running.length ? summary.speedLabel : ''}
            </span>
          </span>
          <ProgressBar
            value={summary.overallPercent}
            height={3}
            label={t('sumProgress')}
            className="w-full"
          />
          <span className="text-[11.5px] text-muted">
            {t('sumQueue', { n: summary.queued.length })}
          </span>
        </button>
      )}
      <button
        type="button"
        onClick={() => openSection('settings')}
        title={updateWaiting ? `${t('settings')} — ${t('updateAvailable')}` : t('settings')}
        aria-current={screen === 'settings' ? 'page' : undefined}
        className={`flex h-10 items-center gap-3 overflow-hidden whitespace-nowrap rounded-full px-[14px] text-[13.5px] font-semibold hover:bg-surface/60 hover:text-fg ${
          screen === 'settings' ? 'bg-surface text-fg' : 'text-muted'
        }`}
      >
        <span className="relative grid">
          <Icon
            name="settings"
            fill={screen === 'settings'}
            className={screen === 'settings' ? 'text-accent-strong' : ''}
          />
          {collapsed && updateWaiting && (
            <span className="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-accent" />
          )}
        </span>
        {!collapsed && (
          <>
            <span className="flex-1 text-left">{t('settings')}</span>
            {updateWaiting && (
              <span
                role="img"
                aria-label={t('updateAvailable')}
                className="block h-2 w-2 rounded-full bg-accent"
              />
            )}
          </>
        )}
      </button>
      <button
        type="button"
        onClick={toggle}
        title={`${collapsed ? t('expandSidebar') : t('collapseSidebar')} (Ctrl+B)`}
        aria-label={collapsed ? t('expandSidebar') : t('collapseSidebar')}
        className="flex h-[34px] items-center gap-3 whitespace-nowrap rounded-full px-[14px] text-[12.5px] font-medium text-muted hover:bg-surface hover:text-fg"
      >
        <Icon name={collapsed ? 'left_panel_open' : 'left_panel_close'} />
        {!collapsed && (
          <>
            <span className="flex-1 text-left">{t('collapse')}</span>
            <Kbd>Ctrl B</Kbd>
          </>
        )}
      </button>
    </nav>
  );
}

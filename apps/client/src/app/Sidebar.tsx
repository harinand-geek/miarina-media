import { useMemo } from 'react';
import { Icon } from '../components/Icon';
import { Kbd } from '../components/Feedback';
import { ProgressBar } from '../components/ProgressBar';
import { SECTION_ORDER } from '../hooks/useGlobalShortcuts';
import { summarize, useDownloads } from '../stores/downloads';
import { useUi, type Screen } from '../stores/ui';

const NAV: Record<string, { label: string; icon: string }> = {
  home: { label: 'Home', icon: 'home' },
  downloads: { label: 'Downloads', icon: 'download' },
  library: { label: 'Library', icon: 'video_library' },
  player: { label: 'Player', icon: 'play_circle' },
  history: { label: 'History', icon: 'history' },
  browser: { label: 'Browser', icon: 'travel_explore' },
  settings: { label: 'Settings', icon: 'settings' },
};

export function Sidebar({ collapsed }: { collapsed: boolean }) {
  const screen = useUi((s) => s.screen);
  const go = useUi((s) => s.go);
  const toggle = useUi((s) => s.toggleSidebar);
  const tasks = useDownloads((s) => s.tasks);
  const summary = useMemo(() => summarize(tasks), [tasks]);

  const isCurrent = (id: Screen) => screen === id || (id === 'home' && screen === 'analysis');

  return (
    <nav
      aria-label="Main"
      className="flex shrink-0 flex-col gap-0.5 overflow-hidden border-r border-divider bg-sidebar px-2.5 py-3 transition-[width] duration-200 ease-standard"
      style={{ width: collapsed ? 64 : 232 }}
    >
      {SECTION_ORDER.map((id, i) => {
        const item = NAV[id]!;
        const on = isCurrent(id);
        const badge =
          id === 'downloads' && summary.openCount
            ? String(summary.openCount)
            : id === 'browser'
              ? 'Later'
              : '';
        return (
          <button
            key={id}
            type="button"
            onClick={() => go(id)}
            title={`${item.label} (Ctrl+${i + 1})`}
            aria-current={on ? 'page' : undefined}
            className={`flex h-10 items-center gap-3 overflow-hidden whitespace-nowrap rounded-sm px-[13px] text-left text-[13.5px] font-semibold transition-colors duration-[80ms] hover:text-fg ${
              on ? 'bg-surface text-fg' : 'text-muted'
            }`}
          >
            <Icon name={item.icon} fill={on} className={on ? 'text-accent-strong' : ''} />
            {!collapsed && (
              <>
                <span className="flex-1">{item.label}</span>
                {badge && (
                  <span
                    className={`rounded-xs px-1.5 py-0.5 font-mono text-[11px] font-semibold ${
                      id === 'browser'
                        ? 'bg-line-strong text-muted'
                        : 'bg-accent-subtle text-chip-text'
                    }`}
                  >
                    {badge}
                  </span>
                )}
              </>
            )}
          </button>
        );
      })}
      <div className="flex-1" />
      {!collapsed && (
        <button
          type="button"
          onClick={() => go('downloads')}
          className="mb-1.5 flex flex-col gap-2 rounded-md border border-surface2 bg-surface p-3 text-left"
        >
          <span className="flex w-full justify-between text-[12px]">
            <span className="font-semibold">{summary.stateLabel}</span>
            <span className="font-mono text-accent-strong">{summary.speedLabel}</span>
          </span>
          <ProgressBar
            value={summary.overallPercent}
            height={3}
            label="Overall download progress"
            className="w-full"
          />
          <span className="text-[11.5px] text-muted">{summary.queued.length} waiting in queue</span>
        </button>
      )}
      <button
        type="button"
        onClick={toggle}
        title="Toggle sidebar (Ctrl+B)"
        aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        className="flex h-9 items-center gap-3 whitespace-nowrap rounded-sm px-[13px] text-[12.5px] font-medium text-muted hover:bg-surface hover:text-fg"
      >
        <Icon name={collapsed ? 'left_panel_open' : 'left_panel_close'} />
        {!collapsed && (
          <>
            <span className="flex-1 text-left">Collapse</span>
            <Kbd>Ctrl B</Kbd>
          </>
        )}
      </button>
    </nav>
  );
}

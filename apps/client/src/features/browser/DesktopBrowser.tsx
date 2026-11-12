import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
} from 'react';
import { Icon } from '../../components/Icon';
import { t as tNow, useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { BrowserSnapshot, BrowserTab, Favorite } from '../../services/types';
import { useUi } from '../../stores/ui';
import { StartPage } from './BrowserView';
import { candidates, hostOf, splitAddress } from './candidates';
import { HistoryTab } from './HistoryTab';

/** How often the native page is asked for its state while shown. */
const POLL_MS = 250;

const EMPTY: BrowserSnapshot = {
  url: '',
  title: '',
  loading: false,
  canGoBack: false,
  canGoForward: false,
  startPage: true,
  sheet: false,
  media: [],
  streamPlayer: false,
  kind: 'start',
  tabs: [],
};

function report(e: unknown) {
  const full = (e as { code?: string } | null)?.code === 'too_many_tabs';
  useUi.getState().pushToast({
    tone: 'error',
    message: full ? tNow('bTooManyTabs') : e instanceof Error ? e.message : tNow('addressFailed'),
  });
}

/**
 * Windows v2 screen 8: tab strip (NAV-02), toolbar with the address pill,
 * then the page. Each tab's page is a child webview that Rust places over
 * the page area; the floating button and format sheet are the overlay's.
 * The history tab (miarina://history) and the start page are drawn here.
 */
export function DesktopBrowser({ covered }: { covered: boolean }) {
  const t = useT();
  const [state, setState] = useState<BrowserSnapshot>(EMPTY);
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState('');
  const [favorites, setFavorites] = useState<Favorite[]>([]);
  const [historyView, setHistoryView] = useState<'history' | 'favorites'>('history');
  const pageRef = useRef<HTMLDivElement>(null);
  const pushToast = useUi((s) => s.pushToast);
  const media = candidates(state);
  const tabs: BrowserTab[] = state.tabs?.length
    ? state.tabs
    : [
        {
          id: 0,
          kind: state.kind ?? 'start',
          title: state.title,
          url: state.url,
          media: media.length,
          loading: state.loading,
          active: true,
        },
      ];
  const kind = state.kind ?? (state.startPage ? 'start' : 'web');

  useEffect(() => {
    let alive = true;
    let timer = 0;
    const tick = async () => {
      try {
        const next = await backend.browserState();
        if (alive) setState(next);
      } catch {
        // Not available (preview): keep the start page.
      }
      if (alive) timer = window.setTimeout(tick, POLL_MS);
    };
    void tick();
    // Shortcuts pressed while the page had focus (Rust handles the tabs).
    const stopShortcuts = backend.onBrowserShortcut((name) => {
      if (name === 'Ctrl+L' || name === 'Ctrl+T') setEditing(true);
    });
    return () => {
      alive = false;
      window.clearTimeout(timer);
      stopShortcuts();
    };
  }, []);

  const loadFavorites = useCallback(() => {
    backend
      .browserFavorites()
      .then(setFavorites)
      .catch(() => {});
  }, []);
  useEffect(loadFavorites, [loadFavorites]);
  const starred = !!state.url && favorites.some((f) => f.url === state.url);
  const toggleFavorite = (url = state.url, title = state.title) => {
    backend
      .browserFavoriteToggle(url, title)
      .then((list) => {
        setFavorites(list);
        pushToast({
          tone: 'success',
          message: list.some((f) => f.url === url) ? tNow('favAdded') : tNow('favRemoved'),
        });
      })
      .catch(report);
  };

  // Place the selected tab's page over the page area, or hide it.
  const showPage = kind === 'web' && !covered;
  const place = useCallback(() => {
    const el = pageRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    void backend
      .browserFrame({
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        visible: showPage,
        fab: null,
        snapshot: false,
      })
      .catch(() => {});
  }, [showPage]);
  useLayoutEffect(() => {
    place();
    const el = pageRef.current;
    if (!el) return;
    const observer = new ResizeObserver(place);
    observer.observe(el);
    // The page area can move without changing size (sidebar, window).
    window.addEventListener('resize', place);
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', place);
    };
  }, [place]);
  useEffect(
    () => () => {
      void backend
        .browserFrame({
          x: 0,
          y: 0,
          width: 0,
          height: 0,
          visible: false,
          fab: null,
          snapshot: false,
        })
        .catch(() => {});
    },
    [],
  );

  const open = useCallback((address: string) => {
    setEditing(false);
    setError('');
    backend.browserNavigate(address).catch((e: unknown) => {
      setError(e instanceof Error ? e.message : tNow('addressFailed'));
    });
  }, []);

  // A search or address typed on Home.
  const request = useUi((s) => s.browserRequest);
  const openInBrowser = useUi((s) => s.openInBrowser);
  useEffect(() => {
    if (!request) return;
    openInBrowser(null);
    backend.browserNavigate(request).catch((e: unknown) => {
      setError(e instanceof Error ? e.message : tNow('addressFailed'));
    });
  }, [request, openInBrowser]);

  const newTab = () => {
    backend
      .browserTabNew()
      .then(() => setEditing(true))
      .catch(report);
  };
  const closeTab = (id: number) => void backend.browserTabClose(id).catch(report);
  const showHistory = (view: 'history' | 'favorites') => {
    setHistoryView(view);
    loadFavorites();
    void backend.browserTabNew({ kind: 'history' }).catch(report);
  };

  // Shortcuts while the app (not the page) has focus.
  const onKeyDown = (e: ReactKeyboardEvent) => {
    if (!e.ctrlKey || e.altKey) return;
    const key = e.key.toLowerCase();
    if (key === 't' && !e.shiftKey) newTab();
    else if (key === 'w' && !e.shiftKey) closeTab(tabs.find((x) => x.active)?.id ?? 0);
    else if (key === 'h' && !e.shiftKey) showHistory('history');
    else if (key === 'l' && !e.shiftKey) setEditing(true);
    else if (e.key === 'Tab') void backend.browserTabSelect({ step: e.shiftKey ? -1 : 1 });
    else return;
    e.preventDefault();
  };

  const { host, rest, secure } = splitAddress(state.url);
  const mediaChip =
    media.length === 0
      ? null
      : media.length === 1
        ? t('bMediaOne')
        : t('bMediaMany', { n: media.length });

  return (
    <div className="flex min-h-0 flex-1 flex-col" onKeyDown={onKeyDown}>
      <div
        role="tablist"
        aria-label={t('bTabs')}
        className="flex h-[38px] shrink-0 items-end gap-0.5 bg-sidebar px-2.5"
      >
        {tabs.map((tab) => (
          <TabItem key={tab.id} tab={tab} onClose={() => closeTab(tab.id)} />
        ))}
        <button
          type="button"
          onClick={newTab}
          aria-label={t('bNewTab')}
          title={t('bNewTab')}
          className="mb-px grid size-[30px] shrink-0 place-items-center rounded-sm text-muted hover:bg-line hover:text-fg"
        >
          <Icon name="add" size={18} />
        </button>
      </div>

      <div className="relative flex h-12 shrink-0 items-center gap-1 border-b border-line bg-surface px-3">
        <ToolButton
          icon="arrow_back"
          label={t('back')}
          disabled={!state.canGoBack}
          onClick={() => void backend.browserNav('back')}
        />
        <ToolButton
          icon="arrow_forward"
          label={t('forward')}
          disabled={!state.canGoForward}
          onClick={() => void backend.browserNav('forward')}
        />
        <ToolButton
          icon={state.loading ? 'close' : 'refresh'}
          label={state.loading ? t('bStop') : t('reload')}
          disabled={kind !== 'web'}
          onClick={() => void backend.browserNav(state.loading ? 'stop' : 'reload')}
        />
        <ToolButton
          icon="home"
          label={t('startPage')}
          onClick={() => void backend.browserNav('home').catch(report)}
        />

        {editing ? (
          <form
            role="search"
            className="mx-2 flex h-[34px] min-w-0 flex-1 items-center gap-2 rounded-[17px] border border-accent bg-bg px-3.5"
            onSubmit={(e) => {
              e.preventDefault();
              const text = new FormData(e.currentTarget).get('address')?.toString().trim() ?? '';
              if (text) open(text);
            }}
          >
            <Icon name="search" size={16} className="text-muted" />
            <input
              name="address"
              autoFocus
              defaultValue={kind === 'web' ? state.url : ''}
              aria-label={t('addressPh')}
              placeholder={t('addressPh')}
              autoCapitalize="off"
              autoCorrect="off"
              spellCheck={false}
              onFocus={(e) => e.currentTarget.select()}
              onBlur={() => setEditing(false)}
              onKeyDown={(e) => {
                if (e.key === 'Escape') setEditing(false);
              }}
              className="min-w-0 flex-1 bg-transparent font-mono text-[12.5px] text-fg outline-none placeholder:font-sans placeholder:text-muted"
            />
          </form>
        ) : (
          <div className="mx-2 flex h-[34px] min-w-0 flex-1 items-center gap-2 rounded-[17px] border border-line-strong bg-bg pl-3.5 pr-1.5">
            <button
              type="button"
              onClick={() => setEditing(true)}
              aria-label={kind === 'web' ? t('addressEdit', { url: state.url }) : t('addressPh')}
              className="flex h-full min-w-0 flex-1 items-center gap-2 text-left font-mono text-[12.5px]"
            >
              {kind === 'web' ? (
                <>
                  <Icon
                    name={secure ? 'lock' : 'info'}
                    size={16}
                    className={secure ? 'text-accent-strong' : 'text-muted'}
                  />
                  <span className="shrink-0">{host || hostOf(state.url)}</span>
                  <span className="min-w-0 flex-1 truncate text-muted">{rest}</span>
                </>
              ) : kind === 'history' ? (
                <>
                  <Icon name="shield_with_heart" size={16} className="text-accent-strong" />
                  <span className="min-w-0 flex-1 truncate">miarina://history</span>
                </>
              ) : (
                <>
                  <Icon name="search" size={16} className="text-muted" />
                  <span className="min-w-0 flex-1 truncate font-sans text-muted">
                    {t('addressPh')}
                  </span>
                </>
              )}
            </button>
            {mediaChip && (
              <button
                type="button"
                onClick={() => void backend.browserSheet(true)}
                aria-label={t('downloadFound', { n: media.length })}
                className="shrink-0 rounded-[11px] bg-accent-subtle px-[9px] py-[3px] font-sans text-[11.5px] font-bold text-chip-text"
              >
                {mediaChip}
              </button>
            )}
          </div>
        )}

        <ToolButton
          icon="star"
          fill={starred}
          label={starred ? t('favRemove') : t('favAdd')}
          pressed={starred}
          disabled={kind !== 'web'}
          onClick={() => toggleFavorite()}
          className={starred ? 'text-planned' : undefined}
        />
        <ToolButton
          icon="bookmarks"
          label={t('favorites')}
          onClick={() => showHistory('favorites')}
        />
        <ToolButton icon="history" label={t('bHistory')} onClick={() => showHistory('history')} />
        {state.loading && (
          <div
            aria-hidden="true"
            className="absolute bottom-[-1px] left-0 h-0.5 w-1/3 animate-pulse bg-accent"
          />
        )}
      </div>

      <div ref={pageRef} className="relative min-h-0 flex-1 overflow-hidden bg-bg">
        {kind === 'history' ? (
          <HistoryTab
            view={historyView}
            onView={setHistoryView}
            favorites={favorites}
            onOpen={open}
            onUnstar={(f) => toggleFavorite(f.url, f.title)}
          />
        ) : kind === 'start' ? (
          <StartPage error={error} favorites={favorites} onOpen={open} />
        ) : null}
      </div>
    </div>
  );
}

function TabItem({ tab, onClose }: { tab: BrowserTab; onClose: () => void }) {
  const t = useT();
  const title =
    tab.kind === 'history'
      ? t('bHistory')
      : tab.kind === 'start'
        ? t('bStartTab')
        : tab.title || hostOf(tab.url) || tab.url;
  return (
    <div
      className={`group flex h-8 min-w-[90px] max-w-[220px] flex-1 items-center gap-2 rounded-t-lg pl-3 pr-1.5 text-[12.5px] font-semibold ${
        tab.active ? 'bg-surface text-fg' : 'text-muted hover:bg-line hover:text-fg'
      }`}
      onAuxClick={(e) => {
        if (e.button === 1) onClose();
      }}
    >
      <button
        type="button"
        role="tab"
        aria-selected={tab.active}
        title={tab.kind === 'web' ? tab.url : title}
        onClick={() => void backend.browserTabSelect({ id: tab.id }).catch(report)}
        className="flex h-full min-w-0 flex-1 items-center gap-2 text-left"
      >
        <Icon
          name={
            tab.kind === 'history'
              ? 'shield_with_heart'
              : tab.loading
                ? 'progress_activity'
                : 'public'
          }
          size={16}
          className={tab.loading ? 'shrink-0 animate-spin' : 'shrink-0'}
        />
        <span className="min-w-0 flex-1 truncate">{title}</span>
        {tab.media > 0 && (
          <span
            aria-label={t('downloadFound', { n: tab.media })}
            className="shrink-0 rounded-xs bg-accent px-[5px] py-px font-mono text-[10.5px] font-bold text-accent-ink"
          >
            {tab.media}
          </span>
        )}
      </button>
      <button
        type="button"
        onClick={onClose}
        aria-label={t('bCloseTab', { title })}
        className="grid size-5 shrink-0 place-items-center rounded-xs text-muted hover:bg-line-strong hover:text-fg"
      >
        <Icon name="close" size={15} />
      </button>
    </div>
  );
}

function ToolButton({
  icon,
  label,
  onClick,
  disabled = false,
  pressed,
  fill,
  className,
}: {
  icon: string;
  label: string;
  onClick: () => void;
  disabled?: boolean;
  pressed?: boolean;
  fill?: boolean;
  className?: string;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      aria-pressed={pressed}
      disabled={disabled}
      onClick={onClick}
      className={`grid size-[34px] shrink-0 place-items-center rounded-sm hover:bg-line hover:text-fg disabled:text-faint-icon disabled:hover:bg-transparent ${
        className ?? 'text-muted'
      }`}
    >
      <Icon name={icon} size={20} fill={fill} />
    </button>
  );
}

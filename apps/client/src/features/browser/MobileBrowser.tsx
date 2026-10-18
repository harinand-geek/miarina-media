import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Icon } from '../../components/Icon';
import { Logo } from '../../components/Logo';
import { backend } from '../../services/backend';
import type { BrowserSnapshot } from '../../services/types';
import { useUi, type AnalysisChoice } from '../../stores/ui';
import { defaultFormat, shortQuality, useStartActions } from '../analysis/useAnalysis';
import { candidates, distinctLabels, hostOf, mainCandidate, splitAddress } from './candidates';
import { browserBack } from './browserBack';
import { StartShortcuts } from './StartShortcuts';

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
};

interface MobileBrowserProps {
  /** An app panel (sheet, settings, player, dialog) covers the page. */
  covered: boolean;
  onExit: () => void;
  onOpenSettings: () => void;
  onShowDownloads: () => void;
}

/**
 * Android browser (design M1): address bar on top with page-load line,
 * the page in the middle, browser bar at the bottom. The page itself is a
 * native WebView (`BrowserPlugin.kt`) placed over the page area; native
 * views draw above the app, so the page is hidden while an app panel
 * covers it and a picture of it is shown instead.
 */
export function MobileBrowser({
  covered,
  onExit,
  onOpenSettings,
  onShowDownloads,
}: MobileBrowserProps) {
  const [state, setState] = useState<BrowserSnapshot>(EMPTY);
  const [menuOpen, setMenuOpen] = useState(false);
  const [editing, setEditing] = useState(false);
  const [picture, setPicture] = useState<string | null>(null);
  const [error, setError] = useState('');
  const pageRef = useRef<HTMLDivElement>(null);
  const analyzeChoice = useUi((s) => s.analyzeChoice);
  const pushToast = useUi((s) => s.pushToast);
  const { download } = useStartActions();

  const media = candidates(state);
  const labels = distinctLabels(media.map((c) => c.title));
  const choices: AnalysisChoice[] = media.map((c, i) => ({
    url: c.url,
    label: labels[i] ?? c.title,
    kind: c.kind === 'audio' ? 'audio' : 'video',
  }));
  const first = mainCandidate(media);
  const fabLabel =
    media.length === 0 ? null : media.length === 1 ? 'Download' : `Download · ${media.length}`;

  const openSheet = useCallback(() => {
    if (first) analyzeChoice(first.url, choices);
    // `choices` follows `first`: both come from the same snapshot.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [first?.url, media.length, analyzeChoice]);

  /** Long press on the button: default format, no sheet (design notes M1). */
  const quickDownload = useCallback(async () => {
    if (!first) return;
    try {
      const result = await backend.analyze(first.url);
      if (!result.ok) throw new Error('not downloadable');
      const kind = result.info.formats.video.length ? 'video' : 'audio';
      const format = defaultFormat(result.info.formats[kind]);
      if (!format) throw new Error('no format');
      if (await download(result.info, format, kind)) {
        pushToast({
          tone: 'success',
          message: `Downloading · ${shortQuality(format)}`,
          action: { label: 'View', run: onShowDownloads },
        });
      }
    } catch {
      pushToast({ tone: 'error', message: 'This media cannot be downloaded directly.' });
    }
  }, [first, download, pushToast, onShowDownloads]);

  // Page state, while the browser is shown.
  const gesture = useRef({ openSheet, quickDownload });
  useEffect(() => {
    gesture.current = { openSheet, quickDownload };
  });
  useEffect(() => {
    let alive = true;
    let timer = 0;
    const tick = async () => {
      try {
        const next = await backend.browserState();
        if (!alive) return;
        setState(next);
        if (next.fab === 'tap') gesture.current.openSheet();
        else if (next.fab === 'hold') void gesture.current.quickDownload();
      } catch {
        // Not available (preview): keep the start page.
      }
      if (alive) timer = window.setTimeout(tick, POLL_MS);
    };
    void tick();
    return () => {
      alive = false;
      window.clearTimeout(timer);
    };
  }, []);

  // Place the native page over the page area, or hide it.
  const showPage = !state.startPage && !covered && !menuOpen;
  const shown = useRef(false);
  const place = useCallback(() => {
    const el = pageRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const hiding = shown.current && !showPage;
    shown.current = showPage;
    void backend
      .browserFrame({
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        visible: showPage,
        fab: showPage ? fabLabel : null,
        snapshot: hiding,
      })
      .then((jpeg) => {
        if (hiding) setPicture(jpeg);
        else if (showPage) setPicture(null);
      })
      .catch(() => {});
  }, [showPage, fabLabel]);
  useLayoutEffect(() => {
    place();
    const el = pageRef.current;
    if (!el) return;
    const observer = new ResizeObserver(place);
    observer.observe(el);
    return () => observer.disconnect();
  }, [place]);
  useEffect(
    () => () => {
      shown.current = false;
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

  useEffect(() => {
    browserBack.current = () => {
      if (menuOpen) setMenuOpen(false);
      else if (editing) setEditing(false);
      else if (state.canGoBack) void backend.browserNav('back');
      else return false;
      return true;
    };
    return () => {
      browserBack.current = null;
    };
  }, [menuOpen, editing, state.canGoBack]);

  const open = (address: string) => {
    setEditing(false);
    setError('');
    backend.browserNavigate(address).catch((e: unknown) => {
      setError(e instanceof Error ? e.message : 'This address cannot be opened');
    });
  };

  return (
    <div className="relative flex min-h-0 flex-1 flex-col">
      <div className="flex h-[60px] shrink-0 items-center gap-1 pl-3 pr-1.5">
        <AddressBar
          state={state}
          editing={editing}
          mediaCount={media.length}
          onEdit={() => setEditing(true)}
          onCancel={() => setEditing(false)}
          onSubmit={open}
          onMedia={openSheet}
        />
        <span role="img" aria-label="1 tab" className="grid size-11 shrink-0 place-items-center">
          <span className="grid size-[22px] place-items-center rounded-[5px] border-2 border-fg text-[11px] font-extrabold">
            1
          </span>
        </span>
        <button
          type="button"
          aria-label="More"
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          onClick={() => setMenuOpen((o) => !o)}
          className="grid size-11 shrink-0 place-items-center rounded-full active:bg-line-strong"
        >
          <Icon name="more_vert" size={24} />
        </button>
      </div>
      <div className="h-[3px] shrink-0 bg-surface" aria-hidden="true">
        {state.loading && (
          <div
            className="h-full bg-accent transition-[width] duration-200"
            style={{ width: `${Math.max(state.progress ?? 0, 8)}%` }}
          />
        )}
      </div>

      <div ref={pageRef} className="relative min-h-0 flex-1 overflow-hidden bg-bg">
        {state.startPage ? (
          <StartPage error={error} onOpen={open} />
        ) : (
          picture && (
            <img
              src={picture}
              alt=""
              className="absolute inset-0 h-full w-full object-cover object-top"
            />
          )
        )}
      </div>

      <nav
        aria-label="Browser"
        className="grid h-16 shrink-0 grid-cols-5 items-center border-t border-divider bg-sidebar"
      >
        <BarButton
          icon="arrow_back"
          label="Back"
          disabled={!state.canGoBack}
          onClick={() => void backend.browserNav('back')}
        />
        <BarButton
          icon="arrow_forward"
          label="Forward"
          disabled={!state.canGoForward}
          onClick={() => void backend.browserNav('forward')}
        />
        <BarButton icon="home" label="Start page" onClick={() => void backend.browserNav('home')} />
        <BarButton icon="history" label="History (coming soon)" disabled onClick={() => {}} />
        <BarButton icon="apps" label="Back to Miarina Media" accent onClick={onExit} />
      </nav>

      {menuOpen && (
        <>
          <div
            className="absolute inset-0 z-20"
            aria-hidden="true"
            onClick={() => setMenuOpen(false)}
          />
          <div
            role="menu"
            aria-label="Browser menu"
            className="absolute right-3.5 top-14 z-20 flex w-[220px] animate-fade-in flex-col rounded-[12px] border border-overlay-border bg-surface2 p-1.5 shadow-menu"
          >
            {!state.startPage && (
              <MenuRow
                icon="refresh"
                label="Reload"
                onSelect={() => {
                  setMenuOpen(false);
                  void backend.browserNav('reload');
                }}
              />
            )}
            <MenuRow
              icon="settings"
              label="Settings"
              onSelect={() => {
                setMenuOpen(false);
                onOpenSettings();
              }}
            />
          </div>
        </>
      )}
    </div>
  );
}

function AddressBar({
  state,
  editing,
  mediaCount,
  onEdit,
  onCancel,
  onSubmit,
  onMedia,
}: {
  state: BrowserSnapshot;
  editing: boolean;
  mediaCount: number;
  onEdit: () => void;
  onCancel: () => void;
  onSubmit: (address: string) => void;
  onMedia: () => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (editing) inputRef.current?.select();
  }, [editing]);
  const { host, secure } = splitAddress(state.url);

  if (editing) {
    return (
      <form
        role="search"
        className="flex h-11 min-w-0 flex-1 items-center gap-2 rounded-[22px] border border-accent bg-surface pl-3.5 pr-1.5"
        onSubmit={(e) => {
          e.preventDefault();
          const text = inputRef.current?.value.trim() ?? '';
          if (text) onSubmit(text);
        }}
      >
        <Icon name="search" size={18} className="text-muted" />
        <input
          ref={inputRef}
          autoFocus
          defaultValue={state.url}
          aria-label="Search or type a web address"
          placeholder="Search or type a web address"
          enterKeyHint="go"
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
          inputMode="url"
          onBlur={onCancel}
          className="min-w-0 flex-1 bg-transparent font-mono text-[14px] text-fg outline-none placeholder:font-sans placeholder:text-muted"
        />
      </form>
    );
  }
  return (
    <div className="flex h-11 min-w-0 flex-1 items-center gap-2 rounded-[22px] bg-surface pl-3.5 pr-1.5">
      <button
        type="button"
        onClick={onEdit}
        aria-label={state.url ? `Address: ${state.url}. Edit` : 'Search or type a web address'}
        className="flex h-full min-w-0 flex-1 items-center gap-2 text-left"
      >
        {state.startPage ? (
          <>
            <Icon name="search" size={18} className="text-muted" />
            <span className="truncate text-[14px] text-muted">Search or type a web address</span>
          </>
        ) : (
          <>
            <Icon
              name={secure ? 'lock' : 'info'}
              size={18}
              className={secure ? 'text-accent' : 'text-muted'}
            />
            <span className="min-w-0 flex-1 truncate font-mono text-[14px]">
              {host || hostOf(state.url)}
            </span>
          </>
        )}
      </button>
      {mediaCount > 0 && (
        <button
          type="button"
          onClick={onMedia}
          aria-label={`Download media found on this page (${mediaCount})`}
          className="flex h-8 shrink-0 items-center gap-1 rounded-2xl border border-chip-border bg-accent-subtle px-2.5 text-[13px] font-bold text-chip-text"
        >
          <Icon name="download" size={16} />
          {mediaCount}
        </button>
      )}
    </div>
  );
}

function StartPage({ error, onOpen }: { error: string; onOpen: (address: string) => void }) {
  return (
    <main className="flex h-full flex-col items-center gap-6 overflow-auto px-4 pb-6 pt-10 text-center">
      <div className="flex flex-col items-center gap-3">
        <Logo size={44} />
        <h1 className="m-0 text-[17px] font-bold">Search or open a web page</h1>
        <p className="m-0 max-w-[320px] text-[13px] text-muted">
          When a page has a video or audio file, a download button appears above the bar.
        </p>
      </div>
      {error && (
        <p role="alert" className="m-0 text-[13px] text-danger">
          {error}
        </p>
      )}
      <StartShortcuts onOpen={onOpen} />
      <p className="m-0 mt-auto text-[12px] text-faint">
        Only download media you own or have permission to save.
      </p>
    </main>
  );
}

function BarButton({
  icon,
  label,
  disabled = false,
  accent = false,
  onClick,
}: {
  icon: string;
  label: string;
  disabled?: boolean;
  accent?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={`grid h-12 place-items-center ${accent ? 'text-accent' : 'text-fg'} disabled:text-faint-icon`}
    >
      <Icon name={icon} size={24} />
    </button>
  );
}

function MenuRow({ icon, label, onSelect }: { icon: string; label: string; onSelect: () => void }) {
  return (
    <button
      type="button"
      role="menuitem"
      onClick={onSelect}
      className="flex h-12 items-center gap-3 rounded-lg px-3 text-left text-[14px] text-fg active:bg-secondary-hover"
    >
      <Icon name={icon} size={22} className="text-muted" />
      {label}
    </button>
  );
}

import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { Icon } from '../../components/Icon';
import { Logo } from '../../components/Logo';
import { backend } from '../../services/backend';
import type { BrowserAction, BrowserSnapshot } from '../../services/types';
import { closeWindow, minimizeWindow, toggleMaximizeWindow } from '../../services/window';
import { summarize, useDownloads } from '../../stores/downloads';
import { candidates, hostOf, splitAddress } from './candidates';
import { useBrowserState } from './useBrowserState';

const WINDOW_BUTTON =
  'grid h-10 w-[46px] place-items-center text-muted transition-colors duration-[80ms] hover:bg-surface hover:text-fg';
const TOOL_BUTTON =
  'grid size-[34px] shrink-0 place-items-center rounded-sm transition-colors duration-[80ms] hover:bg-line disabled:text-faint disabled:hover:bg-transparent';

/**
 * Browser window chrome (design D1): title bar with the tab, toolbar with
 * the address bar. Fills the window on the start page, otherwise sits above
 * the page webview.
 */
export function BrowserChrome() {
  const state = useBrowserState();
  if (!state) return <div className="h-full bg-sidebar" />;
  return (
    <div className="flex h-full flex-col">
      <TitleStrip state={state} />
      <Toolbar state={state} />
      {state.startPage && <StartPage />}
    </div>
  );
}

function TitleStrip({ state }: { state: BrowserSnapshot }) {
  const count = candidates(state).length;
  const title = state.startPage ? 'New tab' : state.title || hostOf(state.url) || 'Loading…';
  return (
    <header data-tauri-drag-region className="flex h-10 shrink-0 items-end bg-sidebar pl-3">
      <div data-tauri-drag-region className="flex h-10 items-center pr-3">
        <Logo size={18} />
      </div>
      <div
        role="tab"
        aria-selected="true"
        className="flex h-[34px] w-[220px] min-w-[120px] items-center gap-2 rounded-t-md bg-surface pl-3 pr-1.5 text-fg"
        title={state.url || undefined}
      >
        <Icon
          name={state.loading ? 'progress_activity' : count ? 'movie' : 'public'}
          size={16}
          className={state.loading ? 'animate-spin text-muted' : ''}
        />
        <span className="min-w-0 flex-1 truncate text-[12.5px] font-semibold">{title}</span>
        {count > 0 && (
          <span className="rounded-xs bg-accent-subtle px-[5px] py-px font-mono text-[10.5px] font-semibold text-chip-text">
            {count}
          </span>
        )}
        {!state.startPage && (
          <button
            type="button"
            aria-label="Close tab"
            onClick={() => void backend.browserNav('home')}
            className="grid size-[22px] place-items-center rounded-xs hover:bg-line"
          >
            <Icon name="close" size={14} />
          </button>
        )}
      </div>
      <div data-tauri-drag-region className="h-10 flex-1" />
      <div className="flex h-10 self-start">
        <button
          type="button"
          aria-label="Minimize"
          className={WINDOW_BUTTON}
          onClick={minimizeWindow}
        >
          <Icon name="remove" size={16} />
        </button>
        <button
          type="button"
          aria-label="Maximize"
          className={WINDOW_BUTTON}
          onClick={toggleMaximizeWindow}
        >
          <Icon name="crop_square" size={14} />
        </button>
        <button
          type="button"
          aria-label="Close"
          className={`${WINDOW_BUTTON} hover:bg-window-close hover:text-white`}
          onClick={closeWindow}
        >
          <Icon name="close" size={16} />
        </button>
      </div>
    </header>
  );
}

function Toolbar({ state }: { state: BrowserSnapshot }) {
  const tasks = useDownloads((s) => s.tasks);
  const openDownloads = useMemo(() => summarize(tasks).openCount, [tasks]);
  const count = candidates(state).length;
  const nav = (action: BrowserAction) => void backend.browserNav(action);

  return (
    <div className="flex h-12 shrink-0 items-center gap-1 border-b border-line bg-surface px-2.5">
      <button
        type="button"
        className={TOOL_BUTTON}
        aria-label="Back"
        title="Back · Alt+←"
        disabled={!state.canGoBack}
        onClick={() => nav('back')}
      >
        <Icon name="arrow_back" />
      </button>
      <button
        type="button"
        className={TOOL_BUTTON}
        aria-label="Forward"
        title="Forward · Alt+→"
        disabled={!state.canGoForward}
        onClick={() => nav('forward')}
      >
        <Icon name="arrow_forward" />
      </button>
      <button
        type="button"
        className={TOOL_BUTTON}
        aria-label={state.loading ? 'Stop' : 'Reload'}
        title={state.loading ? 'Stop · Esc' : 'Reload · F5'}
        disabled={state.startPage}
        onClick={() => nav(state.loading ? 'stop' : 'reload')}
      >
        <Icon name={state.loading ? 'close' : 'refresh'} />
      </button>
      <button
        type="button"
        className={TOOL_BUTTON}
        aria-label="Home"
        title="Home"
        onClick={() => nav('home')}
      >
        <Icon name="home" />
      </button>
      <AddressBar state={state} count={count} />
      <button
        type="button"
        className={`${TOOL_BUTTON} relative`}
        aria-label={openDownloads ? `Downloads, ${openDownloads} in progress` : 'Downloads'}
        title="Downloads"
        onClick={() => void backend.browserShowInApp('downloads')}
      >
        <Icon name="download" />
        {openDownloads > 0 && (
          <span className="absolute right-0.5 top-[3px] grid h-[15px] min-w-[15px] place-items-center rounded-lg bg-accent px-[3px] text-[9.5px] font-bold text-accent-ink">
            {openDownloads}
          </span>
        )}
      </button>
    </div>
  );
}

function AddressBar({ state, count }: { state: BrowserSnapshot; count: number }) {
  const input = useRef<HTMLInputElement>(null);
  const [draft, setDraft] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const editing = draft !== null;
  const address = splitAddress(state.url);

  const focus = () => {
    setDraft((d) => d ?? state.url);
    requestAnimationFrame(() => input.current?.select());
  };

  // Ctrl+L (also from the page) and the start page focus the address bar;
  // `onFocus` then opens the editor.
  useEffect(
    () =>
      backend.onBrowserShortcut((name) => {
        if (name === 'Ctrl+L') input.current?.focus();
      }),
    [],
  );
  useEffect(() => {
    if (state.startPage) input.current?.focus();
  }, [state.startPage]);

  const submit = async () => {
    if (draft === null) return;
    try {
      await backend.browserNavigate(draft);
      setDraft(null);
      setError(null);
      input.current?.blur();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const onKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') void submit();
    if (e.key === 'Escape') {
      setDraft(null);
      setError(null);
      input.current?.blur();
    }
  };

  return (
    <div
      className={`mx-1.5 flex h-[34px] min-w-0 flex-1 items-center gap-2 rounded-[17px] border bg-bg pl-3 pr-1.5 ${
        error ? 'border-danger' : 'border-line-strong focus-within:border-accent'
      }`}
    >
      <Icon
        name={error ? 'error' : address.secure || editing ? 'lock' : 'info'}
        size={16}
        className={error ? 'text-danger' : address.secure ? 'text-accent-strong' : 'text-muted'}
      />
      <div className="relative flex h-full min-w-0 flex-1 items-center">
        <input
          ref={input}
          aria-label="Address"
          aria-invalid={!!error}
          aria-describedby={error ? 'address-error' : undefined}
          spellCheck={false}
          autoComplete="off"
          placeholder={editing || !state.url ? 'Type a web address' : undefined}
          value={draft ?? ''}
          onChange={(e) => {
            setDraft(e.target.value);
            setError(null);
          }}
          onFocus={focus}
          onBlur={() => {
            if (!error) setDraft(null);
          }}
          onKeyDown={onKeyDown}
          className={`h-full w-full bg-transparent font-mono text-[12.5px] outline-none ${
            editing ? '' : 'text-transparent'
          }`}
        />
        {!editing && state.url && (
          <span
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 flex items-center truncate font-mono text-[12.5px]"
          >
            <span>{address.host}</span>
            <span className="truncate text-muted">{address.rest}</span>
          </span>
        )}
      </div>
      {error ? (
        <span id="address-error" role="alert" className="truncate text-[12px] text-danger">
          {error}
        </span>
      ) : (
        count > 0 &&
        !state.startPage && (
          <button
            type="button"
            onClick={() => void backend.browserSheet(true)}
            title="Download from this page · Ctrl+Shift+S"
            className="flex h-6 shrink-0 items-center gap-[5px] rounded-xl border border-chip-border bg-accent-subtle px-2.5 text-[12px] font-bold text-chip-text"
          >
            <Icon name="download" size={15} />
            {count} media
          </button>
        )
      )}
    </div>
  );
}

/** Not in the handoff: built from design-system pieces (empty-state pattern). */
function StartPage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-3 px-6 text-center">
      <Icon name="travel_explore" size={40} className="text-faint-icon" />
      <h1 className="m-0 text-[15px] font-bold">Open a web page</h1>
      <p className="m-0 max-w-[440px] text-[13px] text-muted">
        Type an address above. When a page has video or audio, a download button appears in the
        corner.
      </p>
      <p className="m-0 text-[12px] text-faint">
        Only download media you own or have permission to save.
      </p>
    </main>
  );
}

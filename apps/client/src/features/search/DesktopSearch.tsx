import { useEffect, useRef, useState } from 'react';
import { Kbd } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { usePlayer } from '../../stores/player';
import { useUi } from '../../stores/ui';
import { LinkIssueNote } from '../home/LinkIssueNote';
import { useLinkInput } from '../home/useLinkInput';
import { durationLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { isWebLink, useLocalResults, youtubeSearch } from './searchLogic';
import { SiteTiles } from './SiteTiles';

const RESULTS = 8;

function ActionRow({
  icon,
  label,
  onClick,
  strong = false,
}: {
  icon: string;
  label: string;
  onClick: () => void;
  strong?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex h-11 w-full items-center gap-3 rounded-xl px-2 text-left text-[13.5px] font-semibold hover:bg-surface focus-visible:bg-surface"
    >
      <span
        className={`grid h-8 w-8 shrink-0 place-items-center rounded-full ${strong ? 'bg-accent-subtle text-chip-text' : 'bg-surface2 text-muted'}`}
      >
        <Icon name={icon} size={18} />
      </span>
      <span className="min-w-0 flex-1 truncate">{label}</span>
    </button>
  );
}

/**
 * Windows title bar search (decision 0006), the desktop form of the Android
 * search page: a field that opens a panel. Empty: the sites. Words: what is
 * on this computer first, then "search on YouTube / the web"; Enter with
 * nothing found locally opens YouTube in the built-in browser, ↓ walks the
 * results. A link: analyzed. Ctrl+K focuses it, Escape closes it.
 */
export function DesktopSearch() {
  const t = useT();
  const { url: q, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();
  const openInBrowser = useUi((s) => s.openInBrowser);
  const go = useUi((s) => s.go);
  const focusRequest = useUi((s) => s.searchFocus);
  const open = useUi((s) => s.searchOpen);
  const setOpen = (searchOpen: boolean) => useUi.setState({ searchOpen });
  const box = useRef<HTMLDivElement>(null);
  const panel = useRef<HTMLDivElement>(null);
  const isLink = isWebLink(q);
  const words = q.trim();
  const results = useLocalResults(isLink ? '' : q, RESULTS);
  const [focused, setFocused] = useState(false);

  // Ctrl+K from anywhere.
  useEffect(() => {
    if (!focusRequest) return;
    inputRef.current?.focus();
    inputRef.current?.select();
  }, [focusRequest, inputRef]);

  // A click elsewhere closes the panel.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('pointerdown', onDown);
    return () => document.removeEventListener('pointerdown', onDown);
  }, [open]);

  const done = () => {
    change('');
    setOpen(false);
    inputRef.current?.blur();
  };
  const web = (text: string) => {
    openInBrowser(text);
    done();
  };
  const play = (m: MediaRecord, list: MediaRecord[]) => {
    usePlayer.getState().playMedia(m, list);
    if (m.kind === 'video') go('player');
    done();
  };

  const onSubmit = () => {
    if (!words) return;
    if (isLink) {
      void submit().then(() => {
        if (useUi.getState().screen === 'analysis') done();
      });
      return;
    }
    if (results && results.length === 0) web(youtubeSearch(words, false));
    else if (results?.[0]) play(results[0], results);
  };

  return (
    <div ref={box} className="relative w-[460px] max-w-full">
      <form
        role="search"
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit();
        }}
        className={`flex h-8 items-center gap-2 rounded-full border bg-surface pl-3 pr-1 transition-colors duration-150 ${
          focused ? 'border-accent' : 'border-line'
        }`}
      >
        <Icon name="search" size={17} className="text-muted" />
        <input
          ref={inputRef}
          type="search"
          value={q}
          onChange={(e) => {
            change(e.target.value);
            setOpen(true);
          }}
          onFocus={() => {
            setFocused(true);
            setOpen(true);
          }}
          onBlur={() => setFocused(false)}
          onKeyDown={(e) => {
            if (e.key === 'Escape') {
              e.preventDefault();
              setOpen(false);
              inputRef.current?.blur();
            } else if (e.key === 'ArrowDown') {
              e.preventDefault();
              panel.current?.querySelector<HTMLButtonElement>('button')?.focus();
            }
          }}
          placeholder={t('mSearchField')}
          aria-label={t('mSearchField')}
          aria-expanded={open}
          aria-controls="title-search-panel"
          autoComplete="off"
          className="h-full min-w-0 flex-1 bg-transparent text-[12.5px] text-fg outline-none placeholder:text-muted focus-visible:outline-none"
        />
        {words ? (
          <button
            type="button"
            aria-label={t('clearSearch')}
            onClick={() => {
              change('');
              inputRef.current?.focus();
            }}
            className="grid h-6 w-6 place-items-center rounded-full text-muted hover:text-fg"
          >
            <Icon name="close" size={16} />
          </button>
        ) : (
          <span className="pr-1.5">
            <Kbd>Ctrl K</Kbd>
          </span>
        )}
      </form>

      {open && (
        <div
          id="title-search-panel"
          ref={panel}
          onKeyDown={(e) => {
            if (e.key === 'Escape') {
              setOpen(false);
              inputRef.current?.focus();
            }
          }}
          className="absolute left-1/2 top-10 z-50 flex max-h-[70vh] w-[560px] -translate-x-1/2 animate-fade-in flex-col gap-3 overflow-auto rounded-[22px] border border-line bg-sidebar p-4 shadow-dialog"
        >
          {isLink && issue && (
            <LinkIssueNote id="title-search-issue" issue={issue} onFix={applyFix} compact />
          )}
          {!words && (
            <section aria-label={t('sites')} className="flex flex-col gap-3">
              <div className="flex items-center justify-between">
                <h2 className="m-0 text-[13px] font-bold">{t('sites')}</h2>
                <button
                  type="button"
                  onClick={paste}
                  className="flex h-8 items-center gap-1.5 rounded-full bg-surface px-3 text-[12px] font-semibold hover:bg-surface2"
                >
                  <Icon name="content_paste" size={16} />
                  {t('pasteShort')}
                </button>
              </div>
              <SiteTiles label={t('sites')} onOpen={web} />
              <p className="m-0 text-[12px] text-muted">{t('searchHintDesktop')}</p>
            </section>
          )}

          {isLink && (
            <ActionRow icon="download" label={t('analyzeLink')} onClick={onSubmit} strong />
          )}

          {words && !isLink && (
            <>
              {results && results.length > 0 && (
                <section aria-label={t('onThisComputer')} className="flex flex-col">
                  <h2 className="m-0 px-2 pb-1 text-[12px] font-bold text-muted">
                    {t('onThisComputer')}
                  </h2>
                  {results.map((m) => (
                    <button
                      key={m.id}
                      type="button"
                      onClick={() => play(m, results)}
                      aria-label={t('playTitle', { title: m.title })}
                      className="flex h-14 w-full items-center gap-3 rounded-xl px-2 text-left hover:bg-surface focus-visible:bg-surface"
                    >
                      <MediaThumb media={m} className="h-10 w-10 rounded-[10px]" />
                      <span className="flex min-w-0 flex-1 flex-col">
                        <span className="truncate text-[13.5px] font-bold">{m.title}</span>
                        <span className="truncate text-[12px] text-muted">
                          {[
                            m.kind === 'video' ? t('kindVideo') : m.artist,
                            durationLabel(m.durationSecs),
                          ]
                            .filter(Boolean)
                            .join(' · ')}
                        </span>
                      </span>
                    </button>
                  ))}
                </section>
              )}
              {results && results.length === 0 && (
                <p className="m-0 px-2 text-[13px] text-muted">
                  {t('notOnComputer', { q: words })}
                </p>
              )}
              <section
                aria-label={t('searchWeb')}
                className="flex flex-col border-t border-divider pt-2"
              >
                <ActionRow
                  icon="smart_display"
                  label={t('searchOnYoutube', { q: words })}
                  onClick={() => web(youtubeSearch(words, false))}
                  strong
                />
                <ActionRow
                  icon="travel_explore"
                  label={t('searchOnWeb', { q: words })}
                  onClick={() => web(words)}
                />
              </section>
            </>
          )}
        </div>
      )}
    </div>
  );
}

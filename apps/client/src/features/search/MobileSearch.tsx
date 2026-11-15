import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import { useMobilePlayback } from '../../stores/mobilePlayback';
import { useUi } from '../../stores/ui';
import { LinkIssueNote } from '../home/LinkIssueNote';
import { linkFieldBorder, useLinkInput } from '../home/useLinkInput';
import { durationLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { isWebLink, useLocalResults, youtubeSearch } from './searchLogic';
import { SiteTiles } from './SiteTiles';

const RESULTS = 30;

/**
 * Android search (decision 0006): one field for the library, the web and
 * links. Empty: site shortcuts. Words: local results first, then "search on
 * YouTube / the web"; Enter with nothing found locally opens YouTube in the
 * built-in browser. A link: analyzed, as on the Downloads card.
 */
export function MobileSearch({ onClose }: { onClose: () => void }) {
  const t = useT();
  const { url: q, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();
  const openInBrowser = useUi((s) => s.openInBrowser);
  const isLink = isWebLink(q);
  const results = useLocalResults(isLink ? '' : q, RESULTS);
  const words = q.trim();

  const onSubmit = () => {
    if (!words) return;
    if (isLink) {
      void submit();
      return;
    }
    // Nothing on the phone: look for it on YouTube straight away.
    if (results && results.length === 0) openInBrowser(youtubeSearch(words));
    else inputRef.current?.blur();
  };

  const row = (icon: string, label: string, run: () => void, strong = false) => (
    <button
      type="button"
      onClick={run}
      className="flex min-h-14 w-full items-center gap-3 rounded-xl px-1 text-left active:bg-surface"
    >
      <span
        className={`grid h-10 w-10 shrink-0 place-items-center rounded-full ${strong ? 'bg-accent-subtle text-chip-text' : 'bg-surface2 text-muted'}`}
      >
        <Icon name={icon} size={22} />
      </span>
      <span className="min-w-0 flex-1 truncate text-[14.5px] font-semibold">{label}</span>
    </button>
  );

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <form
        role="search"
        className="flex shrink-0 items-center gap-1 px-2 pb-2 pt-1.5"
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit();
        }}
      >
        <button
          type="button"
          aria-label={t('back')}
          onClick={onClose}
          className="grid h-12 w-12 shrink-0 place-items-center"
        >
          <Icon name="arrow_back" size={24} />
        </button>
        <label
          className={`flex h-12 min-w-0 flex-1 items-center gap-2 rounded-3xl border bg-surface pl-4 pr-1.5 ${linkFieldBorder(isLink ? issue : null)}`}
        >
          <input
            ref={inputRef}
            type="search"
            autoFocus
            enterKeyHint="search"
            value={q}
            onChange={(e) => change(e.target.value)}
            placeholder={t('mSearchField')}
            aria-label={t('mSearchField')}
            autoComplete="off"
            className="min-w-0 flex-1 bg-transparent text-[15px] font-medium text-fg outline-none focus-visible:outline-none"
          />
          {words ? (
            <button
              type="button"
              aria-label={t('clearSearch')}
              onClick={() => change('')}
              className="grid h-9 w-9 place-items-center text-muted"
            >
              <Icon name="close" size={20} />
            </button>
          ) : (
            <button
              type="button"
              onClick={paste}
              className="flex h-9 items-center gap-1.5 rounded-full bg-surface2 px-3 text-[12.5px] font-semibold"
            >
              <Icon name="content_paste" size={16} />
              {t('pasteShort')}
            </button>
          )}
        </label>
      </form>
      {isLink && issue && (
        <div className="px-4">
          <LinkIssueNote id="search-link-issue" issue={issue} onFix={applyFix} compact />
        </div>
      )}

      <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-auto px-4 pb-4 pt-2">
        {!words && (
          <section aria-label={t('sites')} className="flex flex-col gap-3">
            <h2 className="m-0 text-[15px] font-bold">{t('sites')}</h2>
            <SiteTiles label={t('sites')} onOpen={openInBrowser} />
            <p className="m-0 text-[12.5px] text-muted">{t('searchHint')}</p>
          </section>
        )}

        {isLink && row('download', t('analyzeLink'), () => void submit(), true)}

        {words && !isLink && (
          <>
            {results && results.length > 0 && (
              <section aria-label={t('onThisPhone')} className="flex flex-col gap-1">
                <h2 className="m-0 pb-1 text-[13px] font-bold text-muted">{t('onThisPhone')}</h2>
                <ul className="m-0 flex list-none flex-col p-0">
                  {results.map((m) => (
                    <li key={m.id}>
                      <button
                        type="button"
                        onClick={() =>
                          useMobilePlayback
                            .getState()
                            .start(m, results, t('searchSource', { q: words }))
                        }
                        aria-label={t('playTitle', { title: m.title })}
                        className="flex h-16 w-full items-center gap-3 text-left"
                      >
                        <MediaThumb media={m} className="h-12 w-12 rounded-lg" />
                        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                          <span className="truncate text-[14.5px] font-bold">{m.title}</span>
                          <span className="truncate text-[12.5px] text-muted">
                            {[
                              m.kind === 'video' ? t('kindVideo') : m.artist,
                              durationLabel(m.durationSecs),
                            ]
                              .filter(Boolean)
                              .join(' · ')}
                          </span>
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              </section>
            )}
            {results && results.length === 0 && (
              <p className="m-0 text-[13.5px] text-muted">{t('notOnPhone', { q: words })}</p>
            )}
            <section aria-label={t('searchWeb')} className="flex flex-col">
              {row(
                'smart_display',
                t('searchOnYoutube', { q: words }),
                () => openInBrowser(youtubeSearch(words)),
                true,
              )}
              {row('travel_explore', t('searchOnWeb', { q: words }), () => openInBrowser(words))}
            </section>
          </>
        )}
      </div>
    </div>
  );
}

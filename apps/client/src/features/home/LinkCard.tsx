import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import { LinkIssueNote } from './LinkIssueNote';
import { linkFieldBorder, useLinkInput } from './useLinkInput';

/**
 * Android: paste a link, then quick actions (screen 01 card). Since
 * decision 0006 it heads the Downloads tab, the last one of the bar.
 */
export function LinkCard({ onBrowser }: { onBrowser: () => void }) {
  const t = useT();
  const { url, issue, inputRef, change, submit, paste, applyFix } = useLinkInput();

  const quick = [
    { icon: 'music_note', label: t('qAudio'), run: () => void submit(url, 'audio') },
    { icon: 'playlist_play', label: t('qPlaylist'), planned: true },
    { icon: 'travel_explore', label: t('tabBrowser'), run: onBrowser },
  ];

  return (
    <div className="flex flex-col gap-3.5">
      <form
        className="flex flex-col gap-3 rounded-[16px] bg-surface p-4"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <label htmlFor="mobile-link" className="text-[15px] font-bold">
          {t('homeLink')}
        </label>
        <div
          className={`flex h-[52px] items-center gap-2 rounded-[10px] border bg-bg pl-3.5 pr-1.5 transition-colors duration-150 focus-within:shadow-[0_0_0_3px_rgba(53,201,189,0.16)] ${linkFieldBorder(issue)}`}
        >
          <input
            id="mobile-link"
            ref={inputRef}
            value={url}
            onChange={(e) => change(e.target.value)}
            placeholder="https://"
            inputMode="url"
            autoComplete="off"
            aria-invalid={issue?.tone === 'warn'}
            aria-describedby={issue ? 'mobile-link-issue' : undefined}
            className="h-full min-w-0 flex-1 bg-transparent font-mono text-[14px] text-fg outline-none focus-visible:outline-none"
          />
          <button
            type="button"
            onClick={paste}
            className="flex h-10 items-center gap-1.5 rounded-sm bg-surface2 px-3 text-[13px] font-semibold"
          >
            <Icon name="content_paste" size={18} />
            {t('pasteShort')}
          </button>
        </div>
        {issue && <LinkIssueNote id="mobile-link-issue" issue={issue} onFix={applyFix} compact />}
        <Button type="submit" variant="primary" pill className="h-[52px] gap-2 text-[15px]">
          {t('analyzeLink')}
          <Icon name="arrow_forward" size={20} />
        </Button>
        <span className="text-center text-[12px] text-muted">{t('shareHint')}</span>
      </form>

      <div className="grid grid-cols-3 gap-2">
        {quick.map((q) => (
          <button
            key={q.icon}
            type="button"
            disabled={q.planned}
            aria-label={q.planned ? t('plannedNamed', { name: q.label }) : q.label}
            onClick={q.run}
            className="flex flex-col items-center gap-2 text-[12px] font-semibold text-fg disabled:text-muted"
          >
            <span
              className={`relative grid h-[52px] w-[52px] place-items-center rounded-[16px] bg-surface ${q.planned ? 'text-faint in-data-[theme=light]:bg-surface2' : 'text-accent-strong in-data-[theme=light]:bg-accent-subtle'}`}
            >
              <Icon name={q.icon} size={24} />
              {q.planned && (
                <span className="absolute -right-2 -top-[5px] rounded-xs bg-planned-ink px-1 py-px font-mono text-[9px] font-bold text-planned">
                  {t('planned')}
                </span>
              )}
            </span>
            {q.label}
          </button>
        ))}
      </div>
    </div>
  );
}

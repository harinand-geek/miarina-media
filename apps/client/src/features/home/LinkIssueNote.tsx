import { Icon } from '../../components/Icon';
import type { LinkIssue } from './useLinkInput';

/**
 * Feedback under the link field. Replaces the red error line: an empty
 * field gets a calm hint, an unusable link an amber note with its fix.
 */
export function LinkIssueNote({
  id,
  issue,
  onFix,
  compact = false,
}: {
  id?: string;
  issue: LinkIssue;
  onFix: () => void;
  compact?: boolean;
}) {
  if (issue.tone === 'hint') {
    return (
      <p
        id={id}
        role="status"
        className={`m-0 flex items-center gap-1.5 text-muted ${compact ? 'text-[12.5px]' : 'text-[12px]'}`}
      >
        <Icon name="info" size={16} className="text-accent" />
        {issue.message}
      </p>
    );
  }
  return (
    <div
      id={id}
      role="alert"
      className={`flex items-center gap-2.5 rounded-sm border border-warn/30 bg-warn/10 ${
        compact ? 'flex-wrap px-3 py-2.5 text-[13px]' : 'px-3 py-2 text-[12.5px]'
      }`}
    >
      <Icon name="link_off" size={18} className="text-warn" />
      <span className="min-w-0 flex-1 text-fg">{issue.message}</span>
      {issue.fix && (
        <button
          type="button"
          onClick={onFix}
          title={issue.fix}
          className="flex h-8 shrink-0 items-center gap-1 rounded-sm bg-surface2 px-2.5 text-[12.5px] font-semibold text-fg hover:bg-overlay-border"
        >
          <Icon name="auto_fix_high" size={16} className="text-accent" />
          Add https://
        </button>
      )}
    </div>
  );
}

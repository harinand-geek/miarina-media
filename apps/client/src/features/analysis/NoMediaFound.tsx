import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';

/**
 * "No downloadable media found" (Windows v2 screen 2, no-media state).
 * Miarina never bypasses logins, DRM or live restrictions: it says so.
 */
export function NoMediaFound({
  onRetry,
  onOpenBrowser,
  reason,
}: {
  onRetry: () => void;
  /** Opens the page in the built-in browser, where media can be detected. */
  onOpenBrowser?: () => void;
  reason?: string;
}) {
  const t = useT();
  return (
    <div
      role="alert"
      className="mx-auto my-[60px] flex max-w-[460px] flex-col items-center gap-3 text-center"
    >
      <Icon name="link_off" size={40} className="text-danger" />
      <span className="text-[18px] font-bold">{t('noMediaTitle')}</span>
      <span className="text-[13.5px] leading-[1.55] text-muted">{t('noMediaBody')}</span>
      {reason && <span className="text-[12.5px] text-muted">{t('noMediaReason', { reason })}</span>}
      <div className="flex gap-2.5 pt-2">
        <button
          type="button"
          onClick={onRetry}
          className="h-9 rounded-sm border border-line-strong bg-surface2 px-3.5 text-[13px] font-semibold text-fg hover:bg-secondary-hover"
        >
          {t('tryAgain')}
        </button>
        {onOpenBrowser && (
          <button
            type="button"
            onClick={onOpenBrowser}
            className="h-9 rounded-sm bg-accent px-4 text-[13px] font-bold text-accent-ink hover:bg-accent-hover"
          >
            {t('openInBrowser')}
          </button>
        )}
      </div>
    </div>
  );
}

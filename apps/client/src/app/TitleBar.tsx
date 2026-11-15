import { Icon } from '../components/Icon';
import { PlannedBadge } from '../components/Feedback';
import { Logo } from '../components/Logo';
import { DesktopSearch } from '../features/search/DesktopSearch';
import { useT } from '../i18n';
import { backend } from '../services/backend';
import { closeWindow, minimizeWindow, toggleMaximizeWindow } from '../services/window';

const WINDOW_BUTTON =
  'grid h-10 w-[46px] place-items-center text-muted transition-colors duration-[80ms] hover:bg-surface hover:text-fg';

/** Custom 40 px title bar (decorations are disabled in tauri.conf.json). */
export function TitleBar() {
  const t = useT();
  return (
    <header
      data-tauri-drag-region
      className="flex h-10 shrink-0 items-center border-b border-divider bg-sidebar"
    >
      <div data-tauri-drag-region className="flex w-[232px] items-center gap-2.5 px-4">
        <Logo size={18} outlined />
        <span
          data-tauri-drag-region
          className="whitespace-nowrap text-[13px] font-extrabold tracking-[-0.01em]"
        >
          Miarina Media
        </span>
      </div>
      <div data-tauri-drag-region className="flex flex-1 justify-center">
        <DesktopSearch />
      </div>
      <div className="flex w-[232px] items-center justify-end">
        {backend.kind === 'mock' && (
          <span data-tauri-drag-region className="mr-2" title={t('preview')}>
            <PlannedBadge label="PREVIEW" />
          </span>
        )}
        <button
          type="button"
          aria-label={t('minimize')}
          className={WINDOW_BUTTON}
          onClick={minimizeWindow}
        >
          <Icon name="remove" size={16} />
        </button>
        <button
          type="button"
          aria-label={t('maximize')}
          className={WINDOW_BUTTON}
          onClick={toggleMaximizeWindow}
        >
          <Icon name="crop_square" size={14} />
        </button>
        <button
          type="button"
          aria-label={t('close')}
          className={`${WINDOW_BUTTON} hover:bg-window-close hover:text-white`}
          onClick={closeWindow}
        >
          <Icon name="close" size={16} />
        </button>
      </div>
    </header>
  );
}

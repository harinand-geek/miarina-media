import { PlannedBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { useUi } from '../../stores/ui';

/** Embedded browser: a concept only, shown as PLANNED (design + CLAUDE.md "Later, not MVP"). */
export default function BrowserScreen() {
  const go = useUi((s) => s.go);
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex items-center gap-3 border-b border-planned-border bg-planned-bg px-5 py-2.5 text-[13px]">
        <PlannedBadge />
        <span className="flex-1">
          The built-in browser is a concept for a future release. It is not available in this
          version.
        </span>
        <button
          type="button"
          onClick={() => go('home')}
          className="font-semibold text-accent-strong hover:text-accent-hover"
        >
          Paste a link instead
        </button>
      </div>
      <div aria-hidden="true" className="flex flex-1 flex-col opacity-55">
        <div className="flex items-center gap-2 border-b border-divider px-5 py-3 text-muted">
          <Icon name="arrow_back" />
          <Icon name="arrow_forward" />
          <Icon name="refresh" />
          <div className="flex h-[34px] flex-1 items-center gap-2 rounded-sm border border-line bg-surface px-3 font-mono text-[12.5px]">
            <Icon name="lock" size={16} />
            studio.blender.org/films
          </div>
        </div>
        <div className="hatch relative m-5 grid flex-1 place-items-center rounded-lg border border-dashed border-line-strong">
          <span className="font-mono text-[12px] font-medium text-faint">web page viewport</span>
          <div className="absolute bottom-5 left-1/2 flex -translate-x-1/2 items-center gap-3.5 rounded-lg border border-line-strong bg-surface py-2.5 pl-4 pr-2.5 shadow-menu">
            <Icon name="movie" className="text-accent-strong" />
            <span className="text-[13px]">
              <span className="font-bold">1 video detected</span>{' '}
              <span className="text-muted">on this page</span>
            </span>
            <button
              type="button"
              disabled
              tabIndex={-1}
              className="h-8 rounded-sm bg-line px-3.5 text-[12.5px] font-bold text-muted"
            >
              Analyze
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

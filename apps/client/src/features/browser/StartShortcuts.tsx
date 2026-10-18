import { SHORTCUTS } from './shortcuts';

/**
 * Start page shortcuts. Not in the handoff: letter tiles like the M4
 * favorites grid (no remote icons are loaded, the app CSP forbids them).
 */
export function StartShortcuts({
  onOpen,
  columns = 4,
}: {
  onOpen: (address: string) => void;
  columns?: 4 | 8;
}) {
  return (
    <ul
      aria-label="Shortcuts"
      className={`m-0 grid w-full list-none gap-x-2 gap-y-4 p-0 ${
        columns === 8 ? 'max-w-[720px] grid-cols-8' : 'grid-cols-4'
      }`}
    >
      {SHORTCUTS.map((site) => (
        <li key={site.name}>
          <button
            type="button"
            onClick={() => onOpen(site.address)}
            className="flex w-full flex-col items-center gap-2 rounded-lg py-1 text-center hover:bg-card-hover focus-visible:bg-card-hover"
          >
            <span
              aria-hidden="true"
              className="grid h-12 w-12 place-items-center rounded-full bg-surface2 text-[18px] font-bold text-accent"
            >
              {site.name[0]}
            </span>
            <span className="w-full truncate text-[12px] text-muted">{site.name}</span>
          </button>
        </li>
      ))}
    </ul>
  );
}

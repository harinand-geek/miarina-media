import { BrandMark } from '../search/SiteTiles';
import { brandOf } from '../search/sites';
import { SHORTCUTS } from './shortcuts';

interface Site {
  name: string;
  address: string;
}

/**
 * Start page shortcuts. Known sites show their own mark (inlined, decision
 * 0006); others keep the letter tile of the M4 favorites grid (no remote
 * icons are loaded, the app CSP forbids them).
 */
export function StartShortcuts({
  onOpen,
  columns = 4,
  sites = SHORTCUTS,
  label = 'Shortcuts',
}: {
  onOpen: (address: string) => void;
  columns?: 4 | 8;
  sites?: Site[];
  label?: string;
}) {
  return (
    <ul
      aria-label={label}
      className={`m-0 grid w-full list-none gap-x-2 gap-y-4 p-0 ${
        columns === 8 ? 'max-w-[720px] grid-cols-8' : 'grid-cols-4'
      }`}
    >
      {sites.map((site) => {
        const brand = brandOf(site.address);
        return (
          <li key={site.address}>
            <button
              type="button"
              onClick={() => onOpen(site.address)}
              className="flex w-full flex-col items-center gap-2 rounded-2xl py-1.5 text-center transition-transform duration-150 hover:bg-card-hover focus-visible:bg-card-hover active:scale-95"
            >
              {brand ? (
                <BrandMark site={brand} size={48} />
              ) : (
                <span
                  aria-hidden="true"
                  className="grid h-12 w-12 place-items-center rounded-full bg-surface2 text-[18px] font-bold text-accent"
                >
                  {site.name[0]}
                </span>
              )}
              <span className="w-full truncate text-[12px] text-muted">{site.name}</span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

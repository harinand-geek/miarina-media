import { BRAND_SITES, type BrandSite } from './sites';

/** A site's own mark: white glyph on a round tile of its color. */
export function BrandMark({ site, size = 56 }: { site: BrandSite; size?: number }) {
  return (
    <span
      aria-hidden="true"
      className="grid shrink-0 place-items-center rounded-full ring-1 ring-[rgb(245_247_250/0.08)]"
      style={{ background: site.color, width: size, height: size }}
    >
      <svg viewBox="0 0 24 24" width={size / 2} height={size / 2} fill="#FFFFFF">
        <path d={site.path} />
      </svg>
    </span>
  );
}

/** Round brand tiles of the search (decision 0006), four per row, named under the mark. */
export function SiteTiles({ label, onOpen }: { label: string; onOpen: (address: string) => void }) {
  return (
    <ul aria-label={label} className="m-0 grid list-none grid-cols-4 gap-x-2 gap-y-4 p-0">
      {BRAND_SITES.map((site) => (
        <li key={site.address}>
          <button
            type="button"
            onClick={() => onOpen(site.address)}
            className="flex w-full flex-col items-center gap-2 rounded-2xl py-1.5 text-center transition-transform duration-150 hover:bg-surface focus-visible:bg-surface active:scale-95 active:bg-surface"
          >
            <BrandMark site={site} />
            <span className="w-full truncate text-[12px] text-muted">{site.name}</span>
          </button>
        </li>
      ))}
    </ul>
  );
}

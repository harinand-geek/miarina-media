import { useEffect, useRef, useState, type ReactNode, type Ref } from 'react';

/** Scroll needed in one direction before the header changes (no flicker). */
const SCROLL_SLOP = 6;

/**
 * Lark-like "quick return" header (decision 0006). A direct child of the
 * scrolling element, sticky on top: scrolling down slides the `header`
 * (logo, search…) away and keeps the `bar` (tabs) on top; scrolling up,
 * even deep in a long list, brings the header back at once. Once the list
 * has moved it gains a soft shadow and blur.
 */
export function CollapsingHeader({
  scroller,
  header,
  bar,
  inset = false,
}: {
  scroller: HTMLElement | null;
  header: ReactNode;
  bar: ReactNode;
  /** The scroller already pads its sides: bleed to its edges. */
  inset?: boolean;
}) {
  const headerRef = useRef<HTMLDivElement>(null);
  /** Header hidden, and how far the block slides up for it (its height). */
  const [{ hidden, offset }, setSlide] = useState({ hidden: false, offset: 0 });
  const [lifted, setLifted] = useState(false);

  useEffect(() => {
    if (!scroller) return;
    let last = scroller.scrollTop;
    let frame = 0;
    let pending = false;
    // One update per frame (a timer where frames are not available).
    const nextFrame = (run: () => void) =>
      typeof requestAnimationFrame === 'function'
        ? requestAnimationFrame(run)
        : window.setTimeout(run, 16);
    const onScroll = () => {
      if (pending) return;
      pending = true;
      frame = nextFrame(() => {
        pending = false;
        const y = scroller.scrollTop;
        const headerHeight = headerRef.current?.offsetHeight ?? 0;
        setLifted(y > 0);
        const show = { hidden: false, offset: 0 };
        if (y <= headerHeight) {
          // Near the top: the header stays.
          setSlide(show);
          last = y;
        } else if (y > last + SCROLL_SLOP) {
          setSlide({ hidden: true, offset: headerHeight });
          last = y;
        } else if (y < last - SCROLL_SLOP) {
          setSlide(show);
          last = y;
        }
      });
    };
    scroller.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      scroller.removeEventListener('scroll', onScroll);
      if (typeof cancelAnimationFrame === 'function') cancelAnimationFrame(frame);
      window.clearTimeout(frame);
    };
  }, [scroller]);

  return (
    <div
      className={`sticky top-0 z-20 shrink-0 transition-[transform,background-color,box-shadow] duration-300 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${inset ? '-mx-4' : ''} ${
        lifted ? 'bg-bg/90 shadow-[0_10px_20px_-8px_rgb(0_0_0/0.45)] backdrop-blur-md' : 'bg-bg'
      }`}
      style={{ transform: hidden ? `translateY(-${offset}px)` : undefined }}
    >
      <div
        ref={headerRef}
        // Hidden header: out of reach for focus and assistive technologies.
        inert={hidden}
        className={`px-4 pt-1 transition-opacity duration-200 ${hidden ? 'opacity-0' : 'opacity-100'}`}
      >
        {header}
      </div>
      <div className="px-4 pb-1.5 pt-1">{bar}</div>
    </div>
  );
}

/**
 * Android library card (decision 0006, Lark-like style in Miarina colors):
 * a rounded surface with the cover on the left, the name, up to two muted
 * lines and the count in the top right corner. Used for playlists, albums,
 * artists and folders.
 */
export function LibraryCard({
  cover,
  title,
  lines,
  count,
  onOpen,
  label,
  action,
}: {
  cover: ReactNode;
  title: string;
  lines: (string | null | false | undefined)[];
  count?: number;
  onOpen: () => void;
  /** Accessible name when the title alone is ambiguous. */
  label?: string;
  /** A round button over the bottom right corner (e.g. play an album). */
  action?: { icon: ReactNode; label: string; run: () => void };
}) {
  const card = (
    <button
      type="button"
      onClick={onOpen}
      aria-label={label}
      className={`flex h-[100px] w-full items-center gap-3.5 rounded-[22px] bg-surface p-3 text-left transition-[background-color,transform] duration-150 active:scale-[0.98] active:bg-surface2 ${action ? 'pr-14' : ''}`}
    >
      <span className="h-[76px] w-[76px] shrink-0">{cover}</span>
      <span className="flex min-w-0 flex-1 flex-col gap-1 self-stretch py-1">
        <span className="flex items-baseline gap-2">
          <span className="min-w-0 flex-1 truncate text-[16px] font-bold">{title}</span>
          {count != null && (
            <span className="shrink-0 font-mono text-[12px] text-muted tabular">{count}</span>
          )}
        </span>
        {lines.filter(Boolean).map((line, i) => (
          <span key={i} className="truncate text-[13px] text-muted">
            {line}
          </span>
        ))}
      </span>
    </button>
  );
  if (!action) return card;
  return (
    <div className="relative">
      {card}
      <button
        type="button"
        aria-label={action.label}
        onClick={action.run}
        className="absolute bottom-3 right-3 grid h-10 w-10 place-items-center rounded-full bg-coral text-coral-ink shadow-[0_4px_12px_rgb(0_0_0/0.25)]"
      >
        {action.icon}
      </button>
    </div>
  );
}

/**
 * Android tab header (decision 0006): the Miarina logo and name, as the
 * first thing seen at launch; the tab title stays a heading for assistive
 * technologies. Actions sit on the right.
 */
export function BrandHeader({
  title,
  logoRef,
  logo,
  children,
}: {
  title: string;
  logoRef?: Ref<HTMLSpanElement>;
  logo: ReactNode;
  children?: ReactNode;
}) {
  return (
    <div className="flex h-14 items-center gap-1">
      <span ref={logoRef} className="mr-2 grid shrink-0 place-items-center">
        {logo}
      </span>
      <span
        aria-hidden="true"
        className="flex-1 truncate text-[21px] font-extrabold tracking-[-0.01em]"
      >
        Miarina Media
      </span>
      <h1 className="sr-only">{title}</h1>
      {children}
    </div>
  );
}

/** Pill tabs under the header (Lark-like), coral on the play tabs. */
export function PillTabs<T extends string>({
  label,
  items,
  value,
  onChange,
}: {
  label: string;
  items: { id: T; label: string }[];
  value: T;
  onChange: (id: T) => void;
}) {
  return (
    <div
      role="tablist"
      aria-label={label}
      className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 [scrollbar-width:none]"
    >
      {items.map((item) => (
        <button
          key={item.id}
          type="button"
          role="tab"
          aria-selected={value === item.id}
          onClick={() => onChange(item.id)}
          className={`h-10 shrink-0 rounded-full px-4 text-[14.5px] transition-[color,background-color,transform] duration-200 active:scale-95 ${
            value === item.id
              ? 'bg-coral font-bold text-coral-ink'
              : 'bg-surface font-semibold text-muted'
          }`}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}

import { useState, type ReactNode } from 'react';
import { backend } from '../services/backend';
import type { MediaKind } from '../services/types';
import logo from '../assets/logo.svg';

/**
 * A picture stored on this device (library thumbnail or cached source
 * thumbnail), lazy-loaded through the asset protocol. Falls back to the
 * Miarina watermark when there is none or it cannot be read.
 */
export function LocalThumb(props: {
  path: string | null | undefined;
  kind: MediaKind;
  className?: string;
  /** Optional label displayed over the fallback watermark. */
  label?: string;
  children?: ReactNode;
}) {
  // A new path gets a fresh error state.
  return <Picture key={props.path ?? ''} {...props} />;
}

function Picture({ path, className = '', label, children }: Parameters<typeof LocalThumb>[0]) {
  const [failed, setFailed] = useState(false);
  const src = path && !failed ? backend.mediaUrl(path) : '';
  return (
    <div
      className={`relative grid shrink-0 place-items-center overflow-hidden bg-surface2 ${className}`}
    >
      {src ? (
        <img
          src={src}
          alt=""
          loading="lazy"
          decoding="async"
          onError={() => setFailed(true)}
          className="absolute inset-0 h-full w-full object-cover"
        />
      ) : (
        <>
          <img
            src={logo}
            alt=""
            aria-hidden="true"
            className="pointer-events-none absolute h-[48%] w-[48%] object-contain opacity-15"
          />
          {label && <span className="relative font-mono text-[9px] text-muted">{label}</span>}
        </>
      )}
      {children}
    </div>
  );
}

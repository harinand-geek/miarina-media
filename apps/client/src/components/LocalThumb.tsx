import { useState, type ReactNode } from 'react';
import { backend } from '../services/backend';
import type { MediaKind } from '../services/types';
import { Thumbnail } from './Feedback';
import { Icon } from './Icon';

/**
 * A picture stored on this device (library thumbnail or cached source
 * thumbnail), lazy-loaded through the asset protocol. Falls back to the
 * design's placeholder when there is none or it cannot be read.
 */
export function LocalThumb(props: {
  path: string | null | undefined;
  kind: MediaKind;
  className?: string;
  /** Placeholder label; defaults to "Video" for videos. */
  label?: string;
  children?: ReactNode;
}) {
  // A new path gets a fresh error state.
  return <Picture key={props.path ?? ''} {...props} />;
}

function Picture({
  path,
  kind,
  className = '',
  label,
  children,
}: Parameters<typeof LocalThumb>[0]) {
  const [failed, setFailed] = useState(false);
  const src = path && !failed ? backend.mediaUrl(path) : '';
  return (
    <Thumbnail
      className={`overflow-hidden ${className}`}
      label={src ? undefined : (label ?? (kind === 'audio' ? undefined : 'Video'))}
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
        kind === 'audio' && !label && <Icon name="music_note" size={22} className="text-audio" />
      )}
      {children}
    </Thumbnail>
  );
}

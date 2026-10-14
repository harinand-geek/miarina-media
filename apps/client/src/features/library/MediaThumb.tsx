import { useState, type ReactNode } from 'react';
import { Thumbnail } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';

/**
 * Real thumbnail when one was generated (lazy-loaded through the asset
 * protocol), otherwise the design's placeholder.
 */
export function MediaThumb({
  media,
  className = '',
  children,
}: {
  media: MediaRecord;
  className?: string;
  children?: ReactNode;
}) {
  const [failed, setFailed] = useState(false);
  const src = media.thumbnail && !failed ? backend.mediaUrl(media.thumbnail) : '';
  return (
    <Thumbnail
      className={`overflow-hidden ${className}`}
      label={src ? undefined : media.kind === 'audio' ? undefined : 'Video'}
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
        media.kind === 'audio' && <Icon name="music_note" size={22} className="text-audio" />
      )}
      {children}
    </Thumbnail>
  );
}

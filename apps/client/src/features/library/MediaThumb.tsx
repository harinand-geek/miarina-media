import type { ReactNode } from 'react';
import { LocalThumb } from '../../components/LocalThumb';
import type { MediaRecord } from '../../services/types';

/**
 * Real thumbnail when one exists (source picture or FFmpeg frame),
 * otherwise the design's placeholder.
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
  return (
    <LocalThumb path={media.thumbnail} kind={media.kind} className={className}>
      {children}
    </LocalThumb>
  );
}

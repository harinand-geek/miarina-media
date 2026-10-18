import { useState, type ReactNode } from 'react';
import type { MediaRecord } from '../../services/types';
import { RenameDialog } from './MediaActions';
import { MobileMediaSheet } from './MobileMediaSheet';

/**
 * `open(media)` shows the actions sheet; render `sheet` once in the screen.
 * `inPlayer` keeps only Share, Open with and Copy link.
 */
export function useMobileMediaSheet({ inPlayer = false } = {}): {
  open: (media: MediaRecord) => void;
  sheet: ReactNode;
} {
  const [target, setTarget] = useState<MediaRecord | null>(null);
  const [renaming, setRenaming] = useState<MediaRecord | null>(null);
  return {
    open: setTarget,
    sheet: (
      <>
        {target && (
          <MobileMediaSheet
            media={target}
            inPlayer={inPlayer}
            onClose={() => setTarget(null)}
            onRename={setRenaming}
          />
        )}
        {renaming && <RenameDialog media={renaming} onClose={() => setRenaming(null)} />}
      </>
    ),
  };
}

import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';
import { useMobileMediaSheet } from './useMobileMediaSheet';

const media = {
  id: 3,
  title: 'Sintel trailer',
  kind: 'video',
  height: 480,
  sizeBytes: 4_372_373,
  sourceUrl: 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
  probed: true,
} as unknown as MediaRecord;

function Harness({ inPlayer = false }: { inPlayer?: boolean }) {
  const sheet = useMobileMediaSheet({ inPlayer });
  return (
    <div>
      <button type="button" onClick={() => sheet.open(media)}>
        More
      </button>
      {sheet.sheet}
    </div>
  );
}

afterEach(() => vi.restoreAllMocks());

describe('useMobileMediaSheet', () => {
  it('lists the file actions and shares through the backend', async () => {
    const share = vi.spyOn(backend, 'libraryShare').mockResolvedValue();
    const user = userEvent.setup();
    render(<Harness />);
    await user.click(screen.getByRole('button', { name: 'More' }));

    const sheet = screen.getByRole('dialog', { name: 'Actions for Sintel trailer' });
    const labels = [...sheet.querySelectorAll('button')].map((b) => b.textContent?.trim());
    expect(labels).toEqual([
      'play_arrowPlay',
      'shareShare',
      'open_in_newOpen with…',
      'content_copyCopy source link',
      'drive_file_rename_outlineRename',
      'deleteDelete file',
    ]);

    await user.click(screen.getByRole('button', { name: /Share/ }));
    expect(share).toHaveBeenCalledWith(3);
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('keeps only share, open with and copy link in the player', async () => {
    const user = userEvent.setup();
    render(<Harness inPlayer />);
    await user.click(screen.getByRole('button', { name: 'More' }));
    const sheet = screen.getByRole('dialog');
    expect(sheet).toHaveTextContent('Share');
    expect(sheet).toHaveTextContent('Open with…');
    expect(sheet).not.toHaveTextContent('Play');
    expect(sheet).not.toHaveTextContent('Delete file');
    expect(sheet).not.toHaveTextContent('Rename');
  });
});

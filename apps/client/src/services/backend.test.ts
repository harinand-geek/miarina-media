import { describe, expect, it } from 'vitest';
import { mapAnalysis } from './backend';
import type { ComponentStatus } from './types';

// Regression: the Tauri mapping once turned every non-ready result into a
// bare "no media", hiding the media-tools consent step and the reason.
describe('analyze_link mapping', () => {
  it('keeps the components that need consent', () => {
    const components: ComponentStatus[] = [
      {
        id: 'yt_dlp',
        name: 'yt-dlp',
        version: 'x',
        license: 'Unlicense',
        downloadBytes: 1,
        installed: false,
        bundled: false,
      },
    ];
    expect(mapAnalysis({ status: 'needs_components', components })).toEqual({
      ok: false,
      reason: 'needs_components',
      components,
    });
  });

  it('keeps the reason of a failed analysis', () => {
    expect(mapAnalysis({ status: 'no_media', reason: 'live streams are not supported' })).toEqual({
      ok: false,
      reason: 'no_media',
      message: 'live streams are not supported',
    });
  });
});

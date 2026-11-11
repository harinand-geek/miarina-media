import { useEffect } from 'react';
import { isRunning, useDownloads } from '../stores/downloads';
import { openSection } from '../app/navigation';
import { usePlayer } from '../stores/player';
import { useUi, type Screen } from '../stores/ui';

/** Order of the sidebar, used by Ctrl+1…7 (design system §10). */
export const SECTION_ORDER: Screen[] = [
  'home',
  'downloads',
  'library',
  'player',
  'history',
  'browser',
  'settings',
  'torrents',
];

function isEditable(target: EventTarget | null) {
  return (
    target instanceof HTMLElement &&
    (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName))
  );
}

/** Keys that act on their own focused control rather than on playback. */
function ownsKey(target: EventTarget | null) {
  return (
    target instanceof HTMLElement &&
    (['BUTTON', 'A', 'SUMMARY'].includes(target.tagName) ||
      ['slider', 'radio', 'tab', 'menuitem', 'option', 'row', 'listitem'].includes(
        target.getAttribute('role') ?? '',
      ) ||
      target.tagName === 'LI')
  );
}

/**
 * Desktop keyboard shortcuts. Space plays/pauses anywhere outside text and
 * controls; ←/→ seek ±10 s on the player screens (Windows v2, WIN-11).
 * F and Escape live in the video screen.
 */
export function useGlobalShortcuts() {
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (useUi.getState().confirm) return;
      const ctrl = e.ctrlKey || e.metaKey;
      if (!ctrl && !e.altKey && !e.shiftKey && !isEditable(e.target) && !ownsKey(e.target)) {
        const player = usePlayer.getState();
        const { screen } = useUi.getState();
        if (e.key === ' ' && player.media && screen !== 'browser') {
          e.preventDefault();
          player.toggle();
          return;
        }
        if ((screen === 'player' || screen === 'now') && player.media) {
          if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
            e.preventDefault();
            player.skip(e.key === 'ArrowLeft' ? -10 : 10);
            return;
          }
        }
      }
      if (!ctrl || e.altKey) return;
      const key = e.key.toLowerCase();

      if (/^[1-8]$/.test(key)) {
        e.preventDefault();
        openSection(SECTION_ORDER[Number(key) - 1]!);
      } else if (key === 'b') {
        e.preventDefault();
        useUi.getState().toggleSidebar();
      } else if (key === 'k') {
        e.preventDefault();
        useUi.getState().focusLibrarySearch();
      } else if (key === 'p') {
        e.preventDefault();
        const downloads = useDownloads.getState();
        if (Object.values(downloads.tasks).some(isRunning)) downloads.pauseAll();
        else downloads.resumeAll();
      }
    };

    // Ctrl+V outside a text field pastes the link and analyzes it.
    const onPaste = (e: ClipboardEvent) => {
      if (isEditable(e.target)) return;
      const text = e.clipboardData?.getData('text')?.trim();
      if (!text) return;
      e.preventDefault();
      useUi.getState().analyze(text);
    };

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('paste', onPaste);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('paste', onPaste);
    };
  }, []);
}

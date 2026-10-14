import { useEffect } from 'react';
import { isRunning, useDownloads } from '../stores/downloads';
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
];

function isEditable(target: EventTarget | null) {
  return (
    target instanceof HTMLElement &&
    (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName))
  );
}

/** Desktop keyboard shortcuts. Player keys live in the player screen. */
export function useGlobalShortcuts() {
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (useUi.getState().confirm) return;
      const ctrl = e.ctrlKey || e.metaKey;
      if (!ctrl || e.altKey) return;
      const key = e.key.toLowerCase();

      if (/^[1-7]$/.test(key)) {
        e.preventDefault();
        useUi.getState().go(SECTION_ORDER[Number(key) - 1]!);
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

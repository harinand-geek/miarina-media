import { backend } from '../services/backend';
import { useUi, type Screen } from '../stores/ui';

/**
 * Opens a sidebar section. The browser lives in its own window (design D1);
 * where that window cannot exist (browser preview), its screen explains it.
 */
export function openSection(id: Screen) {
  if (id !== 'browser') {
    useUi.getState().go(id);
    return;
  }
  backend
    .openBrowser()
    .then((opened) => {
      if (!opened) useUi.getState().go('browser');
    })
    .catch((e: unknown) => {
      const message = e instanceof Error ? e.message : String(e);
      useUi
        .getState()
        .pushToast({ tone: 'error', message: `Could not open the browser: ${message}` });
    });
}

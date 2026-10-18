import { useUi, type Screen } from '../stores/ui';

/** Opens a sidebar section (the browser is a screen of the main window too). */
export function openSection(id: Screen) {
  useUi.getState().go(id);
}

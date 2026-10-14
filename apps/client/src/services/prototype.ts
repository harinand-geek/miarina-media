import { useUi } from '../stores/ui';

/**
 * Marks an action that needs the native backend (folders, file system,
 * system integrations) as explicitly unavailable during Phase 1, instead of
 * faking a success.
 */
export function notAvailableYet(feature: string) {
  useUi.getState().pushToast({
    tone: 'success',
    message: `${feature} is not available in this prototype build yet.`,
  });
}

import { useEffect } from 'react';
import { useSettings } from '../stores/settings';
import { useMediaQuery } from './useMediaQuery';

/** Applies theme and motion preferences to the document root. */
export function useAppearance() {
  const theme = useSettings((s) => s.theme);
  const reduceMotion = useSettings((s) => s.reduceMotion);
  const modeReduces = useSettings((s) => s.limits.reducedMotion);
  const systemDark = useMediaQuery('(prefers-color-scheme: dark)');

  const resolved = theme === 'system' ? (systemDark ? 'dark' : 'light') : theme;
  const reduced = reduceMotion || modeReduces;

  useEffect(() => {
    document.documentElement.dataset.theme = resolved;
  }, [resolved]);

  useEffect(() => {
    if (reduced) document.documentElement.dataset.motion = 'reduced';
    else delete document.documentElement.dataset.motion;
  }, [reduced]);
}

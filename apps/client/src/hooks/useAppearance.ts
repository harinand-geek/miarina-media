import { useEffect } from 'react';
import { setWindowTheme } from '../services/window';
import { useSettings } from '../stores/settings';
import { useMediaQuery } from './useMediaQuery';

/** Applies theme and motion preferences to the document root. */
export function useAppearance() {
  const theme = useSettings((s) => s.theme);
  const reduceMotion = useSettings((s) => s.reduceMotion);
  const modeReduces = useSettings((s) => s.limits.reducedMotion);
  const lang = useSettings((s) => s.lang);
  const systemDark = useMediaQuery('(prefers-color-scheme: dark)');

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const resolved = theme === 'system' ? (systemDark ? 'dark' : 'light') : theme;
  const reduced = reduceMotion || modeReduces;

  useEffect(() => {
    document.documentElement.dataset.theme = resolved;
  }, [resolved]);

  // Browser pages (WebView2) take the window theme: give it the app's choice,
  // or none to follow the system (a light app showed dark pages).
  useEffect(() => {
    void setWindowTheme(theme === 'system' ? null : theme).catch(() => {});
  }, [theme]);

  useEffect(() => {
    if (reduced) document.documentElement.dataset.motion = 'reduced';
    else delete document.documentElement.dataset.motion;
  }, [reduced]);
}

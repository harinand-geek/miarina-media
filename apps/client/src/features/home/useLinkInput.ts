import { useCallback, useRef, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { LINK_ERROR_MESSAGES, checkLink, checkLinkLocally } from '../../services/link';
import { detectPlatform, inTauri } from '../../services/platform';
import { useUi } from '../../stores/ui';

/**
 * Feedback under the link field. An empty field is a `hint`, not an error;
 * a link that cannot be used is a `warn`, with a one-tap `fix` when adding
 * the missing "https://" is enough.
 */
export interface LinkIssue {
  tone: 'hint' | 'warn';
  message: string;
  fix?: string;
}

/** Border of the link field for the current feedback. */
export function linkFieldBorder(issue: LinkIssue | null): string {
  if (!issue) return 'border-line-strong focus-within:border-accent';
  return issue.tone === 'hint' ? 'border-accent' : 'border-warn/60';
}

/** `example.com/video` → `https://example.com/video` when that is valid. */
function suggestFix(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed || trimmed.includes('://') || /\s/.test(trimmed) || !trimmed.includes('.')) {
    return undefined;
  }
  const candidate = `https://${trimmed.replace(/^\/+/, '')}`;
  return checkLinkLocally(candidate).ok ? candidate : undefined;
}

/** URL field state shared by the Windows and Android home screens. */
export function useLinkInput() {
  const [url, setUrl] = useState('');
  const [issue, setIssue] = useState<LinkIssue | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const analyzeInStore = useUi((s) => s.analyze);
  const openInBrowser = useUi((s) => s.openInBrowser);

  const change = useCallback((value: string) => {
    setUrl(value);
    setIssue(null);
  }, []);

  const submit = useCallback(
    async (value = url, tab?: 'video' | 'audio') => {
      const result = await checkLink(value);
      if (!result.ok) {
        const fix =
          result.code === 'malformed' || result.code === 'missing_host'
            ? suggestFix(value)
            : undefined;
        // Words, not a link: search them in the built-in browser.
        if (result.code === 'malformed' && !fix && !value.includes('://')) {
          setIssue(null);
          openInBrowser(value.trim());
          return;
        }
        setIssue({
          tone: result.code === 'empty' ? 'hint' : 'warn',
          message: fix ? 'This link is missing “https://”.' : LINK_ERROR_MESSAGES[result.code],
          fix,
        });
        inputRef.current?.focus();
        return;
      }
      setIssue(null);
      analyzeInStore(result.url, tab);
    },
    [url, analyzeInStore, openInBrowser],
  );

  /** Applies the suggested fix and analyzes it. */
  const applyFix = useCallback(() => {
    if (!issue?.fix) return;
    setUrl(issue.fix);
    void submit(issue.fix);
  }, [issue, submit]);

  const paste = useCallback(async () => {
    const android = detectPlatform() === 'android';
    try {
      // The Android WebView refuses navigator.clipboard: read it natively.
      const text = (
        android && inTauri()
          ? ((await invoke<{ text: string | null }>('app_read_clipboard')).text ?? '')
          : await navigator.clipboard.readText()
      ).trim();
      inputRef.current?.focus();
      if (text) change(text);
      else setIssue({ tone: 'hint', message: 'The clipboard is empty. Copy a link first.' });
    } catch {
      inputRef.current?.focus();
      setIssue({
        tone: 'hint',
        message: android
          ? 'The clipboard could not be read. Long-press the field and choose Paste.'
          : 'Clipboard access was refused. Press Ctrl+V in the field instead.',
      });
    }
  }, [change]);

  return { url, issue, inputRef, change, submit, paste, applyFix };
}

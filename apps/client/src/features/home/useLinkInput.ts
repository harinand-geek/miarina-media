import { useCallback, useRef, useState } from 'react';
import { LINK_ERROR_MESSAGES, checkLink, checkLinkLocally } from '../../services/link';
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
    [url, analyzeInStore],
  );

  /** Applies the suggested fix and analyzes it. */
  const applyFix = useCallback(() => {
    if (!issue?.fix) return;
    setUrl(issue.fix);
    void submit(issue.fix);
  }, [issue, submit]);

  const paste = useCallback(async () => {
    try {
      const text = (await navigator.clipboard.readText()).trim();
      if (text) change(text);
      inputRef.current?.focus();
    } catch {
      // Clipboard read can be refused by the WebView; Ctrl+V still works.
      inputRef.current?.focus();
      setIssue({
        tone: 'hint',
        message: 'Clipboard access was refused. Press Ctrl+V in the field instead.',
      });
    }
  }, [change]);

  return { url, issue, inputRef, change, submit, paste, applyFix };
}

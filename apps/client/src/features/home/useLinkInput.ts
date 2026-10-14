import { useCallback, useRef, useState } from 'react';
import { LINK_ERROR_MESSAGES, checkLink } from '../../services/link';
import { useUi } from '../../stores/ui';

/** URL field state shared by the Windows and Android home screens. */
export function useLinkInput() {
  const [url, setUrl] = useState('');
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const analyzeInStore = useUi((s) => s.analyze);

  const change = useCallback((value: string) => {
    setUrl(value);
    setError(null);
  }, []);

  const submit = useCallback(
    async (value = url, tab?: 'video' | 'audio') => {
      const result = await checkLink(value);
      if (!result.ok) {
        setError(LINK_ERROR_MESSAGES[result.code]);
        inputRef.current?.focus();
        return;
      }
      setError(null);
      analyzeInStore(result.url, tab);
    },
    [url, analyzeInStore],
  );

  const paste = useCallback(async () => {
    try {
      const text = (await navigator.clipboard.readText()).trim();
      if (text) change(text);
      inputRef.current?.focus();
    } catch {
      // Clipboard read can be refused by the WebView; Ctrl+V still works.
      inputRef.current?.focus();
      setError('Clipboard access was refused. Press Ctrl+V in the field instead.');
    }
  }, [change]);

  return { url, error, inputRef, change, submit, paste };
}

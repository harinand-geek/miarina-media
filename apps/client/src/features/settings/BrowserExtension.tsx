import { useCallback, useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { Button } from '../../components/Button';
import { inTauri } from '../../services/platform';
import { useUi } from '../../stores/ui';

interface Entry {
  id: string;
  url: string;
}
export function BrowserExtension() {
  const [browser, setBrowser] = useState('chrome');
  const [extensionId, setExtensionId] = useState('');
  const [entries, setEntries] = useState<Entry[]>([]);
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);
  const refresh = useCallback(async () => {
    if (inTauri()) setEntries(await invoke<Entry[]>('browser_inbox'));
  }, []);
  useEffect(() => {
    if (!inTauri()) return;
    let active = true;
    void invoke<Entry[]>('browser_inbox').then(
      (entries) => {
        if (active) setEntries(entries);
      },
      () => {
        if (active) setStatus('Unable to read received links.');
      },
    );
    return () => {
      active = false;
    };
  }, []);
  const run = async (action: () => Promise<unknown>, success = '') => {
    setBusy(true);
    setStatus('');
    try {
      await action();
      await refresh();
      setStatus(success);
    } catch (e) {
      setStatus(
        typeof e === 'object' && e && 'message' in e ? String(e.message) : 'Operation failed.',
      );
    } finally {
      setBusy(false);
    }
  };
  const register = (enabled: boolean) =>
    run(
      () => invoke('browser_bridge_register', { browser, extensionId, enabled }),
      enabled
        ? 'Connected. Send a link from the extension to test the connection.'
        : 'Disconnected.',
    );
  return (
    <div className="mt-4 flex flex-col gap-4 text-sm">
      <p className="text-muted">
        Send pages and media links from Chrome or Edge to Miarina. Links remain in your local inbox
        until you review them.
      </p>
      <ol className="list-decimal space-y-2 pl-5 text-muted">
        <li>
          Open the extension folder and load it from your browser’s Extensions page using Developer
          mode → Load unpacked.
        </li>
        <li>Open the extension popup, copy its ID, then connect below.</li>
      </ol>
      <div>
        <Button
          disabled={busy || !inTauri()}
          onClick={() => void run(() => invoke('browser_extension_folder'))}
        >
          Open extension folder
        </Button>
      </div>
      <label>
        Browser
        <select
          aria-label="Browser for extension"
          className="ml-3 rounded border border-divider bg-surface p-2"
          value={browser}
          onChange={(e) => setBrowser(e.target.value)}
        >
          <option value="chrome">Chrome</option>
          <option value="edge">Edge</option>
        </select>
      </label>
      <label className="flex flex-col gap-2">
        Extension ID
        <input
          className="rounded border border-divider bg-surface p-3"
          value={extensionId}
          onChange={(e) => setExtensionId(e.target.value.trim())}
          placeholder="32 lowercase letters from the extension popup"
        />
      </label>
      <div className="flex gap-3">
        <Button
          disabled={busy || !inTauri() || !/^[a-p]{32}$/.test(extensionId)}
          onClick={() => void register(true)}
        >
          Connect
        </Button>
        <Button
          disabled={busy || !inTauri() || !/^[a-p]{32}$/.test(extensionId)}
          onClick={() => void register(false)}
        >
          Disconnect
        </Button>
      </div>
      {status && (
        <p role="status" className="rounded border border-divider bg-surface p-3">
          {status}
        </p>
      )}
      <div className="mt-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold">Received links</h3>
        <Button size="sm" disabled={busy || !inTauri()} onClick={() => void run(refresh)}>
          Refresh
        </Button>
      </div>
      {entries.length === 0 && <p className="text-muted">No links received yet.</p>}
      {entries.map((entry) => (
        <article key={entry.id} className="rounded border border-divider bg-surface p-3">
          <p className="break-all">{entry.url}</p>
          <div className="mt-3 flex gap-2">
            <Button size="sm" onClick={() => useUi.getState().analyze(entry.url)}>
              Analyze
            </Button>
            <Button
              size="sm"
              disabled={busy}
              onClick={() => void run(() => invoke('browser_inbox_dismiss', { id: entry.id }))}
            >
              Dismiss
            </Button>
          </div>
        </article>
      ))}
    </div>
  );
}

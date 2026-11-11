import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { useT } from '../../i18n';
import { inTauri } from '../../services/platform';
import { useUi } from '../../stores/ui';

interface Entry {
  id: string;
  url: string;
}

const SECONDARY =
  'h-[34px] shrink-0 rounded-sm border border-line-strong bg-surface2 px-3 text-[13px] font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50';

function Step({
  n,
  title,
  description,
  done,
  children,
}: {
  n: number;
  title: string;
  description: string;
  done?: boolean;
  children?: ReactNode;
}) {
  return (
    <section className="flex flex-col gap-3 rounded-[10px] border border-line bg-surface px-4 py-3.5">
      <div className="flex items-center gap-3.5">
        <span
          className={`grid h-7 w-7 shrink-0 place-items-center rounded-full text-[12.5px] font-bold ${
            done ? 'bg-accent text-accent-ink' : 'bg-accent-subtle text-chip-text'
          }`}
        >
          {n}
        </span>
        <div className="flex min-w-0 flex-1 flex-col gap-0.5">
          <h3 className="m-0 text-[14px] font-bold">{title}</h3>
          <span className="text-[12.5px] text-muted">{description}</span>
        </div>
      </div>
      {children}
    </section>
  );
}

/**
 * Windows v2 Settings › Browser extension (EXT-01): install, connect with
 * the extension ID, then review the links it sent. Nothing is analyzed or
 * downloaded until the user asks.
 */
export function BrowserExtension() {
  const t = useT();
  const [browser, setBrowser] = useState('chrome');
  const [extensionId, setExtensionId] = useState('');
  const [entries, setEntries] = useState<Entry[]>([]);
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);
  const native = inTauri();
  const validId = /^[a-p]{32}$/.test(extensionId);

  const refresh = useCallback(async () => {
    if (inTauri()) setEntries(await invoke<Entry[]>('browser_inbox'));
  }, []);
  useEffect(() => {
    if (!inTauri()) return;
    let active = true;
    void invoke<Entry[]>('browser_inbox').then(
      (list) => {
        if (active) setEntries(list);
      },
      () => {
        if (active) setStatus(t('extReadFailed'));
      },
    );
    return () => {
      active = false;
    };
  }, [t]);
  const run = async (action: () => Promise<unknown>, success = '') => {
    setBusy(true);
    setStatus('');
    try {
      await action();
      await refresh();
      setStatus(success);
    } catch (e) {
      setStatus(typeof e === 'object' && e && 'message' in e ? String(e.message) : t('torFailed'));
    } finally {
      setBusy(false);
    }
  };
  const register = (enabled: boolean) =>
    run(
      () => invoke('browser_bridge_register', { browser, extensionId, enabled }),
      enabled ? t('extConnected') : t('extDisconnected'),
    );

  return (
    <div className="mt-2 flex flex-col gap-2.5">
      <Step n={1} title={t('extStep1')} description={t('extStep1Desc')}>
        <div>
          <button
            type="button"
            className={SECONDARY}
            disabled={busy || !native}
            onClick={() => void run(() => invoke('browser_extension_folder'))}
          >
            {t('openFolder')}
          </button>
        </div>
      </Step>

      <Step n={2} title={t('extStep2')} description={t('extStep2Desc')}>
        <div className="flex flex-wrap items-center gap-2">
          <select
            aria-label={t('extBrowser')}
            className="h-[34px] rounded-sm border border-line-strong bg-bg px-2.5 text-[13px] text-fg"
            value={browser}
            onChange={(e) => setBrowser(e.target.value)}
          >
            <option value="chrome">Chrome</option>
            <option value="edge">Edge</option>
          </select>
          <input
            aria-label={t('extId')}
            className="h-[34px] min-w-[260px] flex-1 rounded-sm border border-line-strong bg-bg px-2.5 font-mono text-[12.5px] text-fg outline-none focus:border-accent"
            value={extensionId}
            spellCheck={false}
            onChange={(e) => setExtensionId(e.target.value.trim())}
            placeholder={t('extIdPh')}
          />
          <button
            type="button"
            className="h-[34px] rounded-sm bg-accent px-3.5 text-[13px] font-bold text-accent-ink enabled:hover:bg-accent-hover disabled:opacity-50"
            disabled={busy || !native || !validId}
            onClick={() => void register(true)}
          >
            {t('extConnect')}
          </button>
          <button
            type="button"
            className={SECONDARY}
            disabled={busy || !native || !validId}
            onClick={() => void register(false)}
          >
            {t('extDisconnect')}
          </button>
        </div>
      </Step>

      <Step n={3} title={t('extStep3')} description={t('extStep3Desc')} done={entries.length > 0}>
        <div className="flex items-center justify-between">
          <h4 className="m-0 text-[13px] font-bold">{t('extReceived')}</h4>
          <button
            type="button"
            className={SECONDARY}
            disabled={busy || !native}
            onClick={() => void run(refresh)}
          >
            {t('extRefresh')}
          </button>
        </div>
        {entries.length === 0 && <p className="m-0 text-[12.5px] text-muted">{t('extNone')}</p>}
        {entries.map((entry) => (
          <article
            key={entry.id}
            className="flex items-center gap-2.5 rounded-lg border border-line bg-bg px-3 py-2"
          >
            <p className="m-0 min-w-0 flex-1 break-all font-mono text-[12px]">{entry.url}</p>
            <button
              type="button"
              className="h-[30px] rounded-sm bg-accent px-3 text-[12.5px] font-bold text-accent-ink hover:bg-accent-hover"
              onClick={() => useUi.getState().analyze(entry.url)}
            >
              {t('analyze')}
            </button>
            <button
              type="button"
              className="h-[30px] rounded-sm border border-line-strong bg-surface2 px-3 text-[12.5px] font-semibold disabled:opacity-50"
              disabled={busy}
              onClick={() => void run(() => invoke('browser_inbox_dismiss', { id: entry.id }))}
            >
              {t('extDismiss')}
            </button>
          </article>
        ))}
      </Step>

      {status && (
        <p role="status" className="m-0 rounded-lg border border-line bg-surface p-3 text-[13px]">
          {status}
        </p>
      )}
      <p className="m-0 pt-1 text-[12.5px] text-muted">{t('extNote')}</p>
    </div>
  );
}

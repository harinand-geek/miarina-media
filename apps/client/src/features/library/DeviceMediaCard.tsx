import { useEffect, useState } from 'react';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import type { DeviceAccess } from '../../services/types';
import { deviceSession, RESYNC_MS } from './deviceMediaSession';

const errorText = (e: unknown) => (e instanceof Error ? e.message : String(e));

/**
 * Android (AND-06): offers to show the music and videos already on the
 * phone, read only. Asks for access only on a tap; after a refusal, points
 * to the system settings and checks again when the app comes back. Hidden
 * on desktop and once access is granted.
 */
export function DeviceMediaCard() {
  const t = useT();
  const [access, setAccess] = useState<DeviceAccess | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hidden, setHidden] = useState(deviceSession.dismissed);

  useEffect(() => {
    let alive = true;
    const check = () =>
      backend
        .deviceMediaAccess()
        .then((now) => {
          if (!alive) return;
          setAccess(now);
          if (now.audio === 'granted' && Date.now() - deviceSession.lastSync > RESYNC_MS) {
            deviceSession.lastSync = Date.now();
            return backend.deviceMediaSync().then(() => undefined);
          }
        })
        .catch((e: unknown) => alive && setError(errorText(e)));
    void check();
    // Back from the system settings: access may have changed.
    const onVisible = () => {
      if (document.visibilityState === 'visible') void check();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      alive = false;
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, []);

  if (!access || hidden || access.audio === 'granted' || access.audio === 'unsupported') {
    return null;
  }
  const denied = access.audio === 'denied';

  const allow = async () => {
    setBusy(true);
    setError(null);
    try {
      const now = denied ? null : await backend.deviceMediaRequest();
      if (now) {
        deviceSession.lastSync = Date.now();
        setAccess(now);
      } else {
        await backend.deviceMediaSettings();
      }
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <section
      aria-label={t('deviceTitle')}
      className="mb-3 flex flex-col gap-2.5 rounded-xl border border-line bg-surface p-4"
    >
      <div className="flex items-center gap-2.5">
        <Icon name="smartphone" size={22} className="text-coral-strong" />
        <h2 className="m-0 flex-1 text-[15px] font-bold">{t('deviceTitle')}</h2>
      </div>
      <p className="m-0 text-[13px] leading-5 text-muted">
        {denied ? t('deviceDenied') : t('deviceBody')}
      </p>
      {error && (
        <p role="alert" className="m-0 text-[12.5px] text-danger">
          {t('deviceFailed', { msg: error })}
        </p>
      )}
      <div className="flex items-center gap-2">
        <button
          type="button"
          disabled={busy}
          onClick={() => void allow()}
          className="flex h-10 items-center gap-2 rounded-full bg-coral px-4 text-[14px] font-extrabold text-coral-ink disabled:opacity-50"
        >
          <Icon name={denied ? 'settings' : 'library_music'} size={20} />
          {denied ? t('deviceSettings') : t('deviceAllow')}
        </button>
        <button
          type="button"
          onClick={() => {
            deviceSession.dismissed = true;
            setHidden(true);
          }}
          className="h-10 px-3 text-[13.5px] font-semibold text-muted"
        >
          {t('deviceLater')}
        </button>
      </div>
    </section>
  );
}

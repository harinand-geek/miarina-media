import { useEffect, useState } from 'react';
import { Button } from '../../components/Button';
import { backend } from '../../services/backend';
import type { ComponentStatus } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { SettingRow } from './SettingRow';
import { useT } from '../../i18n';

/** Status of yt-dlp and FFmpeg: shipped with the Windows installer
 * (decision 0002), downloaded on demand when missing (decision D3).
 * yt-dlp also updates itself, verified by its signature (daily check). */
export function MediaTools() {
  const t = useT();
  const [components, setComponents] = useState<ComponentStatus[]>([]);
  const [installing, setInstalling] = useState(false);
  const [checking, setChecking] = useState(false);
  const pushToast = useUi((s) => s.pushToast);

  const refresh = () =>
    backend
      .componentsStatus()
      .then(setComponents)
      .catch(() => setComponents([]));

  useEffect(() => {
    void refresh();
  }, []);

  const checkUpdates = () => {
    setChecking(true);
    backend
      .updateYtDlp()
      .then((result) => {
        pushToast({
          tone: 'success',
          message:
            result.status === 'updated'
              ? t('ytdlpUpdated', { v: result.version })
              : t('ytdlpLatest', { v: result.version }),
        });
        return refresh();
      })
      .catch((e: unknown) =>
        pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
      )
      .finally(() => setChecking(false));
  };

  const install = () => {
    setInstalling(true);
    backend
      .installComponents(() => {})
      .then((status) => {
        setComponents(status);
        pushToast({ tone: 'success', message: t('toolsInstalled') });
      })
      .catch((e: unknown) =>
        pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
      )
      .finally(() => setInstalling(false));
  };

  return (
    <>
      <h3 className="m-0 pt-7 text-heading font-bold">{t('mediaTools')}</h3>
      {components.map((c) => (
        <SettingRow
          key={c.id}
          label={c.name}
          description={
            c.id === 'yt_dlp' && c.installed
              ? `${c.version} · ${c.license} · ${t('autoUpdated')}`
              : c.bundled
                ? `${c.version} · ${c.license}`
                : `${c.version} · ${c.license} · ${t('toDownload', { size: formatBytes(c.downloadBytes) })}`
          }
        >
          {c.installed ? (
            <span className="flex items-center gap-3">
              <span className="text-[12.5px] font-semibold text-accent-strong">
                {c.bundled ? t('includedVerified') : t('installedVerified')}
              </span>
              {c.id === 'yt_dlp' && (
                <Button
                  size="sm"
                  className="text-[12.5px]"
                  disabled={checking}
                  onClick={checkUpdates}
                >
                  {checking ? t('updChecking') : t('updCheck')}
                </Button>
              )}
            </span>
          ) : (
            <Button size="sm" className="text-[12.5px]" disabled={installing} onClick={install}>
              {installing ? t('downloadingShort') : t('downloadVerb')}
            </Button>
          )}
        </SettingRow>
      ))}
    </>
  );
}

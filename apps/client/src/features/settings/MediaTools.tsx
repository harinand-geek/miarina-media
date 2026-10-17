import { useEffect, useState } from 'react';
import { Button } from '../../components/Button';
import { backend } from '../../services/backend';
import type { ComponentStatus } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useUi } from '../../stores/ui';
import { SettingRow } from './SettingRow';

/** Status of yt-dlp and FFmpeg: shipped with the Windows installer
 * (decision 0002), downloaded on demand when missing (decision D3). */
export function MediaTools() {
  const [components, setComponents] = useState<ComponentStatus[]>([]);
  const [installing, setInstalling] = useState(false);
  const pushToast = useUi((s) => s.pushToast);

  useEffect(() => {
    backend
      .componentsStatus()
      .then(setComponents)
      .catch(() => setComponents([]));
  }, []);

  const install = () => {
    setInstalling(true);
    backend
      .installComponents(() => {})
      .then((status) => {
        setComponents(status);
        pushToast({ tone: 'success', message: 'Media tools installed and verified' });
      })
      .catch((e: unknown) =>
        pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
      )
      .finally(() => setInstalling(false));
  };

  return (
    <>
      <h3 className="m-0 pt-7 text-heading font-bold">Media tools</h3>
      {components.map((c) => (
        <SettingRow
          key={c.id}
          label={c.name}
          description={
            c.bundled
              ? `${c.version} · ${c.license}`
              : `${c.version} · ${c.license} · ${formatBytes(c.downloadBytes)} download`
          }
        >
          {c.installed ? (
            <span className="text-[12.5px] font-semibold text-accent-strong">
              {c.bundled ? 'Included · verified' : 'Installed · verified'}
            </span>
          ) : (
            <Button size="sm" className="text-[12.5px]" disabled={installing} onClick={install}>
              {installing ? 'Downloading…' : 'Download'}
            </Button>
          )}
        </SettingRow>
      ))}
    </>
  );
}

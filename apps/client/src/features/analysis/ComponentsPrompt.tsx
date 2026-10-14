import { useState } from 'react';
import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { backend } from '../../services/backend';
import type { ComponentStatus, InstallProgress } from '../../services/types';
import { formatBytes } from '../../stores/downloads';

interface ComponentsPromptProps {
  components: ComponentStatus[];
  onInstalled: () => void;
  onDismiss: () => void;
}

/**
 * Consent step before downloading yt-dlp and FFmpeg (decision D3). Not part
 * of the design handoff: built from design-system components only.
 */
export function ComponentsPrompt({ components, onInstalled, onDismiss }: ComponentsPromptProps) {
  const [progress, setProgress] = useState<Partial<Record<ComponentStatus['id'], InstallProgress>>>(
    {},
  );
  const [installing, setInstalling] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const missing = components.filter((c) => !c.installed);
  const total = missing.reduce((acc, c) => acc + c.downloadBytes, 0);

  const install = () => {
    setInstalling(true);
    setError(null);
    backend
      .installComponents((p) => setProgress((s) => ({ ...s, [p.id]: p })))
      .then(onInstalled)
      .catch((e: unknown) => setError(e instanceof Error ? e.message : String(e)))
      .finally(() => setInstalling(false));
  };

  return (
    <section
      aria-label="Media tools"
      className="flex max-w-[560px] flex-col gap-4 rounded-lg border border-surface2 bg-surface p-6"
    >
      <div className="flex items-start gap-3">
        <span className="grid h-[34px] w-[34px] shrink-0 place-items-center rounded-md bg-surface2 text-accent-strong">
          <Icon name="download" />
        </span>
        <div className="flex flex-col gap-1.5">
          <h2 className="m-0 text-[15px] font-bold">This page needs the media tools</h2>
          <p className="m-0 text-[13px] leading-normal text-muted">
            Miarina Media reads web pages with yt-dlp and merges or converts files with FFmpeg. They
            are downloaded once from their official releases and checked against a fixed SHA-256
            fingerprint before use.
          </p>
        </div>
      </div>
      <ul className="m-0 flex list-none flex-col gap-3 p-0">
        {missing.map((c) => {
          const p = progress[c.id];
          return (
            <li key={c.id} className="flex flex-col gap-1.5">
              <div className="flex justify-between gap-3 text-[13px]">
                <span>
                  <span className="font-semibold">{c.name}</span>{' '}
                  <span className="text-muted">
                    {c.version} · {c.license}
                  </span>
                </span>
                <span className="shrink-0 font-mono text-[12.5px] text-muted">
                  {p
                    ? `${formatBytes(p.downloaded)} of ${formatBytes(p.total)}`
                    : formatBytes(c.downloadBytes)}
                </span>
              </div>
              {installing && (
                <ProgressBar
                  value={p ? (p.downloaded / p.total) * 100 : 0}
                  label={`${c.name} download`}
                />
              )}
            </li>
          );
        })}
      </ul>
      {error && (
        <p role="alert" className="m-0 text-[12.5px] text-danger">
          {error}
        </p>
      )}
      <div className="flex justify-end gap-2">
        <Button size="sm" className="h-9 text-[13px]" onClick={onDismiss} disabled={installing}>
          Not now
        </Button>
        <Button
          variant="primary"
          size="sm"
          icon="download"
          className="h-9 text-[13px]"
          onClick={install}
          disabled={installing}
        >
          {installing ? 'Downloading…' : `Download tools · ${formatBytes(total)}`}
        </Button>
      </div>
    </section>
  );
}

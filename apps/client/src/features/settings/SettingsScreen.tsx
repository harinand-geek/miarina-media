import { useEffect, useState } from 'react';
import { Button } from '../../components/Button';
import { RadioDot, Segmented, Stepper, Toggle } from '../../components/Controls';
import { PlannedBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { backend } from '../../services/backend';
import type { StorageUsage } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import {
  MAX_CONCURRENCY,
  MIN_CONCURRENCY,
  useSettings,
  type ResourceMode,
  type ThemePref,
} from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { AppUpdates } from './AppUpdates';
import { MediaTools } from './MediaTools';
import { Select, SettingRow } from './SettingRow';
import { BrowserExtension } from './BrowserExtension';

type Tab = 'general' | 'downloads' | 'storage' | 'performance' | 'appearance' | 'language' | 'extension';

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'general', label: 'General', icon: 'tune' },
  { id: 'extension', label: 'Browser extension', icon: 'extension' },
  { id: 'downloads', label: 'Downloads', icon: 'download' },
  { id: 'storage', label: 'Storage', icon: 'hard_drive' },
  { id: 'performance', label: 'Performance', icon: 'speed' },
  { id: 'appearance', label: 'Appearance', icon: 'palette' },
  { id: 'language', label: 'Language', icon: 'language' },
];

export default function SettingsScreen() {
  const [tab, setTab] = useState<Tab>('general');
  const title = TABS.find((t) => t.id === tab)!.label;

  return (
    <div className="flex min-h-0 flex-1">
      <nav
        aria-label="Settings sections"
        className="flex w-[220px] shrink-0 flex-col gap-0.5 border-r border-divider px-3 py-7"
      >
        <h1 className="m-0 px-3 pb-3.5 text-title-lg font-bold tracking-[-0.02em]">Settings</h1>
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            aria-current={tab === t.id ? 'page' : undefined}
            onClick={() => setTab(t.id)}
            className={`flex h-9 items-center gap-2.5 rounded-sm px-3 text-left text-[13px] font-semibold hover:text-fg ${
              tab === t.id ? 'bg-line-strong text-fg' : 'text-muted'
            }`}
          >
            <Icon name={t.icon} size={18} />
            {t.label}
          </button>
        ))}
      </nav>
      <div className="flex-1 overflow-auto px-12 py-9">
        <div className="flex max-w-[700px] flex-col">
          <h2 className="m-0 pb-1.5 text-title font-bold">{title}</h2>
          {tab === 'general' && <GeneralTab />}
          {tab === 'extension' && <BrowserExtension />}
          {tab === 'downloads' && <DownloadsTab />}
          {tab === 'storage' && <StorageTab />}
          {tab === 'performance' && <PerformanceTab />}
          {tab === 'appearance' && <AppearanceTab />}
          {tab === 'language' && <LanguageTab />}
        </div>
      </div>
    </div>
  );
}

function GeneralTab() {
  const toggles = useSettings((s) => s.toggles);
  const toggle = useSettings((s) => s.toggle);
  return (
    <>
      <AppUpdates />
      <SettingRow label="Launch at startup" description="Start minimized in the system tray.">
        <Toggle
          label="Launch at startup"
          checked={toggles.launchAtStartup}
          onChange={() => toggle('launchAtStartup')}
        />
      </SettingRow>
      <SettingRow
        label="Close to tray"
        description="Downloads keep running when the window is closed."
      >
        <Toggle
          label="Close to tray"
          checked={toggles.closeToTray}
          onChange={() => toggle('closeToTray')}
        />
      </SettingRow>
      <SettingRow
        label="Detect copied links"
        description="Offer to analyze a link when one is copied to the clipboard."
      >
        <Toggle
          label="Detect copied links"
          checked={toggles.detectCopiedLinks}
          onChange={() => toggle('detectCopiedLinks')}
        />
      </SettingRow>
      <SettingRow label="When a link is pasted">
        <Select
          label="When a link is pasted"
          value="Analyze automatically"
          options={['Analyze automatically', 'Do nothing']}
        />
      </SettingRow>
    </>
  );
}

/** Destination folder, persisted by the backend after a writability check. */
function PathRow({ label }: { label: string }) {
  const downloadDir = useSettings((s) => s.downloadDir);
  const pick = useSettings((s) => s.pickDownloadDir);
  return (
    <SettingRow label={label}>
      <span
        className="max-w-[320px] truncate font-mono text-[12.5px] text-muted"
        title={downloadDir}
      >
        {downloadDir}
      </span>
      <Button size="sm" className="text-[12.5px]" onClick={pick}>
        Change
      </Button>
    </SettingRow>
  );
}

function DownloadsTab() {
  const concurrency = useSettings((s) => s.concurrency);
  const setConcurrency = useSettings((s) => s.setConcurrency);
  const toggles = useSettings((s) => s.toggles);
  const toggle = useSettings((s) => s.toggle);
  const [quality, setQuality] = useState('1080p');
  const [audio, setAudio] = useState('MP3 · 320 kbps');
  const [limit, setLimit] = useState('Unlimited');
  return (
    <>
      <PathRow label="Save to" />
      <SettingRow
        label="Default video quality"
        description="Falls back to the next lower quality when unavailable."
      >
        <Select
          label="Default video quality"
          value={quality}
          onChange={setQuality}
          options={['2160p', '1440p', '1080p', '720p', '480p']}
        />
      </SettingRow>
      <SettingRow label="Default audio format">
        <Select
          label="Default audio format"
          value={audio}
          onChange={setAudio}
          options={['MP3 · 320 kbps', 'M4A · 256 kbps', 'FLAC', 'Opus · 160 kbps']}
        />
      </SettingRow>
      <SettingRow label="Simultaneous downloads" description="Additional items wait in the queue.">
        <Stepper
          label="Simultaneous downloads"
          value={concurrency}
          min={MIN_CONCURRENCY}
          max={MAX_CONCURRENCY}
          onChange={setConcurrency}
        />
      </SettingRow>
      <SettingRow label="Speed limit">
        <Select
          label="Speed limit"
          value={limit}
          onChange={setLimit}
          options={['Unlimited', '10 MB/s', '5 MB/s', '2 MB/s', '1 MB/s']}
        />
      </SettingRow>
      <SettingRow
        label="Create a subfolder per source"
        description="Example: Videos\Miarina\blender.org"
      >
        <Toggle
          label="Create a subfolder per source"
          checked={toggles.subfolderPerSource}
          onChange={() => toggle('subfolderPerSource')}
        />
      </SettingRow>
      <MediaTools />
    </>
  );
}

function StorageTab() {
  const askConfirm = useUi((s) => s.askConfirm);
  const pushToast = useUi((s) => s.pushToast);
  const [usage, setUsage] = useState<StorageUsage | null>(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    backend
      .storageUsage()
      .then(setUsage)
      .catch(() => setUsage(null));
  }, [version]);

  const run = (action: () => Promise<number>, done: (freed: number) => string) =>
    action()
      .then((freed) => {
        pushToast({ tone: 'success', message: done(freed) });
        setVersion((v) => v + 1);
      })
      .catch((e: unknown) =>
        pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
      );

  const disk = usage?.disk;
  const share = (bytes: number) => (disk?.total ? `${(bytes / disk.total) * 100}%` : '0%');
  const other = disk ? Math.max(0, disk.total - disk.free - (usage?.libraryBytes ?? 0)) : 0;
  const drive = /^([A-Za-z]):/.exec(usage?.downloadDir ?? '')?.[1];

  return (
    <>
      {disk && (
        <div className="mb-1.5 mt-3.5 flex flex-col gap-2.5 rounded-lg border border-surface2 bg-surface p-4">
          <div className="flex justify-between text-[13px]">
            <span className="font-semibold">
              {drive ? `Drive ${drive.toUpperCase()}:` : 'Storage'}
            </span>
            <span className="text-muted">
              {formatBytes(disk.total - disk.free)} used of {formatBytes(disk.total)}
            </span>
          </div>
          <div className="flex h-2 overflow-hidden rounded-[4px] bg-line" aria-hidden="true">
            <div className="bg-accent" style={{ width: share(usage.libraryBytes) }} />
            <div className="bg-faint-icon" style={{ width: share(other) }} />
          </div>
          <div className="flex gap-[18px] text-[12px] text-muted">
            <span className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-[2px] bg-accent" />
              Miarina library {formatBytes(usage.libraryBytes)}
            </span>
            <span className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-[2px] bg-faint-icon" />
              Other {formatBytes(other)}
            </span>
          </div>
        </div>
      )}
      <PathRow label="Library location" />
      <SettingRow
        label="Thumbnail cache"
        description={usage ? formatBytes(usage.thumbnailBytes) : undefined}
      >
        <Button
          size="sm"
          className="text-[12.5px]"
          disabled={!usage?.thumbnailBytes}
          onClick={() =>
            void run(
              () => backend.clearThumbnails(),
              (freed) => `Thumbnail cache cleared · ${formatBytes(freed)} freed`,
            )
          }
        >
          Clear cache
        </Button>
      </SettingRow>
      <SettingRow
        label="Temporary files"
        description={
          usage
            ? usage.orphanTempCount
              ? `${formatBytes(usage.orphanTempBytes)} left by removed or interrupted downloads`
              : 'No leftover partial files'
            : undefined
        }
      >
        <Button
          size="sm"
          className="text-[12.5px]"
          disabled={!usage?.orphanTempCount}
          onClick={() =>
            askConfirm({
              title: 'Delete temporary files?',
              body: `Partial files left by ${usage?.orphanTempCount ?? 0} removed or interrupted downloads (${formatBytes(usage?.orphanTempBytes ?? 0)}) will be removed. Downloads in progress or paused keep theirs.`,
              confirmLabel: 'Delete files',
              onConfirm: () =>
                void run(
                  () => backend.cleanTemp(),
                  (freed) => `Temporary files deleted · ${formatBytes(freed)} freed`,
                ),
            })
          }
        >
          Clean up
        </Button>
      </SettingRow>
    </>
  );
}

const MODE_DESCRIPTIONS: Record<ResourceMode, string> = {
  eco: 'One download at a time, slower progress refresh, no animations.',
  balanced: 'Up to 3 downloads at once. Recommended.',
  performance: 'Uses your “Simultaneous downloads” setting without a cap.',
};

function PerformanceTab() {
  const toggles = useSettings((s) => s.toggles);
  const toggle = useSettings((s) => s.toggle);
  const mode = useSettings((s) => s.resourceMode);
  const setMode = useSettings((s) => s.setResourceMode);
  const reduceMotion = useSettings((s) => s.reduceMotion);
  const setReduceMotion = useSettings((s) => s.setReduceMotion);
  const [thumbs, setThumbs] = useState('Balanced');
  const ecoForcesMotion = useSettings((s) => s.limits.reducedMotion);
  return (
    <>
      {/* Q1: replaces the design's "Low-resource mode" toggle. */}
      <SettingRow label="Resource mode" description={MODE_DESCRIPTIONS[mode]}>
        <Segmented
          label="Resource mode"
          value={mode}
          onChange={setMode}
          options={[
            { value: 'eco', label: 'Eco' },
            { value: 'balanced', label: 'Balanced' },
            { value: 'performance', label: 'Performance' },
          ]}
        />
      </SettingRow>
      <SettingRow
        label="Hardware acceleration"
        description="Use the GPU for video decoding and playback."
      >
        <Toggle
          label="Hardware acceleration"
          checked={toggles.hardwareAcceleration}
          onChange={() => toggle('hardwareAcceleration')}
        />
      </SettingRow>
      <SettingRow
        label="Reduce motion"
        description={
          ecoForcesMotion
            ? 'Always on in Eco mode.'
            : 'Replace slides and scaling with simple fades.'
        }
      >
        <Toggle
          label="Reduce motion"
          checked={reduceMotion || ecoForcesMotion}
          onChange={() => setReduceMotion(!reduceMotion)}
        />
      </SettingRow>
      <SettingRow label="Thumbnail quality">
        <Select
          label="Thumbnail quality"
          value={thumbs}
          onChange={setThumbs}
          options={['Low', 'Balanced', 'High']}
        />
      </SettingRow>
    </>
  );
}

function AppearanceTab() {
  const theme = useSettings((s) => s.theme);
  const setTheme = useSettings((s) => s.setTheme);
  return (
    <>
      <SettingRow label="Theme">
        <Segmented<ThemePref>
          label="Theme"
          value={theme}
          onChange={setTheme}
          options={[
            { value: 'dark', label: 'Dark' },
            { value: 'light', label: 'Light' },
            { value: 'system', label: 'System' },
          ]}
        />
      </SettingRow>
      <SettingRow label="Density" description="Compact density has not been designed yet.">
        <PlannedBadge />
      </SettingRow>
      <SettingRow label="Accent" description="Miarina Teal · #35C9BD">
        <Select label="Accent" value="Teal" options={['Teal']} disabled />
      </SettingRow>
    </>
  );
}

const LANGUAGES = ['English', 'Français', 'Malagasy', 'Español', 'Português'];

function LanguageTab() {
  return (
    <div role="radiogroup" aria-label="Language">
      {LANGUAGES.map((lang) => {
        const available = lang === 'English';
        return (
          <SettingRow
            key={lang}
            label={lang}
            description={available ? undefined : 'Translation planned for a later release.'}
          >
            <span role="radio" aria-checked={available} aria-disabled={!available}>
              <RadioDot checked={available} size={20} />
            </span>
          </SettingRow>
        );
      })}
    </div>
  );
}

import { invoke } from '@tauri-apps/api/core';
import { useEffect, useMemo, useState } from 'react';
import { Segmented, Stepper, Toggle } from '../../components/Controls';
import { PlannedBadge } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { useT, type Lang, type MessageKey } from '../../i18n';
import { backend } from '../../services/backend';
import type { StorageUsage } from '../../services/types';
import { formatBytes, isRunning, summarize, useDownloads } from '../../stores/downloads';
import {
  MAX_CONCURRENCY,
  MIN_CONCURRENCY,
  useSettings,
  type ResourceMode,
  type ThemePref,
} from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { version } from '../../../package.json';
import { BrowserExtension } from './BrowserExtension';
import { MediaTools } from './MediaTools';
import { SettingRow } from './SettingRow';
import { useUpdates } from './useUpdates';

type Tab =
  | 'general'
  | 'updates'
  | 'downloads'
  | 'playback'
  | 'storage'
  | 'performance'
  | 'appearance'
  | 'language'
  | 'extension';

const TABS: { id: Tab; label: MessageKey; icon: string }[] = [
  { id: 'general', label: 'tabGeneral', icon: 'tune' },
  { id: 'updates', label: 'tabUpdates', icon: 'system_update_alt' },
  { id: 'downloads', label: 'downloads', icon: 'download' },
  { id: 'playback', label: 'tabPlayback', icon: 'play_circle' },
  { id: 'storage', label: 'tabStorage', icon: 'hard_drive' },
  { id: 'performance', label: 'modePerformance', icon: 'speed' },
  { id: 'appearance', label: 'tabAppearance', icon: 'palette' },
  { id: 'language', label: 'language', icon: 'language' },
  { id: 'extension', label: 'tabExtension', icon: 'extension' },
];

const SECONDARY =
  'h-[34px] shrink-0 rounded-sm border border-line-strong bg-surface2 px-3 text-[13px] font-semibold text-fg enabled:hover:bg-secondary-hover disabled:opacity-50';

function report(e: unknown) {
  useUi
    .getState()
    .pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });
}

/** A setting the engine does not support yet (UX-06): shown, never faked. */
function Planned() {
  const t = useT();
  return (
    <span title={t('plannedHint')}>
      <PlannedBadge label={t('planned')} />
    </span>
  );
}

/** Windows v2 screen 11: settings, one section at a time. */
export default function SettingsScreen() {
  const t = useT();
  const [tab, setTab] = useState<Tab>('general');
  const update = useUpdates((s) => s.release !== null);
  const title = t(TABS.find((x) => x.id === tab)!.label);

  return (
    <div className="flex min-h-0 flex-1">
      <nav
        aria-label={t('settingsSections')}
        className="flex w-[236px] shrink-0 flex-col gap-0.5 border-r border-divider px-3 py-8"
      >
        <h1 className="m-0 px-3 pb-4 text-[24px] font-extrabold tracking-[-0.02em]">
          {t('settings')}
        </h1>
        {TABS.map((x) => (
          <button
            key={x.id}
            type="button"
            aria-current={tab === x.id ? 'page' : undefined}
            onClick={() => setTab(x.id)}
            className={`flex h-9 items-center gap-2.5 rounded-md px-3 text-left text-[13.5px] font-semibold hover:text-fg ${
              tab === x.id ? 'bg-line-strong text-fg' : 'text-muted'
            }`}
          >
            <Icon name={x.icon} size={18} />
            <span className="flex-1">{t(x.label)}</span>
            {x.id === 'updates' && update && (
              <span className="h-2 w-2 rounded-full bg-accent" aria-label={t('updateAvailable')} />
            )}
          </button>
        ))}
      </nav>
      <div className="flex-1 overflow-auto px-12 py-8">
        <div className="flex max-w-[720px] flex-col">
          <h2 className="m-0 pb-2 text-[18px] font-bold">{title}</h2>
          {tab === 'general' && <GeneralTab />}
          {tab === 'updates' && <UpdatesTab />}
          {tab === 'downloads' && <DownloadsTab />}
          {tab === 'playback' && <PlaybackTab />}
          {tab === 'storage' && <StorageTab />}
          {tab === 'performance' && <PerformanceTab />}
          {tab === 'appearance' && <AppearanceTab />}
          {tab === 'language' && <LanguageTab />}
          {tab === 'extension' && <BrowserExtension />}
        </div>
      </div>
    </div>
  );
}

function GeneralTab() {
  const t = useT();
  return (
    <>
      <SettingRow label={t('launchStartup')} description={t('launchStartupDesc')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('closeTray')} description={t('closeTrayDesc')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('detectCopied')} description={t('detectCopiedDesc')}>
        <Planned />
      </SettingRow>
      {/* Ctrl+V outside a text field always pastes and analyzes. */}
      <SettingRow label={t('whenPasted')}>
        <span className="text-[13px] font-semibold">{t('whenPastedValue')}</span>
      </SettingRow>
    </>
  );
}

const mib = (bytes: number, lang: Lang) =>
  `${(bytes / 1048576).toLocaleString(lang === 'fr' ? 'fr-FR' : 'en-US', { maximumFractionDigits: 1 })} ${lang === 'fr' ? 'Mio' : 'MiB'}`;

/** UPD-01..07: never installs without the user; verified before install. */
function UpdatesTab() {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const { phase, release, error, checked, check, download, install } = useUpdates();
  const tasks = useDownloads((s) => s.tasks);
  const running = useMemo(() => summarize(tasks).active.filter(isRunning).length, [tasks]);
  const [downloaded, setDownloaded] = useState(0);

  useEffect(() => {
    if (phase !== 'downloading') return;
    let alive = true;
    const timer = setInterval(() => {
      void invoke<number>('app_update_progress')
        .then((n) => alive && setDownloaded(n))
        .catch(() => {});
    }, 1000);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, [phase]);

  const size = release ? mib(release.size, lang) : '';
  const notes = (release?.notes ?? '')
    .split('\n')
    .map((l) => l.replace(/^\s*[-•*]\s*/, '').trim())
    .filter(Boolean);
  const ready = phase === 'ready' || phase === 'installing';

  return (
    <>
      {release ? (
        <section
          aria-label={t('updAvailable', { v: release.version })}
          className="mt-2 flex flex-col gap-3.5 rounded-xl border border-line bg-surface p-5"
        >
          <div className="flex items-center gap-3.5">
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg border border-line bg-bg">
              <Icon name="system_update_alt" className="text-accent-strong" />
            </span>
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <span className="text-[15px] font-bold">
                {ready
                  ? t('updReady', { v: release.version })
                  : phase === 'downloading'
                    ? t('updDownloading', { v: release.version })
                    : t('updAvailable', { v: release.version })}
              </span>
              <span className="font-mono text-[12px] text-muted">
                {t('updInstalled', { v: version, size })}
              </span>
            </div>
            <span className="rounded-xs bg-surface2 px-2 py-[3px] text-[11.5px] font-semibold text-muted">
              {t('updBadge')}
            </span>
          </div>
          {notes.length > 0 && (
            <ul className="m-0 flex list-disc flex-col gap-1 pl-5 text-[13px]">
              {notes.map((n) => (
                <li key={n}>{n}</li>
              ))}
            </ul>
          )}
          {phase === 'downloading' && (
            <ProgressBar
              value={release.size ? Math.min(100, (downloaded / release.size) * 100) : null}
              label={t('updProgress')}
            />
          )}
          {ready && (
            <span className="flex items-center gap-1.5 text-[12.5px] font-semibold text-chip-text">
              <Icon name="verified" size={16} />
              {t('updVerified')}
            </span>
          )}
          {ready && running > 0 && (
            <span className="flex items-start gap-2 text-[12.5px] text-muted">
              <Icon name="info" size={16} className="shrink-0 text-warn" />
              {t('updActive', { n: running })}
            </span>
          )}
          {error && (
            <p role="alert" className="m-0 text-[12.5px] text-danger">
              {error}
            </p>
          )}
          <div className="flex gap-2.5">
            {phase === 'available' && (
              <button
                type="button"
                onClick={() => void download()}
                className="h-10 rounded-sm bg-accent px-4 text-[13.5px] font-bold text-accent-ink hover:bg-accent-hover"
              >
                {t('updDownload', { size })}
              </button>
            )}
            {ready && (
              <button
                type="button"
                disabled={phase === 'installing'}
                onClick={() => void install()}
                className="h-10 rounded-sm bg-accent px-4 text-[13.5px] font-bold text-accent-ink enabled:hover:bg-accent-hover disabled:opacity-60"
              >
                {phase === 'installing' ? t('updInstalling') : t('updInstall')}
              </button>
            )}
          </div>
          <span className="text-[12.5px] leading-[18px] text-muted">{t('updWindowsNote')}</span>
        </section>
      ) : (
        <SettingRow
          label={
            phase === 'checking'
              ? t('updChecking')
              : checked
                ? t('updLatest', { v: version })
                : t('versionLabel', { v: version })
          }
          description={t('updAutoCheck')}
        >
          {error && (
            <span role="alert" className="max-w-[240px] text-[12px] text-danger">
              {error}
            </span>
          )}
          <button
            type="button"
            disabled={phase === 'checking'}
            onClick={() => void check()}
            className={SECONDARY}
          >
            {t('updCheck')}
          </button>
        </SettingRow>
      )}
      <SettingRow label={t('updChannel')} description={t('updChannelDesc')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('updAuto')} description={t('updAutoDesc')}>
        <Planned />
      </SettingRow>
    </>
  );
}

/** Destination folder, persisted by the backend after a writability check. */
function PathRow({ label }: { label: string }) {
  const t = useT();
  const downloadDir = useSettings((s) => s.downloadDir);
  const pick = useSettings((s) => s.pickDownloadDir);
  return (
    <SettingRow label={label}>
      <span
        className="max-w-[300px] truncate font-mono text-[12.5px] text-muted"
        title={downloadDir}
      >
        {downloadDir}
      </span>
      <button
        type="button"
        onClick={() => void backend.openDownloadFolder().catch(report)}
        className={SECONDARY}
      >
        {t('openFolder')}
      </button>
      <button type="button" onClick={pick} className={SECONDARY}>
        {t('change')}
      </button>
    </SettingRow>
  );
}

function DownloadsTab() {
  const t = useT();
  const concurrency = useSettings((s) => s.concurrency);
  const setConcurrency = useSettings((s) => s.setConcurrency);
  return (
    <>
      <PathRow label={t('saveTo')} />
      <SettingRow label={t('defaultVideoQuality')} description={t('defaultVideoQualityDesc')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('defaultAudio')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('simultaneous')} description={t('simultaneousDesc')}>
        <Stepper
          label={t('simultaneous')}
          value={concurrency}
          min={MIN_CONCURRENCY}
          max={MAX_CONCURRENCY}
          onChange={setConcurrency}
        />
      </SettingRow>
      <SettingRow label={t('speedLimit')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('downloadSubs')} description={t('downloadSubsDesc')}>
        <Planned />
      </SettingRow>
      <MediaTools />
    </>
  );
}

function PlaybackTab() {
  const t = useT();
  const resume = useSettings((s) => s.resumePlayback);
  const setResume = useSettings((s) => s.setResumePlayback);
  return (
    <>
      <SettingRow label={t('engine')} description={t('engineDesc')}>
        <span className="font-mono text-[12.5px] text-muted">{t('engineValue')}</span>
      </SettingRow>
      <SettingRow label={t('hwDecoding')} description={t('hwDecodingDesc')}>
        <Planned />
      </SettingRow>
      <SettingRow label={t('audioOutput')}>
        <span className="text-[13px] font-semibold">{t('audioOutputValue')}</span>
      </SettingRow>
      <SettingRow label={t('resumeSetting')} description={t('resumeSettingDesc')}>
        <Toggle label={t('resumeSetting')} checked={resume} onChange={() => setResume(!resume)} />
      </SettingRow>
      <SettingRow label={t('gaplessSetting')} description={t('gaplessDesc')}>
        <Planned />
      </SettingRow>
      {/* The player offers "Open with system player" when a file cannot be read. */}
      <SettingRow label={t('externalFallback')} description={t('externalFallbackDesc')}>
        <span className="text-[13px] font-semibold">{t('alwaysOffered')}</span>
      </SettingRow>
      <SettingRow label={t('fileAssoc')} description={t('fileAssocDesc')}>
        <Planned />
      </SettingRow>
    </>
  );
}

function StorageTab() {
  const t = useT();
  const askConfirm = useUi((s) => s.askConfirm);
  const pushToast = useUi((s) => s.pushToast);
  const [usage, setUsage] = useState<StorageUsage | null>(null);
  const [refresh, setRefresh] = useState(0);

  useEffect(() => {
    backend
      .storageUsage()
      .then(setUsage)
      .catch(() => setUsage(null));
  }, [refresh]);

  const run = (action: () => Promise<number>, done: MessageKey) =>
    action()
      .then((freed) => {
        pushToast({ tone: 'success', message: t(done, { size: formatBytes(freed) }) });
        setRefresh((v) => v + 1);
      })
      .catch(report);

  const disk = usage?.disk;
  const share = (bytes: number) => (disk?.total ? `${(bytes / disk.total) * 100}%` : '0%');
  const other = disk ? Math.max(0, disk.total - disk.free - (usage?.libraryBytes ?? 0)) : 0;
  const drive = /^([A-Za-z]):/.exec(usage?.downloadDir ?? '')?.[1];

  return (
    <>
      {disk && usage && (
        <section className="mb-1 mt-2 flex flex-col gap-3 rounded-[10px] border border-line bg-surface p-4">
          <div className="flex justify-between text-[13px]">
            <span className="font-bold">
              {drive ? t('driveLabel', { d: drive.toUpperCase() }) : t('tabStorage')}
            </span>
            <span className="text-muted">
              {t('usedOf', {
                used: formatBytes(disk.total - disk.free),
                total: formatBytes(disk.total),
              })}
            </span>
          </div>
          <div className="flex h-2 overflow-hidden rounded-[4px] bg-line" aria-hidden="true">
            <div className="bg-accent" style={{ width: share(usage.libraryBytes) }} />
            <div className="bg-faint-icon" style={{ width: share(other) }} />
          </div>
          <div className="flex gap-[18px] text-[12px] text-muted">
            <span className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-[2px] bg-accent" />
              {t('libraryShare', { size: formatBytes(usage.libraryBytes) })}
            </span>
            <span className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-[2px] bg-faint-icon" />
              {t('otherShare', { size: formatBytes(other) })}
            </span>
          </div>
        </section>
      )}
      <PathRow label={t('libraryLocation')} />
      <SettingRow label={t('thumbCache')}>
        <span className="font-mono text-[12.5px] text-muted">
          {usage ? formatBytes(usage.thumbnailBytes) : '—'}
        </span>
        <button
          type="button"
          className={SECONDARY}
          disabled={!usage?.thumbnailBytes}
          onClick={() => void run(() => backend.clearThumbnails(), 'thumbsCleared')}
        >
          {t('clearCache')}
        </button>
      </SettingRow>
      <SettingRow label={t('tempFiles')} description={t('tempFilesDesc')}>
        <span className="font-mono text-[12.5px] text-muted">
          {usage ? formatBytes(usage.orphanTempBytes) : '—'}
        </span>
        <button
          type="button"
          className={SECONDARY}
          disabled={!usage?.orphanTempCount}
          onClick={() =>
            askConfirm({
              title: t('tempConfirmTitle'),
              body: t('tempConfirmBody', {
                n: usage?.orphanTempCount ?? 0,
                size: formatBytes(usage?.orphanTempBytes ?? 0),
              }),
              confirmLabel: t('tempConfirm'),
              onConfirm: () => void run(() => backend.cleanTemp(), 'tempDeleted'),
            })
          }
        >
          {t('cleanUp')}
        </button>
      </SettingRow>
    </>
  );
}

const MODES: { value: ResourceMode; label: MessageKey }[] = [
  { value: 'eco', label: 'modeEco' },
  { value: 'balanced', label: 'modeBalanced' },
  { value: 'performance', label: 'modePerformance' },
];

function PerformanceTab() {
  const t = useT();
  const mode = useSettings((s) => s.resourceMode);
  const setMode = useSettings((s) => s.setResourceMode);
  const limits = useSettings((s) => s.limits);
  const reduceMotion = useSettings((s) => s.reduceMotion);
  const setReduceMotion = useSettings((s) => s.setReduceMotion);
  return (
    <>
      <SettingRow
        label={t('resourceMode')}
        description={t('modeDesc', {
          n: limits.maxDownloads,
          c: limits.maxConversions,
          anim: limits.reducedMotion ? t('animReduced') : t('animStandard'),
        })}
      >
        <Segmented
          label={t('resourceMode')}
          value={mode}
          onChange={setMode}
          options={MODES.map((m) => ({ value: m.value, label: t(m.label) }))}
        />
      </SettingRow>
      <SettingRow
        label={t('reduceMotion')}
        description={limits.reducedMotion ? t('reduceMotionEco') : t('reduceMotionDesc')}
      >
        <Toggle
          label={t('reduceMotion')}
          checked={reduceMotion || limits.reducedMotion}
          onChange={() => setReduceMotion(!reduceMotion)}
        />
      </SettingRow>
    </>
  );
}

const THEMES: { value: ThemePref; label: MessageKey }[] = [
  { value: 'dark', label: 'themeDark' },
  { value: 'light', label: 'themeLight' },
  { value: 'system', label: 'themeSystem' },
];

function AppearanceTab() {
  const t = useT();
  const theme = useSettings((s) => s.theme);
  const setTheme = useSettings((s) => s.setTheme);
  return (
    <>
      <SettingRow label={t('theme')}>
        <Segmented<ThemePref>
          label={t('theme')}
          value={theme}
          onChange={setTheme}
          options={THEMES.map((x) => ({ value: x.value, label: t(x.label) }))}
        />
      </SettingRow>
      <SettingRow label={t('colors')}>
        <span className="font-mono text-[12.5px] text-muted">{t('colorsValue')}</span>
      </SettingRow>
    </>
  );
}

/** Catalog languages (CDC UX-01); others wait for a validated translation. */
function LanguageTab() {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const setLang = useSettings((s) => s.setLang);
  return (
    <SettingRow label={t('language')} description={t('languageMg')}>
      <Segmented<Lang>
        label={t('language')}
        value={lang}
        onChange={setLang}
        options={[
          { value: 'fr', label: 'Français' },
          { value: 'en', label: 'English' },
        ]}
      />
    </SettingRow>
  );
}

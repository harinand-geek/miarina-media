import { invoke } from '@tauri-apps/api/core';
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Button } from '../../components/Button';
import { Toggle } from '../../components/Controls';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { useT, type MessageKey } from '../../i18n';
import { isRunning, summarize, useDownloads } from '../../stores/downloads';
import {
  effectiveConcurrency,
  useSettings,
  type ResourceMode,
  type ThemePref,
} from '../../stores/settings';
import { useAndroidStorage } from './useAndroidStorage';
import { useUpdates } from './useUpdates';
import { version } from '../../../package.json';

function Row({
  icon,
  label,
  value,
  onTap,
  control,
}: {
  icon: string;
  label: string;
  value?: string;
  onTap?: () => void;
  control?: ReactNode;
}) {
  const content = (
    <>
      <Icon name={icon} size={22} className="text-muted" />
      <span className="flex min-w-0 flex-1 flex-col gap-0.5 text-left">
        <span className="text-[14.5px] font-semibold">{label}</span>
        {value && <span className="text-[12.5px] text-muted">{value}</span>}
      </span>
      {control}
    </>
  );
  const cls = 'flex min-h-[60px] w-full items-center gap-3.5 border-b border-divider py-2';
  return onTap ? (
    <button type="button" onClick={onTap} className={cls}>
      {content}
    </button>
  ) : (
    <div className={cls}>{content}</div>
  );
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section aria-label={title} className="flex flex-col">
      <h2 className="m-0 pb-1 text-[11.5px] font-bold tracking-[0.06em] text-faint">{title}</h2>
      {children}
    </section>
  );
}

function Planned() {
  const t = useT();
  return (
    <span className="shrink-0 rounded-xs bg-planned-ink px-1.5 py-0.5 font-mono text-[10px] font-bold text-planned">
      {t('planned')}
    </span>
  );
}

const mib = (bytes: number, lang: string) =>
  `${(bytes / 1048576).toLocaleString(lang === 'fr' ? 'fr-FR' : 'en-US', { maximumFractionDigits: 1 })} ${lang === 'fr' ? 'Mio' : 'MiB'}`;

/** Android v2 screen 12, update card: never installs without the user (UPD-04). */
function UpdateCard() {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const { phase, release, error, checked, check, download, install } = useUpdates();
  const tasks = useDownloads((s) => s.tasks);
  const running = useMemo(() => summarize(tasks).active.filter(isRunning).length, [tasks]);
  const [later, setLater] = useState(false);
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

  if (!release || later) {
    return (
      <div className="flex items-center gap-3">
        <span className="flex-1 text-[12.5px] text-muted">
          {phase === 'checking'
            ? t('updChecking')
            : checked && !release
              ? t('updLatest', { v: version })
              : t('versionLabel', { v: version })}
        </span>
        <Button
          pill
          className="h-10 px-4 text-[13px]"
          disabled={phase === 'checking'}
          onClick={() => {
            setLater(false);
            void check();
          }}
        >
          {t('updCheck')}
        </Button>
      </div>
    );
  }

  const size = mib(release.size, lang);
  const title =
    phase === 'ready' || phase === 'installing'
      ? t('updReady', { v: release.version })
      : phase === 'downloading'
        ? t('updDownloading', { v: release.version })
        : t('updAvailable', { v: release.version });

  return (
    <section
      aria-label={title}
      className="flex flex-col gap-3 rounded-2xl border border-chip-border bg-surface p-4"
    >
      <div className="flex items-center gap-3">
        <span className="grid h-10 w-10 place-items-center rounded-xl bg-accent-subtle text-chip-text">
          <Icon name="system_update_alt" size={22} />
        </span>
        <span className="flex flex-1 flex-col">
          <b className="text-[15px]">{title}</b>
          <span className="text-[12.5px] text-muted">{t('updMeta', { size })}</span>
        </span>
      </div>
      {phase === 'downloading' && (
        <ProgressBar
          value={release.size ? Math.min(100, (downloaded / release.size) * 100) : null}
          height={6}
          label={t('updProgress')}
          className="w-full"
        />
      )}
      {(phase === 'ready' || phase === 'installing') && (
        <span className="flex items-center gap-1.5 text-[12.5px] text-chip-text">
          <Icon name="verified" size={16} />
          {t('updVerified')}
        </span>
      )}
      {(phase === 'ready' || phase === 'installing') && running > 0 && (
        <span className="flex items-start gap-2 text-[12.5px] leading-[17px] text-muted">
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
          <Button
            variant="primary"
            pill
            className="h-11 flex-1 text-[14px] font-extrabold"
            onClick={() => void download()}
          >
            {t('updDownload', { size })}
          </Button>
        )}
        {(phase === 'ready' || phase === 'installing') && (
          <Button
            variant="primary"
            pill
            className="h-11 flex-1 text-[14px] font-extrabold"
            disabled={phase === 'installing'}
            onClick={() => void install()}
          >
            {phase === 'installing' ? t('updInstalling') : t('updInstall')}
          </Button>
        )}
        {phase !== 'downloading' && phase !== 'installing' && (
          <Button pill className="h-11 px-[18px] text-[14px]" onClick={() => setLater(true)}>
            {t('updLater')}
          </Button>
        )}
      </div>
    </section>
  );
}

const THEMES: ThemePref[] = ['dark', 'light', 'system'];
const THEME_KEYS: Record<ThemePref, MessageKey> = {
  dark: 'themeDark',
  light: 'themeLight',
  system: 'themeSystem',
};
const MODES: { id: ResourceMode; icon: string; label: MessageKey }[] = [
  { id: 'eco', icon: 'battery_saver', label: 'modeEco' },
  { id: 'balanced', icon: 'balance', label: 'modeBalanced' },
  { id: 'performance', icon: 'speed', label: 'modePerformance' },
];

/** Android v2 Settings (screen 12). */
export function MobileSettings({
  onOpenStorage,
  onBack,
}: {
  onOpenStorage: () => void;
  /** Settings opens as a full page from Home. */
  onBack: () => void;
}) {
  const t = useT();
  const s = useSettings();
  const storage = useAndroidStorage();

  return (
    <div className="flex flex-1 flex-col overflow-auto pb-5">
      <div className="flex h-14 shrink-0 items-center gap-1 px-2">
        <button
          type="button"
          aria-label={t('back')}
          onClick={onBack}
          className="grid h-12 w-12 place-items-center rounded-full"
        >
          <Icon name="arrow_back" size={24} />
        </button>
        <h1 className="m-0 text-[20px] font-extrabold">{t('settings')}</h1>
      </div>
      <div className="flex flex-col gap-[18px] px-4 pt-1">
        <UpdateCard />

        <section aria-label={t('perfTitle')} className="flex flex-col gap-2.5">
          <h2 className="m-0 text-[11.5px] font-bold tracking-[0.06em] text-faint">
            {t('perfTitle')}
          </h2>
          <div
            role="radiogroup"
            aria-label={t('perfTitle')}
            className="flex rounded-[20px] border border-line bg-sidebar p-[3px]"
          >
            {MODES.map((m) => {
              const on = s.resourceMode === m.id;
              return (
                <button
                  key={m.id}
                  type="button"
                  role="radio"
                  aria-checked={on}
                  onClick={() => s.setResourceMode(m.id)}
                  className={`flex h-[38px] flex-1 items-center justify-center gap-1.5 rounded-[19px] text-[13px] ${
                    on ? 'bg-line-strong font-bold text-fg' : 'font-semibold text-muted'
                  }`}
                >
                  <Icon name={m.icon} size={18} />
                  {t(m.label)}
                </button>
              );
            })}
          </div>
          <span className="text-[12.5px] leading-[18px] text-muted">
            {t('modeDesc', {
              n: s.limits.maxDownloads,
              c: s.limits.maxConversions,
              anim: s.limits.reducedMotion ? t('animReduced') : t('animStandard'),
            })}
          </span>
        </section>

        <Group title={t('playbackTitle')}>
          <Row
            icon="history"
            label={t('resumeSetting')}
            value={t('resumeSettingDesc')}
            control={
              <Toggle
                size="mobile"
                label={t('resumeSetting')}
                checked={s.resumePlayback}
                onChange={() => s.setResumePlayback(!s.resumePlayback)}
              />
            }
          />
          <Row
            icon="headphones"
            label={t('headsetSetting')}
            value={t('headsetSettingDesc')}
            control={<Planned />}
          />
          <Row
            icon="gesture"
            label={t('gesturesSetting')}
            value={t('gesturesSettingDesc')}
            control={<Planned />}
          />
          <Row
            icon="blur_linear"
            label={t('crossfadeSetting')}
            value={t('crossfadeSettingDesc')}
            control={<Planned />}
          />
          <Row
            icon="all_inclusive"
            label={t('gaplessSetting')}
            value={t('gaplessSettingDesc')}
            control={<Planned />}
          />
        </Group>

        <Group title={t('downloadsTitle')}>
          <Row
            icon="folder"
            label={t('storageLocation')}
            value={storage.label}
            onTap={storage.canChange ? onOpenStorage : undefined}
          />
          <Row icon="high_quality" label={t('defaultQuality')} value={t('defaultQualityDesc')} />
          <Row icon="stacks" label={t('simultaneous')} value={String(effectiveConcurrency(s))} />
        </Group>

        <Group title={t('appTitle')}>
          <Row icon="notifications" label={t('progressNotif')} value={t('progressNotifDesc')} />
          <Row
            icon="dark_mode"
            label={t('theme')}
            value={t(THEME_KEYS[s.theme])}
            onTap={() => s.setTheme(THEMES[(THEMES.indexOf(s.theme) + 1) % THEMES.length]!)}
          />
          <Row
            icon="language"
            label={t('language')}
            value={s.lang === 'fr' ? 'Français' : 'English'}
            onTap={() => s.setLang(s.lang === 'fr' ? 'en' : 'fr')}
          />
        </Group>

        <Group title={t('aboutTitle')}>
          <Row icon="info" label="Miarina Media" value={t('versionLabel', { v: version })} />
        </Group>
      </div>
    </div>
  );
}

import type { ReactNode } from 'react';
import { Segmented, Toggle } from '../../components/Controls';
import { Icon } from '../../components/Icon';
import { ANDROID_STORES } from '../../dev/fixtures';
import {
  effectiveConcurrency,
  useSettings,
  type ResourceMode,
  type ThemePref,
} from '../../stores/settings';

interface RowProps {
  icon: string;
  label: string;
  value?: string;
  onTap?: () => void;
  control?: ReactNode;
}

function Row({ icon, label, value, onTap, control }: RowProps) {
  const content = (
    <>
      <Icon name={icon} size={24} className="text-muted" />
      <span className="flex min-w-0 flex-1 flex-col gap-0.5 text-left">
        <span className="text-[15px] font-semibold">{label}</span>
        {value && <span className="text-[13px] text-muted">{value}</span>}
      </span>
      {control}
    </>
  );
  const cls = 'flex min-h-16 w-full items-center gap-4 px-4 py-2';
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
    <section aria-label={title} className="flex flex-col py-2">
      <h2 className="m-0 px-4 py-2 text-[12.5px] font-bold text-accent-strong">{title}</h2>
      {children}
    </section>
  );
}

const THEMES: ThemePref[] = ['dark', 'light', 'system'];
const THEME_LABELS: Record<ThemePref, string> = { dark: 'Dark', light: 'Light', system: 'System' };

export function MobileSettings({ onOpenStorage }: { onOpenStorage: () => void }) {
  const s = useSettings();
  const store = ANDROID_STORES.find((x) => x.id === s.androidStore)!;

  return (
    <div className="flex flex-1 flex-col overflow-auto pb-5 pt-2">
      <h1 className="m-0 flex h-14 items-center px-4 text-[22px] font-bold tracking-[-0.02em]">
        Settings
      </h1>
      <Group title="Downloads">
        <Row
          icon="folder"
          label="Storage location"
          value={`${store.label} · ${store.path}`}
          onTap={onOpenStorage}
        />
        <Row
          icon="high_quality"
          label="Default quality"
          value="1080p · falls back when unavailable"
        />
        <Row
          icon="wifi"
          label="Wi-Fi only for large files"
          value="Ask before using mobile data over 100 MB"
          control={
            <Toggle
              size="mobile"
              label="Wi-Fi only for large files"
              checked={s.toggles.wifiOnlyLargeFiles}
              onChange={() => s.toggle('wifiOnlyLargeFiles')}
            />
          }
        />
        <Row icon="stacks" label="Simultaneous downloads" value={String(effectiveConcurrency(s))} />
      </Group>
      <Group title="App">
        <Row
          icon="notifications"
          label="Progress notifications"
          value="Show speed and time left"
          control={
            <Toggle
              size="mobile"
              label="Progress notifications"
              checked={s.toggles.progressNotifications}
              onChange={() => s.toggle('progressNotifications')}
            />
          }
        />
        {/* Q1: Eco / Balanced / Performance replaces the "Low-resource mode" toggle. */}
        <div className="flex flex-col gap-2 px-4 py-2">
          <span className="flex items-center gap-4">
            <Icon name="battery_saver" size={24} className="text-muted" />
            <span className="text-[15px] font-semibold">Resource mode</span>
          </span>
          <Segmented<ResourceMode>
            label="Resource mode"
            variant="mobile"
            value={s.resourceMode}
            onChange={s.setResourceMode}
            options={[
              { value: 'eco', label: 'Eco' },
              { value: 'balanced', label: 'Balanced' },
              { value: 'performance', label: 'Performance' },
            ]}
          />
        </div>
        <Row
          icon="dark_mode"
          label="Theme"
          value={THEME_LABELS[s.theme]}
          onTap={() => s.setTheme(THEMES[(THEMES.indexOf(s.theme) + 1) % THEMES.length]!)}
        />
        <Row icon="language" label="Language" value="English" />
      </Group>
      <Group title="About">
        <Row icon="info" label="Miarina Media" value="Version 0.1.0 · media.miarina.org" />
      </Group>
    </div>
  );
}

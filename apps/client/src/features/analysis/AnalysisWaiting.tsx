import { useState } from 'react';
import { Skeleton } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { ProgressBar } from '../../components/ProgressBar';
import { useT, type MessageKey } from '../../i18n';
import { useNow } from '../downloads/useNow';

/** What the wait says, by elapsed seconds (no invented step or duration). */
const STAGES: { from: number; key: MessageKey }[] = [
  { from: 0, key: 'prepStage1' },
  { from: 4, key: 'prepStage2' },
  { from: 12, key: 'prepStage3' },
  { from: 25, key: 'prepStage4' },
];
const TIPS: MessageKey[] = ['prepTip1', 'prepTip2', 'prepTip3', 'prepTip4'];
const TIP_EVERY_S = 5;

const hostOf = (url: string | null) => {
  try {
    return url ? new URL(url).hostname.replace(/^(www|m)\./, '') : '';
  } catch {
    return '';
  }
};

/**
 * Android: the formats sheet while the link is read (decision 0006 recette:
 * a bare "Reading formats…" made people give up). Says what is happening,
 * how long it has been, and shows a useful tip — no fake progress.
 * Remount it per link (`key`) so the clock restarts.
 */
export function AnalysisWaiting({ url }: { url: string | null }) {
  const t = useT();
  const [start] = useState(() => Date.now());
  const now = useNow(1000);
  const elapsed = Math.max(0, Math.floor((now - start) / 1000));
  const stage = [...STAGES].reverse().find((s) => elapsed >= s.from) ?? STAGES[0]!;
  const tipIndex = Math.floor(elapsed / TIP_EVERY_S) % TIPS.length;
  const host = hostOf(url);

  return (
    <div className="flex flex-col gap-4 pb-6 pt-2" aria-busy="true">
      <div className="flex items-center gap-3.5">
        <span className="relative grid h-14 w-14 shrink-0 place-items-center">
          <span className="absolute inset-0 rounded-full bg-accent-subtle motion-safe:animate-ping motion-safe:[animation-duration:1.8s]" />
          <span className="relative grid h-14 w-14 place-items-center rounded-full bg-accent-subtle text-accent-strong">
            <Icon name="downloading" size={28} />
          </span>
        </span>
        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
          <span className="text-[17px] font-extrabold">{t('prepTitle')}</span>
          <span className="truncate font-mono text-[12.5px] text-muted tabular">
            {[host, t('prepElapsed', { n: elapsed })].filter(Boolean).join(' · ')}
          </span>
        </span>
      </div>

      <ProgressBar value={null} height={4} label={t('prepTitle')} className="w-full" />
      <p aria-live="polite" className="m-0 min-h-[40px] text-[14px] leading-5 text-fg">
        {t(stage.key, { host: host || t('prepThisSite') })}
      </p>

      <Skeleton className="aspect-video rounded-[18px]" />

      <div className="flex items-start gap-3 rounded-[18px] bg-surface p-4">
        <Icon name="lightbulb" size={22} className="shrink-0 text-warn" />
        <span className="flex min-w-0 flex-col gap-0.5">
          <span className="text-[12px] font-bold tracking-[0.04em] text-muted">{t('prepTip')}</span>
          <span key={tipIndex} className="animate-fade-in text-[13.5px] leading-5">
            {t(TIPS[tipIndex]!)}
          </span>
        </span>
      </div>
    </div>
  );
}

import { useEffect } from 'react';
import { useT } from '../../i18n';
import { useSettings } from '../../stores/settings';
import { EQ_MAX_DB, PRESET_LABELS, useEqualizer, type EqPreset } from './equalizer';

/** Band labels of the Android design (screen 09). */
const BANDS = ['60', '230', '910', '3.6k', '9k', '14k'];

const percent = (db: number) => ((db + EQ_MAX_DB) / (2 * EQ_MAX_DB)) * 100;
const signed = (db: number) => (db > 0 ? `+${db}` : String(db));

/**
 * Android v2 screen 09, equalizer (AND-09): switch, reset, presets and six
 * vertical bands, applied by the system equalizer to what plays (files are
 * never modified). Replaced by an explanation when the device has none.
 * Same settings as the Windows equalizer (`mm:eq:v1`).
 */
export function MobileEqualizer() {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const enabled = useEqualizer((s) => s.enabled);
  const preset = useEqualizer((s) => s.preset);
  const gains = useEqualizer((s) => s.gains);
  const supported = useEqualizer((s) => s.supported);
  const { setEnabled, setPreset, setGain } = useEqualizer.getState();

  // Opening the sheet asks the service again (support is known once it plays).
  useEffect(() => useEqualizer.getState().push(), []);

  const label = (band: string) => (lang === 'fr' ? band.replace('.', ',') : band);

  if (supported === false) {
    return (
      <section aria-labelledby="m-eq" className="flex flex-col gap-2.5">
        <h2 id="m-eq" className="m-0 text-[18px] font-extrabold">
          {t('eq')}
        </h2>
        <p className="m-0 text-[13px] leading-[19px] text-muted">{t('eqUnavailable')}</p>
      </section>
    );
  }

  return (
    <section aria-labelledby="m-eq" className="flex flex-col gap-3">
      <div className="flex items-center gap-3">
        <h2 id="m-eq" className="m-0 flex-1 text-[18px] font-extrabold">
          {t('eq')}
        </h2>
        <button
          type="button"
          disabled={!enabled || preset === 'flat'}
          onClick={() => setPreset('flat')}
          className="h-9 px-2 text-[13px] font-semibold text-muted disabled:opacity-45"
        >
          {t('reset')}
        </button>
        <button
          type="button"
          role="switch"
          aria-checked={enabled}
          aria-label={t('eqToggle')}
          onClick={() => setEnabled(!enabled)}
          className={`relative h-8 w-[52px] shrink-0 rounded-full ${enabled ? 'bg-coral' : 'bg-line-strong'}`}
        >
          <span
            className={`absolute top-1 size-6 rounded-full transition-[left] duration-150 ${
              enabled ? 'left-[24px] bg-coral-ink' : 'left-1 bg-muted'
            }`}
          />
        </button>
      </div>

      <div role="radiogroup" aria-label={t('eqPresets')} className="flex flex-wrap gap-2">
        {[...(Object.keys(PRESET_LABELS) as EqPreset[]), 'custom' as const].map((id) => {
          const on = enabled && preset === id;
          const custom = id === 'custom';
          return (
            <button
              key={id}
              type="button"
              role="radio"
              aria-checked={on}
              // "Custom" only shows that a band was moved.
              disabled={custom}
              onClick={() => !custom && setPreset(id)}
              className={`h-[34px] rounded-[17px] border px-3 text-[12.5px] ${
                on
                  ? 'border-coral-chip-border bg-coral-subtle font-bold text-coral-strong'
                  : `border-line-strong font-semibold text-muted ${custom ? 'opacity-60' : ''}`
              }`}
            >
              {custom ? t('eqCustom') : t(PRESET_LABELS[id])}
            </button>
          );
        })}
      </div>

      <div className={`flex justify-between px-1 ${enabled ? '' : 'opacity-45'}`}>
        {BANDS.map((band, i) => {
          const db = gains[i] ?? 0;
          return (
            <label key={band} className="flex w-11 flex-col items-center gap-2">
              <span className="font-mono text-[11px] text-muted">{signed(db)}</span>
              <span className="relative h-[140px] w-1 rounded-full bg-line-strong">
                <span
                  aria-hidden="true"
                  className="absolute inset-x-0 bottom-0 rounded-full bg-coral"
                  style={{ height: `${percent(db)}%` }}
                />
                <span
                  aria-hidden="true"
                  className="absolute -left-2 -mb-2.5 size-5 rounded-full border-[3px] border-coral bg-white"
                  style={{ bottom: `${percent(db)}%` }}
                />
                <input
                  type="range"
                  min={-EQ_MAX_DB}
                  max={EQ_MAX_DB}
                  step={0.5}
                  value={db}
                  disabled={!enabled}
                  aria-label={t('eqBand', { band: label(band) })}
                  aria-valuetext={t('eqGain', { db: signed(db) })}
                  onChange={(e) => setGain(i, Number(e.target.value))}
                  className="absolute -inset-x-4 -inset-y-2.5 touch-none opacity-0 [direction:rtl] [writing-mode:vertical-lr]"
                />
              </span>
              <span className="font-mono text-[11px] text-muted">{label(band)}</span>
            </label>
          );
        })}
      </div>
    </section>
  );
}

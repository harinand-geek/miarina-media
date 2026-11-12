import { useT } from '../../i18n';
import { usePlayer } from '../../stores/player';
import { EQ_BANDS, EQ_MAX_DB, PRESET_LABELS, useEqualizer, type EqPreset } from './equalizer';

const percent = (db: number) => ((db + EQ_MAX_DB) / (2 * EQ_MAX_DB)) * 100;

/**
 * Windows v2 screen 6, "Sound" tab: switch, presets, six bands (60 Hz–14
 * kHz). Applied by libVLC to what plays; files are never modified. Without
 * libVLC (WebView player) it is shown but cannot be used.
 */
export function EqualizerSection() {
  const t = useT();
  const available = usePlayer((s) => s.nativeVideo);
  const enabled = useEqualizer((s) => s.enabled);
  const preset = useEqualizer((s) => s.preset);
  const gains = useEqualizer((s) => s.gains);
  const { setEnabled, setPreset, setGain } = useEqualizer.getState();
  const active = available && enabled;

  return (
    <section className="flex flex-col gap-3" aria-labelledby="eq-head">
      <div className="flex items-center justify-between">
        <span id="eq-head" className="text-[14px] font-bold">
          {t('eq')}
        </span>
        <button
          type="button"
          role="switch"
          aria-checked={enabled}
          aria-label={t('eqToggle')}
          disabled={!available}
          onClick={() => setEnabled(!enabled)}
          className={`relative h-[22px] w-[38px] rounded-[11px] disabled:opacity-45 ${
            enabled ? 'bg-coral' : 'bg-line-strong'
          }`}
        >
          <span
            className={`absolute top-[3px] size-4 rounded-full transition-[left] duration-150 ${
              enabled ? 'left-[19px] bg-coral-ink' : 'left-[3px] bg-muted'
            }`}
          />
        </button>
      </div>

      <div role="radiogroup" aria-label={t('eqPresets')} className="flex flex-wrap gap-1.5">
        {(Object.keys(PRESET_LABELS) as EqPreset[]).map((id) => {
          const on = enabled && preset === id;
          return (
            <button
              key={id}
              type="button"
              role="radio"
              aria-checked={on}
              disabled={!available}
              onClick={() => setPreset(id)}
              className={`h-7 rounded-[14px] border px-[11px] text-[12px] font-semibold disabled:opacity-45 ${
                on ? 'border-coral bg-coral-subtle text-fg' : 'border-line-strong text-muted'
              }`}
            >
              {t(PRESET_LABELS[id])}
            </button>
          );
        })}
      </div>

      <div
        className={`flex h-[140px] items-end justify-between rounded-[10px] border border-line bg-bg px-2 pt-3 ${
          active ? '' : 'opacity-45'
        }`}
      >
        {EQ_BANDS.map((band, i) => {
          const db = gains[i] ?? 0;
          return (
            <label
              key={band}
              className="flex h-full flex-col items-center justify-end gap-1.5 pb-2"
            >
              <span className="relative w-1.5 flex-1 rounded-[3px] bg-line">
                <span
                  aria-hidden="true"
                  className="absolute inset-x-0 bottom-0 rounded-[3px] bg-coral-subtle"
                  style={{ height: `${percent(db)}%` }}
                />
                <span
                  aria-hidden="true"
                  className="absolute -left-[5px] -mb-2 size-4 rounded-full border-[3px] border-bg bg-coral"
                  style={{ bottom: `${percent(db)}%` }}
                />
                <input
                  type="range"
                  min={-EQ_MAX_DB}
                  max={EQ_MAX_DB}
                  step={0.5}
                  value={db}
                  disabled={!active}
                  aria-label={t('eqBand', { band })}
                  aria-valuetext={t('eqGain', { db: db > 0 ? `+${db}` : String(db) })}
                  onChange={(e) => setGain(i, Number(e.target.value))}
                  className="absolute -inset-x-2 inset-y-0 cursor-pointer opacity-0 [direction:rtl] [writing-mode:vertical-lr] disabled:cursor-default"
                />
              </span>
              <span className="font-mono text-[10.5px] text-muted">{band}</span>
            </label>
          );
        })}
      </div>
      <span className="text-[12px] text-muted">
        {available ? t('eqNote') : t('eqEngineMissing')}
      </span>
    </section>
  );
}

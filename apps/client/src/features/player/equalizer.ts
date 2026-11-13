import { create } from 'zustand';
import type { MessageKey, Translate } from '../../i18n';
import { durableSet } from '../../services/durableState';
import { nativePlayback, nativePlayer } from '../../services/nativePlayer';
import { applyEqualizer } from '../../stores/player';

/** Bands of the Windows v2 design (Hz labels). */
export const EQ_BANDS = ['60', '230', '910', '3.6k', '7k', '14k'] as const;
export const EQ_MAX_DB = 12;

export type EqPreset = 'flat' | 'bass' | 'voice' | 'rock' | 'classic';

/** Design positions (0–100, 50 = 0 dB) turned into decibels. */
const fromDesign = (levels: number[]) =>
  levels.map((v) => Math.round(((v - 50) / 50) * EQ_MAX_DB * 2) / 2);

export const EQ_PRESETS: Record<EqPreset, number[]> = {
  flat: fromDesign([50, 50, 50, 50, 50, 50]),
  bass: fromDesign([78, 68, 52, 48, 50, 54]),
  voice: fromDesign([40, 48, 66, 70, 58, 46]),
  rock: fromDesign([70, 58, 44, 52, 64, 70]),
  classic: fromDesign([60, 54, 50, 48, 56, 64]),
};

const STORAGE_KEY = 'mm:eq:v1';

interface Saved {
  enabled: boolean;
  preset: EqPreset | 'custom';
  gains: number[];
}

function load(): Saved {
  try {
    const raw = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null') as Partial<Saved> | null;
    const gains = Array.isArray(raw?.gains) && raw.gains.length === 6 ? raw.gains : null;
    if (raw && gains && gains.every((g) => typeof g === 'number' && Number.isFinite(g))) {
      return {
        enabled: !!raw.enabled,
        preset: raw.preset ?? 'custom',
        gains: gains.map((g) => Math.max(-EQ_MAX_DB, Math.min(EQ_MAX_DB, g))),
      };
    }
  } catch {
    // Unreadable: defaults.
  }
  return { enabled: false, preset: 'flat', gains: [...EQ_PRESETS.flat] };
}

interface EqualizerState extends Saved {
  /** Android: whether the device has an equalizer (`null` until known). */
  supported: boolean | null;
  setEnabled: (on: boolean) => void;
  setPreset: (preset: EqPreset) => void;
  setGain: (band: number, db: number) => void;
  /** Sends the setting to the playback engine (also after an engine change). */
  push: () => void;
}

/**
 * Equalizer of the Windows player (libVLC): applied to what plays, files
 * are never modified. Kept with the other durable playback settings.
 */
export const useEqualizer = create<EqualizerState>((set, get) => {
  const commit = (next: Partial<Saved>) => {
    set(next);
    const { enabled, preset, gains } = get();
    durableSet(STORAGE_KEY, JSON.stringify({ enabled, preset, gains }));
    get().push();
  };
  return {
    ...load(),
    supported: null,
    setEnabled: (enabled) => commit({ enabled }),
    setPreset: (preset) => commit({ preset, gains: [...EQ_PRESETS[preset]], enabled: true }),
    setGain: (band, db) => {
      const gains = [...get().gains];
      gains[band] = Math.max(-EQ_MAX_DB, Math.min(EQ_MAX_DB, db));
      commit({ gains, preset: 'custom' });
    },
    push: () => {
      const { enabled, gains } = get();
      applyEqualizer(enabled ? gains : null);
      // Android: the system equalizer of the playback service (AND-10).
      if (nativePlayback()) {
        void nativePlayer
          .equalizer(enabled, gains)
          .then((supported) => supported !== null && set({ supported }))
          .catch(() => {});
      }
    },
  };
});

export const PRESET_LABELS: Record<EqPreset, MessageKey> = {
  flat: 'eqFlat',
  bass: 'eqBass',
  voice: 'eqVoice',
  rock: 'eqRock',
  classic: 'eqClassic',
};

/** "Equalizer · Bass", "EQ off" (Now playing chip). */
export function equalizerLabel(t: Translate) {
  const { enabled, preset } = useEqualizer.getState();
  if (!enabled) return t('eqOff');
  return `${t('eq')} · ${preset === 'custom' ? t('eqCustom') : t(PRESET_LABELS[preset])}`;
}

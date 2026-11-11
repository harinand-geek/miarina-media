export const PLAYBACK_RATES = [0.5, 0.75, 1, 1.25, 1.5, 2] as const;

export function nextRate(rate: number) {
  const index = PLAYBACK_RATES.indexOf(rate as (typeof PLAYBACK_RATES)[number]);
  return PLAYBACK_RATES[(index + 1) % PLAYBACK_RATES.length]!;
}

/** "1.0×", "1.25×", "0.5×" — the design shows one decimal for whole rates. */
export function formatRate(rate: number) {
  return `${Number.isInteger(rate) ? rate.toFixed(1) : rate}×`;
}

/** "1,25×" in French, "1.25×" in English. */
export function rateLabel(rate: number, lang: string) {
  return `${rate.toLocaleString(lang === 'fr' ? 'fr-FR' : 'en-US')}×`;
}

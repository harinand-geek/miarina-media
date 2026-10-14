/**
 * Flow mark from the design handoff (32-unit grid, radius 8). Colors follow
 * the theme (inverted on light grounds) unless `inverted` forces them.
 */
export function Logo({ size = 18, inverted = false }: { size?: number; inverted?: boolean }) {
  const tile = inverted ? '#101820' : 'var(--mm-logo-tile)';
  const glyph = inverted ? '#35C9BD' : 'var(--mm-logo-glyph)';
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      <rect width="32" height="32" rx="8" fill={tile} />
      <path d="M13 9.5v13l10-6.5z" fill={glyph} />
      <rect x="6" y="10.5" width="4" height="2.5" rx="1.25" fill={glyph} />
      <rect x="4" y="14.75" width="6" height="2.5" rx="1.25" fill={glyph} />
      <rect x="6" y="19" width="4" height="2.5" rx="1.25" fill={glyph} />
    </svg>
  );
}

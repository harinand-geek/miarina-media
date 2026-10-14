interface IconProps {
  name: string;
  size?: number;
  /** FILL 1 is reserved for the active nav item and transport glyphs. */
  fill?: boolean;
  className?: string;
}

/** Material Symbols Rounded, weight 400, grade 0 (design system §9). */
export function Icon({ name, size = 20, fill = false, className = '' }: IconProps) {
  return (
    <span
      aria-hidden="true"
      className={`material-symbols-rounded shrink-0 select-none leading-none ${className}`}
      style={{
        fontSize: size,
        fontVariationSettings: `'FILL' ${fill ? 1 : 0}, 'wght' 400, 'GRAD' 0, 'opsz' ${size <= 20 ? 20 : 24}`,
      }}
    >
      {name}
    </span>
  );
}

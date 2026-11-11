/**
 * 4d app mark (design/design_handoff_windows_v2/assets): dark tile, coral
 * play triangle, teal flow bars. The tile keeps its dark ground on both
 * themes; `outlined` adds the Windows 1 px edge so it reads on dark chrome.
 */
export function Logo({ size = 18, outlined = false }: { size?: number; outlined?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      {outlined ? (
        <rect
          x="0.5"
          y="0.5"
          width="31"
          height="31"
          rx="7.5"
          fill="var(--mm-logo-tile)"
          stroke="var(--mm-logo-stroke)"
          strokeWidth="1"
        />
      ) : (
        <rect width="32" height="32" rx="8" fill="var(--mm-logo-tile)" />
      )}
      <path d="M13 9.5v13l10-6.5z" fill="#FF7A45" />
      <rect x="6" y="10.5" width="4" height="2.5" rx="1.25" fill="#35C9BD" />
      <rect x="4" y="14.75" width="6" height="2.5" rx="1.25" fill="#35C9BD" />
      <rect x="6" y="19" width="4" height="2.5" rx="1.25" fill="#35C9BD" />
    </svg>
  );
}

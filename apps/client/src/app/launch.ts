/**
 * Android cold start (design_handoff_splash): Home plays the end of the
 * splash once — the header logo comes from the splash position, the content
 * rises in, the bottom bar slides up. Each part runs at most once per load.
 */
const pending = { home: true, nav: true };

/** `true` the first time `part` asks during this page load. */
export function takeLaunch(part: keyof typeof pending): boolean {
  const first = pending[part];
  pending[part] = false;
  return first;
}

/** Movement is replaced by fades (reduce motion, Eco mode). */
export function motionReduced(): boolean {
  if (typeof document === 'undefined') return true;
  if (document.documentElement.dataset.motion === 'reduced') return true;
  return typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/** Splash icon tile (112 dp, screen centre) → header logo (`size` px). */
export function flyLogoFromSplash(el: HTMLElement, size: number) {
  if (typeof el.animate !== 'function' || motionReduced()) return;
  const r = el.getBoundingClientRect();
  const dx = window.innerWidth / 2 - (r.left + r.width / 2);
  const dy = window.innerHeight / 2 - (r.top + r.height / 2);
  el.animate(
    [{ transform: `translate(${dx}px, ${dy}px) scale(${112 / size})` }, { transform: 'none' }],
    { duration: 460, easing: 'cubic-bezier(0.2, 0, 0, 1)' },
  );
}

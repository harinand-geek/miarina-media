import { useCallback, useLayoutEffect, useRef, type PointerEvent, type RefObject } from 'react';
import { motionReduced } from '../../app/launch';

/** Movement before the gesture takes the pointer (taps stay taps). */
const SLOP = 8;
/** Share of the way, or a quick flick, that minimizes. */
const DISTANCE = 0.22;
const FLICK = 0.55; // px/ms
const MS = 280;

/**
 * Where the mini-player sits, from the bottom of the shell: bottom bar
 * (72) + its margin (8) + its height (76). Its cover is 56 px, 18 px from
 * the left (8 margin + 10 padding) and 10 px from its top.
 */
const MINI = {
  fromBottom: 156,
  height: 76,
  side: 8,
  cover: 56,
  coverX: 18,
  coverY: 10,
  radius: 22,
};

const clamp = (v: number) => Math.min(1, Math.max(0, v));
const lerp = (a: number, b: number, k: number) => a + (b - a) * k;
const easeOut = (x: number) => 1 - (1 - x) ** 3;

/**
 * Android full player (decision 0006, as in common music players): drag it
 * down with a finger and it turns into the mini-player — the sheet follows
 * the finger and narrows to the mini-player card, the artwork (`[data-swipe-
 * art]`) slides left and shrinks to the mini cover, the rest
 * (`[data-swipe-fade]`) fades out and the mini row (`[data-swipe-mini]`)
 * fades in. Released past a fifth of the way (or flicked) it minimizes,
 * otherwise it springs back. Opening plays the same in reverse.
 *
 * Styles are written straight to the elements, one frame at a time (no
 * React render per move). `follow: false` (video: the native picture cannot
 * move) only minimizes on release. Reduced motion, Eco or no animation
 * support: no movement, the player just minimizes or opens.
 */
export function useSwipeDown(
  ref: RefObject<HTMLElement | null>,
  onMinimize: () => void,
  { open, follow }: { open: boolean; follow: boolean },
) {
  const drag = useRef<{ y: number; id: number; taken: boolean; from: number } | null>(null);
  const last = useRef({ y: 0, t: 0, v: 0 });
  const dy = useRef(0);
  const frame = useRef(0);

  const canAnimate = (el: HTMLElement) =>
    typeof el.animate === 'function' &&
    typeof requestAnimationFrame === 'function' &&
    !motionReduced();

  const endOf = (el: HTMLElement) => Math.max(1, el.offsetHeight - MINI.fromBottom);

  const paint = useCallback((el: HTMLElement, y: number) => {
    dy.current = y;
    const h = el.offsetHeight;
    const k = clamp(y / endOf(el));
    const side = MINI.side * k;
    const bottom = Math.max(0, h - y - lerp(h, MINI.height, k));
    const radius = Math.min(MINI.radius, y / 3);
    el.style.transform = `translateY(${y}px)`;
    el.style.clipPath = `inset(0px ${side}px ${bottom}px ${side}px round ${radius}px)`;

    const art = el.querySelector<HTMLElement>('[data-swipe-art]');
    if (art) {
      const s = lerp(1, MINI.cover / Math.max(1, art.offsetWidth), k);
      const x = lerp(0, MINI.coverX - art.offsetLeft, k);
      const top = lerp(0, MINI.coverY - art.offsetTop, k);
      art.style.transformOrigin = '0 0';
      art.style.transform = `translate(${x}px, ${top}px) scale(${s})`;
    }
    const fade = String(1 - clamp(k * 2.5));
    el.querySelectorAll<HTMLElement>('[data-swipe-fade]').forEach((n) => (n.style.opacity = fade));
    el.querySelectorAll<HTMLElement>('[data-swipe-mini]').forEach(
      (n) => (n.style.opacity = String(clamp((k - 0.35) / 0.65))),
    );
  }, []);

  const reset = useCallback((el: HTMLElement) => {
    dy.current = 0;
    el.style.transform = '';
    el.style.clipPath = '';
    const art = el.querySelector<HTMLElement>('[data-swipe-art]');
    if (art) art.style.transform = '';
    el.querySelectorAll<HTMLElement>('[data-swipe-fade],[data-swipe-mini]').forEach(
      (n) => (n.style.opacity = ''),
    );
  }, []);

  /** Animates the offset to `to` (px), one style write per frame. */
  const run = useCallback(
    (el: HTMLElement, to: number, done?: () => void) => {
      cancelAnimationFrame(frame.current);
      const from = dy.current;
      const start = performance.now();
      const step = (now: number) => {
        const x = clamp((now - start) / MS);
        paint(el, lerp(from, to, easeOut(x)));
        if (x < 1) frame.current = requestAnimationFrame(step);
        else done?.();
      };
      frame.current = requestAnimationFrame(step);
    },
    [paint],
  );

  /**
   * Turns the player into the mini-player (also the ⌄ button). Video goes
   * at once: its native picture is drawn above the page and would stay at
   * the top while the sheet slides away (seen on the phone, 2026-11-15).
   */
  const minimize = useCallback(() => {
    const el = ref.current;
    if (!el || !follow || !canAnimate(el)) {
      if (el) reset(el);
      onMinimize();
      return;
    }
    run(el, endOf(el), () => {
      // Hide now (React does the same on its render): no frame back at rest.
      el.hidden = true;
      onMinimize();
      reset(el);
    });
  }, [ref, follow, onMinimize, reset, run]);

  // Opening: from the mini-player up to the full player.
  useLayoutEffect(() => {
    const el = ref.current;
    if (!open || !el || !follow || !canAnimate(el)) return;
    paint(el, endOf(el));
    run(el, 0, () => reset(el));
    return () => cancelAnimationFrame(frame.current);
  }, [open, follow, ref, paint, run, reset]);

  const onPointerDown = (e: PointerEvent<HTMLElement>) => {
    if (e.button !== 0) return;
    cancelAnimationFrame(frame.current);
    drag.current = { y: e.clientY, id: e.pointerId, taken: false, from: dy.current };
    last.current = { y: e.clientY, t: e.timeStamp, v: 0 };
  };

  const onPointerMove = (e: PointerEvent<HTMLElement>) => {
    const d = drag.current;
    const el = ref.current;
    if (!d || !el || d.id !== e.pointerId) return;
    const moved = e.clientY - d.y;
    if (!d.taken) {
      if (moved < SLOP) return;
      d.taken = true;
      e.currentTarget.setPointerCapture?.(e.pointerId);
    }
    const dt = Math.max(1, e.timeStamp - last.current.t);
    last.current = { y: e.clientY, t: e.timeStamp, v: (e.clientY - last.current.y) / dt };
    if (follow && canAnimate(el)) {
      paint(el, Math.min(endOf(el), Math.max(0, d.from + moved)));
    }
  };

  const onPointerEnd = (e: PointerEvent<HTMLElement>) => {
    const d = drag.current;
    const el = ref.current;
    drag.current = null;
    if (!d?.taken || !el) return;
    const moved = Math.max(0, e.clientY - d.y);
    const way = follow ? endOf(el) : el.offsetHeight;
    if (moved > way * DISTANCE || (last.current.v > FLICK && moved > 40)) {
      minimize();
    } else if (dy.current > 0) {
      run(el, 0, () => reset(el));
    }
  };

  return {
    minimize,
    /** Spread on the zones that drag the player (grab line, top bar, artwork). */
    dragZone: {
      onPointerDown,
      onPointerMove,
      onPointerUp: onPointerEnd,
      onPointerCancel: onPointerEnd,
      style: { touchAction: 'none' as const },
    },
  };
}

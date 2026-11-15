import { useEffect, useRef, useState } from 'react';
import type { LandingText } from '../pages/homeContent';
import { Icon } from './Common';

/** Seconds per screenshot. */
const SHOT_SECONDS = 6;

/**
 * Library and player screenshots (landing v4): Windows albums, Windows now
 * playing, Android phone. Advances every 6 s while visible (not with reduced
 * motion); a tab click selects it and restarts the timer. Without JavaScript
 * the first screenshot and the phone are shown.
 */
export function Showcase({ text }: { text: LandingText }) {
  const [shot, setShot] = useState(0);
  const [restart, setRestart] = useState(0);
  const stage = useRef<HTMLDivElement>(null);
  const bars = useRef<(HTMLSpanElement | null)[]>([]);

  useEffect(() => {
    bars.current.forEach((bar) => bar?.style.setProperty('--p', '0'));
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    let frame = 0;
    let last = performance.now();
    let elapsed = 0;
    let visible = true;
    const io = new IntersectionObserver(([entry]) => {
      visible = !!entry?.isIntersecting;
    });
    if (stage.current) io.observe(stage.current);
    const tick = (now: number) => {
      const dt = Math.min(0.25, (now - last) / 1000);
      last = now;
      if (visible && !document.hidden) elapsed += dt;
      if (elapsed >= SHOT_SECONDS) {
        setShot((s) => (s + 1) % text.shots.length);
        return;
      }
      bars.current[shot]?.style.setProperty('--p', String(elapsed / SHOT_SECONDS));
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      io.disconnect();
    };
  }, [shot, restart, text.shots.length]);

  const select = (i: number) => {
    setShot(i);
    setRestart((r) => r + 1);
  };

  return (
    <>
      <div className="sc-tabs" role="tablist" aria-label={text.libKicker}>
        {text.shots.map(([icon, label], i) => (
          <button
            key={label}
            type="button"
            role="tab"
            id={`shot-tab-${i}`}
            aria-selected={i === shot}
            aria-controls="shot-panel"
            className={i === 1 ? 'sc-tab is-play' : 'sc-tab'}
            onClick={() => select(i)}
          >
            <Icon name={icon} />
            {label}
            <span
              className="sc-progress"
              ref={(el) => {
                bars.current[i] = el;
              }}
            />
          </button>
        ))}
      </div>
      <div
        className="sc-stage"
        id="shot-panel"
        role="tabpanel"
        aria-labelledby={`shot-tab-${shot}`}
        data-shot={shot}
        ref={stage}
        data-reveal="0"
      >
        <div className="sc-screen">
          <img
            className="sc-img sc-img-library"
            src="/assets/img/windows-library.jpg?v=0111"
            width={1280}
            height={800}
            loading="lazy"
            alt={text.shotAlts[0]}
          />
          <img
            className="sc-img sc-img-player"
            src="/assets/img/windows-hero.jpg?v=0111"
            width={1280}
            height={800}
            loading="lazy"
            alt={text.shotAlts[1]}
          />
        </div>
        <div className="sc-phone">
          <img
            src="/assets/img/android-player.jpg?v=0111"
            width={540}
            height={1104}
            loading="lazy"
            alt={text.shotAlts[2]}
          />
        </div>
      </div>
      <p className="sc-caption">{text.shots[shot]![2]}</p>
    </>
  );
}

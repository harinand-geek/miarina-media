import { useEffect, useRef, useState } from 'react';
import type { LandingText } from '../pages/homeContent';
import { Icon, MotionLogo } from './Common';

const URL_TEXT = 'commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm';
/** Length of one loop of the demo (s). */
const LOOP = 14;
/** State shown without JavaScript and with reduced motion: the Listen view. */
const FINAL = 10;
/** 05:10 into a 10:35 track when the Listen view appears. */
const START_SEC = 310;
const TRACK_SEC = 635;

const clamp = (v: number) => Math.max(0, Math.min(1, v));
const clock = (s: number) =>
  `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

/**
 * Hero demo (landing v4): link → format → file → playback, in a 14 s loop.
 * Pre-rendered in its final state; animated only with JavaScript, paused
 * when hidden, frozen with reduced motion. Changing values are classes,
 * `data-*` attributes and CSS properties set from script (CSP: no inline
 * style attribute).
 */
export function HeroDemo({ text }: { text: LandingText['demo'] }) {
  const [t, setT] = useState(FINAL);
  const root = useRef<HTMLDivElement>(null);
  const dlBar = useRef<HTMLSpanElement>(null);
  const playBar = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    let frame = 0;
    let last = performance.now();
    let clockT = 0;
    let visible = true;
    let shown = 0;
    const tick = (now: number) => {
      frame = requestAnimationFrame(tick);
      const dt = Math.min(0.25, (now - last) / 1000);
      last = now;
      if (!visible || document.hidden) return;
      clockT = (clockT + dt) % LOOP;
      // About 16 updates per second are enough for this demo.
      if (now - shown >= 60) {
        shown = now;
        setT(clockT);
      }
    };
    const io = new IntersectionObserver(([entry]) => {
      visible = !!entry?.isIntersecting;
    });
    if (root.current) io.observe(root.current);
    setT(0);
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      io.disconnect();
    };
  }, []);

  const typing = t < 2.6;
  const analyzing = t >= 2.6 && t < 3.3;
  const formatsShown = t >= 3.3 && t < 8;
  const selected = t >= 4.5 ? 1 : 0;
  const dl = clamp((t - 5.4) / 2.4);
  const listen = t >= 8.2;
  const sec = START_SEC + Math.floor(Math.max(0, t - 8.2));
  const step = listen ? 3 : t >= 5.4 ? 2 : t >= 3.3 ? 1 : 0;
  const typed = URL_TEXT.slice(0, Math.round(clamp(t / 2.6) * URL_TEXT.length));

  useEffect(() => {
    dlBar.current?.style.setProperty('--p', String(dl));
    playBar.current?.style.setProperty('--p', String(sec / TRACK_SEC));
  }, [dl, sec]);

  return (
    <div className="hd" ref={root}>
      <div className="hd-halo" />
      <div className="hd-window" aria-hidden="true" data-view={listen ? 'listen' : 'get'}>
        <div className="hd-titlebar">
          <MotionLogo size={18} />
          <span className="hd-brand">Miarina Media</span>
          <span className="hd-tabs">
            <span className="hd-tab hd-tab-get">
              <Icon name="download" />
              {text.get}
            </span>
            <span className="hd-tab hd-tab-listen">
              <Icon name="library_music" />
              {text.listen}
            </span>
          </span>
        </div>
        <div className="hd-body">
          <div className="hd-get">
            <div className="hd-row">
              <span className={typing ? 'hd-field is-typing' : 'hd-field'}>
                <Icon name="link" />
                <span className="hd-url">{typed || '​'}</span>
                <span className="hd-caret" />
              </span>
              <span className={analyzing ? 'hd-analyze is-busy' : 'hd-analyze'}>
                {analyzing ? text.analyzing : text.analyze}
              </span>
            </div>
            <div className={formatsShown ? 'hd-formats is-shown' : 'hd-formats'}>
              <span className="hd-label">Big Buck Bunny · 10:35</span>
              {text.formats.map(([icon, label, meta], i) => (
                <span
                  key={label}
                  className={i === selected && formatsShown ? 'hd-format is-selected' : 'hd-format'}
                >
                  <Icon name={icon} />
                  <span>{label}</span>
                  <span className="hd-meta">{meta}</span>
                </span>
              ))}
            </div>
            <div className={t >= 5.4 ? 'hd-dl is-shown' : 'hd-dl'}>
              <span className="hd-dl-line">
                <span>{text.file}</span>
                <span className="hd-pct">{dl >= 1 ? text.size : `${Math.round(dl * 100)} %`}</span>
              </span>
              <span className="hd-track">
                <span className="hd-fill hd-fill-dl" ref={dlBar} />
              </span>
            </div>
          </div>
          <div className="hd-listen">
            <div className="hd-recent">
              <span className="hd-label">{text.recent}</span>
              <div className="hd-covers">
                <span className="hd-album is-new">
                  <span className="hd-cover hd-cover-bbb" />
                  <span>Big Buck Bunny</span>
                </span>
                {['albinoni', 'mendelssohn', 'bach'].map((id) => (
                  <span className="hd-album" key={id}>
                    <span className={`hd-cover hd-cover-${id}`} />
                    <span>{id[0]!.toUpperCase() + id.slice(1)}</span>
                  </span>
                ))}
              </div>
              <span className="hd-saved">
                <Icon name="check" />
                {text.saved}
              </span>
            </div>
            <span className="hd-track hd-track-play">
              <span className="hd-fill hd-fill-play" ref={playBar} />
            </span>
            <div className="hd-player">
              <span className="hd-cover hd-cover-bbb hd-thumb" />
              <span className="hd-now">
                <span className="hd-now-title">Big Buck Bunny</span>
                <span className="hd-now-src">upload.wikimedia.org</span>
              </span>
              <span className="hd-controls">
                <span className="hd-eq" data-playing={listen ? 'true' : 'false'}>
                  <i />
                  <i />
                  <i />
                  <i />
                </span>
                <span className="hd-time">{`${clock(sec)} / 10:35`}</span>
                <Icon name="skip_previous" className="hd-skip-back" />
                <span className="hd-pause">
                  <Icon name="pause" />
                </span>
                <Icon name="skip_next" />
              </span>
            </div>
          </div>
        </div>
      </div>
      <div className="hd-steps" aria-hidden="true">
        {text.steps.map((label, i) => (
          <span
            key={label}
            className="hd-step"
            data-state={i === step ? 'active' : i < step ? 'done' : 'todo'}
            data-play={i === 3 ? 'true' : undefined}
          >
            {label}
          </span>
        ))}
      </div>
    </div>
  );
}

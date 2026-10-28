import { useEffect, useRef, useState } from 'react';
import { CHANGELOG } from '../release';
export function ReleaseLog() {
  const box = useRef<HTMLDivElement>(null);
  const [metrics, setMetrics] = useState({ ready: false, more: 0, height: 100, y: 0 });
  useEffect(() => {
    const el = box.current!;
    const measure = () => {
      const max = el.scrollHeight - el.clientHeight;
      const height = Math.max(12, (100 * el.clientHeight) / el.scrollHeight);
      const more =
        max - el.scrollTop > 8
          ? Array.from(el.querySelectorAll('article')).filter(
              (a) => a.offsetTop + a.offsetHeight > el.scrollTop + el.clientHeight,
            ).length
          : 0;
      setMetrics({
        ready: true,
        more,
        height,
        y: max > 0 ? ((100 - height) * el.scrollTop) / max : 0,
      });
    };
    measure();
    el.addEventListener('scroll', measure, { passive: true });
    const observer = new ResizeObserver(measure);
    observer.observe(el);
    observer.observe(el.firstElementChild!);
    return () => {
      el.removeEventListener('scroll', measure);
      observer.disconnect();
    };
  }, []);
  return (
    <div className="v-log">
      <div
        ref={box}
        className="v-log-scroll"
        tabIndex={0}
        role="region"
        aria-label="Journal des versions"
      >
        <div className="v-timeline">
          {CHANGELOG.map((r) => (
            <article key={r.name} className={r.planned ? 'planned' : r.current ? 'current' : ''}>
              <h3>{r.name}</h3>
              <p>{r.date}</p>
              <ul>
                {r.items.map((i) => (
                  <li key={i}>{i}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </div>
      {metrics.ready && (
        <svg
          className="v-log-track"
          viewBox="0 0 4 100"
          preserveAspectRatio="none"
          aria-hidden="true"
        >
          <rect width="4" height="100" rx="2" />
          <rect className="thumb" width="4" height={metrics.height} y={metrics.y} rx="2" />
        </svg>
      )}
      {metrics.more > 0 && (
        <div className="v-log-more">
          <button
            onClick={() =>
              box.current?.scrollBy({
                top: 320,
                behavior: matchMedia('(prefers-reduced-motion: reduce)').matches
                  ? 'instant'
                  : 'smooth',
              })
            }
          >
            <b>+{metrics.more}</b> Faites défiler pour les versions précédentes
          </button>
        </div>
      )}
    </div>
  );
}

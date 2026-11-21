import { useRef, useState, type KeyboardEvent } from 'react';
import { englishDate, englishName, type Lang, type LandingText } from '../pages/homeContent';
import { CHANGELOG } from '../release';

const CURRENT = Math.max(
  0,
  CHANGELOG.findIndex((r) => r.current),
);

/**
 * Release notes (landing v4): one box, the list of releases as tabs and the
 * selected one's changes. The current release is selected by default (and
 * in the pre-rendered page). Arrow keys move between releases.
 */
export function VersionLog({ lang, text }: { lang: Lang; text: LandingText }) {
  const [selected, setSelected] = useState(CURRENT);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const en = lang === 'en';
  const release = CHANGELOG[selected]!;

  const onKey = (e: KeyboardEvent) => {
    const step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[e.key];
    let next = step === undefined ? -1 : (selected + step + CHANGELOG.length) % CHANGELOG.length;
    if (e.key === 'Home') next = 0;
    if (e.key === 'End') next = CHANGELOG.length - 1;
    if (next < 0) return;
    e.preventDefault();
    setSelected(next);
    tabs.current[next]?.focus();
  };

  const title = (name: string, planned?: boolean) =>
    planned ? text.verNext : en ? englishName(name) : name;

  return (
    <div className="vl" data-reveal="0">
      <div className="vl-list" role="tablist" aria-label={text.verKicker} onKeyDown={onKey}>
        {CHANGELOG.map((r, i) => {
          const [version, platform] = r.name.split(' · ');
          const date = r.date.split(' · ').pop() ?? r.date;
          const short = platform
            ? en
              ? englishName(platform)
              : platform
            : en
              ? englishDate(date)
              : date;
          return (
            <button
              key={r.name}
              ref={(el) => {
                tabs.current[i] = el;
              }}
              type="button"
              role="tab"
              id={`ver-tab-${i}`}
              aria-selected={i === selected}
              aria-controls="ver-panel"
              tabIndex={i === selected ? 0 : -1}
              className="vl-tab"
              data-kind={r.current ? 'current' : r.beta ? 'beta' : r.planned ? 'planned' : 'past'}
              onClick={() => setSelected(i)}
            >
              <span className="vl-dot" />
              <span className="vl-version">{r.planned ? text.verNext : version}</span>
              <span className="vl-short">{r.planned ? (en ? 'In progress' : r.date) : short}</span>
            </button>
          );
        })}
      </div>
      <div
        className="vl-panel"
        role="tabpanel"
        id="ver-panel"
        aria-labelledby={`ver-tab-${selected}`}
      >
        <div className="vl-head">
          <h3>{title(release.name, release.planned)}</h3>
          {release.current && <span className="tag tag-accent">{text.verCurrent}</span>}
          {release.beta && <span className="tag tag-beta">{text.verBeta}</span>}
          {release.planned && <span className="tag tag-neutral">{text.verPlanned}</span>}
        </div>
        <p className="vl-date">{en ? englishDate(release.date) : release.date}</p>
        <ul>
          {release.items.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}

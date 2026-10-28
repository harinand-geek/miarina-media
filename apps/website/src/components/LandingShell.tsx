import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Icon, Logo } from './Common';
import { RELEASE } from '../release';
const NAV = [
  ['top', 'download', 'Télécharger'],
  ['fonctions', 'tune', 'Fonctionnalités'],
  ['navigateur', 'link', 'Navigateur'],
  ['formats', 'movie', 'Formats'],
  ['bibliotheque', 'video_library', 'Bibliothèque'],
  ['confidentialite', 'visibility_off', 'Confidentialité'],
  ['plateformes', 'desktop_windows', 'Plateformes'],
  ['faq', 'add', 'FAQ'],
  ['versions', 'schedule', 'Versions'],
] as const;
export function LandingShell({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState('light');
  const [ready, setReady] = useState(false);
  const [active, setActive] = useState('top');
  const menu = useRef<HTMLDetailsElement>(null);
  useEffect(() => {
    setReady(true);
    const media = matchMedia('(prefers-color-scheme: dark)');
    const sync = () => {
      let saved: string | null = null;
      try {
        saved = localStorage.getItem('miarina-site-theme');
      } catch {}
      const next = saved === 'light' || saved === 'dark' ? saved : media.matches ? 'dark' : 'light';
      setTheme(next);
      document.documentElement.dataset.theme = next;
    };
    sync();
    media.addEventListener('change', sync);
    return () => media.removeEventListener('change', sync);
  }, []);
  useEffect(() => {
    let frame = 0;
    const update = () => {
      frame = 0;
      let current = 'top';
      for (const [id] of NAV)
        if ((document.getElementById(id)?.getBoundingClientRect().top ?? Infinity) < 160)
          current = id;
      if (innerHeight + scrollY >= document.documentElement.scrollHeight - 8) current = 'versions';
      setActive(current);
    };
    const scroll = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    const resize = () => {
      if (innerWidth >= 900 && menu.current) menu.current.open = false;
      scroll();
    };
    update();
    addEventListener('scroll', scroll, { passive: true });
    addEventListener('resize', resize);
    return () => {
      removeEventListener('scroll', scroll);
      removeEventListener('resize', resize);
      cancelAnimationFrame(frame);
    };
  }, []);
  const toggle = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem('miarina-site-theme', next);
    } catch {}
  };
  const themeButton = (
    <button className="v-theme" onClick={toggle} hidden={!ready}>
      <Icon name="contrast" />
      Thème {theme === 'dark' ? 'sombre' : 'clair'}
    </button>
  );
  const nav = (
    <nav aria-label="Sections">
      {NAV.map(([id, icon, label]) => (
        <a
          key={id}
          href={`#${id === 'top' ? 'telecharger' : id}`}
          aria-current={active === id ? 'location' : undefined}
          onClick={() => {
            if (menu.current) menu.current.open = false;
          }}
        >
          <Icon name={icon} />
          {label}
        </a>
      ))}
    </nav>
  );
  return (
    <div className={`landing-v3${ready ? ' is-ready' : ''}`}>
      <a className="v-skip" href="#top">
        Aller au contenu
      </a>
      <aside className="v-sidebar">
        <a className="v-brand" href="#top">
          <Logo size={28} />
          Miarina Media
        </a>
        {nav}
        <div className="v-sidebar-foot">
          {themeButton}
          <span>
            Windows {RELEASE.windows.version}
            <br />
            Android {RELEASE.android.version} · préversions
          </span>
        </div>
      </aside>
      <main className="v-main">
        <div className="v-mobile">
          <a className="v-brand" href="#top">
            <Logo size={26} />
            <span>Miarina Media</span>
          </a>
          <a className="v-mobile-download" href="#telecharger">
            <Icon name="download" />
            <span>Télécharger</span>
          </a>
          <details
            ref={menu}
            onKeyDown={(e) => {
              if (e.key === 'Escape' && menu.current) menu.current.open = false;
            }}
          >
            <summary aria-label="Menu de navigation">
              <span className="v-hamburger">
                <i />
                <i />
                <i />
              </span>
              <Icon name="add" />
            </summary>
            <div className="v-mobile-menu">
              {nav}
              {themeButton}
            </div>
          </details>
        </div>
        {children}
      </main>
    </div>
  );
}

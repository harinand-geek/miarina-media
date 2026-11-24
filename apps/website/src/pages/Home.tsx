import { useEffect, useState } from 'react';
import { Icon, MotionLogo } from '../components/Common';
import { HeroDemo } from '../components/HeroDemo';
import { Showcase } from '../components/Showcase';
import { VersionLog } from '../components/VersionLog';
import { RELEASE, downloadUrl } from '../release';
import { LANDING, type Lang } from './homeContent';

/**
 * Scroll reveal (landing v4): elements with `data-reveal="delay ms"` fade
 * up once when they enter the viewport. Hidden only from script, so the
 * pre-rendered page stays readable; off with reduced motion.
 */
function useReveal() {
  useEffect(() => {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    if (!('IntersectionObserver' in window)) return;
    const els = [...document.querySelectorAll<HTMLElement>('[data-reveal]')];
    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (!e.isIntersecting) return;
          e.target.classList.add('is-in');
          io.unobserve(e.target);
        }),
      { rootMargin: '0px 0px -8% 0px' },
    );
    els.forEach((el) => {
      el.style.setProperty('--reveal-delay', `${Number(el.dataset.reveal) || 0}ms`);
      el.classList.add('reveal');
      io.observe(el);
    });
    return () => io.disconnect();
  }, []);
}

type Platform = 'windows' | 'android';

/**
 * The visitor's platform: Android on an Android phone or tablet, Windows
 * otherwise. The pre-rendered page says Windows; a phone switches once the
 * script runs (nothing is sent anywhere, the user agent is read locally).
 */
function useSuggestedPlatform(): Platform {
  const [platform, setPlatform] = useState<Platform>('windows');
  useEffect(() => {
    if (/android/i.test(navigator.userAgent)) setPlatform('android');
  }, []);
  return platform;
}

/** Landing page (design_handoff_landing_v4), French at `/`, English at `/en/`. */
export function Home({ lang = 'fr' }: { lang?: Lang }) {
  const t = LANDING[lang];
  useReveal();
  const suggested = useSuggestedPlatform();
  const all = [
    {
      id: 'windows' as const,
      icon: 'desktop_windows',
      platform: 'Windows',
      file: RELEASE.windows,
      req: t.dlWindowsReq,
      cta: t.dlWindowsCta,
      hero: t.ctaWindows,
    },
    {
      id: 'android' as const,
      icon: 'android',
      platform: 'Android',
      file: RELEASE.android,
      req: t.dlAndroidReq,
      cta: t.dlAndroidCta,
      hero: t.ctaAndroid,
    },
  ];
  // The visitor's platform first, and highlighted.
  const downloads = [...all].sort(
    (a, b) => Number(b.id === suggested) - Number(a.id === suggested),
  );

  return (
    <div className="lp" lang={lang}>
      <nav className="lp-top" aria-label={lang === 'fr' ? 'Principale' : 'Main'}>
        <a href="#top" className="lp-brand">
          <MotionLogo size={26} mode="intro" />
          <span>Miarina Media</span>
        </a>
        <div className="lp-links">
          <a href="#obtenir">{t.nav.get}</a>
          <a href="#ecouter">{t.nav.listen}</a>
          <a href="#bibliotheque">{t.nav.library}</a>
          <a href="#versions">{t.nav.versions}</a>
        </div>
        <div className="lp-lang" role="group" aria-label={t.nav.lang}>
          <a href="/" hrefLang="fr" lang="fr" aria-current={lang === 'fr' ? 'true' : undefined}>
            FR
          </a>
          <a href="/en/" hrefLang="en" lang="en" aria-current={lang === 'en' ? 'true' : undefined}>
            EN
          </a>
        </div>
        <a href="#telecharger" className="btn btn-primary lp-cta" aria-label={t.nav.cta}>
          <Icon name="download" />
          <span className="lp-cta-label">{t.nav.cta}</span>
        </a>
      </nav>

      <header id="top" className="lp-hero">
        <div data-reveal="0">
          <h1>
            <span>{t.h1[0]}</span>
            <span className="lp-h1-second">{t.h1[1]}</span>
          </h1>
          <p className="lp-sub">{t.sub}</p>
          <div className="lp-hero-cta">
            {downloads.map((d) => (
              <a
                key={d.id}
                href={downloadUrl(d.file)}
                className={d.id === suggested ? 'btn btn-primary' : 'btn btn-secondary'}
                download
              >
                <Icon name={d.icon} />
                {d.hero}
              </a>
            ))}
          </div>
          <p className="lp-meta">
            {t.heroMeta(RELEASE.windows.version, RELEASE.android.version, RELEASE.beta.version)}
          </p>
        </div>
        <div className="lp-demo" data-reveal="120">
          <HeroDemo text={t.demo} />
        </div>
      </header>

      <div className="lp-rule" />

      <section id="fonctions" className="lp-section lp-features">
        <div className="lp-kicker" data-reveal="0">
          {t.featKicker}
        </div>
        <h2 className="lp-h2 lp-feat-title" data-reveal="60">
          {t.featTitle}
        </h2>
        <div className="lp-groups">
          {t.groups.map((g) => (
            <div
              key={g.id}
              id={g.id}
              className="lp-group"
              data-tone={g.id === 'ecouter' ? 'play' : 'get'}
              data-reveal="0"
            >
              <div className="lp-group-head">
                <span className="lp-num">{g.num}</span>
                <h3>
                  <Icon name={g.icon} />
                  {g.title}
                </h3>
              </div>
              <p className="lp-group-lead">{g.lead}</p>
              {g.items.map(([title, text]) => (
                <div key={title} className="lp-item">
                  <h4>{title}</h4>
                  <p>{text}</p>
                </div>
              ))}
            </div>
          ))}
        </div>
      </section>

      <section id="bibliotheque" className="lp-section lp-library">
        <div className="lp-lib-head">
          <div>
            <div className="lp-kicker" data-reveal="0">
              {t.libKicker}
            </div>
            <h2 className="lp-h2 lp-lib-title" data-reveal="60">
              {t.libTitle}
            </h2>
          </div>
          <p className="lp-lib-body" data-reveal="120">
            {t.libBody}
          </p>
        </div>
        <Showcase text={t} />
      </section>

      <section id="beta" className="lp-section lp-beta">
        <div className="lp-beta-head">
          <div>
            <div className="lp-kicker" data-reveal="0">
              {t.beta.kicker}
            </div>
            <h2 className="lp-h2" data-reveal="60">
              {t.beta.title}
            </h2>
          </div>
          <p className="lp-beta-lead" data-reveal="120">
            {t.beta.lead}
          </p>
        </div>
        <div className="lp-beta-points">
          {t.beta.points.map(([title, text]) => (
            <div key={title} className="lp-beta-point" data-reveal="0">
              <h3>{title}</h3>
              <p>{text}</p>
            </div>
          ))}
        </div>
        <div className="lp-beta-foot" data-reveal="0">
          <a href="#telecharger" className="btn btn-secondary">
            <Icon name="download" />
            {t.beta.cta}
          </a>
          <p>{t.beta.how}</p>
        </div>
      </section>

      <div className="lp-rule" />

      <section id="telecharger" className="lp-section lp-download">
        <div className="lp-dl-intro" data-reveal="0">
          <MotionLogo size={56} mode="loop" />
          <h2 className="lp-h2">{t.dlTitle}</h2>
          <p>{t.dlLead}</p>
        </div>
        <div className="lp-dl-list">
          {downloads.map((d) => (
            <div
              key={d.platform}
              className={d.id === suggested ? 'lp-dl-row is-suggested' : 'lp-dl-row'}
              data-reveal="60"
            >
              <Icon name={d.icon} className="lp-dl-icon" />
              <div className="lp-dl-info">
                <span className="lp-dl-title">
                  {d.platform} {d.file.version}{' '}
                  {d.id === suggested && <span className="lp-dl-badge">{t.dlSuggested}</span>}
                </span>
                <span className="lp-dl-req">
                  {d.req} · {d.file.size}
                </span>
                <span className="lp-dl-hash">
                  {d.file.name} · SHA-256 {d.file.sha256}
                </span>
              </div>
              <a href={downloadUrl(d.file)} className="btn btn-primary" download>
                <Icon name="download" />
                {d.cta}
              </a>
            </div>
          ))}
          <p className="lp-dl-note">{t.dlNote}</p>
        </div>
      </section>

      <section id="versions" className="lp-section lp-versions">
        <div className="lp-ver-head">
          <div>
            <div className="lp-kicker" data-reveal="0">
              {t.verKicker}
            </div>
            <h2 className="lp-ver-title" data-reveal="60">
              {t.verTitle}
            </h2>
          </div>
          {t.verFrenchOnly && <span className="lp-ver-note">{t.verFrenchOnly}</span>}
        </div>
        <VersionLog lang={lang} text={t} />
      </section>

      <footer className="lp-footer">
        <span className="lp-legal">{t.legal}</span>
        <div className="lp-footer-links">
          <a href="/confidentialite.html">{t.privacy}</a>
          <a href="/licences.html">{t.licences}</a>
        </div>
        <span>© 2026 MIARINA</span>
      </footer>
    </div>
  );
}

export const HomeEn = () => <Home lang="en" />;

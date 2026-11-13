import type { ReactNode } from 'react';
import { RELEASE } from '../release';

/** Material Symbols Rounded glyph (self-hosted subset). */
export function Icon({
  name,
  label,
  className,
}: {
  name: string;
  label?: string;
  className?: string;
}) {
  return (
    <span
      className={className ? `icon ${className}` : 'icon'}
      aria-hidden={label ? undefined : 'true'}
      aria-label={label}
    >
      {name}
    </span>
  );
}

export function Logo({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true" className="logo">
      {/* Logo 4d (design/brand): night tile, coral play, teal bars. */}
      <rect x="0.5" y="0.5" width="31" height="31" rx="7.5" className="logo-tile" />
      <path d="M13 9.5v13l10-6.5z" fill="#FF7A45" />
      <rect x="6" y="10.5" width="4" height="2.5" rx="1.25" fill="#35C9BD" />
      <rect x="4" y="14.75" width="6" height="2.5" rx="1.25" fill="#35C9BD" />
      <rect x="6" y="19" width="4" height="2.5" rx="1.25" fill="#35C9BD" />
    </svg>
  );
}

/**
 * Logo v2.0 for the landing page (design_handoff_landing_v4): night tile,
 * teal bars, coral play. `intro` plays once (top bar), `loop` keeps the bars
 * flowing into the play (download section). Animations are CSS classes.
 */
export function MotionLogo({ size, mode }: { size: number; mode?: 'intro' | 'loop' }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      aria-hidden="true"
      className={mode ? `mlogo mlogo-${mode}` : 'mlogo'}
    >
      <rect width="32" height="32" rx="8" fill="#182530" />
      <rect className="mlogo-bar" x="6" y="10.5" width="4" height="2.5" rx="1.25" fill="#35C9BD" />
      <rect className="mlogo-bar" x="4" y="14.75" width="6" height="2.5" rx="1.25" fill="#35C9BD" />
      <rect className="mlogo-bar" x="6" y="19" width="4" height="2.5" rx="1.25" fill="#35C9BD" />
      <path className="mlogo-play" d="M13 9.5v13l10-6.5z" fill="#FF7A45" />
    </svg>
  );
}

/** `home`: in-page anchors; otherwise links back to the home page. */
export function TopBar({ home }: { home: boolean }) {
  const to = (anchor: string) => (home ? `#${anchor}` : `/#${anchor}`);
  return (
    <nav className="topbar" aria-label="Principale">
      <div className="topbar-inner">
        <a href={home ? '#top' : '/'} className="brand">
          <Logo size={28} />
          <span>Miarina Media</span>
        </a>
        <div className="topbar-links">
          <a href={to('obtenir')}>Obtenir</a>
          <a href={to('ecouter')}>Écouter</a>
          <a href={to('bibliotheque')}>Bibliothèque</a>
          <a href={to('versions')}>Versions</a>
        </div>
        <a href={to('telecharger')} className="btn-small">
          <Icon name="download" />
          Télécharger
        </a>
      </div>
    </nav>
  );
}

export function SectionHead({
  eyebrow,
  title,
  children,
  small,
}: {
  eyebrow: string;
  title: string;
  children?: ReactNode;
  small?: boolean;
}) {
  return (
    <div className="section-head">
      <span className="eyebrow">{eyebrow}</span>
      <h2 className={small ? 'h2-small' : undefined}>{title}</h2>
      {children}
    </div>
  );
}

/** Without `home`, the short footer of a document page, linking to the other one. */
export function Footer({
  home,
  other,
}: {
  home?: boolean;
  other?: { href: string; label: string };
}) {
  if (!home) {
    return (
      <footer className="footer">
        <div className="footer-inner">
          <div className="footer-bottom">
            <span>© 2026 MIARINA</span>
            {other && (
              <span>
                <a href={other.href}>{other.label}</a>
              </span>
            )}
          </div>
        </div>
      </footer>
    );
  }
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div className="footer-top">
          <div className="footer-about">
            <div className="brand">
              <Logo size={24} />
              <span>Miarina Media</span>
            </div>
            <p>
              Téléchargez uniquement les contenus dont vous détenez les droits ou dont la licence
              l’autorise. Vous êtes responsable de l’usage que vous faites des fichiers.
            </p>
          </div>
          <div className="footer-cols">
            <div>
              <span className="footer-head">Produit</span>
              <a href="#telecharger">Télécharger</a>
              <a href="#fonctions">Fonctionnalités</a>
              <a href="#plateformes">Plateformes</a>
            </div>
            <div>
              <span className="footer-head">Aide</span>
              <a href="#faq">FAQ</a>
            </div>
            <div>
              <span className="footer-head">Légal</span>
              <a href="/confidentialite.html">Confidentialité</a>
              <a href="/licences.html">Licences</a>
            </div>
          </div>
        </div>
        <div className="footer-bottom">
          <span>© 2026 MIARINA</span>
          <span className="mono">
            Windows {RELEASE.windows.version} · Android {RELEASE.android.version}
          </span>
        </div>
      </div>
    </footer>
  );
}

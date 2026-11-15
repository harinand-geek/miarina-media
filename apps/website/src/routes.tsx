import type { ComponentType } from 'react';
import { Confidentialite } from './pages/Confidentialite';
import { Home, HomeEn } from './pages/Home';
import { Licences } from './pages/Licences';

export const SITE = 'https://media.miarina.org';

export interface Route {
  /** Served path; also the file written by the prerender (`/` → index.html). */
  path: string;
  Page: ComponentType;
  /** Page language (`<html lang>`); French when absent. */
  lang?: 'fr' | 'en';
  /** Same page in the other language (hreflang). */
  alternates?: { fr: string; en: string };
  title: string;
  description: string;
  og?: { title: string; description: string; image: string };
}

export const ROUTES: Route[] = [
  {
    path: '/',
    Page: Home,
    lang: 'fr',
    alternates: { fr: '/', en: '/en/' },
    title: 'Miarina Media — téléchargez une fois, écoutez hors ligne',
    description:
      'Téléchargez vidéos et musique, puis écoutez-les dans le lecteur de Miarina Media : albums, playlists, égaliseur. Windows et Android, sans compte ni publicité.',
    og: {
      title: 'Miarina Media',
      description:
        'Téléchargez une fois, écoutez hors ligne. Bibliothèque et lecteur sur Windows et Android.',
      image: '/assets/img/windows-hero.jpg?v=0111',
    },
  },
  {
    path: '/en/',
    Page: HomeEn,
    lang: 'en',
    alternates: { fr: '/', en: '/en/' },
    title: 'Miarina Media — download once, listen offline',
    description:
      'Download videos and music, then play them in Miarina Media’s own player: albums, playlists, equalizer. Windows and Android, no account, no ads.',
    og: {
      title: 'Miarina Media',
      description: 'Download once, listen offline. Library and player on Windows and Android.',
      image: '/assets/img/windows-hero.jpg?v=0111',
    },
  },
  {
    path: '/licences.html',
    Page: Licences,
    title: 'Licences — Miarina Media',
    description: 'Composants tiers utilisés par Miarina Media et leurs licences.',
  },
  {
    path: '/confidentialite.html',
    Page: Confidentialite,
    title: 'Confidentialité — Miarina Media',
    description:
      'Le fonctionnement local de Miarina Media, les connexions réseau et le traitement des données sur ce site.',
  },
];

export function findRoute(pathname: string): Route {
  const path = pathname === '/en' || pathname === '/en/index.html' ? '/en/' : pathname;
  return ROUTES.find((route) => route.path === path) ?? ROUTES[0]!;
}

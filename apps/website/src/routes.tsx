import type { ComponentType } from 'react';
import { Confidentialite } from './pages/Confidentialite';
import { Home } from './pages/Home';
import { Licences } from './pages/Licences';

export const SITE = 'https://media.miarina.org';

export interface Route {
  /** Served path; also the file written by the prerender (`/` → index.html). */
  path: string;
  Page: ComponentType;
  title: string;
  description: string;
  og?: { title: string; description: string; image: string };
}

export const ROUTES: Route[] = [
  {
    path: '/',
    Page: Home,
    title: 'Miarina Media — téléchargez et gardez vos médias',
    description:
      'Téléchargez vidéos et audio sur Windows et Android. Torrents et extension Chrome/Edge sur Windows. Bibliothèque locale, sans compte ni publicité.',
    og: {
      title: 'Miarina Media',
      description: 'Vidéos et audio sur Windows et Android. Torrents et extension Chrome/Edge sur Windows.',
      image: '/assets/img/windows-hero.jpg?v=018',
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
  return ROUTES.find((route) => route.path === pathname) ?? ROUTES[0]!;
}

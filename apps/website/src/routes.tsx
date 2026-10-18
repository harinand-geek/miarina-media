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
      'Collez un lien, choisissez le format, gardez le fichier. Miarina Media télécharge vidéos et audio sur Windows et Android, sans compte, sans publicité, sans pistage.',
    og: {
      title: 'Miarina Media',
      description: 'Collez un lien, choisissez le format, gardez le fichier. Windows et Android.',
      image: '/assets/img/windows-hero.jpg',
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
      'Ce que Miarina Media et ce site traitent réellement : pas de compte, pas de publicité, pas de mesure d’audience.',
  },
];

export function findRoute(pathname: string): Route {
  return ROUTES.find((route) => route.path === pathname) ?? ROUTES[0]!;
}

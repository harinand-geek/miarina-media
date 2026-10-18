// Everything that changes with a release lives here (docs/test-builds.md).
// Files are served from /downloads/; `?v=` is the digest prefix because
// Cloudflare caches by URL.

export interface ReleaseFile {
  name: string;
  /** Shown on the button, e.g. "69,1 Mo". */
  size: string;
  sha256: string;
}

export const RELEASE = {
  version: '0.1.2',
  windows: {
    name: 'MiarinaMedia-0.1.2-x64-setup.exe',
    size: '69,1 Mo',
    sha256: '2ae0daae2bf5433fe8108956f5bd695c19c0809e2736dff6b4ada33459d26098',
  } satisfies ReleaseFile,
  android: {
    name: 'MiarinaMedia-0.1.2.apk',
    size: '35 Mo',
    sha256: '2480eb7f8057bfcfc393ae78eb7dae4b6b27c55fed5e9e36c2c125278ae11dd1',
  } satisfies ReleaseFile,
};

export const downloadUrl = (file: ReleaseFile) =>
  `/downloads/${file.name}?v=${file.sha256.slice(0, 8)}`;

export interface Release {
  /** Version, or "Prochaines" for planned work. */
  name: string;
  date: string;
  current?: boolean;
  planned?: boolean;
  items: string[];
}

export const CHANGELOG: Release[] = [
  {
    name: 'Prochaines',
    date: 'En préparation',
    planned: true,
    items: [
      'Android : navigateur intégré, avec recherche et raccourcis',
      'Android : pages de sites vidéo (YouTube…)',
      'Android : lecture audio en arrière-plan, plein écran et image dans l’image',
      'Windows : navigateur dans la fenêtre principale, avec onglets',
    ],
  },
  {
    name: '0.1.2',
    date: 'Préversion de test · 18 octobre 2026',
    current: true,
    items: [
      'Windows : correction des téléchargements dont le titre contient des accents',
      'Windows : yt-dlp se met à jour tout seul (une fois par jour au plus, signature vérifiée)',
      'Android : lecteur intégré, miniatures et durées',
      'Android : fichiers dans Films et Musique, visibles dans la galerie (Android 11+)',
      'Android : téléchargements en arrière-plan avec notification (Pause, Annuler) et « Téléchargement terminé »',
      'Android : partager un lien vers l’app, partager ou ouvrir un fichier avec une autre app',
      'Android : nouvelle icône et écran de démarrage',
    ],
  },
  {
    name: '0.1.1',
    date: 'Préversion de test · 17 octobre 2026',
    items: [
      'Windows : yt-dlp, FFmpeg et QuickJS-NG inclus dans l’installateur, plus rien à télécharger au premier usage',
      'Windows : téléchargements YouTube plus rapides',
      'Windows : MP3 en 320, 256, 192 ou 128 kbps, et FLAC',
      'Windows : miniature affichée dès l’analyse et pendant le téléchargement',
      'Windows et Android : message plus clair quand un lien est incomplet, avec ajout de « https:// » en un geste',
    ],
  },
  {
    name: '0.1.0',
    date: 'Préversion de test · 14 octobre 2026',
    items: [
      'Première préversion Windows et Android',
      'Analyse de lien, choix du format, file de téléchargements avec reprise',
      'Windows : pages de sites vidéo (yt-dlp), conversion MP3, bibliothèque avec miniatures, lecteur, navigateur intégré',
    ],
  },
];

/** `true` = available, `false` = not on this platform, string = shown as is. */
type Cell = boolean | 'soon' | string;

export const PLATFORMS: { feature: string; windows: Cell; android: Cell }[] = [
  { feature: 'Téléchargement par lien direct', windows: true, android: true },
  { feature: 'Pages de sites vidéo (via yt-dlp)', windows: true, android: 'soon' },
  { feature: 'Conversion en MP3', windows: true, android: 'soon' },
  { feature: 'File, pause et reprise', windows: true, android: true },
  { feature: 'Bibliothèque', windows: true, android: true },
  { feature: 'Lecteur intégré', windows: true, android: true },
  { feature: 'Image dans l’image', windows: true, android: 'soon' },
  { feature: 'Téléchargement en arrière-plan, notifications', windows: true, android: true },
  { feature: 'Navigateur intégré', windows: true, android: 'soon' },
  { feature: 'Partager un lien vers l’app', windows: false, android: true },
  { feature: 'Partager ou ouvrir un fichier avec une autre app', windows: false, android: true },
  { feature: 'Fichiers visibles dans la galerie (Android 11+)', windows: false, android: true },
  { feature: 'Raccourcis clavier', windows: true, android: false },
  { feature: 'Configuration minimale', windows: 'Windows 10 · 64 bits', android: 'Android 7.0' },
];

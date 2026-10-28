// Everything that changes with a release lives here (docs/test-builds.md).
// Files are served from /downloads/; `?v=` is the digest prefix because
// Cloudflare caches by URL.

export interface ReleaseFile {
  version: string;
  name: string;
  /** Shown on the button, e.g. "69,1 Mo". */
  size: string;
  sha256: string;
}

export const RELEASE = {
  version: '0.1.4',
  windows: {
    version: '0.1.4',
    name: 'MiarinaMedia-0.1.4-x64-setup.exe',
    size: '69,1 Mo',
    sha256: 'a86968b36c9ce9cf272a563bdc8a11c4df0340aca343847f385cb4ab7aed75d9',
  } satisfies ReleaseFile,
  android: {
    version: '0.1.3',
    name: 'MiarinaMedia-0.1.3.apk',
    size: '35 Mo',
    sha256: '1bcfd16e46c24a7c1b7aecb8be2c80d895d124d2b2d4e97f746a8326c2e21008',
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
      'Navigateur : plusieurs onglets et historique',
      'Android : pages de sites vidéo (YouTube…)',
      'Android : lecture audio en arrière-plan, plein écran et image dans l’image',
    ],
  },
  {
    name: '0.1.4 · Windows',
    date: 'Préversion de test · 28 octobre 2026',
    current: true,
    items: [
      'Installateur aux couleurs de Miarina Media, en français et en anglais',
      'Logo discret pour les médias sans miniature',
      'Lecteur : position sauvegardée en quittant une vidéo et fond animé suspendu lorsque la page est masquée',
      'Téléchargements : lecture mémoire bornée et exclusion des fragments intermédiaires lors de la finalisation',
    ],
  },
  {
    name: '0.1.3',
    date: 'Préversion de test · 18 octobre 2026',
    current: true,
    items: [
      'Android : navigateur intégré, avec recherche, raccourcis et bouton de téléchargement quand la page contient un fichier vidéo ou audio',
      'Windows : le navigateur s’ouvre dans la fenêtre principale, avec la même présentation que sur Android',
      'Windows et Android : favoris dans le navigateur (étoile dans la barre d’adresse)',
      'Windows et Android : des mots tapés dans le champ de l’accueil lancent une recherche dans le navigateur',
      'Windows et Android : la meilleure copie jusqu’à 1080p est proposée en premier quand une page en contient plusieurs',
      'Lecteur : fond flou tiré de la vidéo en cours, ou de la pochette pour l’audio',
    ],
  },
  {
    name: '0.1.2',
    date: 'Préversion de test · 18 octobre 2026',
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
  { feature: 'File, pause et reprise selon la source', windows: true, android: true },
  { feature: 'Bibliothèque', windows: true, android: true },
  { feature: 'Lecteur intégré', windows: true, android: true },
  { feature: 'Image dans l’image', windows: true, android: 'soon' },
  { feature: 'Téléchargement en arrière-plan, notifications', windows: true, android: true },
  { feature: 'Navigateur intégré, recherche et favoris', windows: true, android: true },
  {
    feature: 'Détection dans le navigateur',
    windows: 'Fichiers et pages',
    android: 'Fichiers vidéo et audio',
  },
  { feature: 'Partager un lien vers l’app', windows: false, android: true },
  { feature: 'Partager ou ouvrir un fichier avec une autre app', windows: false, android: true },
  { feature: 'Fichiers visibles dans la galerie (Android 11+)', windows: false, android: true },
  { feature: 'Raccourcis clavier', windows: true, android: false },
  { feature: 'Configuration minimale', windows: 'Windows 10 · 64 bits', android: 'Android 7.0' },
];

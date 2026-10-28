export const FEATURES = [
  [
    'link',
    'Collez un lien',
    'Miarina Media lit l’adresse et vous montre ce qui peut être téléchargé.',
  ],
  [
    'tune',
    'Choisissez le format',
    'Qualité vidéo ou audio seul, avec la taille affichée lorsqu’elle est fournie ou estimable.',
  ],
  [
    'download',
    'File de téléchargements',
    'Mettez en pause et reprenez lorsque la source le permet. Les erreurs réseau temporaires font l’objet de tentatives limitées.',
  ],
  [
    'speed',
    'Éco, Équilibré, Performance',
    'Réglez combien de téléchargements tournent en même temps, selon votre machine.',
  ],
  [
    'video_library',
    'Bibliothèque',
    'Vos fichiers rangés par vidéo et audio, avec une recherche, des miniatures et la durée.',
  ],
  ['contrast', 'Clair ou sombre', 'Thème sombre par défaut, thème clair et mode système.'],
] as const;

export const FORMATS: { icon: string; title: string; rows: [string, string, boolean?][] }[] = [
  {
    icon: 'movie',
    title: 'Vidéo',
    rows: [
      ['Jusqu’à 4K', 'si la source le propose'],
      ['MP4', 'H.264'],
      ['WebM', 'VP9'],
      ['Fichier original', 'lien direct'],
    ],
  },
  {
    icon: 'music_note',
    title: 'Audio',
    rows: [
      ['MP3 · 320, 256, 192 ou 128 kbps', 'conversion · Windows'],
      ['FLAC', 'conversion · Windows'],
      ['Piste audio d’origine', 'selon la source'],
      ['Fichier original', 'lien direct'],
    ],
  },
  { icon: 'closed_caption', title: 'Sous-titres', rows: [['SRT', 'Bientôt', true]] },
];

export const FAQ: [string, string][] = [
  [
    'Miarina Media est-il gratuit ?',
    'Oui. L’application est gratuite, sans publicité et sans compte.',
  ],
  [
    'Quels sites sont pris en charge ?',
    'Les liens directs vers un fichier vidéo ou audio fonctionnent sur Windows et Android. Sous Windows, les pages de nombreux sites vidéo sont analysées avec yt-dlp, inclus dans l’installateur avec FFmpeg et QuickJS-NG : rien à télécharger en plus. Les contenus privés, protégés par connexion ou par DRM, et les diffusions en direct ne sont pas pris en charge.',
  ],
  [
    'Ai-je le droit de télécharger ces contenus ?',
    'Cela dépend du contenu et de sa licence. Téléchargez uniquement ce que vous avez le droit de conserver, par exemple des œuvres sous licence libre, dans le domaine public, ou vos propres contenus.',
  ],
  [
    'Où sont enregistrés les fichiers ?',
    'Sous Windows, dans le dossier choisi dans les réglages (par défaut Vidéos\\Miarina). Sous Android 11 et plus, les vidéos vont dans Films/Miarina et l’audio dans Musique/Miarina : ils apparaissent dans la galerie et restent sur le téléphone si vous désinstallez l’application. Sous Android 7 à 10, ils restent pour l’instant dans l’espace de l’application.',
  ],
  [
    'Faut-il une connexion pour lire mes fichiers ?',
    'Non. La bibliothèque et le lecteur fonctionnent hors ligne, sous Windows comme sous Android.',
  ],
  [
    'Pourquoi Windows affiche-t-il un avertissement ?',
    'Cette préversion n’est pas encore signée numériquement, donc Windows SmartScreen peut afficher « Windows a protégé votre ordinateur ». Comparez l’empreinte SHA-256 du fichier avec celle indiquée sur cette page, puis choisissez « Informations complémentaires » et « Exécuter quand même ».',
  ],
  [
    'Comment installer l’APK sur Android ?',
    'Ouvrez le fichier téléchargé : Android vous demandera d’autoriser l’installation depuis votre navigateur la première fois. Les versions publiées ici sont toutes signées avec la même clé : les mises à jour s’installent par-dessus la version précédente. Si vous aviez installé l’APK du tout premier test (avant le 15 octobre 2026), désinstallez-le une fois avant d’installer celui-ci.',
  ],
];

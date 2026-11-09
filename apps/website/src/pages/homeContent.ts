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
  ['download', 'Torrents sur Windows', 'Ajoutez un torrent ou un lien magnet, choisissez les fichiers, réglez les débits et arrêtez le partage quand vous le souhaitez.'],
  ['link', 'Depuis Chrome ou Edge', 'L’extension Windows envoie les liens que vous choisissez vers Miarina, même lorsque l’application est fermée. Installation en mode développeur.'],
  ['music_note', 'Audio sur Android', 'L’extracteur et les outils de conversion sont inclus dans l’APK. Le MP3 à 320 kbps a été vérifié sur émulateur.'],
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
      ['MP3 · 320 kbps', 'Android · testé sur émulateur'],
      ['FLAC', 'conversion · Windows'],
      ['Piste audio d’origine', 'selon la source'],
      ['Fichier original', 'lien direct'],
    ],
  },
  { icon: 'closed_caption', title: 'Sous-titres', rows: [['SRT', 'Bientôt', true]] },
];

export const FAQ: [string, string][] = [
  [
    'Qu’apporte la version 0.1.6 ?',
    'Sous Windows : torrents, liens magnet, sélection des fichiers et limites de débit, ainsi qu’une extension Chrome/Edge pour envoyer des liens. Windows et Android reçoivent aussi des corrections du nettoyage des fichiers temporaires et de la vérification du dossier de téléchargement. Les torrents et l’extension ne sont pas disponibles sur Android.',
  ],
  [
    'Comment connecter l’extension Chrome ou Edge ?',
    'Dans la page des extensions du navigateur, activez le mode développeur et chargez le dossier browser-extension fourni avec l’application Windows. Copiez l’identifiant de l’extension dans Réglages → Extension navigateur de Miarina, puis connectez-la. Les liens envoyés apparaissent dans la boîte de réception des réglages : vous choisissez ensuite lesquels télécharger. L’extension n’intercepte pas automatiquement tous les téléchargements et n’est pas encore publiée dans les magasins Chrome/Edge.',
  ],
  [
    'Comment fonctionnent les torrents ?',
    'Sur Windows, ouvrez la rubrique Torrents et ajoutez un fichier torrent ou un lien magnet. Vous pouvez choisir les fichiers, mettre en pause, reprendre et régler les débits. Un torrent échange des données avec d’autres participants : votre adresse IP leur est visible et des morceaux peuvent être partagés pendant son activité. Vous pouvez arrêter le partage dans l’application.',
  ],
  [
    'Miarina Media est-il gratuit ?',
    'Oui. L’application est gratuite, sans publicité et sans compte.',
  ],
  [
    'Quels liens sont pris en charge ?',
    'Les liens directs vers un fichier vidéo ou audio fonctionnent sur Windows et Android. Sous Windows, les pages de nombreux sites vidéo sont analysées avec yt-dlp, inclus dans l’installateur avec FFmpeg et QuickJS-NG : rien à télécharger en plus. Depuis la version 0.1.5, Android intègre aussi un extracteur : le parcours YouTube a été testé sur émulateur. La conversion MP3 à 320 kbps a été vérifiée sur émulateur ; les essais sur téléphone réel restent à faire. Les contenus privés, protégés par connexion ou par DRM, et les diffusions en direct ne sont pas pris en charge.',
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

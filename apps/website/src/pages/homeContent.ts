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
    'Mettez en pause et reprenez lorsque la source le permet. Sous Windows, la reprise est vérifiée, Miarina attend le retour du réseau et signale un disque plein ou un dossier inaccessible.',
  ],
  [
    'library_music',
    'Bibliothèque musicale',
    'Sous Windows et Android : albums, artistes, dossiers et recherche, avec les pochettes des fichiers. Sous Windows, éditeur de tags et choix de pochette (image, miniature de la source ou image tirée de la vidéo).',
  ],
  [
    'queue_music',
    'Playlists et favoris',
    'Sous Windows et Android : playlists, favoris, file de lecture enregistrable en playlist. Sur Android, titres récents et plus écoutés ; sous Windows, import et export M3U. La file, les positions et l’historique d’écoute sont conservés.',
  ],
  [
    'graphic_eq',
    'Lecteur et égaliseur',
    'Sous Windows, le lecteur s’appuie sur libVLC, fourni avec l’installateur : pistes audio, sous-titres SRT et VTT, vitesse, égaliseur à 6 bandes. Aucun VLC à installer. Sous Android, la musique continue écran éteint, avec les commandes de l’écran verrouillé et du casque Bluetooth ; égaliseur du téléphone, vidéo en plein écran paysage et image dans l’image.',
  ],
  [
    'folder_open',
    'Vos fichiers aussi',
    'Sous Windows, ouvrez des fichiers, importez un dossier ou déposez-les sur la fenêtre. Sous Android, autorisez l’accès à la musique et aux vidéos du téléphone : elles rejoignent la bibliothèque, en lecture seule.',
  ],
  [
    'system_update_alt',
    'Mises à jour vérifiées',
    'Signature et empreinte vérifiées, téléchargement qui reprend après une coupure, copie de la bibliothèque avant la mise à jour. Installation toujours à votre demande.',
  ],
  [
    'speed',
    'Éco, Équilibré, Performance',
    'Réglez combien de téléchargements tournent en même temps, selon votre machine.',
  ],
  [
    'download',
    'Torrents sur Windows',
    'Ajoutez un torrent ou un lien magnet, choisissez les fichiers, réglez les débits et arrêtez le partage quand vous le souhaitez.',
  ],
  [
    'link',
    'Depuis Chrome ou Edge',
    'L’extension Windows envoie les liens que vous choisissez vers Miarina, même lorsque l’application est fermée. Installation en mode développeur.',
  ],
  [
    'music_note',
    'Audio sur Android',
    'L’extracteur et les outils de conversion sont inclus dans l’APK. Le MP3 à 320 kbps a été vérifié sur émulateur.',
  ],
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
  {
    icon: 'closed_caption',
    title: 'Sous-titres',
    rows: [
      ['SRT, VTT et pistes intégrées', 'lecture · Windows et Android'],
      ['Téléchargement des sous-titres', 'Bientôt', true],
    ],
  },
];

export const FAQ: [string, string][] = [
  [
    'Comment mettre à jour Miarina sans revenir sur le site ?',
    'Depuis la version 0.1.7, Miarina recherche les nouvelles versions au démarrage et toutes les six heures lorsque l’interface est visible. Dans Réglages → Mises à jour, téléchargez la version proposée puis choisissez Installer maintenant. Windows ouvre son installateur ; Android demande une autorisation puis votre confirmation. Vos fichiers, playlists et réglages sont conservés. À partir de la 0.1.8 sous Windows, le téléchargement peut être annulé et reprend où il s’était arrêté, même après une coupure ou un redémarrage ; l’installation attend la fin d’une conversion en cours, et la nouvelle version garde une copie de votre bibliothèque avant de la mettre à jour. Depuis la 0.1.6, une première installation manuelle de la 0.1.7 est nécessaire.',
  ],
  [
    'Qu’apporte la version 0.1.9 ?',
    'Surtout Android, qui passe de la 0.1.7 à la 0.1.9 : nouvelle interface, vrai lecteur de musique (bibliothèque par albums, artistes et dossiers, playlists, favoris, titres récents et plus écoutés, égaliseur), accès à la musique et aux vidéos déjà présentes sur le téléphone, lecture qui continue écran éteint, vidéo en plein écran paysage avec pistes, sous-titres et image dans l’image, thème clair et anglais. Ces fonctions ont été vérifiées sur émulateur ; les essais sur téléphone réel sont en cours. Sous Windows, peu de changements : le thème choisi est conservé entre deux lancements et un fichier que Windows refuse de supprimer est signalé clairement.',
  ],
  [
    'Faut-il installer VLC ?',
    'Non. Le lecteur Windows utilise libVLC 3.0.24, fourni avec l’installateur ; un VLC déjà installé n’est pas utilisé. C’est ce qui rend l’installateur plus gros qu’avant.',
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
    'Comment Android accède-t-il à ma musique ?',
    'Dans Musique, la carte « Musique du téléphone » demande l’autorisation d’Android (« Musique et audio », puis « Vidéos »). Miarina lit alors la liste des titres et vidéos du téléphone, mémoire interne et carte SD, sans les copier, déplacer ni modifier ; les sonneries et sons de notification sont ignorés. Vous pouvez refuser : l’application garde ses propres téléchargements. Android ne laisse pas Miarina supprimer un fichier d’une autre application : retirez-le de la bibliothèque ou supprimez-le avec l’app Fichiers.',
  ],
  [
    'Comment installer l’APK sur Android ?',
    'Ouvrez le fichier téléchargé : Android vous demandera d’autoriser l’installation depuis votre navigateur la première fois. Les versions publiées ici sont toutes signées avec la même clé : les mises à jour s’installent par-dessus la version précédente. Si vous aviez installé l’APK du tout premier test (avant le 15 octobre 2026), désinstallez-le une fois avant d’installer celui-ci.',
  ],
];

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
  version: '0.3.0',
  windows: {
    version: '0.3.0',
    name: 'MiarinaMedia-0.3.0-x64-setup.exe',
    size: '113,6 Mio',
    sha256: '82230c2cb5547aa35f5a8da0a139ff06f377a01ff4ffb741ee3f114df28dba84',
  } satisfies ReleaseFile,
  /** Windows on the Beta channel, offered next to the stable build. */
  beta: {
    version: '0.2.4',
    name: 'MiarinaMedia-0.2.4-x64-setup.exe',
    size: '113,1 Mio',
    sha256: 'afa0da67d0a14b0e13d19705464b3bf8315a35a04b20373d78c6cea5a6b28535',
  } satisfies ReleaseFile,
  /** Android beta, a separate app installed next to the stable one. */
  androidBeta: {
    version: '0.2.4',
    name: 'MiarinaMedia-Beta-0.2.4.apk',
    size: '64,5 Mio',
    sha256: 'c58a620258ddf02417759d1249187e2acd4d71a3463c8e73b56d82d36aeb73be',
  } satisfies ReleaseFile,
  android: {
    version: '0.3.0',
    name: 'MiarinaMedia-0.3.0.apk',
    size: '65,2 Mio',
    sha256: 'fc7e329635e410b459235ca20448016d9d59decd9f08f6f100070e3d29c19ff5',
  } satisfies ReleaseFile,
};

export const downloadUrl = (file: ReleaseFile) =>
  `/downloads/${file.name}?v=${file.sha256.slice(0, 8)}`;

export interface Release {
  /** Version, or "Prochaines" for planned work. */
  name: string;
  date: string;
  current?: boolean;
  /** Published on the Beta channel only. */
  beta?: boolean;
  planned?: boolean;
  items: string[];
}

export const CHANGELOG: Release[] = [
  {
    name: 'Prochaines',
    date: 'En préparation',
    planned: true,
    items: [
      'Choix du micro pour l’enregistrement de l’écran',
      'Sous-titres en ligne pour les films et les vidéos',
    ],
  },
  {
    name: '0.3.0 · Windows et Android',
    date: '26 novembre 2026',
    current: true,
    items: [
      'En ligne : cherchez un titre ou un artiste et écoutez-le tout de suite dans le lecteur de l’app, sans le télécharger',
      'En ligne s’ouvre sur des grilles de clips : nouveautés, et d’après votre dernière recherche',
      'Voir le clip d’un titre en ligne dans le lecteur vidéo, au moment où vous en êtes',
      'Obtenir un titre écouté en ligne : Original, MP3 320 ou MP3 128 ; il s’écoute ensuite hors connexion. Option : obtenir les titres écoutés en entier (en Wi-Fi seulement sur Android)',
      'Paroles trouvées automatiquement pour les titres qui n’en ont pas : synchronisées quand elles existent, et les chansons malgaches grâce à Tononkira ; gardées pour l’écoute hors connexion (réglage pour le désactiver)',
      'Sans paroles : les chercher soi-même, sur le web, ou importer un fichier .lrc ; des paroles gardées se remplacent ou se suppriment',
      'Thème sombre neutre, sans reflet bleu',
      'Navigateur : les vrais logos des sites de départ',
      'Android : en baissant le lecteur, la pochette et le titre rejoignent le mini-lecteur',
      'Les écoutes en ligne comptent dans les statistiques d’écoute',
    ],
  },
  {
    name: '0.2.10 · Windows et Android',
    date: '25 novembre 2026',
    items: [
      'Windows : le même style que sur Android : barre de lecture aux couleurs de la pochette, accueil avec vos statistiques d’écoute, albums et artistes redessinés',
      'Vue vinyle : une platine avec son bras de lecture, sur Windows et Android',
      'La vague de la barre de lecture suit le tempo des morceaux qui l’indiquent',
      'Android : le temps d’écoute des 7 derniers jours se met bien à jour',
      'Android : mise à jour depuis l’application (Réglages › Mises à jour) ; depuis la 0.2.9, installez cette version une fois depuis le site',
      'Android : onglet Accueil dans la bibliothèque ; les fichiers vides ne sont plus listés',
    ],
  },
  {
    name: '0.2.9 · Android',
    date: '25 novembre 2026',
    items: [
      'Android : nouveau lecteur aux couleurs de la pochette, avec une barre de lecture animée, de grands boutons et le volume du téléphone',
      'Android : nouvel accueil Musique : dernières écoutes, titres les plus joués, vos artistes, mix du jour, titres à découvrir et temps d’écoute des 7 derniers jours',
      'Android : bibliothèque redessinée : onglets avec leurs nombres, grille ou liste, albums aux couleurs de leur pochette, nouvelles pages d’album et d’artiste',
      'Android : menu du lecteur avec minuteur, égaliseur, vitesse, recul et avance de 10 secondes, vue vinyle, album, artiste et infos du morceau',
      'Windows reste en 0.2.8',
    ],
  },
  {
    name: '0.2.8 · Windows et Android',
    date: '24 novembre 2026',
    items: [
      'En malagasy, les écrans Historique s’affichent de nouveau (ils restaient gris)',
      'Android : si vous avez téléchargé avant d’ouvrir Musique, un bandeau propose maintenant d’afficher la musique du téléphone',
      'Android : appui long ou ⋮ sur un titre pour le lire ensuite, l’ajouter à la file ou à une playlist, le partager ou le supprimer du téléphone',
      'Windows : pages centrées sur les grands écrans, passage plus doux d’une page à l’autre',
      'Windows et Android passent tous deux en 0.2.8',
    ],
  },
  {
    name: '0.2.6 · Windows',
    date: '24 novembre 2026',
    items: [
      'Nouvelle application Windows : elle remplace la 0.1.12 en gardant la bibliothèque, les playlists, les favoris, les reprises et les réglages (la bibliothèque est copiée avant sa mise à jour)',
      'Outils PC : convertir (MP4, MKV, WebM, AVI, MOV, 3GP, GIF, MP3, FLAC…), fusionner, découper, rogner, compresser',
      'Compression en AV1 : jusqu’à 35 % plus léger que le H.264 à qualité égale, ou une taille maximale par fichier ; H.264 pour les anciens appareils',
      'Capture d’écran par raccourci (zone ou écran entier, sur tous les écrans) et enregistrement de l’écran avec le son du PC et le micro',
      'Interface en malagasy, visite guidée au premier lancement',
      'La fermeture de l’application ne bloque plus',
      'Android reste en version 0.2.5',
    ],
  },
  {
    name: '0.2.5 · Android',
    date: '24 novembre 2026',
    items: [
      'Nouvelle application Android : elle remplace la 0.1.11 en gardant la bibliothèque, les favoris, les playlists et l’historique des téléchargements (la base est copiée avant la mise à jour)',
      'Lecteur vidéo : gestes (luminosité, volume, ±10 s, pincer pour remplir l’écran), cadenas, rotation et image dans l’image',
      '« Écouter seulement » : une vidéo continue en son, même écran éteint',
      'Lecture sans blanc entre les titres, import et export de playlists M3U',
      'Les réglages d’affichage de la 0.1.11 (thème…) reviennent à leurs valeurs par défaut',
      'Windows reste en version 0.1.12 ; la bêta Windows 0.2.4 ne change pas',
    ],
  },
  {
    name: '0.2.4 · Windows et Android',
    date: 'Bêta · 23 novembre 2026',
    beta: true,
    items: [
      'Les liens Facebook, Instagram, TikTok, X, Vimeo et des autres sites vidéo vont directement à l’analyse de la vidéo',
      'Une page qui ne répond pas ne bloque plus l’analyse : la vidéo est quand même recherchée. Corrige « le site n’a pas pu être joint » avec certains liens Facebook sur Android',
    ],
  },
  {
    name: '0.2.3 · Android',
    date: 'Bêta · 23 novembre 2026',
    beta: true,
    items: [
      'Choix du format depuis le navigateur intégré : vignette, onglets Vidéo, Audio seul et Sous-titres, qualités et tailles, comme dans la maquette',
      'Playlists : la tuile Playlist d’Obtenir liste les éléments d’une playlist ; vous cochez ceux à télécharger et choisissez une qualité pour tous',
      'S’installe par-dessus la bêta 0.2.2 en gardant la bibliothèque et les téléchargements',
    ],
  },
  {
    name: '0.2.3 · Windows',
    date: 'Bêta · 23 novembre 2026',
    beta: true,
    items: [
      'Touches multimédia du clavier et du casque, et commandes de Windows (titre, pochette, lecture et pause, précédent et suivant)',
      'Extension pour Chrome et Edge : « Envoyer vers Miarina Media » ouvre l’analyse du lien dans l’application, même fermée. À connecter dans Réglages › Extension navigateur, puis à charger en mode développeur',
      'Playlists : la tuile Playlist d’Obtenir liste jusqu’à 200 éléments ; vous cochez ceux à télécharger, choisissez une qualité pour tous et, si vous voulez, un dossier au nom de la playlist',
      'Chaque élément d’une playlist est un téléchargement de la file : même ordre, mêmes limites, nouvel essai un par un',
    ],
  },
  {
    name: '0.2.2 · Android',
    date: 'Bêta · 23 novembre 2026',
    beta: true,
    items: [
      'Navigateur intégré : tuile Navigateur dans Obtenir, onglets, historique et favoris',
      'Les vidéos et fichiers audio d’une page sont détectés ; un bouton « Télécharger » apparaît au-dessus de la page : toucher pour choisir le format, appui long pour le format par défaut',
      'Le bouton Retour du téléphone revient à la page précédente, puis à Obtenir',
      'Pages web seulement : pas de fenêtres surgissantes, et un fichier proposé par un site passe toujours par l’analyse de Miarina Media',
      'S’installe par-dessus la bêta 0.2.1 en gardant la bibliothèque et les téléchargements',
    ],
  },
  {
    name: '0.2.2 · Windows',
    date: 'Bêta · 23 novembre 2026',
    beta: true,
    items: [
      'Une seule fenêtre : un fichier ouvert pendant que Miarina Media tourne s’ajoute à la fenêtre déjà ouverte',
      '« Ouvrir avec Miarina Media » pour la musique et les vidéos, et Miarina Media dans Paramètres › Applications par défaut',
      'Icônes de fichiers Miarina Media pour la musique et les vidéos que vous choisissez d’ouvrir avec l’application ; rien n’est imposé par défaut',
      'Un fichier ouvert au premier lancement est lu tout de suite ; l’accueil vient au lancement suivant',
      'La désinstallation retire seulement ces entrées : les choix faits pour vos autres lecteurs restent',
    ],
  },
  {
    name: '0.2.1 · Android',
    date: 'Bêta · 21 novembre 2026',
    beta: true,
    items: [
      'Téléchargement depuis un lien : collez-le dans Obtenir, ou partagez-le vers Miarina Media Bêta depuis n’importe quelle application',
      'Analyse du lien et choix du format : vidéo jusqu’à la meilleure qualité proposée, ou audio seul converti en MP3',
      'Les fichiers vont dans Films/Miarina et Musique/Miarina et rejoignent la bibliothèque et la galerie du téléphone',
      'Les téléchargements continuent écran éteint, avec la progression, Pause et Annuler dans la notification ; « Téléchargement terminé · toucher pour lire »',
      'Écrans Obtenir et Téléchargements adaptés au téléphone',
      'S’installe par-dessus la bêta 0.2.0 en gardant la bibliothèque ; la 0.1.11 reste installée à côté',
      'APK plus gros (64,4 Mio) : il embarque l’extracteur et FFmpeg, comme la 0.1.11',
    ],
  },
  {
    name: '0.2.0 · Android',
    date: 'Bêta · 21 novembre 2026',
    beta: true,
    items: [
      'Miarina Media Bêta : nouvelle application Android, installée à côté de la 0.1.11 sans la remplacer ni toucher à ses données',
      'La musique et les vidéos du téléphone, avec votre autorisation et en lecture seule : titres, albums, artistes, pochettes et durées',
      'Écouter en trois onglets : Musique, Cinéma et Focus, avec le lecteur, le mini-lecteur et les commandes de l’écran verrouillé',
      '« Ouvrir avec Miarina Media Bêta » pour la musique et les vidéos venant d’autres applications',
      'Le téléchargement depuis un lien arrive dans une prochaine bêta ; il reste disponible dans la 0.1.11',
      'Téléphones Android 64 bits (ARM)',
    ],
  },
  {
    name: '0.2.0 · Windows',
    date: 'Bêta · 21 novembre 2026',
    beta: true,
    items: [
      'Nouvelle application Windows, entièrement refaite ; elle s’installe par-dessus la 0.1.x, dans le même dossier, avec les mêmes raccourcis',
      'Bibliothèque, playlists, favoris, historique, reprises et réglages repris ; copie de sauvegarde de la bibliothèque avant sa mise à jour',
      'Écouter en trois sections : Musique, Cinéma (films et séries, épisodes vus ou en cours) et Focus (podcasts, cours, livres audio, signets avec notes) ; accueil avec reprise et listes automatiques',
      'Musique : titres triables, sélection multiple, filtres (jamais écoutés, hi-res, ajoutés ce mois), format affiché (FLAC 24/96, MP3 320), nombre d’écoutes ; artistes regroupés par artiste de l’album, avec leur image si elle est dans vos dossiers',
      'En lecture : paroles synchronisées depuis un fichier .lrc, file enregistrable en playlist, égaliseur, vitesse, minuteur, mini-lecteur',
      'Éditeur de tags et de pochettes, pour la musique et les vidéos',
      'Nouveau moteur de lecture (libmpv) ; fermeture propre, téléchargements et torrents arrêtés avant de quitter',
      'L’extension pour Chrome et Edge n’est pas reprise dans cette version : l’installateur la retire',
      'Installateur plus gros (113 Mio) ; Android reste en version 0.1.11',
    ],
  },
  {
    name: '0.1.12 · Windows',
    date: 'Préversion de test · 16 novembre 2026',
    items: [
      'Plein écran : titre masqué et commandes qui disparaissent après inactivité',
      'Barre de lecture déplaçable par glissement',
      'Liste de lecture complète dans le panneau droit : ajout, réorganisation, retrait et sauvegarde',
      'Résultats de recherche visibles et cliquables pendant la lecture vidéo native',
      'Android reste en version 0.1.11',
    ],
  },
  {
    name: '0.1.11 · Windows et Android',
    date: 'Préversion de test · 15 novembre 2026',
    items: [
      'Le lecteur d’abord : l’application s’ouvre sur la musique ; Android : barre Musique, Vidéos, Téléchargements ; Windows : espace Écouter en premier',
      'Une seule recherche : titres et vidéos de l’appareil d’abord, puis YouTube ou le web, liens collés analysés ; logos des sites',
      'Android : navigateur ouvert depuis la recherche ; en-tête qui s’efface en descendant et revient en remontant ; grand lecteur qui se réduit en mini-lecteur d’un glissement vers le bas',
      'Formes arrondies, cartes de bibliothèque et animations plus fluides, aux couleurs de Miarina',
      'Écran d’attente pendant l’analyse d’un lien : ce qui se passe, temps écoulé et astuces',
      'Windows : pages du navigateur au thème de l’application (clair ou sombre)',
      'Android : bouton plein écran des vidéos toujours visible ; APK plus léger, pour téléphones 64 bits (ARM)',
    ],
  },
  {
    name: '0.1.10 · Windows',
    date: 'Préversion de test · 14 novembre 2026',
    items: [
      'Lecteur vidéo : bandeau du titre, commandes, volume et progression adaptés au mode clair. Android reste en 0.1.9.',
    ],
  },
  {
    name: '0.1.9 · Windows et Android',
    date: 'Préversion de test · 13 novembre 2026',

    items: [
      'Android : nouvelle interface (Accueil, Navigateur, Téléchargements, Musique, Vidéos), écran de démarrage animé, thème clair et anglais',
      'Android : vrai lecteur de musique — albums, artistes, dossiers, playlists, favoris, titres récents et plus écoutés, file enregistrable en playlist',
      'Android : musique et vidéos déjà présentes sur le téléphone, avec votre autorisation et en lecture seule',
      'Android : lecture qui continue écran éteint, commandes de l’écran verrouillé, du casque et de la notification ; pause au retrait du casque (réglable)',
      'Android : égaliseur du téléphone avec préréglages, vitesse, minuteur, paroles locales',
      'Android : vidéo en plein écran paysage, gestes luminosité et volume, pistes audio, sous-titres SRT et VTT, image dans l’image',
      'Android : vérifié sur émulateur ; essais sur téléphone réel en cours',
      'Windows : le thème choisi est conservé, badge PRÉVU lisible en thème clair, refus de suppression signalé clairement',
    ],
  },
  {
    name: '0.1.8 · Windows',
    date: 'Préversion de test · 12 novembre 2026',
    items: [
      'Nouvelle interface Windows : espaces Obtenir et Écouter, mini-lecteur, écrans revus, français et anglais complets, nouveau logo',
      'Bibliothèque musicale : albums, artistes, dossiers, éditeur de tags et pochettes',
      'Playlists, favoris, import et export M3U ; file de lecture, positions et historique d’écoute conservés',
      'Lecteur intégré : MKV, HEVC, AVI et autres formats, pistes audio, sous-titres SRT et VTT avec décalage, égaliseur à 6 bandes ; image dans l’image retirée avec ce lecteur',
      'Ouvrir des fichiers, importer un dossier, déposer des fichiers sur la fenêtre',
      'Navigateur : plusieurs onglets et historique local',
      'Téléchargements : reprise vérifiée, attente du retour du réseau, disque plein et dossier inaccessible signalés',
      'Mises à jour : annulation et reprise du téléchargement, canal stable ou bêta, téléchargement automatique sur réseau non limité (désactivé par défaut), copie de la bibliothèque avant mise à jour',
      'Installateur plus gros (lecteur inclus) ; Android reste en 0.1.7',
    ],
  },
  {
    name: '0.1.7 · Windows et Android',
    date: 'Préversion de test · 10 novembre 2026',
    items: [
      'Recherche automatique de nouvelles versions et notification dans Miarina Media',
      'Téléchargement dans les réglages avec progression et vérification de la signature',
      'Installation depuis l’application : installateur Windows ou confirmation système Android',
      'Une installation manuelle de la 0.1.7 active ce parcours pour les prochaines versions',
    ],
  },
  {
    name: '0.1.6 · Windows et Android',
    date: 'Préversion de test · 9 novembre 2026',
    items: [
      'Windows : torrents et magnets, sélection des fichiers, pause/reprise, limites de débit et arrêt du partage',
      'Windows : extension Chrome/Edge en mode développeur pour envoyer manuellement des liens vers une boîte de réception locale',
      'Windows et Android : protection du nettoyage des fichiers temporaires et du contrôle du dossier de téléchargement',
      'Tests automatisés et transfert torrent local validés ; essais sur téléphone réel et connexion de l’extension dans un navigateur encore à effectuer',
    ],
  },
  {
    name: '0.1.5 · Windows',
    date: 'Préversion de test · 31 octobre 2026',
    items: [
      'Plein écran du lecteur : barres de navigation masquées, retour avec Échap',
      'Lecture interrompue : bouton Réessayer à la position courante et message adapté à l’erreur',
      'Surface vidéo défaillante masquée sur fond sombre',
      'Protection contre les doubles clics au lancement des téléchargements',
    ],
  },
  {
    name: '0.1.5 · Android',
    date: 'Préversion de test · 29 octobre 2026',
    items: [
      'Extracteur et outils de conversion intégrés à l’APK',
      'Parcours YouTube testé sur émulateur : analyse, téléchargement vidéo et lecture locale',
      'Protection contre les doubles clics lors du lancement et textes de progression corrigés',
      'Logo discret pour les médias sans miniature',
      'MP3 320 kbps vérifié sur émulateur ; téléphone physique et autres débits encore à tester',
    ],
  },
  {
    name: '0.1.4 · Android',
    date: 'Préversion de test · 28 octobre 2026',
    items: [
      'Extracteur et outils de conversion intégrés à l’APK',
      'Parcours YouTube et lecture locale testés sur émulateur',
      'Logo discret pour les médias sans miniature',
    ],
  },
  {
    name: '0.1.4 · Windows',
    date: 'Préversion de test · 28 octobre 2026',
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
  {
    feature: 'Recherche et téléchargement des mises à jour dans l’app',
    windows: true,
    android: true,
  },
  {
    feature: 'Mises à jour : reprise, canal bêta, copie de la bibliothèque',
    windows: true,
    android: 'soon',
  },
  { feature: 'Torrents et liens magnet', windows: true, android: false },
  {
    feature: 'Extension Chrome/Edge : envoi manuel de liens',
    windows: 'Bêta 0.2.3, mode développeur',
    android: false,
  },
  { feature: 'Téléchargement par lien direct', windows: true, android: true },
  {
    feature: 'Playlists : choix des éléments et d’une qualité pour tous',
    windows: 'Bêta 0.2.3',
    android: 'Bêta 0.2.3',
  },
  {
    feature: 'Pages de sites vidéo (via yt-dlp)',
    windows: true,
    android: 'YouTube testé sur émulateur',
  },
  { feature: 'Conversion en MP3', windows: true, android: '320 kbps testé sur émulateur' },
  { feature: 'File, pause et reprise selon la source', windows: true, android: true },
  { feature: 'Bibliothèque', windows: true, android: true },
  {
    feature: 'Bibliothèque musicale : albums, artistes, dossiers, pochettes',
    windows: true,
    android: true,
  },
  { feature: 'Éditeur de tags et choix de pochette', windows: true, android: false },
  { feature: 'Playlists et favoris', windows: true, android: true },
  { feature: 'Import et export M3U', windows: true, android: 'soon' },
  { feature: 'Titres récents et plus écoutés', windows: 'Historique d’écoute', android: true },
  { feature: 'Lecteur intégré', windows: true, android: true },
  {
    feature: 'Commandes système : écran verrouillé, notification, casque Bluetooth',
    windows: 'Bêta 0.2.3 : touches multimédia',
    android: true,
  },
  { feature: 'Pistes audio et sous-titres SRT / VTT', windows: true, android: true },
  { feature: 'Égaliseur', windows: true, android: 'Selon le téléphone' },
  {
    feature: 'Ouvrir des fichiers, importer un dossier, glisser-déposer',
    windows: true,
    android: false,
  },
  {
    feature: '« Ouvrir avec Miarina Media » et icônes de fichiers',
    windows: 'Bêta 0.2.2',
    android: 'Ouvrir avec',
  },
  {
    feature: 'Musique et vidéos déjà présentes sur l’appareil',
    windows: 'Import de dossier',
    android: 'Avec autorisation',
  },
  {
    feature: 'Vidéo plein écran, gestes luminosité et volume',
    windows: 'Plein écran',
    android: true,
  },
  { feature: 'Image dans l’image', windows: false, android: true },
  { feature: 'Téléchargement en arrière-plan, notifications', windows: true, android: true },
  { feature: 'Navigateur intégré, recherche et favoris', windows: true, android: true },
  { feature: 'Navigateur : onglets et historique', windows: true, android: 'Bêta 0.2.2' },
  {
    feature: 'Détection dans le navigateur',
    windows: 'Fichiers et pages',
    android: 'Fichiers vidéo et audio',
  },
  { feature: 'Partager un lien vers l’app', windows: false, android: true },
  { feature: 'Partager ou ouvrir un fichier avec une autre app', windows: false, android: true },
  { feature: 'Fichiers visibles dans la galerie (Android 11+)', windows: false, android: true },
  { feature: 'Raccourcis clavier', windows: true, android: false },
  {
    feature: 'Configuration minimale',
    windows: 'Windows 10 · 64 bits',
    android: 'Android 7.0 · 64 bits (ARM)',
  },
];

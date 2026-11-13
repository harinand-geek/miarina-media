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
  version: '0.1.8',
  windows: {
    version: '0.1.8',
    name: 'MiarinaMedia-0.1.8-x64-setup.exe',
    size: '91,2 Mio',
    sha256: 'e90bc6e275bf8f0d8bdd955a56b11bed459bb03ec1a6406141297d96335a7d49',
  } satisfies ReleaseFile,
  android: {
    version: '0.1.7',
    name: 'MiarinaMedia-0.1.7.apk',
    size: '126,8 Mio',
    sha256: 'b9a04fba921bffa60eca104adc219af25de2814aaf1507a52ca7a9b85c8eba23',
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
      'Android : essais sur téléphone réel (Bluetooth, appels, écran verrouillé) et autres qualités audio',
      'Android : onglets et historique du navigateur, import et export M3U',
      'Fondu entre les titres (désactivé par défaut)',
    ],
  },
  {
    name: '0.1.9 · Windows et Android',
    date: 'Préversion de test · 13 novembre 2026',
    current: true,
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
      'Lecteur libVLC intégré : MKV, HEVC, AVI et autres formats, pistes audio, sous-titres SRT et VTT avec décalage, égaliseur à 6 bandes ; image dans l’image retirée avec ce lecteur',
      'Ouvrir des fichiers, importer un dossier, déposer des fichiers sur la fenêtre',
      'Navigateur : plusieurs onglets et historique local',
      'Téléchargements : reprise vérifiée, attente du retour du réseau, disque plein et dossier inaccessible signalés',
      'Mises à jour : annulation et reprise du téléchargement, canal stable ou bêta, téléchargement automatique sur réseau non limité (désactivé par défaut), copie de la bibliothèque avant mise à jour',
      'Installateur plus gros (libVLC inclus) ; Android reste en 0.1.7',
    ],
  },
  {
    name: '0.1.7 · Windows et Android',
    date: 'Préversion de test · 10 novembre 2026',
    items: [
      'Recherche automatique de nouvelles versions et notification dans Miarina',
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
    windows: 'Mode développeur',
    android: false,
  },
  { feature: 'Téléchargement par lien direct', windows: true, android: true },
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
  { feature: 'Lecteur intégré', windows: 'libVLC', android: 'Media3' },
  {
    feature: 'Commandes système : écran verrouillé, notification, casque Bluetooth',
    windows: false,
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
  { feature: 'Navigateur : onglets et historique', windows: true, android: 'soon' },
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

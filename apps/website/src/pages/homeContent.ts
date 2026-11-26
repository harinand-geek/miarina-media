// Texts of the landing page (design_handoff_landing_v4), French and English.
// Versions, files and the changelog come from ../release.ts. Every sentence
// must stay true for the published release.

export type Lang = 'fr' | 'en';

export interface FeatureGroup {
  id: 'obtenir' | 'ecouter';
  num: string;
  icon: string;
  title: string;
  lead: string;
  items: [string, string][];
}

export interface LandingText {
  nav: {
    get: string;
    listen: string;
    library: string;
    versions: string;
    cta: string;
    lang: string;
  };
  h1: [string, string];
  sub: string;
  ctaWindows: string;
  ctaAndroid: string;
  heroMeta: (windows: string, android: string, beta: string) => string;
  demo: {
    get: string;
    listen: string;
    analyze: string;
    analyzing: string;
    file: string;
    recent: string;
    size: string;
    saved: string;
    steps: [string, string, string, string];
    formats: [string, string, string][];
  };
  featKicker: string;
  featTitle: string;
  groups: [FeatureGroup, FeatureGroup];
  /** Windows 0.2.0 on the Beta channel. */
  beta: {
    kicker: string;
    title: string;
    lead: string;
    points: [string, string][];
    how: string;
    cta: string;
  };
  libKicker: string;
  libTitle: string;
  libBody: string;
  shots: [string, string, string][];
  shotAlts: [string, string, string];
  dlTitle: string;
  dlLead: string;
  dlWindowsReq: string;
  dlAndroidReq: string;
  dlWindowsCta: string;
  dlAndroidCta: string;
  dlNote: string;
  /** Badge on the visitor's platform. */
  dlSuggested: string;
  dlBetaReq: string;
  dlBetaBadge: string;
  dlAndroidBetaReq: string;
  verKicker: string;
  verTitle: string;
  verCurrent: string;
  verBeta: string;
  verPlanned: string;
  verNext: string;
  verFrenchOnly?: string;
  legal: string;
  privacy: string;
  licences: string;
}

const FORMAT_ICONS = ['movie', 'music_note', 'graphic_eq'] as const;

export const LANDING: Record<Lang, LandingText> = {
  fr: {
    nav: {
      get: 'Obtenir',
      listen: 'Écouter',
      library: 'Bibliothèque',
      versions: 'Versions',
      cta: 'Télécharger',
      lang: 'Langue',
    },
    h1: ['Téléchargez une fois.', 'Écoutez hors ligne.'],
    sub: 'Collez un lien, choisissez le format, gardez le fichier. Miarina Media range vidéos et musique dans une bibliothèque sur votre appareil et les lit dans son propre lecteur : albums, playlists, pistes audio, sous-titres et égaliseur. Sur Windows et Android.',
    ctaWindows: 'Télécharger pour Windows',
    ctaAndroid: 'Android (APK)',
    heroMeta: (w, a) => `Windows ${w} · Android ${a} · gratuit, sans compte`,
    demo: {
      get: 'Obtenir',
      listen: 'Écouter',
      analyze: 'Analyser',
      analyzing: 'Analyse…',
      file: 'big_buck_bunny.mp3',
      recent: 'Ajoutés récemment',
      size: '24,8 Mo',
      saved: 'Enregistré dans Musique/Miarina',
      steps: ['Lien', 'Format', 'Fichier', 'Lecture'],
      formats: [
        [FORMAT_ICONS[0], 'Vidéo · MP4 1080p', 'H.264'],
        [FORMAT_ICONS[1], 'Audio · MP3 320 kbps', '24,8 Mo'],
        [FORMAT_ICONS[2], 'Audio · FLAC', 'conversion'],
      ],
    },
    featKicker: 'Fonctionnalités',
    featTitle: 'Deux espaces, une seule application.',
    groups: [
      {
        id: 'obtenir',
        num: '01',
        icon: 'download',
        title: 'Obtenir',
        lead: 'Du lien au fichier : analyse, choix du format, file de téléchargements.',
        items: [
          [
            'Collez un lien',
            'Miarina Media lit l’adresse et vous montre ce qui peut être téléchargé.',
          ],
          [
            'Une seule recherche',
            'Tapez un titre : Miarina Media cherche d’abord sur votre appareil, puis propose YouTube ou le web dans son navigateur intégré.',
          ],
          [
            'Choisissez le format',
            'Qualité vidéo ou audio seul, avec la taille affichée lorsqu’elle est fournie ou estimable.',
          ],
          [
            'File de téléchargements',
            'Mettez en pause et reprenez lorsque la source le permet. Sous Windows, la reprise est vérifiée, Miarina Media attend le retour du réseau et signale un disque plein ou un dossier inaccessible.',
          ],
          [
            'Torrents sur Windows',
            'Ajoutez un torrent ou un lien magnet, choisissez les fichiers, réglez les débits et arrêtez le partage quand vous le souhaitez.',
          ],
          [
            'Depuis Chrome ou Edge',
            'L’extension Windows envoie les liens que vous choisissez vers Miarina Media, même lorsque l’application est fermée. Installation en mode développeur.',
          ],
        ],
      },
      {
        id: 'ecouter',
        num: '02',
        icon: 'library_music',
        title: 'Écouter',
        lead: 'Un vrai lecteur pour ce que vous gardez, et pour la musique déjà présente sur l’appareil.',
        items: [
          [
            'Bibliothèque musicale',
            'Sous Windows et Android : albums, artistes, dossiers et recherche, avec les pochettes des fichiers. Sous Windows, éditeur de tags et choix de pochette.',
          ],
          [
            'Playlists et favoris',
            'Playlists, favoris, file de lecture enregistrable en playlist. Sur Android, titres récents et plus écoutés ; sous Windows, import et export M3U.',
          ],
          [
            'Lecteur et égaliseur',
            'Sous Windows, le lecteur intégré gère les pistes audio, les sous-titres SRT et VTT, la vitesse et l’égaliseur. Sous Android, la musique continue écran éteint, avec les commandes de l’écran verrouillé et du casque Bluetooth, et l’égaliseur du téléphone.',
          ],
          [
            'Vos fichiers aussi',
            'Sous Windows, ouvrez des fichiers, importez un dossier ou déposez-les sur la fenêtre. Sous Android, autorisez l’accès à la musique et aux vidéos du téléphone : elles rejoignent la bibliothèque, en lecture seule.',
          ],
        ],
      },
    ],
    beta: {
      kicker: 'Windows et Android 0.3.0 · nouveau',
      title: 'Écouter en ligne, garder hors connexion.',
      lead: 'Cherchez un titre ou un artiste et écoutez-le tout de suite dans votre lecteur. Un clic sur Obtenir, et il reste avec vous, même sans réseau.',
      points: [
        [
          'En ligne',
          'Une seule recherche pour votre bibliothèque et en ligne. La page s’ouvre sur des grilles de clips : nouveautés, et d’après votre dernière recherche.',
        ],
        [
          'Le clip aussi',
          'Passez d’un titre à son clip dans le lecteur vidéo, au moment où vous en êtes.',
        ],
        [
          'Paroles',
          'Trouvées automatiquement, chansons malgaches comprises, et gardées pour l’écoute hors connexion.',
        ],
        [
          'Hors connexion',
          'Original, MP3 320 ou MP3 128. En option, les titres écoutés en entier s’ajoutent seuls à la bibliothèque.',
        ],
      ],
      how: 'Réglages › Mises à jour propose la 0.3.0. Ou téléchargez l’installateur.',
      cta: 'Télécharger',
    },
    libKicker: 'Bibliothèque et lecteur',
    libTitle: 'Tout ce que vous gardez, au même endroit.',
    libBody:
      'Les téléchargements vidéo et audio arrivent dans la bibliothèque, avec vos propres fichiers si vous les ajoutez. La musique se range par albums, artistes et dossiers, avec pochettes, playlists et favoris. Tout se lit hors ligne.',
    shots: [
      [
        'album',
        'Windows · Albums',
        'Windows 0.2.10 : albums, artistes, titres, playlists et favoris, avec les pochettes des fichiers, des filtres et un éditeur de tags.',
      ],
      [
        'play_circle',
        'Windows · En lecture',
        'Windows 0.2.10 : l’écran prend les couleurs de la pochette ; paroles synchronisées, file de lecture, égaliseur, vitesse, minuteur et mode vinyle. La lecture reprend où vous l’aviez laissée.',
      ],
      [
        'android',
        'Android',
        'Sur Android, Miarina Media s’ouvre sur votre musique : reprise de lecture, favoris, récents, plus joués, mix du jour, albums, artistes et playlists. La lecture continue écran éteint ; les vidéos passent en plein écran paysage avec pistes, sous-titres et image dans l’image.',
      ],
    ],
    shotAlts: [
      'Bibliothèque musicale Windows 0.2.10 : des albums de démonstration avec leurs pochettes',
      'Lecteur Windows 0.2.10 : un titre en lecture, l’écran aux couleurs de sa pochette',
      'Android 0.2.10 : l’accueil Musique de Miarina Media',
    ],
    dlTitle: 'Télécharger Miarina Media',
    dlLead:
      'Gratuit, sans publicité, sans compte. L’application n’envoie ni statistiques d’usage ni rapports de plantage.',
    dlWindowsReq: 'Windows 10 / 11 · 64 bits',
    dlAndroidReq: 'Android 7.0 et plus · 64 bits (ARM)',
    dlSuggested: 'Pour cet appareil',
    dlBetaReq: 'Windows 10 / 11 · 64 bits · nouvelle application, remplace la 0.1.x',
    dlBetaBadge: 'Bêta',
    dlAndroidBetaReq:
      'Android 7.0 et plus · 64 bits (ARM) · lecteur, téléchargements et navigateur, s’installe à côté de la 0.1.11',
    dlWindowsCta: 'Installateur .exe',
    dlAndroidCta: 'Fichier .apk',
    dlNote:
      'L’installateur Windows n’est pas signé : SmartScreen peut afficher un avertissement. Comparez l’empreinte SHA-256 avant d’installer.',
    verKicker: 'Journal des versions',
    verTitle: 'Ce qui a changé, version par version.',
    verCurrent: 'Actuelle',
    verBeta: 'Bêta',
    verPlanned: 'Prévu',
    verNext: 'Prochaines',
    legal:
      'Téléchargez uniquement les contenus dont vous détenez les droits ou dont la licence l’autorise.',
    privacy: 'Confidentialité',
    licences: 'Licences',
  },
  en: {
    nav: {
      get: 'Get',
      listen: 'Listen',
      library: 'Library',
      versions: 'Releases',
      cta: 'Download',
      lang: 'Language',
    },
    h1: ['Download once.', 'Listen offline.'],
    sub: 'Paste a link, pick a format, keep the file. Miarina Media files your videos and music in a library on your device and plays them in its own player: albums, playlists, audio tracks, subtitles and equalizer. On Windows and Android.',
    ctaWindows: 'Download for Windows',
    ctaAndroid: 'Android (APK)',
    heroMeta: (w, a) => `Windows ${w} · Android ${a} · free, no account`,
    demo: {
      get: 'Get',
      listen: 'Listen',
      analyze: 'Analyze',
      analyzing: 'Analyzing…',
      file: 'big_buck_bunny.mp3',
      recent: 'Recently added',
      size: '24.8 MB',
      saved: 'Saved to Music/Miarina',
      steps: ['Link', 'Format', 'File', 'Play'],
      formats: [
        [FORMAT_ICONS[0], 'Video · MP4 1080p', 'H.264'],
        [FORMAT_ICONS[1], 'Audio · MP3 320 kbps', '24.8 MB'],
        [FORMAT_ICONS[2], 'Audio · FLAC', 'conversion'],
      ],
    },
    featKicker: 'Features',
    featTitle: 'Two spaces, one app.',
    groups: [
      {
        id: 'obtenir',
        num: '01',
        icon: 'download',
        title: 'Get',
        lead: 'From link to file: analysis, format choice, download queue.',
        items: [
          ['Paste a link', 'Miarina Media reads the address and shows you what can be downloaded.'],
          [
            'One search',
            'Type a title: Miarina Media looks on your device first, then offers YouTube or the web in its built-in browser.',
          ],
          [
            'Pick the format',
            'Video quality or audio only, with the size shown when the source provides or allows an estimate.',
          ],
          [
            'Download queue',
            'Pause and resume when the source allows it. On Windows, resume is verified, Miarina Media waits for the network to return and flags a full disk or an unreachable folder.',
          ],
          [
            'Torrents on Windows',
            'Add a torrent or magnet link, pick the files, set the rates and stop seeding whenever you want.',
          ],
          [
            'From Chrome or Edge',
            'The Windows extension sends the links you choose to Miarina Media, even when the app is closed. Installed in developer mode.',
          ],
        ],
      },
      {
        id: 'ecouter',
        num: '02',
        icon: 'library_music',
        title: 'Listen',
        lead: 'A real player for what you keep, and for the music already on your device.',
        items: [
          [
            'Music library',
            'On Windows and Android: albums, artists, folders and search, with the files’ cover art. On Windows, a tag editor and cover picker.',
          ],
          [
            'Playlists and favourites',
            'Playlists, favourites, a play queue you can save as a playlist. On Android, recent and most played; on Windows, M3U import and export.',
          ],
          [
            'Player and equalizer',
            'On Windows, the built-in player handles audio tracks, SRT and VTT subtitles, speed and the equalizer. On Android, music keeps playing with the screen off, with lock-screen and Bluetooth headset controls and the phone’s equalizer.',
          ],
          [
            'Your files too',
            'On Windows, open files, import a folder or drop them on the window. On Android, allow access to the phone’s music and videos: they join the library, read-only.',
          ],
        ],
      },
    ],
    beta: {
      kicker: 'Windows and Android 0.3.0 · new',
      title: 'Listen online, keep it offline.',
      lead: 'Search for a track or an artist and play it right away in your player. One click on Get, and it stays with you, even without a network.',
      points: [
        [
          'Online',
          'One search for your library and online. The page opens on grids of clips: new releases, and based on your last search.',
        ],
        [
          'The clip too',
          'Switch from a track to its clip in the video player, where you were.',
        ],
        [
          'Lyrics',
          'Found automatically, Malagasy songs included, and kept for offline listening.',
        ],
        [
          'Offline',
          'Original, MP3 320 or MP3 128. Optionally, tracks played to the end join the library by themselves.',
        ],
      ],
      how: 'Settings › Updates offers 0.3.0. Or download the installer.',
      cta: 'Download',
    },
    libKicker: 'Library and player',
    libTitle: 'Everything you keep, in one place.',
    libBody:
      'Video and audio downloads land in the library, along with your own files if you add them. Music is sorted by album, artist and folder, with cover art, playlists and favourites. Everything plays offline.',
    shots: [
      [
        'album',
        'Windows · Albums',
        'Windows 0.2.10: albums, artists, songs, playlists and favourites, with the files’ cover art, filters and a tag editor.',
      ],
      [
        'play_circle',
        'Windows · Now playing',
        'Windows 0.2.10: the screen takes on the cover’s colours; synced lyrics, play queue, equalizer, speed, sleep timer and vinyl mode. Playback resumes where you left off.',
      ],
      [
        'android',
        'Android',
        'On Android, Miarina Media opens on your music: resume playback, favourites, recent, most played, mix of the day, albums, artists and playlists. Playback continues with the screen off; videos go full-screen landscape with tracks, subtitles and picture-in-picture.',
      ],
    ],
    shotAlts: [
      'Windows 0.2.10 music library: demo albums with their covers',
      'Windows 0.2.10 player: a song playing, the screen in its cover’s colours',
      'Android 0.2.10: Miarina Media’s Music home',
    ],
    dlTitle: 'Download Miarina Media',
    dlLead: 'Free, no ads, no account. The app sends no usage statistics and no crash reports.',
    dlWindowsReq: 'Windows 10 / 11 · 64-bit',
    dlAndroidReq: 'Android 7.0 or later · 64-bit (ARM)',
    dlSuggested: 'For this device',
    dlBetaReq: 'Windows 10 / 11 · 64-bit · new app, replaces 0.1.x',
    dlBetaBadge: 'Beta',
    dlAndroidBetaReq:
      'Android 7.0 or later · 64-bit (ARM) · player, downloads and browser, installs next to 0.1.11',
    dlWindowsCta: '.exe installer',
    dlAndroidCta: '.apk file',
    dlNote:
      'The Windows installer is not signed: SmartScreen may show a warning. Compare the SHA-256 fingerprint before installing.',
    verKicker: 'Release notes',
    verTitle: 'What changed, release by release.',
    verCurrent: 'Current',
    verBeta: 'Beta',
    verPlanned: 'Planned',
    verNext: 'Upcoming',
    verFrenchOnly: 'Release notes are written in French.',
    legal: 'Only download content you hold the rights to or whose licence allows it.',
    privacy: 'Privacy',
    licences: 'Licences',
  },
};

/** "Préversion de test · 13 novembre 2026" → "Test preview · 13 November 2026". */
export function englishDate(text: string): string {
  const months: Record<string, string> = {
    octobre: 'October',
    novembre: 'November',
    décembre: 'December',
  };
  return text
    .replace('Préversion de test', 'Test preview')
    .replace('Bêta', 'Beta')
    .replace('En préparation', 'In progress')
    .replace(
      /(\d+) (octobre|novembre|décembre) (\d+)/,
      (_, d: string, m: string, y: string) => `${d} ${months[m]} ${y}`,
    );
}

export const englishName = (name: string) =>
  name.replace('Windows et Android', 'Windows & Android');

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
    heroMeta: (w, a, b) =>
      `Windows ${w} · Android ${a} · préversions gratuites · Windows ${b} en bêta`,
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
            'Sous Windows, libVLC est fourni avec l’installateur : pistes audio, sous-titres SRT et VTT, vitesse, égaliseur à 6 bandes. Sous Android, la musique continue écran éteint, avec les commandes de l’écran verrouillé et du casque Bluetooth, et l’égaliseur du téléphone.',
          ],
          [
            'Vos fichiers aussi',
            'Sous Windows, ouvrez des fichiers, importez un dossier ou déposez-les sur la fenêtre. Sous Android, autorisez l’accès à la musique et aux vidéos du téléphone : elles rejoignent la bibliothèque, en lecture seule.',
          ],
        ],
      },
    ],
    beta: {
      kicker: 'Windows 0.2.4 · bêta',
      title: 'Une nouvelle application Windows, à essayer.',
      lead: 'La 0.2.0 refait toute l’application Windows. Elle s’installe par-dessus la 0.1.x, dans le même dossier : bibliothèque, playlists, favoris, reprises et réglages sont repris, avec une copie de sauvegarde de la bibliothèque avant sa mise à jour.',
      points: [
        [
          'Musique, Cinéma, Focus',
          'L’espace Écouter en trois sections : albums et artistes, films et séries, podcasts, cours et livres audio. L’accueil reprend où vous en étiez.',
        ],
        [
          'Une bibliothèque plus fine',
          'Tri, sélection multiple, filtres (jamais écoutés, hi-res), format affiché (FLAC 24/96), nombre d’écoutes, éditeur de tags et de pochettes.',
        ],
        [
          'En lecture',
          'Paroles synchronisées depuis un fichier .lrc, file enregistrable en playlist, égaliseur, vitesse, minuteur et mini-lecteur.',
        ],
        [
          'Ce qui change encore',
          'Nouveau depuis la 0.2.3 : téléchargement de playlists, touches multimédia, et le retour de l’extension pour Chrome et Edge. La 0.2.4 fiabilise les liens Facebook, Instagram et TikTok.',
        ],
      ],
      how: 'Depuis la 0.1.x : Réglages › Mises à jour, canal Bêta. Ou téléchargez l’installateur.',
      cta: 'Essayer la bêta',
    },
    libKicker: 'Bibliothèque et lecteur',
    libTitle: 'Tout ce que vous gardez, au même endroit.',
    libBody:
      'Les téléchargements vidéo et audio arrivent dans la bibliothèque, avec vos propres fichiers si vous les ajoutez. La musique se range par albums, artistes et dossiers, avec pochettes, playlists et favoris. Tout se lit hors ligne.',
    shots: [
      [
        'album',
        'Windows · Albums',
        'Windows 0.2.0 (bêta) : albums, artistes, titres, playlists et favoris, avec les pochettes des fichiers, des filtres et un éditeur de tags.',
      ],
      [
        'play_circle',
        'Windows · En lecture',
        'Windows 0.2.0 (bêta) : paroles synchronisées, file de lecture, égaliseur, vitesse et minuteur. La lecture reprend où vous l’aviez laissée.',
      ],
      [
        'android',
        'Android',
        'Sur Android, Miarina Media s’ouvre sur votre musique : titres, playlists, dossiers, artistes et albums. La lecture continue écran éteint ; les vidéos passent en plein écran paysage avec pistes, sous-titres et image dans l’image.',
      ],
    ],
    shotAlts: [
      'Bibliothèque musicale Windows 0.2.0 : albums d’œuvres libres avec leurs pochettes',
      'Lecteur Windows 0.2.0 : un concerto en lecture, avec sa pochette et la file de lecture',
      'Android : la musique de Miarina Media, titres et onglets',
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
      'Préversions. L’installateur Windows n’est pas signé : SmartScreen peut afficher un avertissement. Comparez l’empreinte SHA-256 avant d’installer.',
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
    heroMeta: (w, a, b) => `Windows ${w} · Android ${a} · free previews · Windows ${b} in beta`,
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
            'On Windows, libVLC ships with the installer: audio tracks, SRT and VTT subtitles, speed, 6-band equalizer. On Android, music keeps playing with the screen off, with lock-screen and Bluetooth headset controls and the phone’s equalizer.',
          ],
          [
            'Your files too',
            'On Windows, open files, import a folder or drop them on the window. On Android, allow access to the phone’s music and videos: they join the library, read-only.',
          ],
        ],
      },
    ],
    beta: {
      kicker: 'Windows 0.2.4 · beta',
      title: 'A new Windows app, ready to try.',
      lead: '0.2.0 rebuilds the whole Windows app. It installs over 0.1.x, in the same folder: library, playlists, favourites, resume points and settings carry over, and the library is backed up before it is upgraded.',
      points: [
        [
          'Music, Cinema, Focus',
          'The Listen space in three sections: albums and artists, films and series, podcasts, courses and audiobooks. Home picks up where you left off.',
        ],
        [
          'A finer library',
          'Sorting, multi-select, filters (never played, hi-res), format shown (FLAC 24/96), play counts, tag and cover editor.',
        ],
        [
          'Now playing',
          'Synced lyrics from a .lrc file, a queue you can save as a playlist, equalizer, speed, sleep timer and mini player.',
        ],
        [
          'Still changing',
          'New since 0.2.3: playlist downloads, media keys, and the Chrome and Edge extension is back. 0.2.4 makes Facebook, Instagram and TikTok links more reliable.',
        ],
      ],
      how: 'From 0.1.x: Settings › Updates, Beta channel. Or download the installer.',
      cta: 'Try the beta',
    },
    libKicker: 'Library and player',
    libTitle: 'Everything you keep, in one place.',
    libBody:
      'Video and audio downloads land in the library, along with your own files if you add them. Music is sorted by album, artist and folder, with cover art, playlists and favourites. Everything plays offline.',
    shots: [
      [
        'album',
        'Windows · Albums',
        'Windows 0.2.0 (beta): albums, artists, songs, playlists and favourites, with the files’ cover art, filters and a tag editor.',
      ],
      [
        'play_circle',
        'Windows · Now playing',
        'Windows 0.2.0 (beta): synced lyrics, play queue, equalizer, speed and sleep timer. Playback resumes where you left off.',
      ],
      [
        'android',
        'Android',
        'On Android, Miarina Media opens on your music: songs, playlists, folders, artists and albums. Playback continues with the screen off; videos go full-screen landscape with tracks, subtitles and picture-in-picture.',
      ],
    ],
    shotAlts: [
      'Windows 0.2.0 music library: albums of freely licensed works with their covers',
      'Windows 0.2.0 player: a concerto playing, with its cover and the play queue',
      'Android: Miarina Media’s music, songs and tabs',
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
      'Previews. The Windows installer is not signed: SmartScreen may show a warning. Compare the SHA-256 fingerprint before installing.',
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

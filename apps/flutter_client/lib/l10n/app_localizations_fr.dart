// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Miarina Media';

  @override
  String get spaceGet => 'Obtenir';

  @override
  String get spaceListen => 'Écouter';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSectionMusic => 'Musique';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artistes';

  @override
  String get navTracks => 'Titres';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navSectionCinema => 'Cinéma';

  @override
  String get navMovies => 'Films & séries';

  @override
  String get navPersonalVideos => 'Vidéos perso';

  @override
  String get navSectionFocus => 'Focus';

  @override
  String get navPodcasts => 'Podcasts & cours';

  @override
  String get navAudiobooks => 'Livres audio';

  @override
  String get navSettings => 'Réglages';

  @override
  String get tabMusic => 'Musique';

  @override
  String get tabCinema => 'Cinéma';

  @override
  String get tabFocus => 'Focus';

  @override
  String get tabGet => 'Obtenir';

  @override
  String get searchPlaceholder => 'Rechercher titres, films, podcasts…';

  @override
  String get play => 'Lecture';

  @override
  String get pause => 'Pause';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get shuffle => 'Aléatoire';

  @override
  String get repeatOff => 'Répéter : non';

  @override
  String get repeatAll => 'Répéter : tout';

  @override
  String get repeatOne => 'Répéter : ce titre';

  @override
  String get lyrics => 'Paroles';

  @override
  String get queue => 'File d\'attente';

  @override
  String get miniPlayer => 'Mini-lecteur (Ctrl M)';

  @override
  String get volume => 'Volume';

  @override
  String get mute => 'Couper le son';

  @override
  String get unmute => 'Rétablir le son';

  @override
  String get favoriteAdd => 'Ajouter aux favoris';

  @override
  String get favoriteRemove => 'Retirer des favoris';

  @override
  String get seek => 'Position de lecture';

  @override
  String get nothingPlaying => 'Rien en lecture';

  @override
  String get openNowPlaying => 'Ouvrir En lecture';

  @override
  String get windowMinimize => 'Réduire';

  @override
  String get windowMaximize => 'Agrandir';

  @override
  String get windowRestore => 'Restaurer';

  @override
  String get windowClose => 'Fermer';

  @override
  String get comingSoonTitle => 'Cet écran arrive bientôt';

  @override
  String get comingSoonBody =>
      'Il sera construit d\'après la maquette validée, dans un prochain lot. Rien n\'est simulé en attendant.';

  @override
  String tracksSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
      zero: 'Aucun titre',
    );
    return '$_temp0';
  }

  @override
  String get tracksEmptyTitle => 'Aucun titre pour l\'instant';

  @override
  String get tracksEmptyBody =>
      'Ajoutez un dossier de musique ou téléchargez un titre depuis Obtenir.';

  @override
  String get colTitle => 'Titre';

  @override
  String get colArtist => 'Artiste';

  @override
  String get colAlbum => 'Album';

  @override
  String get colFormat => 'Format';

  @override
  String get colDuration => 'Durée';

  @override
  String get fileMissing => 'Fichier introuvable';

  @override
  String get libraryError => 'La bibliothèque n\'a pas pu être lue.';

  @override
  String get retry => 'Réessayer';

  @override
  String get playbackUnsupported =>
      'La lecture n\'est pas encore disponible sur cette plateforme.';

  @override
  String get unknownArtist => 'Artiste inconnu';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterTracks => 'Filtrer les titres';

  @override
  String get playAll => 'Tout lire';

  @override
  String get comingSoonShort => 'Bientôt disponible';

  @override
  String get nowPlaying => 'En lecture';

  @override
  String get back => 'Retour';

  @override
  String get tabQueue => 'File';

  @override
  String get tabSound => 'Son';

  @override
  String get nowCurrent => 'En cours';

  @override
  String get upNext => 'À suivre';

  @override
  String get clearQueue => 'Vider';

  @override
  String get smartQueueTitle => 'Continuer avec des titres proches';

  @override
  String get smartQueueBody => 'Smart Queue, calculée sur l\'appareil';

  @override
  String lyricsHint(String file) {
    return '$file · clic sur une ligne pour y aller';
  }

  @override
  String get lyricsNoneTitle => 'Pas de paroles pour ce titre';

  @override
  String get lyricsNoneBody =>
      'Placez un fichier .lrc du même nom à côté du fichier audio : il sera lu automatiquement.';

  @override
  String get equalizer => 'Égaliseur';

  @override
  String get equalizerBody => 'Appliqué à toute la lecture audio';

  @override
  String get equalizerUnsupported =>
      'Cet appareil ne propose pas d\'égaliseur pour la lecture.';

  @override
  String get eqFlat => 'Neutre';

  @override
  String get eqBass => 'Basses';

  @override
  String get eqVoice => 'Voix';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassic => 'Classique';

  @override
  String get eqCustom => 'Personnalisé';

  @override
  String get speed => 'Vitesse';

  @override
  String get normalization => 'Normalisation du volume';

  @override
  String get normalizationBody => 'ReplayGain si présent';

  @override
  String get sleepTimer => 'Minuteur';

  @override
  String sleepMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get sleepEndOfTrack => 'Fin du titre';

  @override
  String get sleepOff => 'Désactiver le minuteur';

  @override
  String sleepRemaining(String time) {
    return 'Arrêt dans $time';
  }

  @override
  String get upNextEmpty => 'Rien après ce titre.';

  @override
  String get removeFromQueue => 'Retirer de la file';

  @override
  String get closePlayer => 'Réduire le lecteur';

  @override
  String get showLyrics => 'Afficher les paroles';

  @override
  String get showCover => 'Afficher la pochette';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String albumsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
      zero: 'Aucun album',
    );
    return '$_temp0';
  }

  @override
  String artistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artistes',
      one: '1 artiste',
      zero: 'Aucun artiste',
    );
    return '$_temp0';
  }

  @override
  String get artistsGrouping =>
      'regroupés selon le tag « Artiste de l\'album »';

  @override
  String get albumsEmptyTitle => 'Pas encore d\'album';

  @override
  String get albumsEmptyBody =>
      'Les albums viennent des tags des fichiers (album, artiste). Aucun titre de la bibliothèque n\'en a pour l\'instant.';

  @override
  String get artistsEmptyTitle => 'Pas encore d\'artiste';

  @override
  String get artistsEmptyBody =>
      'Les artistes viennent des tags des fichiers. Aucun titre de la bibliothèque n\'en a pour l\'instant.';

  @override
  String get albumOverline => 'Album';

  @override
  String get albumTracks => 'Titres de l\'album';

  @override
  String get artistTracks => 'Titres';

  @override
  String get groupMissing => 'Cet élément n\'est plus dans la bibliothèque.';

  @override
  String get playVerb => 'Lire';

  @override
  String get homeResume => 'Reprendre';

  @override
  String homeResumeKind(String kind) {
    return 'Reprendre · $kind';
  }

  @override
  String homeResumeAt(String time) {
    return 'Reprendre à $time';
  }

  @override
  String minutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min restantes',
      one: '1 min restante',
      zero: 'moins d\'une minute restante',
    );
    return '$_temp0';
  }

  @override
  String get openAlbum => 'Voir l\'album';

  @override
  String get autoLists => 'Vos listes automatiques';

  @override
  String get listMostPlayed => 'Écoutés souvent';

  @override
  String get listRecentlyAdded => 'Ajoutés récemment';

  @override
  String get listRecentlyAddedBody =>
      'Les derniers titres arrivés dans la bibliothèque';

  @override
  String get listFavoritesBody => 'Vos titres favoris';

  @override
  String andOthers(String names, int count) {
    return '$names et $count autres';
  }

  @override
  String get fullQueue => 'File complète';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get recentAlbums => 'Albums récents';

  @override
  String get homeEmptyTitle => 'Votre espace d\'écoute est prêt';

  @override
  String get homeEmptyBody =>
      'Rien n\'a encore été écouté et la bibliothèque est vide. Ajoutez de la musique depuis Obtenir, ou ouvrez un fichier.';

  @override
  String get goTracks => 'Voir les titres';

  @override
  String get goGet => 'Obtenir de la musique';

  @override
  String get nowPlayingHint =>
      'Lancez un titre : il apparaîtra ici, avec ses paroles et la suite de la file.';

  @override
  String filmsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count films',
      one: '1 film',
      zero: 'aucun film',
    );
    return '$_temp0';
  }

  @override
  String seriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
      zero: 'aucune série',
    );
    return '$_temp0';
  }

  @override
  String videosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '1 vidéo',
      zero: 'aucune vidéo',
    );
    return '$_temp0';
  }

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saisons',
      one: '1 saison',
    );
    return '$_temp0';
  }

  @override
  String get segAll => 'Tout';

  @override
  String get segFilms => 'Films';

  @override
  String get segSeries => 'Séries';

  @override
  String get sortBy => 'Trier';

  @override
  String get sortTitle => 'Titre';

  @override
  String get sortAdded => 'Ajout récent';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get kindFilm => 'Film';

  @override
  String get kindPersonal => 'Vidéo perso';

  @override
  String resumeAtShort(String time) {
    return 'reprendre à $time';
  }

  @override
  String episodeShort(int season, int episode) {
    return 'S$season É$episode';
  }

  @override
  String episodeLabel(int episode, String title) {
    return 'É$episode · $title';
  }

  @override
  String episodeNumber(int episode) {
    return 'Épisode $episode';
  }

  @override
  String get cinemaEmptyTitle => 'Aucun film ni série pour l\'instant';

  @override
  String get cinemaEmptyBody =>
      'Les vidéos de 40 minutes ou plus apparaissent ici comme films. Les fichiers nommés comme S01E04, ou avec le tag Série, forment des séries.';

  @override
  String get cinemaNoMatch => 'Rien dans cette catégorie pour l\'instant.';

  @override
  String get personalEmptyTitle => 'Aucune vidéo perso';

  @override
  String get personalEmptyBody =>
      'Les vidéos courtes de la bibliothèque (clips, vidéos du téléphone) apparaissent ici.';

  @override
  String get seriesWord => 'Série';

  @override
  String get seriesMissing => 'Cette série n\'est plus dans la bibliothèque.';

  @override
  String resumeEpisode(int season, int episode, String time) {
    return 'Reprendre S$season · É$episode à $time';
  }

  @override
  String playEpisode(int season, int episode) {
    return 'Lire S$season · É$episode';
  }

  @override
  String get fromStart => 'Depuis le début';

  @override
  String seasonNumber(int season) {
    return 'Saison $season';
  }

  @override
  String seenOf(int seen, int total) {
    return '$seen vus sur $total';
  }

  @override
  String get watched => 'Vu';

  @override
  String resumeAtLeft(String time, String left) {
    return 'Reprendre à $time · $left';
  }

  @override
  String subtitlesLangs(String langs) {
    return 'Sous-titres $langs';
  }

  @override
  String get subtitles => 'Sous-titres';

  @override
  String get subtitlesOff => 'Désactivés';

  @override
  String get subtitlesLoad => 'Charger un fichier SRT / VTT / ASS…';

  @override
  String get subtitlesExternal => 'externe';

  @override
  String get audioTrack => 'Piste audio';

  @override
  String get noTracks => 'Aucune autre piste dans ce fichier';

  @override
  String get replay10 => 'Reculer de 10 s';

  @override
  String get forward10 => 'Avancer de 10 s';

  @override
  String get fullscreen => 'Plein écran (F)';

  @override
  String get fullscreenExit => 'Quitter le plein écran (Échap)';

  @override
  String get chapters => 'Chapitres';

  @override
  String get chaptersSoon => 'Les chapitres du fichier s\'afficheront ici.';

  @override
  String get nextEpisode => 'Épisode suivant';

  @override
  String get autoNext => 'Lecture auto à la fin';

  @override
  String get videoLoading => 'Ouverture de la vidéo…';

  @override
  String get videoUnavailable => 'Aucune vidéo en cours';

  @override
  String podcastsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts',
      one: '1 podcast',
      zero: 'aucun podcast',
    );
    return '$_temp0';
  }

  @override
  String coursesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cours',
      one: '1 cours',
      zero: 'aucun cours',
    );
    return '$_temp0';
  }

  @override
  String audiobooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livres audio',
      one: '1 livre audio',
      zero: 'aucun livre audio',
    );
    return '$_temp0';
  }

  @override
  String hoursTotal(int hours) {
    return '$hours h';
  }

  @override
  String get segPodcasts => 'Podcasts';

  @override
  String get segCourses => 'Cours';

  @override
  String get segBooks => 'Livres audio';

  @override
  String get focusInProgress => 'En cours';

  @override
  String get focusLibrary => 'Bibliothèque';

  @override
  String get kindPodcast => 'Podcast';

  @override
  String get kindCourse => 'Cours';

  @override
  String get kindAudiobook => 'Livre audio';

  @override
  String episodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count épisodes',
      one: '1 épisode',
    );
    return '$_temp0';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count leçons',
      one: '1 leçon',
    );
    return '$_temp0';
  }

  @override
  String partsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parties',
      one: '1 partie',
    );
    return '$_temp0';
  }

  @override
  String leftAtRate(String left, String rate) {
    return 'reste $left à $rate';
  }

  @override
  String get focusOrderHint =>
      'Ordre lu depuis les numéros des fichiers (01, 02…) ou les tags.';

  @override
  String get focusEmptyTitle => 'Aucun podcast, cours ou livre audio';

  @override
  String get focusEmptyBody =>
      'Un fichier audio rejoint Focus par son genre (Podcast, Cours, Livre audio), par un dossier nommé Podcasts, Cours ou Livres audio, ou s\'il est au format .m4b.';

  @override
  String get focusNoMatch => 'Rien dans cette catégorie pour l\'instant.';

  @override
  String programPosition(String kind, int number, int total) {
    return '$kind $number sur $total';
  }

  @override
  String estimatedEnd(String time, String rate) {
    return 'Fin estimée $time à $rate';
  }

  @override
  String get forward30 => 'Avancer de 30 s';

  @override
  String get bookmark => 'Signet';

  @override
  String get bookmarkAdd => 'Ajouter un signet (B)';

  @override
  String get bookmarks => 'Signets';

  @override
  String get bookmarkNoNote => 'Signet sans note';

  @override
  String get bookmarksEmpty => 'Aucun signet pour l\'instant.';

  @override
  String get bookmarksHint => 'B ajoute un signet à la position courante.';

  @override
  String get bookmarkRemove => 'Supprimer le signet';

  @override
  String get chaptersNone => 'Ce fichier n\'a pas de chapitres.';

  @override
  String get transcript => 'Texte';

  @override
  String get futureBadge => 'FUTUR';

  @override
  String get transcriptTitle => 'Transcription — fonction future';

  @override
  String get transcriptBody =>
      'Un fichier .txt ou .vtt du même nom placé à côté du fichier est affiché ici. La génération locale et la recherche dans les transcriptions viendront plus tard.';

  @override
  String get sleepEndOfChapter => 'Minuteur : fin du chapitre';

  @override
  String get sleepEndOfEpisode => 'Minuteur : fin du fichier';

  @override
  String get skipSilence => 'Sauter les silences';

  @override
  String get voiceBoost => 'Voix renforcée';

  @override
  String get p1Later => 'pour les deux dernières';

  @override
  String get navHistory => 'Historique';

  @override
  String get historySubtitle =>
      'Lectures et positions, conservées sur cet appareil';

  @override
  String get historyClear => 'Effacer l\'historique…';

  @override
  String get historyClearTitle => 'Effacer l\'historique ?';

  @override
  String get historyClearBody =>
      'Les lectures listées ici sont oubliées. Aucun fichier, favori ni point de reprise n\'est supprimé.';

  @override
  String get cancel => 'Annuler';

  @override
  String get clear => 'Effacer';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String positionOf(String position, String total) {
    return '$position sur $total';
  }

  @override
  String get finished => 'Terminé';

  @override
  String get replay => 'Revoir';

  @override
  String get historyEmptyTitle => 'Aucune lecture pour l\'instant';

  @override
  String get historyEmptyBody =>
      'Ce que vous écoutez et regardez apparaîtra ici, avec la position où vous vous êtes arrêté.';

  @override
  String searchTitle(String query) {
    return '« $query »';
  }

  @override
  String searchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
      zero: 'aucun résultat',
    );
    return '$_temp0 dans la bibliothèque locale';
  }

  @override
  String get bestResult => 'Meilleur résultat';

  @override
  String seeAllCount(int count) {
    return 'Tout voir ($count)';
  }

  @override
  String get searchTranscripts => 'Recherche dans les transcriptions';

  @override
  String searchEmptyTitle(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get searchEmptyBody =>
      'La recherche ne tient pas compte des accents et trouve le début des mots. Essayez un autre mot.';

  @override
  String get searchHint => 'Tapez un titre, un artiste, un film ou un podcast.';

  @override
  String get kindTrack => 'Titre';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindArtist => 'Artiste';

  @override
  String get searchClear => 'Effacer la recherche';

  @override
  String get setGeneral => 'Général';

  @override
  String get setAppearance => 'Apparence';

  @override
  String get setPlayback => 'Lecture';

  @override
  String get setLibrary => 'Bibliothèque';

  @override
  String get setShortcuts => 'Raccourcis';

  @override
  String get setData => 'Données et sauvegarde';

  @override
  String get setAbout => 'À propos';

  @override
  String get language => 'Langue';

  @override
  String get languageBody => 'Langue de l\'interface';

  @override
  String get languageSystem => 'Système';

  @override
  String get theme => 'Thème';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeSystem => 'Système';

  @override
  String get playColor => 'Couleur de lecture';

  @override
  String get colorCoral => 'Corail';

  @override
  String get colorRose => 'Rose';

  @override
  String get colorAmber => 'Ambre';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get density => 'Densité';

  @override
  String get densityBody => 'Compacte : lignes de 40 px dans les listes';

  @override
  String get densityComfortable => 'Confortable';

  @override
  String get densityCompact => 'Compacte';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get textSizeBody => '90 à 130 %';

  @override
  String get reduceMotion => 'Réduire les animations';

  @override
  String get reduceMotionBody => 'Suit le réglage Windows par défaut';

  @override
  String get reduceTransparency => 'Réduire la transparence';

  @override
  String get reduceTransparencyBody => 'Surfaces opaques partout';

  @override
  String get coverBackdrop => 'Pochette en fond dans En lecture';

  @override
  String get coverBackdropBody => 'Flou de la pochette derrière le lecteur';

  @override
  String get engineSection => 'Moteur et sortie';

  @override
  String get engine => 'Moteur de lecture';

  @override
  String get engineBodyWindows =>
      'libmpv intégré, décodage matériel avec repli';

  @override
  String get engineBodyAndroid => 'Media3, le lecteur d\'Android';

  @override
  String get engineValue => 'Intégré (recommandé)';

  @override
  String get audioOutput => 'Sortie audio';

  @override
  String get audioOutputBody => 'Périphérique utilisé par Miarina';

  @override
  String get systemDefault => 'Système par défaut';

  @override
  String get exclusive => 'Mode exclusif WASAPI';

  @override
  String get exclusiveBody => 'Pour les DAC externes, coupe les autres sons';

  @override
  String get chainSection => 'Enchaînement';

  @override
  String get resumeSetting => 'Reprendre où j\'en étais';

  @override
  String get resumeSettingBody => 'Audio et vidéo, au démarrage';

  @override
  String get gapless => 'Lecture sans blanc (gapless)';

  @override
  String get gaplessBody => 'Albums live et mixés';

  @override
  String get crossfade => 'Fondu entre les titres';

  @override
  String get crossfadeBody => '0 à 12 s';

  @override
  String get off => 'Désactivé';

  @override
  String get normalizationSetting => 'Normalisation du volume';

  @override
  String get normalizationSettingBody => 'ReplayGain si présent';

  @override
  String get videoSection => 'Vidéo';

  @override
  String get defaultSubtitles => 'Sous-titres par défaut';

  @override
  String get defaultSubtitlesBody => 'Langue préférée, sinon aucun';

  @override
  String get none => 'Aucun';

  @override
  String get sidecar => 'Charger les sous-titres à côté du fichier';

  @override
  String get sidecarBody => '.srt, .vtt, .ass du même nom';

  @override
  String get p1Badge => 'P1';

  @override
  String get keyPlayPause => 'Lecture / pause';

  @override
  String get keyPrevious => 'Titre précédent';

  @override
  String get keyNext => 'Titre suivant';

  @override
  String get keySeekBack => 'Reculer de 10 s';

  @override
  String get keySeekForward => 'Avancer de 10 s';

  @override
  String get keyVolumeUp => 'Monter le volume';

  @override
  String get keyVolumeDown => 'Baisser le volume';

  @override
  String get keyMute => 'Couper le son';

  @override
  String get keySearch => 'Rechercher';

  @override
  String get keyBack => 'Retour';

  @override
  String get keyForward => 'Avant';

  @override
  String get keyToggleSidebar => 'Replier la barre latérale';

  @override
  String get keyNowPlaying => 'En lecture';

  @override
  String get keyFullscreen => 'Plein écran';

  @override
  String get keySubtitles => 'Sous-titres';

  @override
  String get keyAudioTrack => 'Piste audio';

  @override
  String get keyFrameStep => 'Image suivante (pause)';

  @override
  String get keyBookmark => 'Ajouter un signet';

  @override
  String get keyLyrics => 'Paroles';

  @override
  String get keyMiniPlayer => 'Mini-lecteur';

  @override
  String get keySpeedDown => 'Vitesse −';

  @override
  String get keySpeedUp => 'Vitesse +';

  @override
  String get keysPlayback => 'Lecture';

  @override
  String get keysNavigation => 'Navigation';

  @override
  String get keysVideo => 'Vidéo';

  @override
  String get keysFocus => 'Focus et fenêtres';

  @override
  String get keysTitle => 'Raccourcis clavier';

  @override
  String get keysSearch => 'Rechercher un raccourci';

  @override
  String get keysReset => 'Rétablir les valeurs';

  @override
  String get keysHint =>
      'Cliquez sur une touche pour la modifier ; un conflit est signalé avant d\'être enregistré. Échap annule.';

  @override
  String get keyPress => 'Appuyez sur une touche…';

  @override
  String get keyNone => 'Aucune';

  @override
  String get keyShift => 'Maj';

  @override
  String get keySpace => 'Espace';

  @override
  String keyConflict(String key, String action) {
    return '$key est déjà utilisé par « $action ».';
  }

  @override
  String get keyReplace => 'Remplacer';

  @override
  String get keyRemove => 'Retirer la touche';

  @override
  String get libraryTracks => 'Titres audio';

  @override
  String get libraryVideos => 'Vidéos';

  @override
  String get dataFolder => 'Dossier des données';

  @override
  String get dataFolderBody => 'Base de la bibliothèque, réglages et pochettes';

  @override
  String get openFolder => 'Ouvrir le dossier';

  @override
  String get playHistory => 'Historique de lecture';

  @override
  String get playHistoryBody =>
      'Lectures et positions affichées dans Historique';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutDevBuild => 'Version de développement';

  @override
  String get aboutLicense => 'Licence';

  @override
  String get aboutLicenses => 'Licences des composants';

  @override
  String get aboutLicensesBody => 'Polices, icônes et bibliothèques intégrées';

  @override
  String get show => 'Afficher';

  @override
  String get aboutLocal =>
      'Tout reste sur cet appareil : pas de compte, pas d\'envoi de données.';
}

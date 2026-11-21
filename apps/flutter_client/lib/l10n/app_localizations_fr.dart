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
  String get bookmarksHint =>
      'B ajoute un signet à la position courante. Exportables en texte avec le cours.';

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
  String get audioOutputBody => 'Périphérique utilisé par Miarina Media';

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

  @override
  String get aboutCompanyBody =>
      'Miarina Media fait partie de l\'écosystème Miarina.';

  @override
  String get aboutDeveloper => 'Développeur';

  @override
  String get playlistNew => 'Nouvelle';

  @override
  String get playlistImport => 'Importer M3U';

  @override
  String get playlistExport => 'Exporter';

  @override
  String playlistModified(String when) {
    return 'Playlist · modifiée $when';
  }

  @override
  String get agoNow => 'à l\'instant';

  @override
  String agoMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String agoHours(int count) {
    return 'il y a $count h';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'hier',
    );
    return '$_temp0';
  }

  @override
  String titlesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
      zero: 'aucun titre',
    );
    return '$_temp0';
  }

  @override
  String missingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres introuvables',
      one: '1 titre introuvable',
    );
    return '$_temp0';
  }

  @override
  String get addTracks => 'Ajouter des titres';

  @override
  String get playlistHint =>
      'Glisser pour réordonner · Alt+↑/↓ au clavier · Suppr retire de la playlist (le fichier reste)';

  @override
  String get newPlaylistTitle => 'Nouvelle playlist';

  @override
  String get playlistName => 'Nom';

  @override
  String addQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter les $count titres de la file d\'attente',
      one: 'Ajouter le titre de la file d\'attente',
    );
    return '$_temp0';
  }

  @override
  String get smartPlaylist => 'Playlist intelligente (règles)';

  @override
  String get create => 'Créer';

  @override
  String get rename => 'Renommer';

  @override
  String get save => 'Enregistrer';

  @override
  String get deletePlaylist => 'Supprimer la playlist';

  @override
  String deletePlaylistTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deletePlaylistBody =>
      'La playlist est supprimée. Les fichiers restent dans la bibliothèque.';

  @override
  String get delete => 'Supprimer';

  @override
  String importDone(String name, int added, int skipped) {
    return '« $name » : $added titres ajoutés, $skipped introuvables ou en ligne.';
  }

  @override
  String exportDone(String path) {
    return 'Playlist enregistrée : $path';
  }

  @override
  String get playlistsEmptyTitle => 'Aucune playlist';

  @override
  String get playlistsEmptyBody =>
      'Créez une playlist ou importez un fichier M3U.';

  @override
  String get playlistEmpty => 'Cette playlist est vide. Ajoutez des titres.';

  @override
  String get addedShort => 'Ajouté';

  @override
  String get removeFromPlaylist => 'Retirer de la playlist';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get playlistFileType => 'Playlist M3U';

  @override
  String playlistActionFailed(String error) {
    return 'L\'opération n\'a pas abouti : $error';
  }

  @override
  String get close => 'Fermer';

  @override
  String get emptyOpenFiles => 'Ouvrir des fichiers…';

  @override
  String get emptyFormats =>
      'Formats lus : MP3, M4A, FLAC, OGG, Opus, WAV, AAC, et en vidéo MP4, MKV, WebM, MOV, AVI.';

  @override
  String get emptyNote =>
      'Vous téléchargez avec Miarina Media ? Les fichiers obtenus arrivent ici automatiquement.';

  @override
  String get mediaFiles => 'Fichiers audio et vidéo';

  @override
  String get errFormatTitle => 'Format non pris en charge';

  @override
  String get errFormatBody =>
      'Le moteur ne sait pas décoder ce fichier. Le fichier n\'est pas modifié.';

  @override
  String get errDamagedTitle => 'Fichier endommagé';

  @override
  String get errDamagedBody =>
      'La lecture s\'est arrêtée : une partie du fichier semble illisible. Le fichier n\'est pas modifié.';

  @override
  String get errAccessTitle => 'Accès refusé';

  @override
  String get errAccessBody =>
      'Le système ne laisse pas Miarina Media lire ce fichier. Les autres fichiers fonctionnent.';

  @override
  String get errMissingTitle => 'Fichier introuvable';

  @override
  String get errMissingBody =>
      'Le fichier a été déplacé, renommé, ou son disque est débranché. Il garde sa place dans la bibliothèque.';

  @override
  String get errPlaybackTitle => 'Lecture impossible';

  @override
  String get errPlaybackBody =>
      'Ce fichier n\'a pas pu être lu. Rien n\'a été modifié.';

  @override
  String get errLibraryRepairTitle => 'Bibliothèque à réparer';

  @override
  String get errLibraryRepairBody =>
      'L\'index de la bibliothèque n\'a pas pu s\'ouvrir. Vos fichiers ne sont pas touchés.';

  @override
  String get errLibraryTitle => 'La bibliothèque ne s\'ouvre pas';

  @override
  String get errLibraryBody =>
      'Rien n\'a été modifié. Réessayez ; si cela continue, copiez les détails pour le support.';

  @override
  String get copyDetails => 'Copier les détails';

  @override
  String get detailsCopied => 'Détails copiés';

  @override
  String get skipNext => 'Passer au suivant';

  @override
  String get welcomeHeadline =>
      'Votre musique, vos films et vos cours, au même endroit.';

  @override
  String get welcomeLocal =>
      'Tout reste sur cet ordinateur. Aucun compte, aucune donnée envoyée.';

  @override
  String get welcomeFoot =>
      'Lecture locale, sans télémétrie. Modifiable plus tard dans Réglages.';

  @override
  String get stepAppearance => 'Langue et apparence';

  @override
  String get stepFolders => 'Dossiers';

  @override
  String get stepScan => 'Analyse';

  @override
  String get skip => 'Passer';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get analyse => 'Analyser';

  @override
  String get themeFollow => 'Suivre Windows';

  @override
  String get foldersTitle => 'Où sont vos fichiers ?';

  @override
  String get foldersBody =>
      'Miarina Media lit ces dossiers sans les modifier ni les déplacer. Les nouveaux fichiers apparaissent à chaque lancement.';

  @override
  String folderFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers audio ou vidéo',
      one: '1 fichier audio ou vidéo',
      zero: 'aucun fichier audio ou vidéo',
    );
    return '$_temp0';
  }

  @override
  String get kindVideo => 'Vidéo';

  @override
  String get addFolder => 'Ajouter un dossier…';

  @override
  String foldersSummary(int folders, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders dossiers',
      one: '1 dossier',
      zero: 'aucun dossier',
    );
    return '$_temp0 · environ $files fichiers';
  }

  @override
  String get removeFolder => 'Retirer ce dossier';

  @override
  String get scanTitle => 'Analyse de votre bibliothèque';

  @override
  String get scanBody =>
      'Vous pouvez commencer à écouter : l\'analyse continue en arrière-plan.';

  @override
  String scanProgress(int done, int total) {
    return '$done fichiers sur environ $total';
  }

  @override
  String get statTracks => 'titres';

  @override
  String get statAlbums => 'albums';

  @override
  String get statVideos => 'vidéos';

  @override
  String get statUnreadable => 'illisibles';

  @override
  String get readyNow => 'Déjà prêts';

  @override
  String get scanEco =>
      'Analyse en arrière-plan, un fichier à la fois (mode éco).';

  @override
  String get scanNoFfmpeg =>
      'FFmpeg n\'est pas installé à côté de l\'application : titres, artistes et albums sont lus ; durées et vignettes le seront quand il le sera.';

  @override
  String get startListening => 'Commencer à écouter';

  @override
  String get libraryFolders => 'Dossiers suivis';

  @override
  String get libraryFoldersBody =>
      'Analysés à chaque lancement ; rien n\'est modifié ni déplacé.';

  @override
  String get scanNow => 'Analyser maintenant';

  @override
  String get scanDone => 'Analyse terminée';

  @override
  String scanRunning(int done, int total) {
    return '$done sur $total analysés';
  }

  @override
  String get noFolders => 'Aucun dossier suivi pour l\'instant.';

  @override
  String get navSectionLibrary => 'Bibliothèque';

  @override
  String get navMissing => 'Introuvables';

  @override
  String get navDuplicates => 'Doublons';

  @override
  String get healthGroup => 'État de la bibliothèque';

  @override
  String get missingTitle => 'Fichiers introuvables';

  @override
  String missingSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments n\'ont pas été trouvés au dernier passage. Rien n\'a été supprimé.',
      one: '1 élément n\'a pas été trouvé au dernier passage. Rien n\'a été supprimé.',
    );
    return '$_temp0';
  }

  @override
  String missingVolumeTitle(String volume) {
    return 'Disque $volume déconnecté';
  }

  @override
  String missingVolumeBody(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments de $folder. Ils réapparaîtront au branchement.',
      one: '1 élément de $folder. Il réapparaîtra au branchement.',
    );
    return '$_temp0';
  }

  @override
  String get missingMovedTitle => 'Dossier probablement renommé';

  @override
  String missingMovedBody(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fichiers retrouvés dans $folder, avec le même nom et la même taille.',
      one:
          '1 fichier retrouvé dans $folder, avec le même nom et la même taille.',
    );
    return '$_temp0';
  }

  @override
  String missingLostTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers introuvables',
      one: '1 fichier introuvable',
    );
    return '$_temp0';
  }

  @override
  String missingLostBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aucune correspondance trouvée. Ils ont peut-être été supprimés.',
      one: 'Aucune correspondance trouvée. Il a peut-être été supprimé.',
    );
    return '$_temp0';
  }

  @override
  String get missingRelocate => 'Relocaliser…';

  @override
  String get missingHide => 'Masquer';

  @override
  String get missingUpdatePaths => 'Mettre à jour les chemins';

  @override
  String get missingIgnore => 'Ignorer';

  @override
  String get missingLocate => 'Localiser…';

  @override
  String get missingSearchFolder => 'Chercher dans un dossier…';

  @override
  String get missingRemove => 'Retirer de la bibliothèque';

  @override
  String get missingStatusVolume => 'disque absent';

  @override
  String get missingStatusFound => '→ trouvé';

  @override
  String get missingStatusLost => 'introuvable';

  @override
  String missingMore(int count) {
    return 'et $count autres';
  }

  @override
  String missingHiddenGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes masqués',
      one: '1 groupe masqué',
    );
    return '$_temp0';
  }

  @override
  String get missingShowAll => 'Tout afficher';

  @override
  String get missingEmptyTitle => 'Tous vos fichiers sont là';

  @override
  String get missingEmptyBody =>
      'Les fichiers déplacés ou rangés sur un disque débranché apparaîtront ici. Rien n\'est jamais supprimé automatiquement.';

  @override
  String missingPathsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chemins mis à jour',
      one: '1 chemin mis à jour',
      zero: 'Aucun chemin mis à jour',
    );
    return '$_temp0';
  }

  @override
  String missingFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers retrouvés',
      one: '1 fichier retrouvé',
      zero: 'Aucun fichier retrouvé',
    );
    return '$_temp0';
  }

  @override
  String missingLeftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count toujours introuvables',
      one: '1 toujours introuvable',
    );
    return '$_temp0';
  }

  @override
  String missingRemoveTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirer ces $count fichiers de la bibliothèque ?',
      one: 'Retirer ce fichier de la bibliothèque ?',
    );
    return '$_temp0';
  }

  @override
  String get missingRemoveBody =>
      'Ils quittent la bibliothèque, les playlists et la reprise de lecture. Aucun fichier n\'est supprimé du disque : s\'ils réapparaissent, ouvrez-les pour les ajouter à nouveau.';

  @override
  String get remove => 'Retirer';

  @override
  String missingSkipped(String title) {
    return '« $title » est introuvable, titre suivant';
  }

  @override
  String missingSkippedLast(String title) {
    return '« $title » est introuvable';
  }

  @override
  String get locate => 'Localiser';

  @override
  String get fileLocated => 'Fichier retrouvé';

  @override
  String get locateFailed =>
      'Ce fichier ne peut pas être utilisé à la place de l\'original.';

  @override
  String get duplicatesTitle => 'Doublons';

  @override
  String duplicatesSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count groupes · $size récupérables · même titre, même artiste, même durée',
      one:
          '1 groupe · $size récupérables · même titre, même artiste, même durée',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesKeepBest => 'Garder la meilleure qualité partout';

  @override
  String duplicateVersions(int count) {
    return '$count versions';
  }

  @override
  String get duplicateKeep => 'Garder';

  @override
  String get duplicateHide => 'Masquer';

  @override
  String get duplicateTrash => 'Mettre à la Corbeille…';

  @override
  String get duplicatesNote =>
      'Par défaut, les doublons sont seulement masqués de la bibliothèque : le fichier reste sur le disque. La suppression va dans la Corbeille Windows.';

  @override
  String duplicatesHideAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Masquer les $count doublons',
      one: 'Masquer le doublon',
    );
    return '$_temp0';
  }

  @override
  String duplicatesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count doublons masqués, leurs playlists passent à la version gardée',
      one: '1 doublon masqué, ses playlists passent à la version gardée',
    );
    return '$_temp0';
  }

  @override
  String get duplicateTrashTitle => 'Mettre ce fichier à la Corbeille ?';

  @override
  String get duplicateTrashBody =>
      'Ses playlists et son favori passent à la version gardée. Vous pourrez le récupérer depuis la Corbeille Windows.';

  @override
  String get duplicateTrashed => 'Fichier mis à la Corbeille';

  @override
  String get duplicatesEmptyTitle => 'Aucun doublon';

  @override
  String get duplicatesEmptyBody =>
      'Les titres présents en plusieurs versions (même titre, même artiste, même durée) apparaîtront ici.';

  @override
  String get duplicatesNeedFfmpeg =>
      'Les durées sont lues par FFmpeg, absent de cette installation : la recherche de doublons attend.';

  @override
  String sizeKb(String n) {
    return '$n Ko';
  }

  @override
  String sizeMb(String n) {
    return '$n Mo';
  }

  @override
  String sizeGb(String n) {
    return '$n Go';
  }

  @override
  String duplicatesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres présents en plusieurs versions',
      one: '1 titre présent en plusieurs versions',
      zero: 'Aucun doublon trouvé',
    );
    return '$_temp0';
  }

  @override
  String get miniPin => 'Garder au premier plan';

  @override
  String get miniUnpin => 'Ne plus garder au premier plan';

  @override
  String get miniExpand => 'Agrandir la fenêtre';

  @override
  String get favoritesEmptyTitle => 'Aucun favori pour l\'instant';

  @override
  String get favoritesEmptyBody =>
      'Touchez le cœur d\'un titre, dans Titres ou En lecture, pour le retrouver ici.';

  @override
  String get getNavHome => 'Accueil';

  @override
  String get getNavDownloads => 'Téléchargements';

  @override
  String get getNavBrowser => 'Navigateur';

  @override
  String get getNavTorrents => 'Torrents';

  @override
  String get getNavHistory => 'Historique';

  @override
  String get getHomeTitle => 'Du lien à votre bibliothèque';

  @override
  String get getHomeSub =>
      'Collez un lien, choisissez le format, écoutez ou regardez hors ligne.';

  @override
  String get getLinkLabel => 'Lien du média';

  @override
  String get getPaste => 'Coller';

  @override
  String get getAnalyze => 'Analyser';

  @override
  String get getHintPaste => 'pour coller et analyser';

  @override
  String get getHintDrop => 'Glissez un lien dans la fenêtre';

  @override
  String get getHintExt => 'Ou envoyez-le depuis l’extension Chrome/Edge';

  @override
  String get getQAudio => 'Audio seul';

  @override
  String get getQAudioDesc => 'MP3 jusqu’à 320 kbps, FLAC';

  @override
  String get getQPlaylist => 'Playlist';

  @override
  String get getQPlaylistDesc => 'Choisir les éléments';

  @override
  String get getQBatch => 'Plusieurs liens';

  @override
  String get getQBatchDesc => 'Un lien par ligne';

  @override
  String get getQTorrent => 'Torrent / magnet';

  @override
  String get getQTorrentDesc => 'Fichiers et partage maîtrisés';

  @override
  String get getContinue => 'Reprendre';

  @override
  String get getSeeLibrary => 'Voir la bibliothèque';

  @override
  String get getContinueEmpty =>
      'Ce que vous commencez à lire ou regarder reprendra ici.';

  @override
  String get getRecent => 'Récemment téléchargés';

  @override
  String get getHomeEmpty => 'Vos téléchargements apparaîtront ici.';

  @override
  String getPlayTitle(String title) {
    return 'Lire $title';
  }

  @override
  String getMinutesLeft(int n) {
    return 'Reste $n min';
  }

  @override
  String get getLinkEmpty => 'Collez un lien à analyser.';

  @override
  String get getLinkTooLong => 'Ce lien est trop long.';

  @override
  String get getLinkMalformed =>
      'Ce lien semble incomplet. Vérifiez qu’il commence par « https:// ».';

  @override
  String get getLinkScheme => 'Seuls les liens http et https sont acceptés.';

  @override
  String get getLinkCredentials =>
      'Les liens contenant un nom d’utilisateur ou un mot de passe ne sont pas acceptés.';

  @override
  String get getLinkMissingHttps => 'Il manque « https:// » à ce lien.';

  @override
  String get getAddHttps => 'Ajouter https://';

  @override
  String get getClipboardEmpty =>
      'Le presse-papiers est vide. Copiez d’abord un lien.';

  @override
  String get getPlanned => 'PRÉVU';

  @override
  String get getPlannedHint =>
      'Prévu dans un prochain lot : pas encore disponible.';

  @override
  String get getBack => 'Retour';

  @override
  String get getFmtVideo => 'Vidéo';

  @override
  String get getFmtSubs => 'Sous-titres';

  @override
  String get getNoVideoFormats =>
      'Cette source ne propose pas de format vidéo.';

  @override
  String get getNoAudioFormats =>
      'Cette source ne propose pas de format audio seul.';

  @override
  String get getNoSubsFormats => 'Cette source ne propose pas de sous-titres.';

  @override
  String getUpTo(String q) {
    return 'Jusqu’à $q';
  }

  @override
  String get getSubsPlanned => 'Sous-titres : téléchargement prévu (DL-08)';

  @override
  String get getNoteAudio =>
      'La conversion suit le téléchargement ; sa progression est affichée à part.';

  @override
  String get getNoteVideo => 'Tailles indiquées par la source, ou estimées.';

  @override
  String get getNeedsFfmpeg =>
      'Installez FFmpeg pour obtenir plus de qualités (vidéo et audio fusionnés) et la conversion MP3.';

  @override
  String get getDirectResume =>
      'Fichier direct · reprise possible si interrompu';

  @override
  String get getDirectNoResume =>
      'Fichier direct · pas de reprise si interrompu';

  @override
  String getOriginalFile(String ext) {
    return '$ext · fichier d’origine';
  }

  @override
  String get getTagRecommended => 'Recommandé';

  @override
  String get getTagBest => 'Meilleure qualité';

  @override
  String get getChange => 'Changer';

  @override
  String get getAddToQueue => 'Ajouter à la file';

  @override
  String get getStarting => 'Démarrage…';

  @override
  String getDownloadSize(String size) {
    return 'Télécharger · $size';
  }

  @override
  String get getDownload => 'Télécharger';

  @override
  String getAddedToQueue(String q) {
    return 'Ajouté à la file · $q';
  }

  @override
  String get getView => 'Voir';

  @override
  String get getPrepTitle => 'Préparation de votre fichier';

  @override
  String getPrepElapsed(int n) {
    return '$n s';
  }

  @override
  String getPrepStage1(String host) {
    return 'Lecture du lien sur $host…';
  }

  @override
  String get getPrepStage2 =>
      'Recherche des qualités vidéo et audio disponibles…';

  @override
  String get getPrepStage3 =>
      'Certains sites répondent plus lentement. Merci de patienter, ça continue.';

  @override
  String get getPrepStage4 =>
      'Toujours en cours. Les vidéos longues ou très demandées peuvent prendre plus de temps.';

  @override
  String get getPrepThisSite => 'ce site';

  @override
  String get getPrepTip => 'ASTUCE';

  @override
  String get getPrepTip1 =>
      'Choisissez « Audio seul » pour ne garder que la musique, dans un fichier plus léger.';

  @override
  String get getPrepTip2 =>
      'Vos téléchargements arrivent directement dans la bibliothèque.';

  @override
  String get getPrepTip3 =>
      'Les qualités proposées sont celles que la source publie, rien n’est inventé.';

  @override
  String get getPrepTip4 =>
      'Plusieurs titres ? Ajoutez-les « À la file » : ils se téléchargent chacun leur tour.';

  @override
  String get getNoMediaTitle => 'Aucun média téléchargeable trouvé';

  @override
  String get getNoMediaBody =>
      'Cette page ne contient pas de média pris en charge, ou il demande une connexion, est protégé (DRM) ou est un direct. Miarina Media ne contourne pas ces protections.';

  @override
  String getNoMediaReason(String reason) {
    return 'Raison : $reason';
  }

  @override
  String get getWhyNetwork =>
      'le site n’a pas pu être joint ; vérifiez le lien et votre connexion';

  @override
  String getWhyHttp(String status) {
    return 'le site a refusé la demande (HTTP $status)';
  }

  @override
  String get getWhyPlatform =>
      'la lecture des pages web n’est pas disponible sur cet appareil';

  @override
  String get getTryAgain => 'Réessayer';

  @override
  String get getToolsNeeded => 'Cette page a besoin des outils média';

  @override
  String get getToolsBody =>
      'Miarina Media lit les pages web avec yt-dlp et fusionne ou convertit les fichiers avec FFmpeg. Ils sont téléchargés une fois depuis leurs publications officielles et contrôlés avec une empreinte SHA-256 fixe avant usage.';

  @override
  String getBytesOf(String done, String total) {
    return '$done sur $total';
  }

  @override
  String get getNotNow => 'Plus tard';

  @override
  String get getDownloadingShort => 'Téléchargement…';

  @override
  String getDownloadTools(String size) {
    return 'Télécharger les outils · $size';
  }

  @override
  String getTabActive(int n) {
    return 'En cours · $n';
  }

  @override
  String getTabDone(int n) {
    return 'Terminés · $n';
  }

  @override
  String getTabFailed(int n) {
    return 'Échecs · $n';
  }

  @override
  String getDlSubRunning(int n, String speed) {
    return '$n en cours · $speed · reprise automatique si la source l’accepte';
  }

  @override
  String get getDlSubPaused => 'Tout est en pause';

  @override
  String getDlSubIdle(int n) {
    return 'Rien en cours · jusqu’à $n à la fois';
  }

  @override
  String get getPauseAll => 'Tout mettre en pause';

  @override
  String get getResumeAll => 'Tout reprendre';

  @override
  String get getDlNothing => 'Rien ici pour le moment.';

  @override
  String getActRetry(String title) {
    return 'Réessayer $title';
  }

  @override
  String getActResume(String title) {
    return 'Reprendre $title';
  }

  @override
  String getActStart(String title) {
    return 'Démarrer $title maintenant';
  }

  @override
  String getActPause(String title) {
    return 'Mettre en pause $title';
  }

  @override
  String get getCannotPause =>
      'Impossible de mettre en pause pendant la préparation du fichier';

  @override
  String getRemoveNamed(String title) {
    return 'Retirer $title';
  }

  @override
  String getCancelNamed(String title) {
    return 'Annuler $title';
  }

  @override
  String get getCancelTitle => 'Annuler le téléchargement ?';

  @override
  String getCancelBody(String title) {
    return '$title sera retiré de la file et ses fichiers partiels supprimés.';
  }

  @override
  String get getCancelConfirm => 'Annuler le téléchargement';

  @override
  String get getKeepDownloading => 'Continuer';

  @override
  String getActRestart(String title) {
    return 'Recommencer $title depuis le début';
  }

  @override
  String get getOpenFolder => 'Ouvrir le dossier';

  @override
  String get getShowInFolder => 'Afficher dans le dossier';

  @override
  String get getStDone => 'Terminé';

  @override
  String get getFileGone => 'Ce fichier n’est plus dans la bibliothèque.';

  @override
  String get getStFailed => 'Échec';

  @override
  String getStResumeAt(int n) {
    return 'reprise $n %';
  }

  @override
  String get getStOffline => 'En pause · hors ligne';

  @override
  String getStRetry(int n) {
    return 'Connexion perdue · nouvel essai $n s';
  }

  @override
  String get getStDownloading => 'Téléchargement';

  @override
  String get getStConverting => 'Conversion';

  @override
  String getStConvertingTo(String ext) {
    return 'Conversion $ext';
  }

  @override
  String getStFinalizing(String ext) {
    return 'Finalisation $ext';
  }

  @override
  String get getStStep => 'étape 2/2 · ffmpeg';

  @override
  String get getStPaused => 'En pause';

  @override
  String get getStPausedRestart => 'En pause · redémarrera';

  @override
  String get getStDiskFull => 'Échec · disque plein';

  @override
  String get getStAccessDenied => 'Échec · dossier non accessible';

  @override
  String get getStDiskFullHint => 'libérez de l’espace puis réessayez';

  @override
  String get getStAccessDeniedHint => 'choisissez un autre dossier';

  @override
  String get getStAnalyzing => 'Analyse des formats…';

  @override
  String get getStQueued => 'En attente';

  @override
  String get getWhyDiskFull => 'Disque plein';

  @override
  String get getWhyNoSpace => 'Espace disque insuffisant pour ce fichier';

  @override
  String get getWhyDenied =>
      'Dossier de destination non accessible en écriture';

  @override
  String getSumRunning(int n) {
    return '$n en cours';
  }

  @override
  String get getSumOffline => 'En pause · hors ligne';

  @override
  String get getSumPaused => 'Tout en pause';

  @override
  String get getSumIdle => 'Aucun téléchargement';

  @override
  String getSumQueue(int n) {
    return '$n en attente';
  }

  @override
  String get getDirRefused =>
      'Ce dossier n’accepte pas de fichiers. Choisissez-en un autre.';

  @override
  String get getHistKind => 'Type d’historique';

  @override
  String get getHistDownloads => 'Téléchargements';

  @override
  String get getHistPlays => 'Lectures';

  @override
  String get getClearHistory => 'Effacer l’historique';

  @override
  String get getClearDlTitle => 'Effacer l’historique des téléchargements ?';

  @override
  String get getClearDlBody =>
      'La liste des téléchargements passés est effacée. Les fichiers déjà enregistrés dans votre bibliothèque ne sont pas supprimés.';

  @override
  String get getHistEmptyDl =>
      'Les téléchargements terminés, échoués ou annulés apparaissent ici.';

  @override
  String get getHistNoteDl => 'Effacer l’historique ne supprime aucun fichier.';

  @override
  String getFailedBecause(String reason) {
    return 'Échec · $reason';
  }

  @override
  String get getStCanceled => 'Annulé';

  @override
  String getActionsFor(String title) {
    return 'Actions pour $title';
  }

  @override
  String get getCopySourceLink => 'Copier le lien source';

  @override
  String get getLinkCopied => 'Lien source copié';

  @override
  String get getToday => 'Aujourd’hui';

  @override
  String get getYesterday => 'Hier';

  @override
  String get setDownloads => 'Téléchargements';

  @override
  String get getSaveTo => 'Enregistrer dans';

  @override
  String get getDefaultVideoQuality => 'Qualité vidéo par défaut';

  @override
  String get getDefaultVideoQualityDesc =>
      'Qualité inférieure si indisponible.';

  @override
  String get getDefaultAudio => 'Format audio par défaut';

  @override
  String get getSimultaneous => 'Téléchargements simultanés';

  @override
  String get getSimultaneousDesc => 'Les suivants attendent dans la file.';

  @override
  String get getSpeedLimit => 'Limite de vitesse';

  @override
  String get getDownloadSubs => 'Télécharger les sous-titres';

  @override
  String get getDownloadSubsDesc =>
      'Langue de l’interface en priorité, si disponible.';

  @override
  String get getResourceMode => 'Mode de ressources';

  @override
  String get getModeEco => 'Éco';

  @override
  String get getModeBalanced => 'Équilibré';

  @override
  String get getModePerformance => 'Performance';

  @override
  String getModeDesc(int n, int c) {
    return '$n téléchargement(s) simultané(s), $c conversion(s) à la fois.';
  }

  @override
  String get getMediaTools => 'Outils média';

  @override
  String get getAutoUpdated => 'mise à jour automatique';

  @override
  String get getIncludedVerified => 'Inclus · vérifié';

  @override
  String get getInstalledVerified => 'Installé · vérifié';

  @override
  String getToDownload(String size) {
    return '$size à télécharger';
  }

  @override
  String get getToolsInstalled => 'Outils média installés et vérifiés';

  @override
  String get getUpdCheck => 'Rechercher une mise à jour';

  @override
  String get getUpdChecking => 'Recherche…';

  @override
  String getYtdlpLatest(String v) {
    return 'yt-dlp est à jour ($v)';
  }

  @override
  String getYtdlpUpdated(String v) {
    return 'yt-dlp mis à jour en $v · signature vérifiée';
  }

  @override
  String get getUpdFailed =>
      'La mise à jour de yt-dlp n’a pas pu se faire. Réessayez plus tard.';

  @override
  String get getInstallFailed =>
      'Les outils n’ont pas pu être téléchargés. Vérifiez la connexion puis réessayez.';

  @override
  String get getLess => 'Moins';

  @override
  String get getMore => 'Plus';

  @override
  String get brAddressPh => 'Rechercher ou saisir une adresse web';

  @override
  String brCloseTab(String title) {
    return 'Fermer l’onglet $title';
  }

  @override
  String get brNewTab => 'Nouvel onglet (Ctrl T)';

  @override
  String get brStartTab => 'Nouvel onglet';

  @override
  String get brStop => 'Arrêter le chargement';

  @override
  String get brBack => 'Précédent';

  @override
  String get brForward => 'Suivant';

  @override
  String get brReload => 'Recharger';

  @override
  String get brHome => 'Page de démarrage';

  @override
  String get brMediaOne => '1 média';

  @override
  String brMediaMany(int n) {
    return '$n médias';
  }

  @override
  String get brStartTitle => 'Rechercher ou ouvrir une page web';

  @override
  String get brStartBody =>
      'Quand une page contient une vidéo ou un fichier audio, une barre de téléchargement apparaît sous la page.';

  @override
  String get brLegalHint =>
      'Téléchargez seulement les médias qui vous appartiennent ou que vous avez le droit d’enregistrer.';

  @override
  String brDownloadFound(int n) {
    return 'Télécharger les médias trouvés sur cette page ($n)';
  }

  @override
  String brMediaFound(int n) {
    return '$n médias trouvés';
  }

  @override
  String get brMediaFoundOne => '1 média trouvé';

  @override
  String get brChooseMedia => 'Choisir le média et le format';

  @override
  String get brSheetTitle => 'Télécharger depuis cette page';

  @override
  String get brKindVideo => 'Vidéo';

  @override
  String get brKindAudio => 'Audio';

  @override
  String get brKindHls => 'Flux (HLS)';

  @override
  String get brKindDash => 'Flux (DASH)';

  @override
  String get brKindPage => 'Lecteur de la page';

  @override
  String get brItemProtected =>
      'Cet élément est peut-être protégé ou demande une connexion. Essayez un autre élément de la page.';

  @override
  String get brClosePanel => 'Fermer le panneau';

  @override
  String get brTooManyTabs =>
      '12 onglets au plus : fermez-en un pour en ouvrir un autre.';

  @override
  String get brUnsupported =>
      'Seules les pages web (http, https) s’ouvrent dans le navigateur.';

  @override
  String get brUnavailable =>
      'Le navigateur n’a pas pu démarrer : WebView2 est introuvable ou n’a pas répondu.';

  @override
  String get brHistory => 'Historique';

  @override
  String get brFavorites => 'Favoris';

  @override
  String get brHistoryViews => 'Historique ou favoris';

  @override
  String get brHistorySearch => 'Rechercher dans les pages visitées';

  @override
  String brNoMatch(String q) {
    return 'Rien ne correspond à « $q ».';
  }

  @override
  String get brHistoryEmpty => 'Les pages que vous visitez apparaissent ici.';

  @override
  String get brFavoritesEmpty =>
      'Ajoutez une page aux favoris avec l’étoile de la barre d’adresse.';

  @override
  String get brHistoryNote =>
      'Gardé sur cet appareil seulement. L’effacer ne supprime aucun fichier ni téléchargement.';

  @override
  String brDeleteVisit(String title) {
    return 'Retirer $title de l’historique';
  }

  @override
  String brRemoveFavorite(String title) {
    return 'Retirer $title des favoris';
  }

  @override
  String get brClearTitle => 'Effacer l’historique du navigateur ?';

  @override
  String get brClearBody =>
      'Les pages visitées sont oubliées. Les téléchargements, la bibliothèque et les favoris restent.';

  @override
  String get brCleared => 'Historique du navigateur effacé';

  @override
  String get brClearHistory => 'Effacer l’historique';

  @override
  String get brFavAdd => 'Ajouter aux favoris';

  @override
  String get brFavRemove => 'Retirer des favoris';

  @override
  String get brFavAdded => 'Ajouté aux favoris';

  @override
  String get brFavRemoved => 'Retiré des favoris';

  @override
  String get brSites => 'Sites';

  @override
  String getReorderNamed(String title) {
    return 'Réordonner $title (Alt + flèches haut et bas, ou glisser)';
  }

  @override
  String get torCapped => 'Partage plafonné, en Ko/s';

  @override
  String get torChecking => 'Vérification des fichiers';

  @override
  String torDoneMeta(String size) {
    return 'Terminé · $size';
  }

  @override
  String torDoneSharing(String size) {
    return 'Terminé · $size · partage en cours';
  }

  @override
  String get torDown => 'Reçu';

  @override
  String get torDownLimit => 'Limite de réception';

  @override
  String get torEmpty => 'Vos torrents apparaîtront ici.';

  @override
  String get torEnable => 'Activer la session';

  @override
  String get torError => 'Erreur · le transfert s’est arrêté';

  @override
  String get torFailed => 'L’opération n’a pas pu aboutir.';

  @override
  String get torInactive => 'Session arrêtée';

  @override
  String get torInspect => 'Analyser le lien';

  @override
  String get torLeft => 'Reste';

  @override
  String get torLimitsSaved => 'Limites appliquées';

  @override
  String get torMagnet => 'Lien magnet';

  @override
  String get torOpenFile => 'Ouvrir un .torrent';

  @override
  String torPausedMeta(String done, String total) {
    return 'En pause · $done / $total';
  }

  @override
  String get torPeers => 'Pairs';

  @override
  String get torPreviewNote =>
      'Les fichiers sont enregistrés dans un nouveau dossier, sous votre dossier de téléchargement / Torrents. De petits morceaux en bordure de fichiers non choisis peuvent aussi être écrits.';

  @override
  String get torRatio => 'Ratio';

  @override
  String get torRatioDesc => 'Arrêt du partage au-delà';

  @override
  String get torRemove => 'Retirer';

  @override
  String get torRemoveBody =>
      'Les fichiers téléchargés sont conservés. Le transfert et le partage s’arrêtent.';

  @override
  String torRemoveNamed(String name) {
    return 'Retirer $name';
  }

  @override
  String get torRemoveTitle => 'Retirer ce torrent ?';

  @override
  String get torResume => 'Reprendre';

  @override
  String get torSeedDesc => 'Arrêt après la durée';

  @override
  String get torSeedTime => 'Durée de partage';

  @override
  String get torSequential => 'Télécharger les morceaux dans l’ordre';

  @override
  String get torSessionOff => 'Session arrêtée';

  @override
  String get torSessionOn => 'Session active';

  @override
  String get torSessionSharing => 'Session active · partage en cours';

  @override
  String get torSharing => 'Partage';

  @override
  String get torStart => 'Démarrer le téléchargement';

  @override
  String get torStopAll => 'Arrêter tout et le partage';

  @override
  String get torStopSharing => 'Arrêter le partage';

  @override
  String get torSub =>
      'Ajoutez un lien magnet ou un fichier .torrent. Un torrent partage les morceaux téléchargés avec d’autres pairs, y compris après la fin : le partage est affiché et vous pouvez l’arrêter à tout moment.';

  @override
  String get torTargetRatio => 'Ratio cible';

  @override
  String get torUnlimited => '0 = illimité, en Ko/s';

  @override
  String get torUp => 'Envoyé';

  @override
  String get torUpLimit => 'Limite d’envoi';

  @override
  String get torWait => 'Patientez…';

  @override
  String get torLinkInvalid => 'Ce lien magnet n’est pas valide.';

  @override
  String get torDuplicate => 'Ce torrent est déjà dans la liste.';

  @override
  String get torSelection => 'Sélectionnez au moins un fichier.';

  @override
  String get torSessionChanged =>
      'La session a changé : analysez le lien à nouveau.';

  @override
  String get torPlannedHint =>
      'Prévu dans un prochain lot : pas encore disponible.';

  @override
  String get torPlanned => 'PRÉVU';

  @override
  String filterMissingCount(int count) {
    return 'Introuvables · $count';
  }

  @override
  String get filterAddedThisMonth => 'Ajoutés ce mois';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get playNext => 'Lire ensuite';

  @override
  String get addToQueue => 'Ajouter à la file';

  @override
  String get addTo => 'Ajouter à…';

  @override
  String get addToPlaylist => 'Ajouter à une playlist…';

  @override
  String get addToPlaylistTitle => 'Ajouter à une playlist';

  @override
  String get newPlaylistEllipsis => 'Nouvelle playlist…';

  @override
  String get showInExplorer => 'Afficher dans l’Explorateur';

  @override
  String get removeEllipsis => 'Retirer…';

  @override
  String playNextDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count titres seront lus ensuite',
      one: 'Le titre sera lu ensuite',
    );
    return '$_temp0';
  }

  @override
  String queueAddDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres ajoutés à la file',
      one: '1 titre ajouté à la file',
    );
    return '$_temp0';
  }

  @override
  String playlistAddDone(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres ajoutés à « $name »',
      one: '1 titre ajouté à « $name »',
    );
    return '$_temp0';
  }

  @override
  String sortByColumn(String column) {
    return 'Trier par $column';
  }

  @override
  String get sortedAscending => 'tri croissant';

  @override
  String get sortedDescending => 'tri décroissant';

  @override
  String get clearSelection => 'Désélectionner';

  @override
  String get playSelection => 'Lire';

  @override
  String get keyEnter => 'Entrée';

  @override
  String get keyCtrlEnter => 'Ctrl Entrée';

  @override
  String get keyDelete => 'Suppr';

  @override
  String get filterNeverPlayed => 'Jamais écoutés';

  @override
  String get filterHiRes => 'Hi-res';

  @override
  String get groupSortAdded => 'Ajoutés récemment';

  @override
  String get groupSortName => 'A → Z';

  @override
  String get groupSortYear => 'Année';

  @override
  String get groupSortPlays => 'Les plus écoutés';

  @override
  String get groupSortTracks => 'Nombre de titres';

  @override
  String get filterLossless => 'FLAC / hi-res';

  @override
  String get filterDownloaded => 'Téléchargés avec Miarina Media';

  @override
  String get filterCompilations => 'Compilations';

  @override
  String filterNoCover(int count) {
    return 'Sans pochette · $count';
  }

  @override
  String get filterEmptyTitle => 'Rien avec ce filtre';

  @override
  String get filterEmptyBody =>
      'Choisissez « Tous » pour revoir toute la liste.';

  @override
  String get viewGrid => 'Grille';

  @override
  String get viewList => 'Liste';

  @override
  String playsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count écoutes',
      one: '1 écoute',
    );
    return '$_temp0';
  }

  @override
  String playedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'écouté $count fois',
      one: 'écouté 1 fois',
    );
    return '$_temp0';
  }

  @override
  String get saveAsPlaylist => 'Enregistrer en playlist';

  @override
  String get editTags => 'Modifier les tags';

  @override
  String get tagFromName => 'Remplir depuis le nom du fichier';

  @override
  String get tagRename => 'Renommer le fichier « Artiste - Titre »';

  @override
  String get fTitle => 'Titre';

  @override
  String get fArtist => 'Artiste';

  @override
  String get fAlbumArtist => 'Artiste de l’album';

  @override
  String get fAlbum => 'Album';

  @override
  String get fYear => 'Année';

  @override
  String get fGenre => 'Genre';

  @override
  String get fTrack => 'N° de piste';

  @override
  String get fDisc => 'N° de disque';

  @override
  String get fComment => 'Commentaire';

  @override
  String get fLyrics => 'Paroles (facultatif)';

  @override
  String get fLyricsPh => 'Collez le texte ou le contenu d’un fichier .lrc';

  @override
  String get tagNote =>
      'Modifier un tag ne change pas la qualité audio ou vidéo.';

  @override
  String renameNote(String name) {
    return 'Le fichier sera renommé : $name';
  }

  @override
  String get tagWrite =>
      'Écrire aussi dans le fichier (sinon : bibliothèque Miarina Media seulement)';

  @override
  String get tagWriteUnsupported =>
      'Ce format garde ses tags dans la bibliothèque Miarina Media seulement.';

  @override
  String get tagsSavedFile => 'Tags écrits dans le fichier.';

  @override
  String get tagsSavedLibrary =>
      'Tags enregistrés dans la bibliothèque. Fichier inchangé.';

  @override
  String get invalidNumber => 'Nombre entier attendu';

  @override
  String get coverChoose => 'Choisir une image…';

  @override
  String get coverSource => 'Miniature de la source';

  @override
  String get coverNoSource => 'La source n’a pas fourni de miniature';

  @override
  String get coverRemove => 'Retirer la pochette';

  @override
  String get coverNone => 'Aucune pochette';

  @override
  String get coverWorking => 'Préparation de la pochette…';

  @override
  String get coverNote =>
      'JPEG, PNG, WebP, BMP ou GIF. Réduite à 1000 px et gardée dans la bibliothèque, appliquée tout de suite ; le fichier n’est pas modifié.';

  @override
  String get coverUpdated => 'Pochette mise à jour';

  @override
  String get coverRemoved => 'Pochette retirée';

  @override
  String get errTagsUnsupported =>
      'Ce type de fichier ne prend pas de tags : rien n’a été enregistré.';

  @override
  String get errTagsWrite =>
      'Les tags n’ont pas pu être écrits dans le fichier : rien n’a été enregistré.';

  @override
  String get errInvalidName => 'Ce nom ne peut pas être utilisé.';

  @override
  String get errNotInLibrary => 'Ce titre n’est plus dans la bibliothèque.';

  @override
  String get errCoverRefused =>
      'Cette image ne peut pas servir de pochette (format ou taille).';

  @override
  String get errLibrary => 'La bibliothèque n’a pas pu faire ce changement.';

  @override
  String get coverImageType => 'Images';

  @override
  String get keyCtrlI => 'Ctrl I';

  @override
  String get markSeasonSeen => 'Marquer la saison comme vue';

  @override
  String get markSeasonUnseen => 'Marquer la saison comme non vue';

  @override
  String get markSeriesSeen => 'Marquer la série comme vue';

  @override
  String get markSeriesUnseen => 'Marquer la série comme non vue';

  @override
  String get markSeen => 'Marquer comme vu';

  @override
  String get markUnseen => 'Marquer comme non vu';

  @override
  String get fDirector => 'Réalisateur / auteur';

  @override
  String get fSeries => 'Série / collection';

  @override
  String get fLicense => 'Licence / commentaire';

  @override
  String coverFrame(String time) {
    return 'Capturer l’image à $time';
  }

  @override
  String get bookmarkAddNote => 'Ajouter une note…';

  @override
  String get bookmarkEditNote => 'Modifier la note…';

  @override
  String bookmarkNoteTitle(String time) {
    return 'Note du signet à $time';
  }

  @override
  String get bookmarksExport => 'Exporter…';

  @override
  String bookmarksExported(String path) {
    return 'Signets enregistrés : $path';
  }

  @override
  String get bookmarksExportFailed =>
      'Les signets n’ont pas pu être enregistrés dans ce dossier.';

  @override
  String get dbProblemTitle => 'Votre bibliothèque n’a pas été ouverte';

  @override
  String dbTooNew(String found, String supported) {
    return 'Cette bibliothèque a été mise à jour par une version plus récente de Miarina Media : cette version ne peut pas l’ouvrir sans risque (schéma $found, cette version s’arrête au schéma $supported).\n\nVos données n’ont pas été modifiées. Installez la version la plus récente de Miarina Media.';
  }

  @override
  String dbUpgradeFailed(String backup, String reason) {
    return 'La mise à jour de votre bibliothèque a échoué. Elle a été annulée : vos données n’ont pas été modifiées.\n\nCopie de sauvegarde : $backup\nDétail : $reason\n\nRéinstallez la version précédente de Miarina Media pour continuer à utiliser cette bibliothèque.';
  }

  @override
  String get dbNoBackup => 'aucune';

  @override
  String dbBackupFailed(String reason) {
    return 'Miarina Media n’a pas pu copier votre bibliothèque avant de la mettre à jour : la mise à jour n’a pas été faite et vos données n’ont pas été modifiées.\n\nVérifiez l’espace libre sur le disque puis relancez Miarina Media.\nDétail : $reason';
  }

  @override
  String dbOpenFailed(String file, String reason) {
    return 'La bibliothèque de Miarina Media n’a pas pu être ouverte.\n\nFichier : $file\nDétail : $reason';
  }

  @override
  String get updConverting =>
      'Conversion en cours : l’installation sera possible quand elle sera terminée';

  @override
  String get updNetwork =>
      'Connexion au serveur de mises à jour perdue. Réessayez : un téléchargement reprend là où il s’est arrêté.';

  @override
  String updAvailable(String v) {
    return 'Miarina Media $v est disponible';
  }

  @override
  String get updBeta => 'Bêta';

  @override
  String updActive(String n) {
    return '$n téléchargement(s) en cours : interrompus pendant l’installation, retrouvés en pause au redémarrage. Bibliothèque et réglages conservés.';
  }

  @override
  String get updStopsPlayback => 'La lecture en cours sera arrêtée';

  @override
  String get updStopsSharing => 'Le partage torrent sera arrêté';

  @override
  String updReady(String v) {
    return '$v est prête';
  }

  @override
  String updDownloading(String v) {
    return 'Téléchargement de $v…';
  }

  @override
  String updInstalled(String v, String channel, String size) {
    return 'Version installée $v · canal $channel · $size';
  }

  @override
  String get updBadgeReady => 'Prête';

  @override
  String get updBadgeDownloading => 'Téléchargement';

  @override
  String get updBadge => 'Disponible';

  @override
  String get updProgress => 'Progression de la mise à jour';

  @override
  String updProgressText(String done, String size) {
    return '$done / $size · vérification à la fin';
  }

  @override
  String updPartial(String done, String size) {
    return '$done / $size déjà téléchargés : la suite reprend où elle s’est arrêtée.';
  }

  @override
  String get updVerified => 'Signature et SHA-256 vérifiées';

  @override
  String get updResume => 'Reprendre le téléchargement';

  @override
  String updDownload(String size) {
    return 'Télécharger · $size';
  }

  @override
  String get updInstalling => 'Ouverture de l’installation…';

  @override
  String get updInstall => 'Installer maintenant';

  @override
  String get updLater => 'Plus tard';

  @override
  String get updKeptReady => 'Mise à jour gardée prête.';

  @override
  String get updWindowsNote =>
      'Windows ferme Miarina Media et ouvre l’installateur. Votre bibliothèque, vos playlists, vos positions de lecture et vos réglages sont conservés. Rien n’est installé sans votre accord.';

  @override
  String get updChecking => 'Recherche…';

  @override
  String updLatest(String v) {
    return 'Vous utilisez la dernière version ($v).';
  }

  @override
  String get updAutoCheck =>
      'Recherche automatique au démarrage et toutes les six heures.';

  @override
  String get updCheck => 'Rechercher une mise à jour';

  @override
  String get updChannel => 'Canal';

  @override
  String get updChannelDesc =>
      'La bêta reçoit les nouveautés avant validation complète.';

  @override
  String get updAuto => 'Télécharger automatiquement';

  @override
  String get updAutoDesc =>
      'Uniquement en Wi-Fi ou réseau non limité. L’installation reste toujours à votre demande.';

  @override
  String get setUpdates => 'Mises à jour';

  @override
  String get updView => 'Voir';

  @override
  String updVersion(String v) {
    return 'Version $v';
  }

  @override
  String get updDevBuild =>
      'Version de développement : les mises à jour sont désactivées.';

  @override
  String get deviceAccessTitle =>
      'Accédez à la musique et aux vidéos de ce téléphone';

  @override
  String get deviceAccessBody =>
      'Miarina Media lit vos fichiers sur l\'appareil. Rien n\'est envoyé, aucun compte n\'est nécessaire.';

  @override
  String get deviceAccessMusic => 'Musique et audio';

  @override
  String get deviceAccessMusicBody =>
      'Pour afficher vos albums, podcasts et cours.';

  @override
  String get deviceAccessVideo => 'Vidéos';

  @override
  String get deviceAccessVideoBody => 'Pour vos films, séries et vidéos perso.';

  @override
  String get deviceAccessNotif => 'Notifications';

  @override
  String get deviceAccessNotifBody =>
      'Pour les commandes de lecture sur l\'écran verrouillé.';

  @override
  String get deviceAccessAllow => 'Autoriser l\'accès';

  @override
  String get deviceDeniedTitle => 'Accès aux fichiers refusé';

  @override
  String get deviceDeniedBody =>
      'Sans cette autorisation, Miarina Media ne voit pas la musique et les vidéos du téléphone. Vos playlists sont conservées.';

  @override
  String get deviceDeniedSettings => 'Ouvrir les paramètres Android';

  @override
  String get dlNotifWaiting => 'En attente d\'une place libre';

  @override
  String get dlNotifAnalyzing => 'Lecture des formats…';

  @override
  String get dlNotifProcessing => 'Préparation du fichier…';

  @override
  String dlNotifOf(String done, String total) {
    return '$done sur $total';
  }

  @override
  String dlNotifSpeed(String speed) {
    return '$speed Mo/s';
  }

  @override
  String get dlNotifLeftSoon => 'moins d\'une minute restante';

  @override
  String dlNotifLeftMin(int minutes) {
    return '$minutes min restantes';
  }

  @override
  String dlNotifLeftHours(int hours, int minutes) {
    return '$hours h $minutes min restantes';
  }

  @override
  String get dlNotifTapToPlay => 'toucher pour lire';

  @override
  String get dlNotifPause => 'Pause';

  @override
  String get dlNotifCancel => 'Annuler';

  @override
  String get dlNotifPauseAll => 'Tout mettre en pause';

  @override
  String get dlNotifComplete => 'Téléchargement terminé';

  @override
  String get dlNotifSeveral => '%d en cours';

  @override
  String get dlNotifChannelProgress => 'Téléchargements en cours';

  @override
  String get dlNotifChannelDone => 'Téléchargements terminés';

  @override
  String get getPasteLinkTitle => 'Coller un lien';

  @override
  String get getAnalyzeLink => 'Analyser le lien';

  @override
  String get getShareHint =>
      'Ou partagez un lien vers Miarina Media depuis n\'importe quelle app.';

  @override
  String getDlCard(int running, int queued) {
    return '$running en cours · $queued en attente';
  }
}

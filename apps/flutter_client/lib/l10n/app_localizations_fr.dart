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
  String get smartQueueBody =>
      'Même artiste ou même album, calculé sur l’appareil';

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
      'Cliquez sur une touche pour la modifier ; un conflit est signalé avant d\'être enregistré. Échap annule. Touches multimédia du clavier et du casque prises en charge (contrôles média de Windows).';

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
  String get getStStep => 'étape 2/2';

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
  String get setExtension => 'Extension navigateur';

  @override
  String get extLead =>
      'Envoyez une page ou une vidéo de Chrome ou Edge vers Miarina Media en un clic : l’analyse s’ouvre ici et vous choisissez le format.';

  @override
  String get extAccept => 'Accepter les liens envoyés par l’extension';

  @override
  String get extAcceptBody => 'Rien n’est capturé automatiquement.';

  @override
  String get extSteps => 'Mise en route';

  @override
  String get extStep1 => 'Installer l’extension';

  @override
  String get extStep1Body =>
      'Chrome · Edge : page Extensions, activez le mode développeur, puis « Charger l’extension non empaquetée » et choisissez ce dossier.';

  @override
  String get extOpenFolder => 'Ouvrir le dossier';

  @override
  String get extStep2 => 'Connecter ce PC';

  @override
  String get extStep2Body =>
      'Chrome et Edge pourront envoyer des liens à Miarina Media sur cet ordinateur.';

  @override
  String get extConnected => 'Chrome et Edge sont connectés.';

  @override
  String get extOther =>
      'Une autre installation de Miarina Media est connectée ; Connecter la remplace.';

  @override
  String get extConnect => 'Connecter';

  @override
  String get extDisconnect => 'Déconnecter';

  @override
  String get extStep3 => 'Tester la connexion';

  @override
  String get extTest => 'Tester';

  @override
  String get extTestNever => 'Pas encore testée.';

  @override
  String extTestOk(String time) {
    return 'Dernier test : réussi à $time';
  }

  @override
  String extTestFailed(String time) {
    return 'Dernier test : échoué à $time';
  }

  @override
  String get extTestDone => 'La connexion fonctionne.';

  @override
  String get extTestBad =>
      'Le pont du navigateur ne répond pas. Déconnectez puis reconnectez.';

  @override
  String get extNoBridge =>
      'Cette version de Miarina Media n’inclut pas le pont du navigateur.';

  @override
  String get extFailed => 'La connexion n’a pas pu être modifiée.';

  @override
  String get extPrivacy =>
      'L’extension ne lit rien dans les pages : seul le lien que vous envoyez part, et seulement vers Miarina Media sur cet ordinateur.';

  @override
  String get brTabs => 'Onglets';

  @override
  String brTabsOpen(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n onglets ouverts',
      one: '1 onglet ouvert',
    );
    return '$_temp0';
  }

  @override
  String get brBackToApp => 'Retour à Miarina Media';

  @override
  String brDownloadCount(int n) {
    return 'Télécharger · $n';
  }

  @override
  String get brDownloadHoldHint =>
      'Appui long : télécharger le média principal au format par défaut';

  @override
  String get brUnavailablePhone =>
      'Le navigateur n’a pas pu démarrer sur cet appareil.';

  @override
  String get brStartBodyPhone =>
      'Quand une page contient une vidéo ou un fichier audio, un bouton Télécharger apparaît au-dessus de la page.';

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
  String get torRatioDesc => 'Arrêt du partage au-delà · 0 = sans limite';

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
  String get torSeedDesc => 'Arrêt après la durée · 0 = sans limite';

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
      zero: 'aucune écoute',
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

  @override
  String plCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String plTruncated(int shown, int total) {
    return 'Les $shown premiers sur $total';
  }

  @override
  String plTruncatedUnknown(int shown) {
    return 'Les $shown premiers éléments';
  }

  @override
  String get plQuality => 'Qualité pour tous les éléments';

  @override
  String get plQualityNote =>
      'Si un élément n’a pas cette qualité, la meilleure en dessous est prise.';

  @override
  String get plItems => 'Éléments';

  @override
  String plSelected(int selected, int total) {
    return '$selected sur $total sélectionnés';
  }

  @override
  String get plSelectAll => 'Tout sélectionner';

  @override
  String get plSelectNone => 'Tout désélectionner';

  @override
  String get plUnavailable => 'Indisponible';

  @override
  String plItemFallback(int index) {
    return 'Élément $index';
  }

  @override
  String plOwnFolder(String name) {
    return 'Dans un dossier « $name »';
  }

  @override
  String plDownload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count éléments',
      one: 'Télécharger 1 élément',
      zero: 'Télécharger',
    );
    return '$_temp0';
  }

  @override
  String get plPreparing => 'Préparation…';

  @override
  String plQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements ajoutés à la file',
      one: '1 téléchargement ajouté à la file',
    );
    return '$_temp0';
  }

  @override
  String get plQueueFull =>
      'La file est pleine. Terminez ou retirez des téléchargements, puis réessayez.';

  @override
  String get plFailed => 'La playlist n’a pas pu être ajoutée. Réessayez.';

  @override
  String batchLead(int max) {
    return 'Collez jusqu’à $max liens, un par ligne. Chacun est analysé, puis ajouté à la file.';
  }

  @override
  String get batchHint => 'https://…\nhttps://…';

  @override
  String get batchClear => 'Vider';

  @override
  String batchTruncated(int max) {
    return 'Seuls les $max premiers liens sont gardés.';
  }

  @override
  String get batchQuality => 'Qualité pour les pages vidéo';

  @override
  String get batchQualityNote =>
      'Un fichier direct est gardé tel quel. Si une page n’a pas cette qualité, la meilleure en dessous est prise.';

  @override
  String get batchLinks => 'Liens';

  @override
  String batchValid(int valid, int total) {
    return '$valid valides sur $total';
  }

  @override
  String get batchEmpty => 'Les liens collés apparaîtront ici.';

  @override
  String get batchAnalyzing => 'Analyse…';

  @override
  String get batchAdded => 'Ajouté à la file';

  @override
  String get batchFailed => 'Pas ajouté';

  @override
  String get batchIsPlaylist =>
      'C’est une playlist : utilisez la tuile Playlist';

  @override
  String get batchNeedsTools =>
      'Outils média à installer : analysez d’abord un lien seul';

  @override
  String get batchNoAudio => 'Fichier sans audio seul';

  @override
  String get batchNoVideo => 'Fichier sans vidéo';

  @override
  String batchStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count liens',
      one: 'Télécharger 1 lien',
      zero: 'Télécharger',
    );
    return '$_temp0';
  }

  @override
  String get batchRunning => 'Analyse des liens…';

  @override
  String batchDone(int added, int failed) {
    return '$added ajoutés à la file · $failed non ajoutés';
  }

  @override
  String get getSpeedLimitDesc =>
      'Partagée entre les téléchargements en cours.';

  @override
  String get getSpeedUnlimited => 'Illimitée';

  @override
  String get getNoteSubs =>
      'Un fichier de sous-titres par langue, enregistré à côté de vos vidéos. Pour les avoir dans la vidéo, activez Réglages › Téléchargements › Télécharger les sous-titres.';

  @override
  String get crossfadeExclusive =>
      'Pas disponible avec la sortie audio exclusive.';

  @override
  String crossfadeSeconds(int s) {
    return '$s s';
  }

  @override
  String get videoSettings => 'Vidéo';

  @override
  String get subtitleDelay => 'Décalage';

  @override
  String get subtitleSize => 'Taille';

  @override
  String get earlier => 'Plus tôt';

  @override
  String get later => 'Plus tard';

  @override
  String get smaller => 'Plus petit';

  @override
  String get larger => 'Plus grand';

  @override
  String get slower => 'Plus lent';

  @override
  String get faster => 'Plus rapide';

  @override
  String get aspectRatio => 'Format d’image';

  @override
  String get aspectAuto => 'Auto';

  @override
  String get cropSetting => 'Recadrage';

  @override
  String get cropNone => 'Aucun';

  @override
  String get cropFill => 'Remplir l’écran';

  @override
  String get audioSync => 'Synchro audio';

  @override
  String get hwDecoding => 'Décodage matériel';

  @override
  String get hwDecodingBody => 'Repli logiciel automatique en cas d’échec.';

  @override
  String hwAuto(String decoder) {
    return 'Auto ($decoder)';
  }

  @override
  String get hwSoftware => 'Logiciel';

  @override
  String get abLoop => 'Boucle A–B';

  @override
  String get abOff => 'Désactivée';

  @override
  String abFrom(String time) {
    return 'A à $time';
  }

  @override
  String get abHintA => 'Touchez pour placer A à la position actuelle.';

  @override
  String get abHintB => 'Touchez pour placer B : la partie A–B se répète.';

  @override
  String get abHintOff => 'Touchez pour arrêter la boucle.';

  @override
  String get smartSection => 'Playlists intelligentes';

  @override
  String get smartNewTitle => 'Nouvelle playlist intelligente';

  @override
  String get smartEdit => 'Modifier les règles';

  @override
  String get smartText => 'Contient';

  @override
  String get smartTextHint => 'Titre, artiste, album…';

  @override
  String get smartAny => 'Tous';

  @override
  String get smartFavorites => 'Favoris uniquement';

  @override
  String get smartAdded => 'Ajoutés';

  @override
  String get smartAddedAny => 'Depuis toujours';

  @override
  String smartAddedDays(int n) {
    return '$n derniers jours';
  }

  @override
  String get smartSort => 'Trier par';

  @override
  String get smartLimit => 'Nombre de titres';

  @override
  String get smartLimitAll => 'Tous';

  @override
  String smartLimitN(int n) {
    return '$n titres';
  }

  @override
  String smartCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n titres',
      one: '1 titre',
      zero: 'Aucun titre',
    );
    return '$_temp0 · mise à jour automatique';
  }

  @override
  String get smartReading => 'Lecture de la bibliothèque…';

  @override
  String get smartEmptyTitle => 'Aucun titre pour ces règles';

  @override
  String get smartEmptyBody =>
      'La playlist se remplira d’elle-même quand la bibliothèque aura des titres qui y correspondent.';

  @override
  String get smartDeleteBody =>
      'Seules les règles sont supprimées : aucun fichier n’est touché.';

  @override
  String smartQueueAddAll(int n) {
    return 'Ajouter les $n';
  }

  @override
  String get addQueueOne => 'Ajouter à la file';

  @override
  String get toolsGroup => 'Outils PC';

  @override
  String get navConvert => 'Convertir';

  @override
  String get convLead =>
      'Choisissez un format ou un outil, ajoutez vos fichiers, puis démarrez. Tout reste sur cet ordinateur.';

  @override
  String get convRemove => 'Retirer';

  @override
  String get convClear => 'Vider la liste';

  @override
  String get convStart => 'Démarrer';

  @override
  String get convStop => 'Arrêter';

  @override
  String get catVideo => 'Vidéo';

  @override
  String get catAudio => 'Audio';

  @override
  String get catImage => 'Image';

  @override
  String get fmtHelpMp4 => 'H.264 + AAC, lisible partout';

  @override
  String get fmtHelpMkv => 'Toutes les pistes et sous-titres';

  @override
  String get fmtHelpWebm => 'VP9 + Opus, pour le web';

  @override
  String get fmtHelpAvi => 'Anciens lecteurs et TV';

  @override
  String get fmtHelpMov => 'Montage, appareils Apple';

  @override
  String get fmtHelpGif => 'Animation courte sans son';

  @override
  String get fmtHelpMp3 => 'Lisible partout';

  @override
  String get fmtHelpM4a => 'AAC, appareils Apple';

  @override
  String get fmtHelpFlac => 'Sans perte';

  @override
  String get fmtHelpWav => 'Non compressé';

  @override
  String get fmtHelpOgg => 'Vorbis, format libre';

  @override
  String get fmtHelpOpus => 'Très léger, voix et musique';

  @override
  String get fmtHelpPng => 'Sans perte, transparence';

  @override
  String get fmtHelpJpg => 'Photos, léger';

  @override
  String get fmtHelpWebp => 'Web, très léger';

  @override
  String get fmtHelpIco => 'Icône Windows (256 px)';

  @override
  String get fmtHelpBmp => 'Non compressé';

  @override
  String get toolJoin => 'Fusionner';

  @override
  String get toolCut => 'Découper';

  @override
  String get toolCrop => 'Rogner';

  @override
  String get toolCompress => 'Compresser';

  @override
  String get toolFrames => 'Exporter les images';

  @override
  String get toolExtract => 'Extraire d’une vidéo';

  @override
  String get toolResize => 'Redimensionner';

  @override
  String get toolHelpJoinVideo => 'Plusieurs vidéos bout à bout, en un MP4';

  @override
  String get toolHelpJoinAudio => 'Plusieurs fichiers bout à bout, en un MP3';

  @override
  String get toolHelpCut => 'Garder une partie, sans réencoder';

  @override
  String get toolHelpCrop => 'Recadrer au centre : 16:9, 4:3, 1:1, 9:16';

  @override
  String get toolHelpCompress =>
      'Fichier bien plus léger, qualité proche de l’original (AV1 ou H.264)';

  @override
  String get toolHelpFrames => 'Une image JPG toutes les quelques secondes';

  @override
  String get toolHelpExtract => 'Garder le son, en MP3';

  @override
  String get toolHelpResize => 'Changer la largeur, proportions gardées';

  @override
  String convTo(String format) {
    return 'Convertir en $format';
  }

  @override
  String get convNoFiles => 'Aucun fichier. Ajoutez-en ou glissez-les ici.';

  @override
  String get convAddFiles => 'Ajouter des fichiers';

  @override
  String get convAddFolder => 'Ajouter un dossier';

  @override
  String convAddToList(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ajouter à la liste ($n)',
      zero: 'Ajouter à la liste',
    );
    return '$_temp0';
  }

  @override
  String get convJoinNeedsTwo => 'Ajoutez au moins deux fichiers à fusionner.';

  @override
  String get optQuality => 'Qualité';

  @override
  String get optSource => 'Source';

  @override
  String get optHigh => 'Haute';

  @override
  String get optMedium => 'Moyenne';

  @override
  String get optSmall => 'Petite';

  @override
  String get optResolution => 'Résolution';

  @override
  String get optBitrate => 'Débit';

  @override
  String get optKeep => 'Garder de… à…';

  @override
  String get optKeepHint => 'hh:mm:ss ; la fin vide = jusqu’au bout';

  @override
  String get optCrop => 'Format';

  @override
  String get optEvery => 'Une image toutes les';

  @override
  String get optWidth => 'Largeur';

  @override
  String get optOutDir => 'Dossier de sortie';

  @override
  String optSeconds(int n) {
    return '$n s';
  }

  @override
  String get colPreview => 'Aperçu';

  @override
  String colSource(int n) {
    return 'Source · $n';
  }

  @override
  String get colOutput => 'Sortie / état';

  @override
  String get stWaiting => 'En attente';

  @override
  String get stConverting => 'Conversion…';

  @override
  String get stDone => 'Terminé';

  @override
  String get stStopped => 'Arrêté';

  @override
  String get stFailed => 'Échec';

  @override
  String convLineFormat(String quality) {
    return 'Conversion · qualité $quality';
  }

  @override
  String get convLineSame => 'Conversion · qualité identique à la source';

  @override
  String convFiles(int n) {
    return '$n fichiers';
  }

  @override
  String get convEmptyTitle => 'La liste est vide';

  @override
  String get convEmptyBody =>
      'Choisissez un format à gauche, ou glissez des fichiers ici.';

  @override
  String get convDropHint =>
      'Glissez des fichiers ici pour les ajouter avec le dernier format choisi';

  @override
  String get convDropNoChoice =>
      'Choisissez d’abord un format ou un outil à gauche.';

  @override
  String get convMulti => 'Multi-conversion';

  @override
  String get convElapsed => 'Temps écoulé';

  @override
  String get convShutdown => 'Éteindre le PC à la fin';

  @override
  String get convNotify => 'Notifier';

  @override
  String get convDone => 'Conversion terminée';

  @override
  String get convOpenFolder => 'Ouvrir le dossier';

  @override
  String convRemoveRunning(String name) {
    return '« $name » est en cours de conversion. La retirer arrête sa conversion.';
  }

  @override
  String get convShutdownTitle => 'Le PC va s’éteindre';

  @override
  String get convShutdownBody =>
      'Les conversions sont terminées. Windows éteint le PC dans une minute.';

  @override
  String get convShutdownCancel => 'Annuler l’arrêt';

  @override
  String get convToolsMissing =>
      'Les outils média ne sont pas installés : analysez un lien dans Obtenir pour les installer.';

  @override
  String convFailed(String reason) {
    return 'Ajout impossible : $reason';
  }

  @override
  String get capTab => 'Capture d’écran';

  @override
  String get capIntroTitle => 'Capture depuis n’importe quelle application';

  @override
  String get capIntroBody =>
      'Les raccourcis fonctionnent même quand Miarina Media est réduite.';

  @override
  String get capTry => 'Essayer';

  @override
  String get capRegion => 'Capturer une zone';

  @override
  String get capRegionDesc => 'Assombrit l’écran ; tracez la zone à garder.';

  @override
  String get capFull => 'Capturer tout l’écran';

  @override
  String get capFullDesc =>
      'Capture immédiate de l’écran où se trouve la souris.';

  @override
  String get capRecord => 'Démarrer / arrêter l’enregistrement vidéo';

  @override
  String get capRecordDesc =>
      'Utilise les derniers réglages de l’enregistreur.';

  @override
  String get capEdit => 'Modifier';

  @override
  String get capCancel => 'Annuler';

  @override
  String get capListening => 'Appuyez sur la combinaison…';

  @override
  String get capNoKey => 'Aucun';

  @override
  String get capFormat => 'Format de l’image';

  @override
  String get capFormatDesc =>
      'PNG garde tous les détails ; JPG et WebP sont plus légers.';

  @override
  String get capDelay => 'Retardateur';

  @override
  String get capDelayDesc => 'Le temps d’ouvrir un menu avant la capture.';

  @override
  String get capDelayNone => 'Aucun';

  @override
  String capDelaySecs(int n) {
    return '$n s';
  }

  @override
  String get capSaveTo => 'Enregistrer dans';

  @override
  String get capOpenFolder => 'Ouvrir le dossier';

  @override
  String get capCopySetting => 'Copier dans le presse-papiers';

  @override
  String get capCopySettingDesc => 'Pour coller tout de suite avec Ctrl V.';

  @override
  String get capPreview => 'Afficher un aperçu';

  @override
  String get capPreviewDesc =>
      'Une vignette apparaît en bas à droite pendant 4 secondes.';

  @override
  String get capSound => 'Son d’obturateur';

  @override
  String get capCursor => 'Inclure le curseur';

  @override
  String get capNeedModifier =>
      'Il faut Ctrl, Alt ou Maj avec une autre touche.';

  @override
  String get capKeyUnsupported =>
      'Cette touche ne peut pas servir de raccourci global.';

  @override
  String capConflict(String keys, String action) {
    return '$keys sert déjà à « $action ».';
  }

  @override
  String capTaken(String keys) {
    return '$keys est déjà pris par une autre application.';
  }

  @override
  String get capTakenShort => 'Pris par une autre application';

  @override
  String get capHelp => 'Glissez pour choisir une zone';

  @override
  String get capHelpEnter => 'capturer';

  @override
  String get capHelpEsc => 'annuler';

  @override
  String get capKeyEnter => 'Entrée';

  @override
  String get capKeyEsc => 'Échap';

  @override
  String get capWholeScreen => 'Tout l’écran';

  @override
  String get capFilm => 'Filmer';

  @override
  String get capCopy => 'Copier';

  @override
  String get capSave => 'Enregistrer';

  @override
  String get capClose => 'Fermer';

  @override
  String get capCopied => 'Capture copiée dans le presse-papiers';

  @override
  String get capOpen => 'Ouvrir';

  @override
  String get capFailed => 'La capture n’a pas pu être faite.';

  @override
  String capPngFallback(String name) {
    return '$name (JPG/WebP indisponible : enregistrée en PNG)';
  }

  @override
  String get recNav => 'Enregistrer l’écran';

  @override
  String get recSubtitle =>
      'Filmez votre écran avec le son du PC et le micro. Les vidéos arrivent dans la bibliothèque.';

  @override
  String get recSourceTitle => 'Source';

  @override
  String get recScreen => 'Plein écran';

  @override
  String recScreenDesc(int n, int w, int h) {
    return 'Écran $n · $w × $h. Choisissez l’écran si vous en avez plusieurs.';
  }

  @override
  String recScreenN(int n) {
    return 'Écran $n';
  }

  @override
  String get recWindow => 'Une fenêtre';

  @override
  String get recWindowDesc => 'Seule la fenêtre choisie est filmée.';

  @override
  String get recPickWindow => 'Choisir la fenêtre';

  @override
  String get recNoWindows => 'Aucune fenêtre à filmer.';

  @override
  String get recRegion => 'Une zone';

  @override
  String get recRegionDesc =>
      'Tracez un rectangle sur l’écran avant de démarrer.';

  @override
  String recRegionSize(int w, int h) {
    return 'Zone $w × $h';
  }

  @override
  String get recDraw => 'Tracer la zone';

  @override
  String get recVideo => 'Vidéo';

  @override
  String get recFormat => 'Format';

  @override
  String get recFps => 'Images par seconde';

  @override
  String get recQuality => 'Qualité';

  @override
  String get recQMedium => 'Moyenne';

  @override
  String get recQHigh => 'Haute';

  @override
  String get recQOriginal => 'Originale';

  @override
  String get recFolder => 'Dossier';

  @override
  String get recSoundOptions => 'Son et options';

  @override
  String get recSystemAudio => 'Son du PC';

  @override
  String get recSystemAudioDesc =>
      'Ce que vous entendez dans les haut-parleurs';

  @override
  String get recMic => 'Micro';

  @override
  String get recMicDesc => 'Microphone par défaut de Windows';

  @override
  String get recCursor => 'Afficher le curseur';

  @override
  String get recCursorDesc => 'Le pointeur de la souris apparaît dans la vidéo';

  @override
  String get recCountdown => 'Compte à rebours';

  @override
  String get recCountdownDesc => '3 secondes avant de démarrer';

  @override
  String get recStart => 'Démarrer l’enregistrement';

  @override
  String recStopAt(String time) {
    return 'Arrêter · $time';
  }

  @override
  String get recOrPress => 'ou appuyez sur';

  @override
  String get recAnywhere => 'n’importe où';

  @override
  String get recFpsUnit => 'i/s';

  @override
  String get recSumSystem => 'son du PC';

  @override
  String get recSumNoSystem => 'sans son du PC';

  @override
  String get recSumMic => 'micro';

  @override
  String get recSumNoSound => 'sans son';

  @override
  String get recRecent => 'Enregistrements récents';

  @override
  String get recEmpty => 'Aucun enregistrement pour l’instant.';

  @override
  String get recSaved => 'Enregistré';

  @override
  String get recMissing => 'Fichier introuvable';

  @override
  String get recPlay => 'Lire';

  @override
  String get recConvert => 'Convertir';

  @override
  String get recShowFolder => 'Afficher dans le dossier';

  @override
  String get recRemove => 'Retirer de la liste';

  @override
  String get recRec => 'REC';

  @override
  String get recPausedLabel => 'PAUSE';

  @override
  String get recPause => 'Pause';

  @override
  String get recResume => 'Reprendre';

  @override
  String get recMicMute => 'Couper le micro';

  @override
  String get recMicUnmute => 'Activer le micro';

  @override
  String get recStop => 'Arrêter';

  @override
  String get recFinalizing => 'Finalisation…';

  @override
  String get recStarting => 'Démarrage dans';

  @override
  String get recSavedToast => 'Vidéo enregistrée dans la bibliothèque';

  @override
  String get recGifSaved => 'GIF enregistré';

  @override
  String get recFailed => 'L’enregistrement n’a pas pu démarrer.';

  @override
  String get recFinishFailed =>
      'La vidéo n’a pas pu être finalisée ; les morceaux restent dans le dossier.';

  @override
  String get recWindowGone => 'La fenêtre choisie n’est plus ouverte.';

  @override
  String get recNoScreen => 'Aucun écran trouvé.';

  @override
  String get recFileWord => 'Enregistrement';

  @override
  String get recConvertPick =>
      'Choisissez un format ou un outil : le fichier sera ajouté.';

  @override
  String get toolRecord => 'Enregistrer l’écran';

  @override
  String get toolHelpRecord => 'Filmer l’écran, une fenêtre ou une zone.';

  @override
  String get videoGestures => 'Gestes vidéo';

  @override
  String get videoGesturesBody =>
      'Glisser à gauche : luminosité ; à droite : volume. Double-toucher les côtés : ±10 s. Pincer : remplir l’écran.';

  @override
  String get gestBrightness => 'Luminosité';

  @override
  String get gestVolume => 'Volume';

  @override
  String gestJump(String sign, int n) {
    return '$sign$n s';
  }

  @override
  String get lockControls => 'Verrouiller l’écran';

  @override
  String get unlockControls => 'Déverrouiller';

  @override
  String get pipEnter => 'Image dans l’image';

  @override
  String get rotateScreen => 'Tourner l’écran';

  @override
  String get fillScreen => 'Remplir l’écran';

  @override
  String get fitScreen => 'Image entière';

  @override
  String playlistExportAndroid(String path) {
    return 'Exportée dans $path';
  }

  @override
  String videoTracksN(int n) {
    return '$n pistes';
  }

  @override
  String videoSubsN(int n) {
    return '$n ST';
  }

  @override
  String get listenOnly => 'Écouter seulement';

  @override
  String get showVideo => 'Revoir la vidéo';

  @override
  String get tourWelcomeTitle => 'Bienvenue dans Miarina Media';

  @override
  String get tourWelcomeBody =>
      'Une visite rapide des endroits principaux. Vous pouvez la passer et la revoir plus tard dans Réglages › Général.';

  @override
  String get tourSpaceTitle => 'Deux espaces';

  @override
  String get tourSpaceBody =>
      'Obtenir pour télécharger des vidéos et de la musique, Écouter pour votre bibliothèque. Passez de l’un à l’autre ici.';

  @override
  String get tourLinkTitle => 'Coller un lien';

  @override
  String get tourLinkBody =>
      'Collez l’adresse d’une vidéo ou d’une playlist : Miarina Media l’analyse et vous propose les formats et qualités.';

  @override
  String get tourToolsTitle => 'Outils PC';

  @override
  String get tourToolsBody =>
      'Enregistrer l’écran et convertir vos fichiers (MP4, MP3, 3GP…). La capture d’écran se règle dans Réglages.';

  @override
  String get tourLibraryTitle => 'Votre bibliothèque';

  @override
  String get tourLibraryBody =>
      'Musique, films et séries, Focus pour les podcasts et les cours : tout ce que vous téléchargez ou ajoutez arrive ici.';

  @override
  String get tourSearchTitle => 'Rechercher';

  @override
  String get tourSearchBody =>
      'Titres, albums, films et podcasts, depuis n’importe quel écran. Raccourci : Ctrl K.';

  @override
  String get tourPlaybarTitle => 'Lecture';

  @override
  String get tourPlaybarBody =>
      'Ce qui joue : pause, titre suivant, volume. Cliquez sur la pochette pour ouvrir le lecteur complet.';

  @override
  String get tourSettingsTitle => 'Réglages';

  @override
  String get tourSettingsBody =>
      'Thème et langue, dossier des téléchargements, raccourcis, capture d’écran et mises à jour.';

  @override
  String get tourSkip => 'Passer la visite';

  @override
  String get tourBack => 'Précédent';

  @override
  String get tourNext => 'Suivant';

  @override
  String get tourDone => 'Terminer';

  @override
  String get tourReplay => 'Visite guidée';

  @override
  String get tourReplayBody => 'Revoir la présentation des écrans principaux.';

  @override
  String get tourStart => 'Lancer';

  @override
  String get fmtHelp3gp => 'Anciens téléphones, fichier léger';

  @override
  String get optCodec => 'Codec';

  @override
  String get optCodecAv1 => 'AV1';

  @override
  String get optCodecH264 => 'H.264';

  @override
  String get optCodecAv1Note =>
      '20 à 35 % plus léger à qualité égale. Lisible sur Windows 10 et 11, Android 10 et plus, les navigateurs récents et Miarina Media. Encodage plus long (environ la moitié de la durée de la vidéo).';

  @override
  String get optCodecH264Note =>
      'Lisible sur tous les appareils, même anciens. Fichier plus gros qu’en AV1 pour la même qualité.';

  @override
  String get optGoal => 'Objectif';

  @override
  String get optGoalQuality => 'Qualité';

  @override
  String get optGoalSize => 'Taille maximale';

  @override
  String get optBalanced => 'Équilibrée';

  @override
  String get optTargetMb => 'Taille max. par fichier';

  @override
  String get optMb => 'Mo';

  @override
  String get deviceBannerTitle =>
      'La musique de ce téléphone n\'est pas encore affichée';

  @override
  String get deviceBannerAllow => 'Autoriser l\'accès';

  @override
  String get share => 'Partager';

  @override
  String get shareFailed => 'Ce fichier ne peut pas être partagé';

  @override
  String get deleteFromPhone => 'Supprimer du téléphone';

  @override
  String get deleteFailed => 'Le fichier n\'a pas pu être supprimé';

  @override
  String deletedFromPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers supprimés du téléphone',
      one: 'Supprimé du téléphone',
    );
    return '$_temp0';
  }

  @override
  String get on => 'Activé';

  @override
  String get skipBack10 => 'Reculer de 10 secondes';

  @override
  String get skipForward10 => 'Avancer de 10 secondes';

  @override
  String get showVinyl => 'Afficher le vinyle';

  @override
  String get viewAlbum => 'Voir l\'album';

  @override
  String get viewArtist => 'Voir l\'artiste';

  @override
  String get trackInfo => 'Infos du morceau';

  @override
  String get trackPlays => 'Écoutes';

  @override
  String get trackFile => 'Fichier';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get quickRecent => 'Récents';

  @override
  String get quickMostPlayed => 'Plus joués';

  @override
  String get dailyMix => 'Mix du jour';

  @override
  String get recentlyPlayed => 'Récemment joués';

  @override
  String get recentlyAddedAlbums => 'Récemment ajoutés';

  @override
  String get mostPlayedTitle => 'Les plus joués';

  @override
  String get yourArtists => 'Vos artistes';

  @override
  String get counterNever => 'Jamais écoutés';

  @override
  String get counterAdded => 'Ajoutés ce mois';

  @override
  String get discoverTitle => 'À découvrir';

  @override
  String discoverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres jamais écoutés',
      one: '1 titre jamais écouté',
    );
    return '$_temp0';
  }

  @override
  String get shufflePlay => 'Lecture aléatoire';

  @override
  String get randomAlbum => 'Album au hasard';

  @override
  String get artistOfWeek => 'Artiste de la semaine';

  @override
  String get last7Days => '7 derniers jours';

  @override
  String get shuffleAll => 'Tout mélanger';

  @override
  String get addAllToQueue => 'Tout ajouter à la file';

  @override
  String get noListenYet =>
      'Écoutez de la musique pour voir ici votre temps d\'écoute.';

  @override
  String minutesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
      zero: '0 minute',
    );
    return '$_temp0';
  }

  @override
  String get phoneLibrary => 'Bibliothèque';

  @override
  String get updAllowInstall =>
      'Autorisez Miarina Media à installer des applications (l\'écran vient de s\'ouvrir), puis appuyez de nouveau sur « Installer maintenant ».';

  @override
  String get updAndroidNote =>
      'Android ouvre l\'installation : appuyez sur « Mettre à jour ». Votre bibliothèque, vos playlists, vos positions de lecture et vos réglages sont conservés. Rien n\'est installé sans votre accord.';

  @override
  String get vinylChip => 'Vinyle';

  @override
  String get navOnline => 'En ligne';

  @override
  String get onlinePlaceholder => 'Rechercher un titre ou un artiste en ligne';

  @override
  String get onlineHintTitle => 'Cherchez un titre ou un artiste';

  @override
  String get onlineRecent => 'Recherches récentes';

  @override
  String get onlineClearRecent => 'Effacer';

  @override
  String onlineRemoveRecent(String query) {
    return 'Retirer « $query »';
  }

  @override
  String onlineNoResult(String query) {
    return 'Aucun résultat en ligne pour « $query »';
  }

  @override
  String get onlineMore => 'Plus de résultats';

  @override
  String get onlineToolsTitle => 'L\'extracteur n\'est pas installé';

  @override
  String get onlineToolsInstall => 'Installer les outils';

  @override
  String get onlineOfflineTitle => 'Pas de connexion';

  @override
  String get onlineOpenTracks => 'Voir mes titres';

  @override
  String get onlineBlockedTitle => 'YouTube limite les requêtes';

  @override
  String get onlineBlockedBody => 'Réessayez dans quelques minutes.';

  @override
  String get onlineErrorTitle => 'La recherche en ligne a échoué';

  @override
  String get onlineErrorBody =>
      'Réessayez. Si cela continue, mettez à jour l\'extracteur dans Obtenir.';

  @override
  String onlineObtainTitle(String title) {
    return 'Obtenir « $title »';
  }

  @override
  String get onlineFormatOriginal => 'Original';

  @override
  String get onlineFormatMp3High => 'MP3 320 kbps';

  @override
  String get onlineFormatMp3Low => 'MP3 128 kbps';

  @override
  String get onlineFormatAlways => 'Toujours utiliser ce format';

  @override
  String get onlineFormatAsk => 'Demander';

  @override
  String onlineObtainStarted(String title) {
    return 'Obtention lancée : $title';
  }

  @override
  String onlineObtainAuto(String title) {
    return 'Ajouté hors connexion : $title';
  }

  @override
  String get onlineObtainFailed => 'L\'obtention n\'a pas pu démarrer.';

  @override
  String get onlineSeeDownloads => 'Voir';

  @override
  String get onlineOffline => 'Hors connexion';

  @override
  String get onlineObtaining => 'Obtention…';

  @override
  String get onlineSettingsSection => 'Écoute en ligne';

  @override
  String get onlineAutoObtain => 'Obtenir les titres écoutés en entier';

  @override
  String get onlineObtainFormat => 'Format d\'Obtenir';

  @override
  String get onlineSlowTitle => 'YouTube ne répond pas';
}

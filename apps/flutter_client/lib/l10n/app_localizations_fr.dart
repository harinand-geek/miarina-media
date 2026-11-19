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
}

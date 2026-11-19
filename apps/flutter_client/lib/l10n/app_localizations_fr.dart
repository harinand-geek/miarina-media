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
}

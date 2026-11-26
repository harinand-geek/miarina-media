import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_mg.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('mg'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media'**
  String get appTitle;

  /// No description provided for @spaceGet.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir'**
  String get spaceGet;

  /// No description provided for @spaceListen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get spaceListen;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navSectionMusic.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get navSectionMusic;

  /// No description provided for @navAlbums.
  ///
  /// In fr, this message translates to:
  /// **'Albums'**
  String get navAlbums;

  /// No description provided for @navArtists.
  ///
  /// In fr, this message translates to:
  /// **'Artistes'**
  String get navArtists;

  /// No description provided for @navTracks.
  ///
  /// In fr, this message translates to:
  /// **'Titres'**
  String get navTracks;

  /// No description provided for @navPlaylists.
  ///
  /// In fr, this message translates to:
  /// **'Playlists'**
  String get navPlaylists;

  /// No description provided for @navFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get navFavorites;

  /// No description provided for @navSectionCinema.
  ///
  /// In fr, this message translates to:
  /// **'Cinéma'**
  String get navSectionCinema;

  /// No description provided for @navMovies.
  ///
  /// In fr, this message translates to:
  /// **'Films & séries'**
  String get navMovies;

  /// No description provided for @navPersonalVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos perso'**
  String get navPersonalVideos;

  /// No description provided for @navSectionFocus.
  ///
  /// In fr, this message translates to:
  /// **'Focus'**
  String get navSectionFocus;

  /// No description provided for @navPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts & cours'**
  String get navPodcasts;

  /// No description provided for @navAudiobooks.
  ///
  /// In fr, this message translates to:
  /// **'Livres audio'**
  String get navAudiobooks;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get navSettings;

  /// No description provided for @tabMusic.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get tabMusic;

  /// No description provided for @tabCinema.
  ///
  /// In fr, this message translates to:
  /// **'Cinéma'**
  String get tabCinema;

  /// No description provided for @tabFocus.
  ///
  /// In fr, this message translates to:
  /// **'Focus'**
  String get tabFocus;

  /// No description provided for @tabGet.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir'**
  String get tabGet;

  /// No description provided for @searchPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher titres, films, podcasts…'**
  String get searchPlaceholder;

  /// No description provided for @play.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @previous.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @shuffle.
  ///
  /// In fr, this message translates to:
  /// **'Aléatoire'**
  String get shuffle;

  /// No description provided for @repeatOff.
  ///
  /// In fr, this message translates to:
  /// **'Répéter : non'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In fr, this message translates to:
  /// **'Répéter : tout'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In fr, this message translates to:
  /// **'Répéter : ce titre'**
  String get repeatOne;

  /// No description provided for @lyrics.
  ///
  /// In fr, this message translates to:
  /// **'Paroles'**
  String get lyrics;

  /// No description provided for @queue.
  ///
  /// In fr, this message translates to:
  /// **'File d\'attente'**
  String get queue;

  /// No description provided for @miniPlayer.
  ///
  /// In fr, this message translates to:
  /// **'Mini-lecteur (Ctrl M)'**
  String get miniPlayer;

  /// No description provided for @volume.
  ///
  /// In fr, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @mute.
  ///
  /// In fr, this message translates to:
  /// **'Couper le son'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir le son'**
  String get unmute;

  /// No description provided for @favoriteAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get favoriteRemove;

  /// No description provided for @seek.
  ///
  /// In fr, this message translates to:
  /// **'Position de lecture'**
  String get seek;

  /// No description provided for @nothingPlaying.
  ///
  /// In fr, this message translates to:
  /// **'Rien en lecture'**
  String get nothingPlaying;

  /// No description provided for @openNowPlaying.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir En lecture'**
  String get openNowPlaying;

  /// No description provided for @windowMinimize.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get windowClose;

  /// No description provided for @tracksSummary.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun titre} =1{1 titre} other{{count} titres}}'**
  String tracksSummary(int count);

  /// No description provided for @tracksEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun titre pour l\'instant'**
  String get tracksEmptyTitle;

  /// No description provided for @tracksEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un dossier de musique ou téléchargez un titre depuis Obtenir.'**
  String get tracksEmptyBody;

  /// No description provided for @colTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get colTitle;

  /// No description provided for @colArtist.
  ///
  /// In fr, this message translates to:
  /// **'Artiste'**
  String get colArtist;

  /// No description provided for @colAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Album'**
  String get colAlbum;

  /// No description provided for @colFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get colFormat;

  /// No description provided for @colDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get colDuration;

  /// No description provided for @fileMissing.
  ///
  /// In fr, this message translates to:
  /// **'Fichier introuvable'**
  String get fileMissing;

  /// No description provided for @libraryError.
  ///
  /// In fr, this message translates to:
  /// **'La bibliothèque n\'a pas pu être lue.'**
  String get libraryError;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @playbackUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'La lecture n\'est pas encore disponible sur cette plateforme.'**
  String get playbackUnsupported;

  /// No description provided for @unknownArtist.
  ///
  /// In fr, this message translates to:
  /// **'Artiste inconnu'**
  String get unknownArtist;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// No description provided for @filterTracks.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les titres'**
  String get filterTracks;

  /// No description provided for @playAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout lire'**
  String get playAll;

  /// No description provided for @nowPlaying.
  ///
  /// In fr, this message translates to:
  /// **'En lecture'**
  String get nowPlaying;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @tabQueue.
  ///
  /// In fr, this message translates to:
  /// **'File'**
  String get tabQueue;

  /// No description provided for @tabSound.
  ///
  /// In fr, this message translates to:
  /// **'Son'**
  String get tabSound;

  /// No description provided for @nowCurrent.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get nowCurrent;

  /// No description provided for @upNext.
  ///
  /// In fr, this message translates to:
  /// **'À suivre'**
  String get upNext;

  /// No description provided for @clearQueue.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get clearQueue;

  /// No description provided for @smartQueueTitle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec des titres proches'**
  String get smartQueueTitle;

  /// No description provided for @smartQueueBody.
  ///
  /// In fr, this message translates to:
  /// **'Même artiste ou même album, calculé sur l’appareil'**
  String get smartQueueBody;

  /// No description provided for @lyricsHint.
  ///
  /// In fr, this message translates to:
  /// **'{file} · clic sur une ligne pour y aller'**
  String lyricsHint(String file);

  /// No description provided for @lyricsNoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de paroles pour ce titre'**
  String get lyricsNoneTitle;

  /// No description provided for @equalizer.
  ///
  /// In fr, this message translates to:
  /// **'Égaliseur'**
  String get equalizer;

  /// No description provided for @equalizerBody.
  ///
  /// In fr, this message translates to:
  /// **'Appliqué à toute la lecture audio'**
  String get equalizerBody;

  /// No description provided for @equalizerUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne propose pas d\'égaliseur pour la lecture.'**
  String get equalizerUnsupported;

  /// No description provided for @eqFlat.
  ///
  /// In fr, this message translates to:
  /// **'Neutre'**
  String get eqFlat;

  /// No description provided for @eqBass.
  ///
  /// In fr, this message translates to:
  /// **'Basses'**
  String get eqBass;

  /// No description provided for @eqVoice.
  ///
  /// In fr, this message translates to:
  /// **'Voix'**
  String get eqVoice;

  /// No description provided for @eqRock.
  ///
  /// In fr, this message translates to:
  /// **'Rock'**
  String get eqRock;

  /// No description provided for @eqClassic.
  ///
  /// In fr, this message translates to:
  /// **'Classique'**
  String get eqClassic;

  /// No description provided for @eqCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get eqCustom;

  /// No description provided for @speed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse'**
  String get speed;

  /// No description provided for @normalization.
  ///
  /// In fr, this message translates to:
  /// **'Normalisation du volume'**
  String get normalization;

  /// No description provided for @normalizationBody.
  ///
  /// In fr, this message translates to:
  /// **'ReplayGain si présent'**
  String get normalizationBody;

  /// No description provided for @sleepTimer.
  ///
  /// In fr, this message translates to:
  /// **'Minuteur'**
  String get sleepTimer;

  /// No description provided for @sleepMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String sleepMinutes(int minutes);

  /// No description provided for @sleepEndOfTrack.
  ///
  /// In fr, this message translates to:
  /// **'Fin du titre'**
  String get sleepEndOfTrack;

  /// No description provided for @sleepOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le minuteur'**
  String get sleepOff;

  /// No description provided for @sleepRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt dans {time}'**
  String sleepRemaining(String time);

  /// No description provided for @upNextEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien après ce titre.'**
  String get upNextEmpty;

  /// No description provided for @removeFromQueue.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la file'**
  String get removeFromQueue;

  /// No description provided for @closePlayer.
  ///
  /// In fr, this message translates to:
  /// **'Réduire le lecteur'**
  String get closePlayer;

  /// No description provided for @showLyrics.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les paroles'**
  String get showLyrics;

  /// No description provided for @showCover.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la pochette'**
  String get showCover;

  /// No description provided for @moreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get moreOptions;

  /// No description provided for @albumsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun album} =1{1 album} other{{count} albums}}'**
  String albumsCount(int count);

  /// No description provided for @artistsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun artiste} =1{1 artiste} other{{count} artistes}}'**
  String artistsCount(int count);

  /// No description provided for @artistsGrouping.
  ///
  /// In fr, this message translates to:
  /// **'regroupés selon le tag « Artiste de l\'album »'**
  String get artistsGrouping;

  /// No description provided for @albumsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'album'**
  String get albumsEmptyTitle;

  /// No description provided for @albumsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les albums viennent des tags des fichiers (album, artiste). Aucun titre de la bibliothèque n\'en a pour l\'instant.'**
  String get albumsEmptyBody;

  /// No description provided for @artistsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'artiste'**
  String get artistsEmptyTitle;

  /// No description provided for @artistsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les artistes viennent des tags des fichiers. Aucun titre de la bibliothèque n\'en a pour l\'instant.'**
  String get artistsEmptyBody;

  /// No description provided for @albumOverline.
  ///
  /// In fr, this message translates to:
  /// **'Album'**
  String get albumOverline;

  /// No description provided for @albumTracks.
  ///
  /// In fr, this message translates to:
  /// **'Titres de l\'album'**
  String get albumTracks;

  /// No description provided for @artistTracks.
  ///
  /// In fr, this message translates to:
  /// **'Titres'**
  String get artistTracks;

  /// No description provided for @groupMissing.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément n\'est plus dans la bibliothèque.'**
  String get groupMissing;

  /// No description provided for @playVerb.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get playVerb;

  /// No description provided for @homeResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get homeResume;

  /// No description provided for @homeResumeKind.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre · {kind}'**
  String homeResumeKind(String kind);

  /// No description provided for @homeResumeAt.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre à {time}'**
  String homeResumeAt(String time);

  /// No description provided for @minutesLeft.
  ///
  /// In fr, this message translates to:
  /// **'{minutes, plural, =0{moins d\'une minute restante} =1{1 min restante} other{{minutes} min restantes}}'**
  String minutesLeft(int minutes);

  /// No description provided for @openAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'album'**
  String get openAlbum;

  /// No description provided for @autoLists.
  ///
  /// In fr, this message translates to:
  /// **'Vos listes automatiques'**
  String get autoLists;

  /// No description provided for @listMostPlayed.
  ///
  /// In fr, this message translates to:
  /// **'Écoutés souvent'**
  String get listMostPlayed;

  /// No description provided for @listRecentlyAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutés récemment'**
  String get listRecentlyAdded;

  /// No description provided for @listRecentlyAddedBody.
  ///
  /// In fr, this message translates to:
  /// **'Les derniers titres arrivés dans la bibliothèque'**
  String get listRecentlyAddedBody;

  /// No description provided for @listFavoritesBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos titres favoris'**
  String get listFavoritesBody;

  /// No description provided for @andOthers.
  ///
  /// In fr, this message translates to:
  /// **'{names} et {count} autres'**
  String andOthers(String names, int count);

  /// No description provided for @fullQueue.
  ///
  /// In fr, this message translates to:
  /// **'File complète'**
  String get fullQueue;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get seeAll;

  /// No description provided for @recentAlbums.
  ///
  /// In fr, this message translates to:
  /// **'Albums récents'**
  String get recentAlbums;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre espace d\'écoute est prêt'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'a encore été écouté et la bibliothèque est vide. Ajoutez de la musique depuis Obtenir, ou ouvrez un fichier.'**
  String get homeEmptyBody;

  /// No description provided for @goTracks.
  ///
  /// In fr, this message translates to:
  /// **'Voir les titres'**
  String get goTracks;

  /// No description provided for @goGet.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir de la musique'**
  String get goGet;

  /// No description provided for @nowPlayingHint.
  ///
  /// In fr, this message translates to:
  /// **'Lancez un titre : il apparaîtra ici, avec ses paroles et la suite de la file.'**
  String get nowPlayingHint;

  /// No description provided for @filmsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun film} =1{1 film} other{{count} films}}'**
  String filmsCount(int count);

  /// No description provided for @seriesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucune série} =1{1 série} other{{count} séries}}'**
  String seriesCount(int count);

  /// No description provided for @videosCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucune vidéo} =1{1 vidéo} other{{count} vidéos}}'**
  String videosCount(int count);

  /// No description provided for @seasonsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 saison} other{{count} saisons}}'**
  String seasonsCount(int count);

  /// No description provided for @segAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get segAll;

  /// No description provided for @segFilms.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get segFilms;

  /// No description provided for @segSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get segSeries;

  /// No description provided for @sortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier'**
  String get sortBy;

  /// No description provided for @sortTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get sortTitle;

  /// No description provided for @sortAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajout récent'**
  String get sortAdded;

  /// No description provided for @minutesShort.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @kindFilm.
  ///
  /// In fr, this message translates to:
  /// **'Film'**
  String get kindFilm;

  /// No description provided for @kindPersonal.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo perso'**
  String get kindPersonal;

  /// No description provided for @resumeAtShort.
  ///
  /// In fr, this message translates to:
  /// **'reprendre à {time}'**
  String resumeAtShort(String time);

  /// No description provided for @episodeShort.
  ///
  /// In fr, this message translates to:
  /// **'S{season} É{episode}'**
  String episodeShort(int season, int episode);

  /// No description provided for @episodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'É{episode} · {title}'**
  String episodeLabel(int episode, String title);

  /// No description provided for @episodeNumber.
  ///
  /// In fr, this message translates to:
  /// **'Épisode {episode}'**
  String episodeNumber(int episode);

  /// No description provided for @cinemaEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun film ni série pour l\'instant'**
  String get cinemaEmptyTitle;

  /// No description provided for @cinemaEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos de 40 minutes ou plus apparaissent ici comme films. Les fichiers nommés comme S01E04, ou avec le tag Série, forment des séries.'**
  String get cinemaEmptyBody;

  /// No description provided for @cinemaNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Rien dans cette catégorie pour l\'instant.'**
  String get cinemaNoMatch;

  /// No description provided for @personalEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vidéo perso'**
  String get personalEmptyTitle;

  /// No description provided for @personalEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos courtes de la bibliothèque (clips, vidéos du téléphone) apparaissent ici.'**
  String get personalEmptyBody;

  /// No description provided for @seriesWord.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get seriesWord;

  /// No description provided for @seriesMissing.
  ///
  /// In fr, this message translates to:
  /// **'Cette série n\'est plus dans la bibliothèque.'**
  String get seriesMissing;

  /// No description provided for @resumeEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre S{season} · É{episode} à {time}'**
  String resumeEpisode(int season, int episode, String time);

  /// No description provided for @playEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Lire S{season} · É{episode}'**
  String playEpisode(int season, int episode);

  /// No description provided for @fromStart.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le début'**
  String get fromStart;

  /// No description provided for @seasonNumber.
  ///
  /// In fr, this message translates to:
  /// **'Saison {season}'**
  String seasonNumber(int season);

  /// No description provided for @seenOf.
  ///
  /// In fr, this message translates to:
  /// **'{seen} vus sur {total}'**
  String seenOf(int seen, int total);

  /// No description provided for @watched.
  ///
  /// In fr, this message translates to:
  /// **'Vu'**
  String get watched;

  /// No description provided for @resumeAtLeft.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre à {time} · {left}'**
  String resumeAtLeft(String time, String left);

  /// No description provided for @subtitlesLangs.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres {langs}'**
  String subtitlesLangs(String langs);

  /// No description provided for @subtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get subtitles;

  /// No description provided for @subtitlesOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés'**
  String get subtitlesOff;

  /// No description provided for @subtitlesLoad.
  ///
  /// In fr, this message translates to:
  /// **'Charger un fichier SRT / VTT / ASS…'**
  String get subtitlesLoad;

  /// No description provided for @subtitlesExternal.
  ///
  /// In fr, this message translates to:
  /// **'externe'**
  String get subtitlesExternal;

  /// No description provided for @audioTrack.
  ///
  /// In fr, this message translates to:
  /// **'Piste audio'**
  String get audioTrack;

  /// No description provided for @noTracks.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre piste dans ce fichier'**
  String get noTracks;

  /// No description provided for @replay10.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 10 s'**
  String get replay10;

  /// No description provided for @forward10.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 10 s'**
  String get forward10;

  /// No description provided for @fullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran (F)'**
  String get fullscreen;

  /// No description provided for @fullscreenExit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le plein écran (Échap)'**
  String get fullscreenExit;

  /// No description provided for @chapters.
  ///
  /// In fr, this message translates to:
  /// **'Chapitres'**
  String get chapters;

  /// No description provided for @chaptersSoon.
  ///
  /// In fr, this message translates to:
  /// **'Les chapitres du fichier s\'afficheront ici.'**
  String get chaptersSoon;

  /// No description provided for @nextEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant'**
  String get nextEpisode;

  /// No description provided for @autoNext.
  ///
  /// In fr, this message translates to:
  /// **'Lecture auto à la fin'**
  String get autoNext;

  /// No description provided for @videoLoading.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture de la vidéo…'**
  String get videoLoading;

  /// No description provided for @videoUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vidéo en cours'**
  String get videoUnavailable;

  /// No description provided for @podcastsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun podcast} =1{1 podcast} other{{count} podcasts}}'**
  String podcastsCount(int count);

  /// No description provided for @coursesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun cours} =1{1 cours} other{{count} cours}}'**
  String coursesCount(int count);

  /// No description provided for @audiobooksCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun livre audio} =1{1 livre audio} other{{count} livres audio}}'**
  String audiobooksCount(int count);

  /// No description provided for @hoursTotal.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h'**
  String hoursTotal(int hours);

  /// No description provided for @segPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get segPodcasts;

  /// No description provided for @segCourses.
  ///
  /// In fr, this message translates to:
  /// **'Cours'**
  String get segCourses;

  /// No description provided for @segBooks.
  ///
  /// In fr, this message translates to:
  /// **'Livres audio'**
  String get segBooks;

  /// No description provided for @focusInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get focusInProgress;

  /// No description provided for @focusLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get focusLibrary;

  /// No description provided for @kindPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Podcast'**
  String get kindPodcast;

  /// No description provided for @kindCourse.
  ///
  /// In fr, this message translates to:
  /// **'Cours'**
  String get kindCourse;

  /// No description provided for @kindAudiobook.
  ///
  /// In fr, this message translates to:
  /// **'Livre audio'**
  String get kindAudiobook;

  /// No description provided for @episodesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 épisode} other{{count} épisodes}}'**
  String episodesCount(int count);

  /// No description provided for @lessonsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 leçon} other{{count} leçons}}'**
  String lessonsCount(int count);

  /// No description provided for @partsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 partie} other{{count} parties}}'**
  String partsCount(int count);

  /// No description provided for @leftAtRate.
  ///
  /// In fr, this message translates to:
  /// **'reste {left} à {rate}'**
  String leftAtRate(String left, String rate);

  /// No description provided for @focusOrderHint.
  ///
  /// In fr, this message translates to:
  /// **'Ordre lu depuis les numéros des fichiers (01, 02…) ou les tags.'**
  String get focusOrderHint;

  /// No description provided for @focusEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun podcast, cours ou livre audio'**
  String get focusEmptyTitle;

  /// No description provided for @focusEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Un fichier audio rejoint Focus par son genre (Podcast, Cours, Livre audio), par un dossier nommé Podcasts, Cours ou Livres audio, ou s\'il est au format .m4b.'**
  String get focusEmptyBody;

  /// No description provided for @focusNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Rien dans cette catégorie pour l\'instant.'**
  String get focusNoMatch;

  /// No description provided for @programPosition.
  ///
  /// In fr, this message translates to:
  /// **'{kind} {number} sur {total}'**
  String programPosition(String kind, int number, int total);

  /// No description provided for @estimatedEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin estimée {time} à {rate}'**
  String estimatedEnd(String time, String rate);

  /// No description provided for @forward30.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 30 s'**
  String get forward30;

  /// No description provided for @bookmark.
  ///
  /// In fr, this message translates to:
  /// **'Signet'**
  String get bookmark;

  /// No description provided for @bookmarkAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un signet (B)'**
  String get bookmarkAdd;

  /// No description provided for @bookmarks.
  ///
  /// In fr, this message translates to:
  /// **'Signets'**
  String get bookmarks;

  /// No description provided for @bookmarkNoNote.
  ///
  /// In fr, this message translates to:
  /// **'Signet sans note'**
  String get bookmarkNoNote;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signet pour l\'instant.'**
  String get bookmarksEmpty;

  /// No description provided for @bookmarksHint.
  ///
  /// In fr, this message translates to:
  /// **'B ajoute un signet à la position courante. Exportables en texte avec le cours.'**
  String get bookmarksHint;

  /// No description provided for @bookmarkRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le signet'**
  String get bookmarkRemove;

  /// No description provided for @chaptersNone.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'a pas de chapitres.'**
  String get chaptersNone;

  /// No description provided for @transcript.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get transcript;

  /// No description provided for @futureBadge.
  ///
  /// In fr, this message translates to:
  /// **'FUTUR'**
  String get futureBadge;

  /// No description provided for @transcriptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transcription — fonction future'**
  String get transcriptTitle;

  /// No description provided for @transcriptBody.
  ///
  /// In fr, this message translates to:
  /// **'Un fichier .txt ou .vtt du même nom placé à côté du fichier est affiché ici. La génération locale et la recherche dans les transcriptions viendront plus tard.'**
  String get transcriptBody;

  /// No description provided for @sleepEndOfChapter.
  ///
  /// In fr, this message translates to:
  /// **'Minuteur : fin du chapitre'**
  String get sleepEndOfChapter;

  /// No description provided for @sleepEndOfEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Minuteur : fin du fichier'**
  String get sleepEndOfEpisode;

  /// No description provided for @skipSilence.
  ///
  /// In fr, this message translates to:
  /// **'Sauter les silences'**
  String get skipSilence;

  /// No description provided for @voiceBoost.
  ///
  /// In fr, this message translates to:
  /// **'Voix renforcée'**
  String get voiceBoost;

  /// No description provided for @p1Later.
  ///
  /// In fr, this message translates to:
  /// **'pour les deux dernières'**
  String get p1Later;

  /// No description provided for @navHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get navHistory;

  /// No description provided for @historySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Lectures et positions, conservées sur cet appareil'**
  String get historySubtitle;

  /// No description provided for @historyClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique…'**
  String get historyClear;

  /// No description provided for @historyClearTitle.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique ?'**
  String get historyClearTitle;

  /// No description provided for @historyClearBody.
  ///
  /// In fr, this message translates to:
  /// **'Les lectures listées ici sont oubliées. Aucun fichier, favori ni point de reprise n\'est supprimé.'**
  String get historyClearBody;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clear;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get yesterday;

  /// No description provided for @positionOf.
  ///
  /// In fr, this message translates to:
  /// **'{position} sur {total}'**
  String positionOf(String position, String total);

  /// No description provided for @finished.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get finished;

  /// No description provided for @replay.
  ///
  /// In fr, this message translates to:
  /// **'Revoir'**
  String get replay;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune lecture pour l\'instant'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous écoutez et regardez apparaîtra ici, avec la position où vous vous êtes arrêté.'**
  String get historyEmptyBody;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'« {query} »'**
  String searchTitle(String query);

  /// No description provided for @searchCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun résultat} =1{1 résultat} other{{count} résultats}} dans la bibliothèque locale'**
  String searchCount(int count);

  /// No description provided for @bestResult.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur résultat'**
  String get bestResult;

  /// No description provided for @seeAllCount.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir ({count})'**
  String seeAllCount(int count);

  /// No description provided for @searchTranscripts.
  ///
  /// In fr, this message translates to:
  /// **'Recherche dans les transcriptions'**
  String get searchTranscripts;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour « {query} »'**
  String searchEmptyTitle(String query);

  /// No description provided for @searchEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'La recherche ne tient pas compte des accents et trouve le début des mots. Essayez un autre mot.'**
  String get searchEmptyBody;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Tapez un titre, un artiste, un film ou un podcast.'**
  String get searchHint;

  /// No description provided for @kindTrack.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get kindTrack;

  /// No description provided for @kindAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Album'**
  String get kindAlbum;

  /// No description provided for @kindArtist.
  ///
  /// In fr, this message translates to:
  /// **'Artiste'**
  String get kindArtist;

  /// No description provided for @searchClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get searchClear;

  /// No description provided for @setGeneral.
  ///
  /// In fr, this message translates to:
  /// **'Général'**
  String get setGeneral;

  /// No description provided for @setAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get setAppearance;

  /// No description provided for @setPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get setPlayback;

  /// No description provided for @setLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get setLibrary;

  /// No description provided for @setShortcuts.
  ///
  /// In fr, this message translates to:
  /// **'Raccourcis'**
  String get setShortcuts;

  /// No description provided for @setData.
  ///
  /// In fr, this message translates to:
  /// **'Données et sauvegarde'**
  String get setData;

  /// No description provided for @setAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get setAbout;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @languageBody.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'interface'**
  String get languageBody;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get languageSystem;

  /// No description provided for @theme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @playColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur de lecture'**
  String get playColor;

  /// No description provided for @colorCoral.
  ///
  /// In fr, this message translates to:
  /// **'Corail'**
  String get colorCoral;

  /// No description provided for @colorRose.
  ///
  /// In fr, this message translates to:
  /// **'Rose'**
  String get colorRose;

  /// No description provided for @colorAmber.
  ///
  /// In fr, this message translates to:
  /// **'Ambre'**
  String get colorAmber;

  /// No description provided for @colorBlue.
  ///
  /// In fr, this message translates to:
  /// **'Bleu'**
  String get colorBlue;

  /// No description provided for @density.
  ///
  /// In fr, this message translates to:
  /// **'Densité'**
  String get density;

  /// No description provided for @densityBody.
  ///
  /// In fr, this message translates to:
  /// **'Compacte : lignes de 40 px dans les listes'**
  String get densityBody;

  /// No description provided for @densityComfortable.
  ///
  /// In fr, this message translates to:
  /// **'Confortable'**
  String get densityComfortable;

  /// No description provided for @densityCompact.
  ///
  /// In fr, this message translates to:
  /// **'Compacte'**
  String get densityCompact;

  /// No description provided for @textSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille du texte'**
  String get textSize;

  /// No description provided for @textSizeBody.
  ///
  /// In fr, this message translates to:
  /// **'90 à 130 %'**
  String get textSizeBody;

  /// No description provided for @reduceMotion.
  ///
  /// In fr, this message translates to:
  /// **'Réduire les animations'**
  String get reduceMotion;

  /// No description provided for @reduceMotionBody.
  ///
  /// In fr, this message translates to:
  /// **'Suit le réglage Windows par défaut'**
  String get reduceMotionBody;

  /// No description provided for @reduceTransparency.
  ///
  /// In fr, this message translates to:
  /// **'Réduire la transparence'**
  String get reduceTransparency;

  /// No description provided for @reduceTransparencyBody.
  ///
  /// In fr, this message translates to:
  /// **'Surfaces opaques partout'**
  String get reduceTransparencyBody;

  /// No description provided for @coverBackdrop.
  ///
  /// In fr, this message translates to:
  /// **'Pochette en fond dans En lecture'**
  String get coverBackdrop;

  /// No description provided for @coverBackdropBody.
  ///
  /// In fr, this message translates to:
  /// **'Flou de la pochette derrière le lecteur'**
  String get coverBackdropBody;

  /// No description provided for @engineSection.
  ///
  /// In fr, this message translates to:
  /// **'Moteur et sortie'**
  String get engineSection;

  /// No description provided for @engine.
  ///
  /// In fr, this message translates to:
  /// **'Moteur de lecture'**
  String get engine;

  /// No description provided for @engineBodyWindows.
  ///
  /// In fr, this message translates to:
  /// **'libmpv intégré, décodage matériel avec repli'**
  String get engineBodyWindows;

  /// No description provided for @engineBodyAndroid.
  ///
  /// In fr, this message translates to:
  /// **'Media3, le lecteur d\'Android'**
  String get engineBodyAndroid;

  /// No description provided for @engineValue.
  ///
  /// In fr, this message translates to:
  /// **'Intégré (recommandé)'**
  String get engineValue;

  /// No description provided for @audioOutput.
  ///
  /// In fr, this message translates to:
  /// **'Sortie audio'**
  String get audioOutput;

  /// No description provided for @audioOutputBody.
  ///
  /// In fr, this message translates to:
  /// **'Périphérique utilisé par Miarina Media'**
  String get audioOutputBody;

  /// No description provided for @systemDefault.
  ///
  /// In fr, this message translates to:
  /// **'Système par défaut'**
  String get systemDefault;

  /// No description provided for @exclusive.
  ///
  /// In fr, this message translates to:
  /// **'Mode exclusif WASAPI'**
  String get exclusive;

  /// No description provided for @exclusiveBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour les DAC externes, coupe les autres sons'**
  String get exclusiveBody;

  /// No description provided for @chainSection.
  ///
  /// In fr, this message translates to:
  /// **'Enchaînement'**
  String get chainSection;

  /// No description provided for @resumeSetting.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre où j\'en étais'**
  String get resumeSetting;

  /// No description provided for @resumeSettingBody.
  ///
  /// In fr, this message translates to:
  /// **'Audio et vidéo, au démarrage'**
  String get resumeSettingBody;

  /// No description provided for @gapless.
  ///
  /// In fr, this message translates to:
  /// **'Lecture sans blanc (gapless)'**
  String get gapless;

  /// No description provided for @gaplessBody.
  ///
  /// In fr, this message translates to:
  /// **'Albums live et mixés'**
  String get gaplessBody;

  /// No description provided for @crossfade.
  ///
  /// In fr, this message translates to:
  /// **'Fondu entre les titres'**
  String get crossfade;

  /// No description provided for @crossfadeBody.
  ///
  /// In fr, this message translates to:
  /// **'0 à 12 s'**
  String get crossfadeBody;

  /// No description provided for @off.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get off;

  /// No description provided for @normalizationSetting.
  ///
  /// In fr, this message translates to:
  /// **'Normalisation du volume'**
  String get normalizationSetting;

  /// No description provided for @normalizationSettingBody.
  ///
  /// In fr, this message translates to:
  /// **'ReplayGain si présent'**
  String get normalizationSettingBody;

  /// No description provided for @videoSection.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get videoSection;

  /// No description provided for @defaultSubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres par défaut'**
  String get defaultSubtitles;

  /// No description provided for @defaultSubtitlesBody.
  ///
  /// In fr, this message translates to:
  /// **'Langue préférée, sinon aucun'**
  String get defaultSubtitlesBody;

  /// No description provided for @none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get none;

  /// No description provided for @sidecar.
  ///
  /// In fr, this message translates to:
  /// **'Charger les sous-titres à côté du fichier'**
  String get sidecar;

  /// No description provided for @sidecarBody.
  ///
  /// In fr, this message translates to:
  /// **'.srt, .vtt, .ass du même nom'**
  String get sidecarBody;

  /// No description provided for @p1Badge.
  ///
  /// In fr, this message translates to:
  /// **'P1'**
  String get p1Badge;

  /// No description provided for @keyPlayPause.
  ///
  /// In fr, this message translates to:
  /// **'Lecture / pause'**
  String get keyPlayPause;

  /// No description provided for @keyPrevious.
  ///
  /// In fr, this message translates to:
  /// **'Titre précédent'**
  String get keyPrevious;

  /// No description provided for @keyNext.
  ///
  /// In fr, this message translates to:
  /// **'Titre suivant'**
  String get keyNext;

  /// No description provided for @keySeekBack.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 10 s'**
  String get keySeekBack;

  /// No description provided for @keySeekForward.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 10 s'**
  String get keySeekForward;

  /// No description provided for @keyVolumeUp.
  ///
  /// In fr, this message translates to:
  /// **'Monter le volume'**
  String get keyVolumeUp;

  /// No description provided for @keyVolumeDown.
  ///
  /// In fr, this message translates to:
  /// **'Baisser le volume'**
  String get keyVolumeDown;

  /// No description provided for @keyMute.
  ///
  /// In fr, this message translates to:
  /// **'Couper le son'**
  String get keyMute;

  /// No description provided for @keySearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get keySearch;

  /// No description provided for @keyBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get keyBack;

  /// No description provided for @keyForward.
  ///
  /// In fr, this message translates to:
  /// **'Avant'**
  String get keyForward;

  /// No description provided for @keyToggleSidebar.
  ///
  /// In fr, this message translates to:
  /// **'Replier la barre latérale'**
  String get keyToggleSidebar;

  /// No description provided for @keyNowPlaying.
  ///
  /// In fr, this message translates to:
  /// **'En lecture'**
  String get keyNowPlaying;

  /// No description provided for @keyFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get keyFullscreen;

  /// No description provided for @keySubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get keySubtitles;

  /// No description provided for @keyAudioTrack.
  ///
  /// In fr, this message translates to:
  /// **'Piste audio'**
  String get keyAudioTrack;

  /// No description provided for @keyFrameStep.
  ///
  /// In fr, this message translates to:
  /// **'Image suivante (pause)'**
  String get keyFrameStep;

  /// No description provided for @keyBookmark.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un signet'**
  String get keyBookmark;

  /// No description provided for @keyLyrics.
  ///
  /// In fr, this message translates to:
  /// **'Paroles'**
  String get keyLyrics;

  /// No description provided for @keyMiniPlayer.
  ///
  /// In fr, this message translates to:
  /// **'Mini-lecteur'**
  String get keyMiniPlayer;

  /// No description provided for @keySpeedDown.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse −'**
  String get keySpeedDown;

  /// No description provided for @keySpeedUp.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse +'**
  String get keySpeedUp;

  /// No description provided for @keysPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get keysPlayback;

  /// No description provided for @keysNavigation.
  ///
  /// In fr, this message translates to:
  /// **'Navigation'**
  String get keysNavigation;

  /// No description provided for @keysVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get keysVideo;

  /// No description provided for @keysFocus.
  ///
  /// In fr, this message translates to:
  /// **'Focus et fenêtres'**
  String get keysFocus;

  /// No description provided for @keysTitle.
  ///
  /// In fr, this message translates to:
  /// **'Raccourcis clavier'**
  String get keysTitle;

  /// No description provided for @keysSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un raccourci'**
  String get keysSearch;

  /// No description provided for @keysReset.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir les valeurs'**
  String get keysReset;

  /// No description provided for @keysHint.
  ///
  /// In fr, this message translates to:
  /// **'Cliquez sur une touche pour la modifier ; un conflit est signalé avant d\'être enregistré. Échap annule. Touches multimédia du clavier et du casque prises en charge (contrôles média de Windows).'**
  String get keysHint;

  /// No description provided for @keyPress.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur une touche…'**
  String get keyPress;

  /// No description provided for @keyNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get keyNone;

  /// No description provided for @keyShift.
  ///
  /// In fr, this message translates to:
  /// **'Maj'**
  String get keyShift;

  /// No description provided for @keySpace.
  ///
  /// In fr, this message translates to:
  /// **'Espace'**
  String get keySpace;

  /// No description provided for @keyConflict.
  ///
  /// In fr, this message translates to:
  /// **'{key} est déjà utilisé par « {action} ».'**
  String keyConflict(String key, String action);

  /// No description provided for @keyReplace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer'**
  String get keyReplace;

  /// No description provided for @keyRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la touche'**
  String get keyRemove;

  /// No description provided for @libraryTracks.
  ///
  /// In fr, this message translates to:
  /// **'Titres audio'**
  String get libraryTracks;

  /// No description provided for @libraryVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get libraryVideos;

  /// No description provided for @dataFolder.
  ///
  /// In fr, this message translates to:
  /// **'Dossier des données'**
  String get dataFolder;

  /// No description provided for @dataFolderBody.
  ///
  /// In fr, this message translates to:
  /// **'Base de la bibliothèque, réglages et pochettes'**
  String get dataFolderBody;

  /// No description provided for @openFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier'**
  String get openFolder;

  /// No description provided for @playHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique de lecture'**
  String get playHistory;

  /// No description provided for @playHistoryBody.
  ///
  /// In fr, this message translates to:
  /// **'Lectures et positions affichées dans Historique'**
  String get playHistoryBody;

  /// No description provided for @aboutVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutDevBuild.
  ///
  /// In fr, this message translates to:
  /// **'Version de développement'**
  String get aboutDevBuild;

  /// No description provided for @aboutLicense.
  ///
  /// In fr, this message translates to:
  /// **'Licence'**
  String get aboutLicense;

  /// No description provided for @aboutLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences des composants'**
  String get aboutLicenses;

  /// No description provided for @aboutLicensesBody.
  ///
  /// In fr, this message translates to:
  /// **'Polices, icônes et bibliothèques intégrées'**
  String get aboutLicensesBody;

  /// No description provided for @show.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get show;

  /// No description provided for @aboutLocal.
  ///
  /// In fr, this message translates to:
  /// **'Tout reste sur cet appareil : pas de compte, pas d\'envoi de données.'**
  String get aboutLocal;

  /// No description provided for @aboutCompanyBody.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media fait partie de l\'écosystème Miarina.'**
  String get aboutCompanyBody;

  /// No description provided for @aboutDeveloper.
  ///
  /// In fr, this message translates to:
  /// **'Développeur'**
  String get aboutDeveloper;

  /// No description provided for @playlistNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle'**
  String get playlistNew;

  /// No description provided for @playlistImport.
  ///
  /// In fr, this message translates to:
  /// **'Importer M3U'**
  String get playlistImport;

  /// No description provided for @playlistExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get playlistExport;

  /// No description provided for @playlistModified.
  ///
  /// In fr, this message translates to:
  /// **'Playlist · modifiée {when}'**
  String playlistModified(String when);

  /// No description provided for @agoNow.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get agoNow;

  /// No description provided for @agoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} min'**
  String agoMinutes(int count);

  /// No description provided for @agoHours.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} h'**
  String agoHours(int count);

  /// No description provided for @agoDays.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{hier} other{il y a {count} jours}}'**
  String agoDays(int count);

  /// No description provided for @titlesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun titre} =1{1 titre} other{{count} titres}}'**
  String titlesCount(int count);

  /// No description provided for @missingCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 titre introuvable} other{{count} titres introuvables}}'**
  String missingCount(int count);

  /// No description provided for @addTracks.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des titres'**
  String get addTracks;

  /// No description provided for @playlistHint.
  ///
  /// In fr, this message translates to:
  /// **'Glisser pour réordonner · Alt+↑/↓ au clavier · Suppr retire de la playlist (le fichier reste)'**
  String get playlistHint;

  /// No description provided for @newPlaylistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle playlist'**
  String get newPlaylistTitle;

  /// No description provided for @playlistName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get playlistName;

  /// No description provided for @addQueue.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Ajouter le titre de la file d\'attente} other{Ajouter les {count} titres de la file d\'attente}}'**
  String addQueue(int count);

  /// No description provided for @smartPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Playlist intelligente (règles)'**
  String get smartPlaylist;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @deletePlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String deletePlaylistTitle(String name);

  /// No description provided for @deletePlaylistBody.
  ///
  /// In fr, this message translates to:
  /// **'La playlist est supprimée. Les fichiers restent dans la bibliothèque.'**
  String get deletePlaylistBody;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @importDone.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » : {added} titres ajoutés, {skipped} introuvables ou en ligne.'**
  String importDone(String name, int added, int skipped);

  /// No description provided for @exportDone.
  ///
  /// In fr, this message translates to:
  /// **'Playlist enregistrée : {path}'**
  String exportDone(String path);

  /// No description provided for @playlistsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune playlist'**
  String get playlistsEmptyTitle;

  /// No description provided for @playlistsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Créez une playlist ou importez un fichier M3U.'**
  String get playlistsEmptyBody;

  /// No description provided for @playlistEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Cette playlist est vide. Ajoutez des titres.'**
  String get playlistEmpty;

  /// No description provided for @addedShort.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté'**
  String get addedShort;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la playlist'**
  String get removeFromPlaylist;

  /// No description provided for @moveUp.
  ///
  /// In fr, this message translates to:
  /// **'Monter'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In fr, this message translates to:
  /// **'Descendre'**
  String get moveDown;

  /// No description provided for @playlistFileType.
  ///
  /// In fr, this message translates to:
  /// **'Playlist M3U'**
  String get playlistFileType;

  /// No description provided for @playlistActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'opération n\'a pas abouti : {error}'**
  String playlistActionFailed(String error);

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @emptyOpenFiles.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir des fichiers…'**
  String get emptyOpenFiles;

  /// No description provided for @emptyFormats.
  ///
  /// In fr, this message translates to:
  /// **'Formats lus : MP3, M4A, FLAC, OGG, Opus, WAV, AAC, et en vidéo MP4, MKV, WebM, MOV, AVI.'**
  String get emptyFormats;

  /// No description provided for @emptyNote.
  ///
  /// In fr, this message translates to:
  /// **'Vous téléchargez avec Miarina Media ? Les fichiers obtenus arrivent ici automatiquement.'**
  String get emptyNote;

  /// No description provided for @mediaFiles.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers audio et vidéo'**
  String get mediaFiles;

  /// No description provided for @errFormatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Format non pris en charge'**
  String get errFormatTitle;

  /// No description provided for @errFormatBody.
  ///
  /// In fr, this message translates to:
  /// **'Le moteur ne sait pas décoder ce fichier. Le fichier n\'est pas modifié.'**
  String get errFormatBody;

  /// No description provided for @errDamagedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fichier endommagé'**
  String get errDamagedTitle;

  /// No description provided for @errDamagedBody.
  ///
  /// In fr, this message translates to:
  /// **'La lecture s\'est arrêtée : une partie du fichier semble illisible. Le fichier n\'est pas modifié.'**
  String get errDamagedBody;

  /// No description provided for @errAccessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé'**
  String get errAccessTitle;

  /// No description provided for @errAccessBody.
  ///
  /// In fr, this message translates to:
  /// **'Le système ne laisse pas Miarina Media lire ce fichier. Les autres fichiers fonctionnent.'**
  String get errAccessBody;

  /// No description provided for @errMissingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fichier introuvable'**
  String get errMissingTitle;

  /// No description provided for @errMissingBody.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier a été déplacé, renommé, ou son disque est débranché. Il garde sa place dans la bibliothèque.'**
  String get errMissingBody;

  /// No description provided for @errPlaybackTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lecture impossible'**
  String get errPlaybackTitle;

  /// No description provided for @errPlaybackBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'a pas pu être lu. Rien n\'a été modifié.'**
  String get errPlaybackBody;

  /// No description provided for @errLibraryRepairTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque à réparer'**
  String get errLibraryRepairTitle;

  /// No description provided for @errLibraryRepairBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'index de la bibliothèque n\'a pas pu s\'ouvrir. Vos fichiers ne sont pas touchés.'**
  String get errLibraryRepairBody;

  /// No description provided for @errLibraryTitle.
  ///
  /// In fr, this message translates to:
  /// **'La bibliothèque ne s\'ouvre pas'**
  String get errLibraryTitle;

  /// No description provided for @errLibraryBody.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'a été modifié. Réessayez ; si cela continue, copiez les détails pour le support.'**
  String get errLibraryBody;

  /// No description provided for @copyDetails.
  ///
  /// In fr, this message translates to:
  /// **'Copier les détails'**
  String get copyDetails;

  /// No description provided for @detailsCopied.
  ///
  /// In fr, this message translates to:
  /// **'Détails copiés'**
  String get detailsCopied;

  /// No description provided for @skipNext.
  ///
  /// In fr, this message translates to:
  /// **'Passer au suivant'**
  String get skipNext;

  /// No description provided for @welcomeHeadline.
  ///
  /// In fr, this message translates to:
  /// **'Votre musique, vos films et vos cours, au même endroit.'**
  String get welcomeHeadline;

  /// No description provided for @welcomeLocal.
  ///
  /// In fr, this message translates to:
  /// **'Tout reste sur cet ordinateur. Aucun compte, aucune donnée envoyée.'**
  String get welcomeLocal;

  /// No description provided for @welcomeFoot.
  ///
  /// In fr, this message translates to:
  /// **'Lecture locale, sans télémétrie. Modifiable plus tard dans Réglages.'**
  String get welcomeFoot;

  /// No description provided for @stepAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Langue et apparence'**
  String get stepAppearance;

  /// No description provided for @stepFolders.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers'**
  String get stepFolders;

  /// No description provided for @stepScan.
  ///
  /// In fr, this message translates to:
  /// **'Analyse'**
  String get stepScan;

  /// No description provided for @skip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get skip;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @analyse.
  ///
  /// In fr, this message translates to:
  /// **'Analyser'**
  String get analyse;

  /// No description provided for @themeFollow.
  ///
  /// In fr, this message translates to:
  /// **'Suivre Windows'**
  String get themeFollow;

  /// No description provided for @foldersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Où sont vos fichiers ?'**
  String get foldersTitle;

  /// No description provided for @foldersBody.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media lit ces dossiers sans les modifier ni les déplacer. Les nouveaux fichiers apparaissent à chaque lancement.'**
  String get foldersBody;

  /// No description provided for @folderFiles.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun fichier audio ou vidéo} =1{1 fichier audio ou vidéo} other{{count} fichiers audio ou vidéo}}'**
  String folderFiles(int count);

  /// No description provided for @kindVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get kindVideo;

  /// No description provided for @addFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dossier…'**
  String get addFolder;

  /// No description provided for @foldersSummary.
  ///
  /// In fr, this message translates to:
  /// **'{folders, plural, =0{aucun dossier} =1{1 dossier} other{{folders} dossiers}} · environ {files} fichiers'**
  String foldersSummary(int folders, int files);

  /// No description provided for @removeFolder.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce dossier'**
  String get removeFolder;

  /// No description provided for @scanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de votre bibliothèque'**
  String get scanTitle;

  /// No description provided for @scanBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez commencer à écouter : l\'analyse continue en arrière-plan.'**
  String get scanBody;

  /// No description provided for @scanProgress.
  ///
  /// In fr, this message translates to:
  /// **'{done} fichiers sur environ {total}'**
  String scanProgress(int done, int total);

  /// No description provided for @statTracks.
  ///
  /// In fr, this message translates to:
  /// **'titres'**
  String get statTracks;

  /// No description provided for @statAlbums.
  ///
  /// In fr, this message translates to:
  /// **'albums'**
  String get statAlbums;

  /// No description provided for @statVideos.
  ///
  /// In fr, this message translates to:
  /// **'vidéos'**
  String get statVideos;

  /// No description provided for @statUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'illisibles'**
  String get statUnreadable;

  /// No description provided for @readyNow.
  ///
  /// In fr, this message translates to:
  /// **'Déjà prêts'**
  String get readyNow;

  /// No description provided for @scanEco.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en arrière-plan, un fichier à la fois (mode éco).'**
  String get scanEco;

  /// No description provided for @scanNoFfmpeg.
  ///
  /// In fr, this message translates to:
  /// **'FFmpeg n\'est pas installé à côté de l\'application : titres, artistes et albums sont lus ; durées et vignettes le seront quand il le sera.'**
  String get scanNoFfmpeg;

  /// No description provided for @startListening.
  ///
  /// In fr, this message translates to:
  /// **'Commencer à écouter'**
  String get startListening;

  /// No description provided for @libraryFolders.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers suivis'**
  String get libraryFolders;

  /// No description provided for @libraryFoldersBody.
  ///
  /// In fr, this message translates to:
  /// **'Analysés à chaque lancement ; rien n\'est modifié ni déplacé.'**
  String get libraryFoldersBody;

  /// No description provided for @scanNow.
  ///
  /// In fr, this message translates to:
  /// **'Analyser maintenant'**
  String get scanNow;

  /// No description provided for @scanDone.
  ///
  /// In fr, this message translates to:
  /// **'Analyse terminée'**
  String get scanDone;

  /// No description provided for @scanRunning.
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total} analysés'**
  String scanRunning(int done, int total);

  /// No description provided for @noFolders.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier suivi pour l\'instant.'**
  String get noFolders;

  /// No description provided for @navSectionLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get navSectionLibrary;

  /// No description provided for @navMissing.
  ///
  /// In fr, this message translates to:
  /// **'Introuvables'**
  String get navMissing;

  /// No description provided for @navDuplicates.
  ///
  /// In fr, this message translates to:
  /// **'Doublons'**
  String get navDuplicates;

  /// No description provided for @healthGroup.
  ///
  /// In fr, this message translates to:
  /// **'État de la bibliothèque'**
  String get healthGroup;

  /// No description provided for @missingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers introuvables'**
  String get missingTitle;

  /// No description provided for @missingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 élément n\'a pas été trouvé au dernier passage. Rien n\'a été supprimé.} other{{count} éléments n\'ont pas été trouvés au dernier passage. Rien n\'a été supprimé.}}'**
  String missingSubtitle(int count);

  /// No description provided for @missingVolumeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Disque {volume} déconnecté'**
  String missingVolumeTitle(String volume);

  /// No description provided for @missingVolumeBody.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 élément de {folder}. Il réapparaîtra au branchement.} other{{count} éléments de {folder}. Ils réapparaîtront au branchement.}}'**
  String missingVolumeBody(int count, String folder);

  /// No description provided for @missingMovedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dossier probablement renommé'**
  String get missingMovedTitle;

  /// No description provided for @missingMovedBody.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 fichier retrouvé dans {folder}, avec le même nom et la même taille.} other{{count} fichiers retrouvés dans {folder}, avec le même nom et la même taille.}}'**
  String missingMovedBody(int count, String folder);

  /// No description provided for @missingLostTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 fichier introuvable} other{{count} fichiers introuvables}}'**
  String missingLostTitle(int count);

  /// No description provided for @missingLostBody.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Aucune correspondance trouvée. Il a peut-être été supprimé.} other{Aucune correspondance trouvée. Ils ont peut-être été supprimés.}}'**
  String missingLostBody(int count);

  /// No description provided for @missingRelocate.
  ///
  /// In fr, this message translates to:
  /// **'Relocaliser…'**
  String get missingRelocate;

  /// No description provided for @missingHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get missingHide;

  /// No description provided for @missingUpdatePaths.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour les chemins'**
  String get missingUpdatePaths;

  /// No description provided for @missingIgnore.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get missingIgnore;

  /// No description provided for @missingLocate.
  ///
  /// In fr, this message translates to:
  /// **'Localiser…'**
  String get missingLocate;

  /// No description provided for @missingSearchFolder.
  ///
  /// In fr, this message translates to:
  /// **'Chercher dans un dossier…'**
  String get missingSearchFolder;

  /// No description provided for @missingRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la bibliothèque'**
  String get missingRemove;

  /// No description provided for @missingStatusVolume.
  ///
  /// In fr, this message translates to:
  /// **'disque absent'**
  String get missingStatusVolume;

  /// No description provided for @missingStatusFound.
  ///
  /// In fr, this message translates to:
  /// **'→ trouvé'**
  String get missingStatusFound;

  /// No description provided for @missingStatusLost.
  ///
  /// In fr, this message translates to:
  /// **'introuvable'**
  String get missingStatusLost;

  /// No description provided for @missingMore.
  ///
  /// In fr, this message translates to:
  /// **'et {count} autres'**
  String missingMore(int count);

  /// No description provided for @missingHiddenGroups.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 groupe masqué} other{{count} groupes masqués}}'**
  String missingHiddenGroups(int count);

  /// No description provided for @missingShowAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout afficher'**
  String get missingShowAll;

  /// No description provided for @missingEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos fichiers sont là'**
  String get missingEmptyTitle;

  /// No description provided for @missingEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers déplacés ou rangés sur un disque débranché apparaîtront ici. Rien n\'est jamais supprimé automatiquement.'**
  String get missingEmptyBody;

  /// No description provided for @missingPathsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun chemin mis à jour} =1{1 chemin mis à jour} other{{count} chemins mis à jour}}'**
  String missingPathsUpdated(int count);

  /// No description provided for @missingFoundCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun fichier retrouvé} =1{1 fichier retrouvé} other{{count} fichiers retrouvés}}'**
  String missingFoundCount(int count);

  /// No description provided for @missingLeftCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 toujours introuvable} other{{count} toujours introuvables}}'**
  String missingLeftCount(int count);

  /// No description provided for @missingRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Retirer ce fichier de la bibliothèque ?} other{Retirer ces {count} fichiers de la bibliothèque ?}}'**
  String missingRemoveTitle(int count);

  /// No description provided for @missingRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'Ils quittent la bibliothèque, les playlists et la reprise de lecture. Aucun fichier n\'est supprimé du disque : s\'ils réapparaissent, ouvrez-les pour les ajouter à nouveau.'**
  String get missingRemoveBody;

  /// No description provided for @remove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get remove;

  /// No description provided for @missingSkipped.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » est introuvable, titre suivant'**
  String missingSkipped(String title);

  /// No description provided for @missingSkippedLast.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » est introuvable'**
  String missingSkippedLast(String title);

  /// No description provided for @locate.
  ///
  /// In fr, this message translates to:
  /// **'Localiser'**
  String get locate;

  /// No description provided for @fileLocated.
  ///
  /// In fr, this message translates to:
  /// **'Fichier retrouvé'**
  String get fileLocated;

  /// No description provided for @locateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier ne peut pas être utilisé à la place de l\'original.'**
  String get locateFailed;

  /// No description provided for @duplicatesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Doublons'**
  String get duplicatesTitle;

  /// No description provided for @duplicatesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 groupe · {size} récupérables · même titre, même artiste, même durée} other{{count} groupes · {size} récupérables · même titre, même artiste, même durée}}'**
  String duplicatesSubtitle(int count, String size);

  /// No description provided for @duplicatesKeepBest.
  ///
  /// In fr, this message translates to:
  /// **'Garder la meilleure qualité partout'**
  String get duplicatesKeepBest;

  /// No description provided for @duplicateVersions.
  ///
  /// In fr, this message translates to:
  /// **'{count} versions'**
  String duplicateVersions(int count);

  /// No description provided for @duplicateKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get duplicateKeep;

  /// No description provided for @duplicateHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get duplicateHide;

  /// No description provided for @duplicateTrash.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à la Corbeille…'**
  String get duplicateTrash;

  /// No description provided for @duplicatesNote.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut, les doublons sont seulement masqués de la bibliothèque : le fichier reste sur le disque. La suppression va dans la Corbeille Windows.'**
  String get duplicatesNote;

  /// No description provided for @duplicatesHideAll.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Masquer le doublon} other{Masquer les {count} doublons}}'**
  String duplicatesHideAll(int count);

  /// No description provided for @duplicatesHidden.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 doublon masqué, ses playlists passent à la version gardée} other{{count} doublons masqués, leurs playlists passent à la version gardée}}'**
  String duplicatesHidden(int count);

  /// No description provided for @duplicateTrashTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mettre ce fichier à la Corbeille ?'**
  String get duplicateTrashTitle;

  /// No description provided for @duplicateTrashBody.
  ///
  /// In fr, this message translates to:
  /// **'Ses playlists et son favori passent à la version gardée. Vous pourrez le récupérer depuis la Corbeille Windows.'**
  String get duplicateTrashBody;

  /// No description provided for @duplicateTrashed.
  ///
  /// In fr, this message translates to:
  /// **'Fichier mis à la Corbeille'**
  String get duplicateTrashed;

  /// No description provided for @duplicatesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun doublon'**
  String get duplicatesEmptyTitle;

  /// No description provided for @duplicatesEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les titres présents en plusieurs versions (même titre, même artiste, même durée) apparaîtront ici.'**
  String get duplicatesEmptyBody;

  /// No description provided for @duplicatesNeedFfmpeg.
  ///
  /// In fr, this message translates to:
  /// **'Les durées sont lues par FFmpeg, absent de cette installation : la recherche de doublons attend.'**
  String get duplicatesNeedFfmpeg;

  /// No description provided for @sizeKb.
  ///
  /// In fr, this message translates to:
  /// **'{n} Ko'**
  String sizeKb(String n);

  /// No description provided for @sizeMb.
  ///
  /// In fr, this message translates to:
  /// **'{n} Mo'**
  String sizeMb(String n);

  /// No description provided for @sizeGb.
  ///
  /// In fr, this message translates to:
  /// **'{n} Go'**
  String sizeGb(String n);

  /// No description provided for @duplicatesFound.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun doublon trouvé} =1{1 titre présent en plusieurs versions} other{{count} titres présents en plusieurs versions}}'**
  String duplicatesFound(int count);

  /// No description provided for @miniPin.
  ///
  /// In fr, this message translates to:
  /// **'Garder au premier plan'**
  String get miniPin;

  /// No description provided for @miniUnpin.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus garder au premier plan'**
  String get miniUnpin;

  /// No description provided for @miniExpand.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir la fenêtre'**
  String get miniExpand;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori pour l\'instant'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Touchez le cœur d\'un titre, dans Titres ou En lecture, pour le retrouver ici.'**
  String get favoritesEmptyBody;

  /// No description provided for @getNavHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get getNavHome;

  /// No description provided for @getNavDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get getNavDownloads;

  /// No description provided for @getNavBrowser.
  ///
  /// In fr, this message translates to:
  /// **'Navigateur'**
  String get getNavBrowser;

  /// No description provided for @getNavTorrents.
  ///
  /// In fr, this message translates to:
  /// **'Torrents'**
  String get getNavTorrents;

  /// No description provided for @getNavHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get getNavHistory;

  /// No description provided for @getHomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Du lien à votre bibliothèque'**
  String get getHomeTitle;

  /// No description provided for @getHomeSub.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien, choisissez le format, écoutez ou regardez hors ligne.'**
  String get getHomeSub;

  /// No description provided for @getLinkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien du média'**
  String get getLinkLabel;

  /// No description provided for @getPaste.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get getPaste;

  /// No description provided for @getAnalyze.
  ///
  /// In fr, this message translates to:
  /// **'Analyser'**
  String get getAnalyze;

  /// No description provided for @getHintPaste.
  ///
  /// In fr, this message translates to:
  /// **'pour coller et analyser'**
  String get getHintPaste;

  /// No description provided for @getHintDrop.
  ///
  /// In fr, this message translates to:
  /// **'Glissez un lien dans la fenêtre'**
  String get getHintDrop;

  /// No description provided for @getHintExt.
  ///
  /// In fr, this message translates to:
  /// **'Ou envoyez-le depuis l’extension Chrome/Edge'**
  String get getHintExt;

  /// No description provided for @getQAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio seul'**
  String get getQAudio;

  /// No description provided for @getQAudioDesc.
  ///
  /// In fr, this message translates to:
  /// **'MP3 jusqu’à 320 kbps, FLAC'**
  String get getQAudioDesc;

  /// No description provided for @getQPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Playlist'**
  String get getQPlaylist;

  /// No description provided for @getQPlaylistDesc.
  ///
  /// In fr, this message translates to:
  /// **'Choisir les éléments'**
  String get getQPlaylistDesc;

  /// No description provided for @getQBatch.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs liens'**
  String get getQBatch;

  /// No description provided for @getQBatchDesc.
  ///
  /// In fr, this message translates to:
  /// **'Un lien par ligne'**
  String get getQBatchDesc;

  /// No description provided for @getQTorrent.
  ///
  /// In fr, this message translates to:
  /// **'Torrent / magnet'**
  String get getQTorrent;

  /// No description provided for @getQTorrentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers et partage maîtrisés'**
  String get getQTorrentDesc;

  /// No description provided for @getContinue.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get getContinue;

  /// No description provided for @getSeeLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Voir la bibliothèque'**
  String get getSeeLibrary;

  /// No description provided for @getContinueEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous commencez à lire ou regarder reprendra ici.'**
  String get getContinueEmpty;

  /// No description provided for @getRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récemment téléchargés'**
  String get getRecent;

  /// No description provided for @getHomeEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vos téléchargements apparaîtront ici.'**
  String get getHomeEmpty;

  /// No description provided for @getPlayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lire {title}'**
  String getPlayTitle(String title);

  /// No description provided for @getMinutesLeft.
  ///
  /// In fr, this message translates to:
  /// **'Reste {n} min'**
  String getMinutesLeft(int n);

  /// No description provided for @getLinkEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien à analyser.'**
  String get getLinkEmpty;

  /// No description provided for @getLinkTooLong.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien est trop long.'**
  String get getLinkTooLong;

  /// No description provided for @getLinkMalformed.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien semble incomplet. Vérifiez qu’il commence par « https:// ».'**
  String get getLinkMalformed;

  /// No description provided for @getLinkScheme.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les liens http et https sont acceptés.'**
  String get getLinkScheme;

  /// No description provided for @getLinkCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Les liens contenant un nom d’utilisateur ou un mot de passe ne sont pas acceptés.'**
  String get getLinkCredentials;

  /// No description provided for @getLinkMissingHttps.
  ///
  /// In fr, this message translates to:
  /// **'Il manque « https:// » à ce lien.'**
  String get getLinkMissingHttps;

  /// No description provided for @getAddHttps.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter https://'**
  String get getAddHttps;

  /// No description provided for @getClipboardEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le presse-papiers est vide. Copiez d’abord un lien.'**
  String get getClipboardEmpty;

  /// No description provided for @getPlanned.
  ///
  /// In fr, this message translates to:
  /// **'PRÉVU'**
  String get getPlanned;

  /// No description provided for @getPlannedHint.
  ///
  /// In fr, this message translates to:
  /// **'Prévu dans un prochain lot : pas encore disponible.'**
  String get getPlannedHint;

  /// No description provided for @getBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get getBack;

  /// No description provided for @getFmtVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get getFmtVideo;

  /// No description provided for @getFmtSubs.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get getFmtSubs;

  /// No description provided for @getNoVideoFormats.
  ///
  /// In fr, this message translates to:
  /// **'Cette source ne propose pas de format vidéo.'**
  String get getNoVideoFormats;

  /// No description provided for @getNoAudioFormats.
  ///
  /// In fr, this message translates to:
  /// **'Cette source ne propose pas de format audio seul.'**
  String get getNoAudioFormats;

  /// No description provided for @getNoSubsFormats.
  ///
  /// In fr, this message translates to:
  /// **'Cette source ne propose pas de sous-titres.'**
  String get getNoSubsFormats;

  /// No description provided for @getUpTo.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à {q}'**
  String getUpTo(String q);

  /// No description provided for @getSubsPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres : téléchargement prévu (DL-08)'**
  String get getSubsPlanned;

  /// No description provided for @getNoteAudio.
  ///
  /// In fr, this message translates to:
  /// **'La conversion suit le téléchargement ; sa progression est affichée à part.'**
  String get getNoteAudio;

  /// No description provided for @getNoteVideo.
  ///
  /// In fr, this message translates to:
  /// **'Tailles indiquées par la source, ou estimées.'**
  String get getNoteVideo;

  /// No description provided for @getNeedsFfmpeg.
  ///
  /// In fr, this message translates to:
  /// **'Installez FFmpeg pour obtenir plus de qualités (vidéo et audio fusionnés) et la conversion MP3.'**
  String get getNeedsFfmpeg;

  /// No description provided for @getDirectResume.
  ///
  /// In fr, this message translates to:
  /// **'Fichier direct · reprise possible si interrompu'**
  String get getDirectResume;

  /// No description provided for @getDirectNoResume.
  ///
  /// In fr, this message translates to:
  /// **'Fichier direct · pas de reprise si interrompu'**
  String get getDirectNoResume;

  /// No description provided for @getOriginalFile.
  ///
  /// In fr, this message translates to:
  /// **'{ext} · fichier d’origine'**
  String getOriginalFile(String ext);

  /// No description provided for @getTagRecommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé'**
  String get getTagRecommended;

  /// No description provided for @getTagBest.
  ///
  /// In fr, this message translates to:
  /// **'Meilleure qualité'**
  String get getTagBest;

  /// No description provided for @getChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get getChange;

  /// No description provided for @getAddToQueue.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la file'**
  String get getAddToQueue;

  /// No description provided for @getStarting.
  ///
  /// In fr, this message translates to:
  /// **'Démarrage…'**
  String get getStarting;

  /// No description provided for @getDownloadSize.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger · {size}'**
  String getDownloadSize(String size);

  /// No description provided for @getDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get getDownload;

  /// No description provided for @getAddedToQueue.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à la file · {q}'**
  String getAddedToQueue(String q);

  /// No description provided for @getView.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get getView;

  /// No description provided for @getPrepTitle.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de votre fichier'**
  String get getPrepTitle;

  /// No description provided for @getPrepElapsed.
  ///
  /// In fr, this message translates to:
  /// **'{n} s'**
  String getPrepElapsed(int n);

  /// No description provided for @getPrepStage1.
  ///
  /// In fr, this message translates to:
  /// **'Lecture du lien sur {host}…'**
  String getPrepStage1(String host);

  /// No description provided for @getPrepStage2.
  ///
  /// In fr, this message translates to:
  /// **'Recherche des qualités vidéo et audio disponibles…'**
  String get getPrepStage2;

  /// No description provided for @getPrepStage3.
  ///
  /// In fr, this message translates to:
  /// **'Certains sites répondent plus lentement. Merci de patienter, ça continue.'**
  String get getPrepStage3;

  /// No description provided for @getPrepStage4.
  ///
  /// In fr, this message translates to:
  /// **'Toujours en cours. Les vidéos longues ou très demandées peuvent prendre plus de temps.'**
  String get getPrepStage4;

  /// No description provided for @getPrepThisSite.
  ///
  /// In fr, this message translates to:
  /// **'ce site'**
  String get getPrepThisSite;

  /// No description provided for @getPrepTip.
  ///
  /// In fr, this message translates to:
  /// **'ASTUCE'**
  String get getPrepTip;

  /// No description provided for @getPrepTip1.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez « Audio seul » pour ne garder que la musique, dans un fichier plus léger.'**
  String get getPrepTip1;

  /// No description provided for @getPrepTip2.
  ///
  /// In fr, this message translates to:
  /// **'Vos téléchargements arrivent directement dans la bibliothèque.'**
  String get getPrepTip2;

  /// No description provided for @getPrepTip3.
  ///
  /// In fr, this message translates to:
  /// **'Les qualités proposées sont celles que la source publie, rien n’est inventé.'**
  String get getPrepTip3;

  /// No description provided for @getPrepTip4.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs titres ? Ajoutez-les « À la file » : ils se téléchargent chacun leur tour.'**
  String get getPrepTip4;

  /// No description provided for @getNoMediaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média téléchargeable trouvé'**
  String get getNoMediaTitle;

  /// No description provided for @getNoMediaBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette page ne contient pas de média pris en charge, ou il demande une connexion, est protégé (DRM) ou est un direct. Miarina Media ne contourne pas ces protections.'**
  String get getNoMediaBody;

  /// No description provided for @getNoMediaReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison : {reason}'**
  String getNoMediaReason(String reason);

  /// No description provided for @getWhyNetwork.
  ///
  /// In fr, this message translates to:
  /// **'le site n’a pas pu être joint ; vérifiez le lien et votre connexion'**
  String get getWhyNetwork;

  /// No description provided for @getWhyHttp.
  ///
  /// In fr, this message translates to:
  /// **'le site a refusé la demande (HTTP {status})'**
  String getWhyHttp(String status);

  /// No description provided for @getWhyPlatform.
  ///
  /// In fr, this message translates to:
  /// **'la lecture des pages web n’est pas disponible sur cet appareil'**
  String get getWhyPlatform;

  /// No description provided for @getTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get getTryAgain;

  /// No description provided for @getToolsNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Cette page a besoin des outils média'**
  String get getToolsNeeded;

  /// No description provided for @getToolsBody.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media lit les pages web avec yt-dlp et fusionne ou convertit les fichiers avec FFmpeg. Ils sont téléchargés une fois depuis leurs publications officielles et contrôlés avec une empreinte SHA-256 fixe avant usage.'**
  String get getToolsBody;

  /// No description provided for @getBytesOf.
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total}'**
  String getBytesOf(String done, String total);

  /// No description provided for @getNotNow.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get getNotNow;

  /// No description provided for @getDownloadingShort.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement…'**
  String get getDownloadingShort;

  /// No description provided for @getDownloadTools.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les outils · {size}'**
  String getDownloadTools(String size);

  /// No description provided for @getTabActive.
  ///
  /// In fr, this message translates to:
  /// **'En cours · {n}'**
  String getTabActive(int n);

  /// No description provided for @getTabDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminés · {n}'**
  String getTabDone(int n);

  /// No description provided for @getTabFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échecs · {n}'**
  String getTabFailed(int n);

  /// No description provided for @getDlSubRunning.
  ///
  /// In fr, this message translates to:
  /// **'{n} en cours · {speed} · reprise automatique si la source l’accepte'**
  String getDlSubRunning(int n, String speed);

  /// No description provided for @getDlSubPaused.
  ///
  /// In fr, this message translates to:
  /// **'Tout est en pause'**
  String get getDlSubPaused;

  /// No description provided for @getDlSubIdle.
  ///
  /// In fr, this message translates to:
  /// **'Rien en cours · jusqu’à {n} à la fois'**
  String getDlSubIdle(int n);

  /// No description provided for @getPauseAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout mettre en pause'**
  String get getPauseAll;

  /// No description provided for @getResumeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout reprendre'**
  String get getResumeAll;

  /// No description provided for @getDlNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien ici pour le moment.'**
  String get getDlNothing;

  /// No description provided for @getActRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer {title}'**
  String getActRetry(String title);

  /// No description provided for @getActResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre {title}'**
  String getActResume(String title);

  /// No description provided for @getActStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer {title} maintenant'**
  String getActStart(String title);

  /// No description provided for @getActPause.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause {title}'**
  String getActPause(String title);

  /// No description provided for @getCannotPause.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre en pause pendant la préparation du fichier'**
  String get getCannotPause;

  /// No description provided for @getRemoveNamed.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {title}'**
  String getRemoveNamed(String title);

  /// No description provided for @getCancelNamed.
  ///
  /// In fr, this message translates to:
  /// **'Annuler {title}'**
  String getCancelNamed(String title);

  /// No description provided for @getCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le téléchargement ?'**
  String get getCancelTitle;

  /// No description provided for @getCancelBody.
  ///
  /// In fr, this message translates to:
  /// **'{title} sera retiré de la file et ses fichiers partiels supprimés.'**
  String getCancelBody(String title);

  /// No description provided for @getCancelConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le téléchargement'**
  String get getCancelConfirm;

  /// No description provided for @getKeepDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get getKeepDownloading;

  /// No description provided for @getActRestart.
  ///
  /// In fr, this message translates to:
  /// **'Recommencer {title} depuis le début'**
  String getActRestart(String title);

  /// No description provided for @getOpenFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier'**
  String get getOpenFolder;

  /// No description provided for @getShowInFolder.
  ///
  /// In fr, this message translates to:
  /// **'Afficher dans le dossier'**
  String get getShowInFolder;

  /// No description provided for @getStDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get getStDone;

  /// No description provided for @getFileGone.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est plus dans la bibliothèque.'**
  String get getFileGone;

  /// No description provided for @getStFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get getStFailed;

  /// No description provided for @getStResumeAt.
  ///
  /// In fr, this message translates to:
  /// **'reprise {n} %'**
  String getStResumeAt(int n);

  /// No description provided for @getStOffline.
  ///
  /// In fr, this message translates to:
  /// **'En pause · hors ligne'**
  String get getStOffline;

  /// No description provided for @getStRetry.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue · nouvel essai {n} s'**
  String getStRetry(int n);

  /// No description provided for @getStDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement'**
  String get getStDownloading;

  /// No description provided for @getStConverting.
  ///
  /// In fr, this message translates to:
  /// **'Conversion'**
  String get getStConverting;

  /// No description provided for @getStConvertingTo.
  ///
  /// In fr, this message translates to:
  /// **'Conversion {ext}'**
  String getStConvertingTo(String ext);

  /// No description provided for @getStFinalizing.
  ///
  /// In fr, this message translates to:
  /// **'Finalisation {ext}'**
  String getStFinalizing(String ext);

  /// No description provided for @getStStep.
  ///
  /// In fr, this message translates to:
  /// **'étape 2/2'**
  String get getStStep;

  /// No description provided for @getStPaused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get getStPaused;

  /// No description provided for @getStPausedRestart.
  ///
  /// In fr, this message translates to:
  /// **'En pause · redémarrera'**
  String get getStPausedRestart;

  /// No description provided for @getStDiskFull.
  ///
  /// In fr, this message translates to:
  /// **'Échec · disque plein'**
  String get getStDiskFull;

  /// No description provided for @getStAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Échec · dossier non accessible'**
  String get getStAccessDenied;

  /// No description provided for @getStDiskFullHint.
  ///
  /// In fr, this message translates to:
  /// **'libérez de l’espace puis réessayez'**
  String get getStDiskFullHint;

  /// No description provided for @getStAccessDeniedHint.
  ///
  /// In fr, this message translates to:
  /// **'choisissez un autre dossier'**
  String get getStAccessDeniedHint;

  /// No description provided for @getStAnalyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse des formats…'**
  String get getStAnalyzing;

  /// No description provided for @getStQueued.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get getStQueued;

  /// No description provided for @getWhyDiskFull.
  ///
  /// In fr, this message translates to:
  /// **'Disque plein'**
  String get getWhyDiskFull;

  /// No description provided for @getWhyNoSpace.
  ///
  /// In fr, this message translates to:
  /// **'Espace disque insuffisant pour ce fichier'**
  String get getWhyNoSpace;

  /// No description provided for @getWhyDenied.
  ///
  /// In fr, this message translates to:
  /// **'Dossier de destination non accessible en écriture'**
  String get getWhyDenied;

  /// No description provided for @getSumRunning.
  ///
  /// In fr, this message translates to:
  /// **'{n} en cours'**
  String getSumRunning(int n);

  /// No description provided for @getSumOffline.
  ///
  /// In fr, this message translates to:
  /// **'En pause · hors ligne'**
  String get getSumOffline;

  /// No description provided for @getSumPaused.
  ///
  /// In fr, this message translates to:
  /// **'Tout en pause'**
  String get getSumPaused;

  /// No description provided for @getSumIdle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun téléchargement'**
  String get getSumIdle;

  /// No description provided for @getSumQueue.
  ///
  /// In fr, this message translates to:
  /// **'{n} en attente'**
  String getSumQueue(int n);

  /// No description provided for @getDirRefused.
  ///
  /// In fr, this message translates to:
  /// **'Ce dossier n’accepte pas de fichiers. Choisissez-en un autre.'**
  String get getDirRefused;

  /// No description provided for @getHistKind.
  ///
  /// In fr, this message translates to:
  /// **'Type d’historique'**
  String get getHistKind;

  /// No description provided for @getHistDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get getHistDownloads;

  /// No description provided for @getHistPlays.
  ///
  /// In fr, this message translates to:
  /// **'Lectures'**
  String get getHistPlays;

  /// No description provided for @getClearHistory.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l’historique'**
  String get getClearHistory;

  /// No description provided for @getClearDlTitle.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l’historique des téléchargements ?'**
  String get getClearDlTitle;

  /// No description provided for @getClearDlBody.
  ///
  /// In fr, this message translates to:
  /// **'La liste des téléchargements passés est effacée. Les fichiers déjà enregistrés dans votre bibliothèque ne sont pas supprimés.'**
  String get getClearDlBody;

  /// No description provided for @getHistEmptyDl.
  ///
  /// In fr, this message translates to:
  /// **'Les téléchargements terminés, échoués ou annulés apparaissent ici.'**
  String get getHistEmptyDl;

  /// No description provided for @getHistNoteDl.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l’historique ne supprime aucun fichier.'**
  String get getHistNoteDl;

  /// No description provided for @getFailedBecause.
  ///
  /// In fr, this message translates to:
  /// **'Échec · {reason}'**
  String getFailedBecause(String reason);

  /// No description provided for @getStCanceled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get getStCanceled;

  /// No description provided for @getActionsFor.
  ///
  /// In fr, this message translates to:
  /// **'Actions pour {title}'**
  String getActionsFor(String title);

  /// No description provided for @getCopySourceLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien source'**
  String get getCopySourceLink;

  /// No description provided for @getLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien source copié'**
  String get getLinkCopied;

  /// No description provided for @getToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get getToday;

  /// No description provided for @getYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get getYesterday;

  /// No description provided for @setDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get setDownloads;

  /// No description provided for @getSaveTo.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans'**
  String get getSaveTo;

  /// No description provided for @getDefaultVideoQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité vidéo par défaut'**
  String get getDefaultVideoQuality;

  /// No description provided for @getDefaultVideoQualityDesc.
  ///
  /// In fr, this message translates to:
  /// **'Qualité inférieure si indisponible.'**
  String get getDefaultVideoQualityDesc;

  /// No description provided for @getDefaultAudio.
  ///
  /// In fr, this message translates to:
  /// **'Format audio par défaut'**
  String get getDefaultAudio;

  /// No description provided for @getSimultaneous.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements simultanés'**
  String get getSimultaneous;

  /// No description provided for @getSimultaneousDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les suivants attendent dans la file.'**
  String get getSimultaneousDesc;

  /// No description provided for @getSpeedLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite de vitesse'**
  String get getSpeedLimit;

  /// No description provided for @getDownloadSubs.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les sous-titres'**
  String get getDownloadSubs;

  /// No description provided for @getDownloadSubsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l’interface en priorité, si disponible.'**
  String get getDownloadSubsDesc;

  /// No description provided for @getResourceMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de ressources'**
  String get getResourceMode;

  /// No description provided for @getModeEco.
  ///
  /// In fr, this message translates to:
  /// **'Éco'**
  String get getModeEco;

  /// No description provided for @getModeBalanced.
  ///
  /// In fr, this message translates to:
  /// **'Équilibré'**
  String get getModeBalanced;

  /// No description provided for @getModePerformance.
  ///
  /// In fr, this message translates to:
  /// **'Performance'**
  String get getModePerformance;

  /// No description provided for @getModeDesc.
  ///
  /// In fr, this message translates to:
  /// **'{n} téléchargement(s) simultané(s), {c} conversion(s) à la fois.'**
  String getModeDesc(int n, int c);

  /// No description provided for @getMediaTools.
  ///
  /// In fr, this message translates to:
  /// **'Outils média'**
  String get getMediaTools;

  /// No description provided for @getAutoUpdated.
  ///
  /// In fr, this message translates to:
  /// **'mise à jour automatique'**
  String get getAutoUpdated;

  /// No description provided for @getIncludedVerified.
  ///
  /// In fr, this message translates to:
  /// **'Inclus · vérifié'**
  String get getIncludedVerified;

  /// No description provided for @getInstalledVerified.
  ///
  /// In fr, this message translates to:
  /// **'Installé · vérifié'**
  String get getInstalledVerified;

  /// No description provided for @getToDownload.
  ///
  /// In fr, this message translates to:
  /// **'{size} à télécharger'**
  String getToDownload(String size);

  /// No description provided for @getToolsInstalled.
  ///
  /// In fr, this message translates to:
  /// **'Outils média installés et vérifiés'**
  String get getToolsInstalled;

  /// No description provided for @getUpdCheck.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une mise à jour'**
  String get getUpdCheck;

  /// No description provided for @getUpdChecking.
  ///
  /// In fr, this message translates to:
  /// **'Recherche…'**
  String get getUpdChecking;

  /// No description provided for @getYtdlpLatest.
  ///
  /// In fr, this message translates to:
  /// **'yt-dlp est à jour ({v})'**
  String getYtdlpLatest(String v);

  /// No description provided for @getYtdlpUpdated.
  ///
  /// In fr, this message translates to:
  /// **'yt-dlp mis à jour en {v} · signature vérifiée'**
  String getYtdlpUpdated(String v);

  /// No description provided for @getUpdFailed.
  ///
  /// In fr, this message translates to:
  /// **'La mise à jour de yt-dlp n’a pas pu se faire. Réessayez plus tard.'**
  String get getUpdFailed;

  /// No description provided for @getInstallFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les outils n’ont pas pu être téléchargés. Vérifiez la connexion puis réessayez.'**
  String get getInstallFailed;

  /// No description provided for @getLess.
  ///
  /// In fr, this message translates to:
  /// **'Moins'**
  String get getLess;

  /// No description provided for @getMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get getMore;

  /// No description provided for @brAddressPh.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher ou saisir une adresse web'**
  String get brAddressPh;

  /// No description provided for @brCloseTab.
  ///
  /// In fr, this message translates to:
  /// **'Fermer l’onglet {title}'**
  String brCloseTab(String title);

  /// No description provided for @brNewTab.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel onglet (Ctrl T)'**
  String get brNewTab;

  /// No description provided for @brStartTab.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel onglet'**
  String get brStartTab;

  /// No description provided for @brStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter le chargement'**
  String get brStop;

  /// No description provided for @brBack.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get brBack;

  /// No description provided for @brForward.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get brForward;

  /// No description provided for @brReload.
  ///
  /// In fr, this message translates to:
  /// **'Recharger'**
  String get brReload;

  /// No description provided for @brHome.
  ///
  /// In fr, this message translates to:
  /// **'Page de démarrage'**
  String get brHome;

  /// No description provided for @brMediaOne.
  ///
  /// In fr, this message translates to:
  /// **'1 média'**
  String get brMediaOne;

  /// No description provided for @brMediaMany.
  ///
  /// In fr, this message translates to:
  /// **'{n} médias'**
  String brMediaMany(int n);

  /// No description provided for @brStartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher ou ouvrir une page web'**
  String get brStartTitle;

  /// No description provided for @brStartBody.
  ///
  /// In fr, this message translates to:
  /// **'Quand une page contient une vidéo ou un fichier audio, une barre de téléchargement apparaît sous la page.'**
  String get brStartBody;

  /// No description provided for @brLegalHint.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez seulement les médias qui vous appartiennent ou que vous avez le droit d’enregistrer.'**
  String get brLegalHint;

  /// No description provided for @brDownloadFound.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les médias trouvés sur cette page ({n})'**
  String brDownloadFound(int n);

  /// No description provided for @brMediaFound.
  ///
  /// In fr, this message translates to:
  /// **'{n} médias trouvés'**
  String brMediaFound(int n);

  /// No description provided for @brMediaFoundOne.
  ///
  /// In fr, this message translates to:
  /// **'1 média trouvé'**
  String get brMediaFoundOne;

  /// No description provided for @brChooseMedia.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le média et le format'**
  String get brChooseMedia;

  /// No description provided for @brSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger depuis cette page'**
  String get brSheetTitle;

  /// No description provided for @brKindVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get brKindVideo;

  /// No description provided for @brKindAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get brKindAudio;

  /// No description provided for @brKindHls.
  ///
  /// In fr, this message translates to:
  /// **'Flux (HLS)'**
  String get brKindHls;

  /// No description provided for @brKindDash.
  ///
  /// In fr, this message translates to:
  /// **'Flux (DASH)'**
  String get brKindDash;

  /// No description provided for @brKindPage.
  ///
  /// In fr, this message translates to:
  /// **'Lecteur de la page'**
  String get brKindPage;

  /// No description provided for @brItemProtected.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément est peut-être protégé ou demande une connexion. Essayez un autre élément de la page.'**
  String get brItemProtected;

  /// No description provided for @brClosePanel.
  ///
  /// In fr, this message translates to:
  /// **'Fermer le panneau'**
  String get brClosePanel;

  /// No description provided for @brTooManyTabs.
  ///
  /// In fr, this message translates to:
  /// **'12 onglets au plus : fermez-en un pour en ouvrir un autre.'**
  String get brTooManyTabs;

  /// No description provided for @brUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Seules les pages web (http, https) s’ouvrent dans le navigateur.'**
  String get brUnsupported;

  /// No description provided for @brUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le navigateur n’a pas pu démarrer : WebView2 est introuvable ou n’a pas répondu.'**
  String get brUnavailable;

  /// No description provided for @brHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get brHistory;

  /// No description provided for @brFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get brFavorites;

  /// No description provided for @brHistoryViews.
  ///
  /// In fr, this message translates to:
  /// **'Historique ou favoris'**
  String get brHistoryViews;

  /// No description provided for @brHistorySearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans les pages visitées'**
  String get brHistorySearch;

  /// No description provided for @brNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Rien ne correspond à « {q} ».'**
  String brNoMatch(String q);

  /// No description provided for @brHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Les pages que vous visitez apparaissent ici.'**
  String get brHistoryEmpty;

  /// No description provided for @brFavoritesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez une page aux favoris avec l’étoile de la barre d’adresse.'**
  String get brFavoritesEmpty;

  /// No description provided for @brHistoryNote.
  ///
  /// In fr, this message translates to:
  /// **'Gardé sur cet appareil seulement. L’effacer ne supprime aucun fichier ni téléchargement.'**
  String get brHistoryNote;

  /// No description provided for @brDeleteVisit.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {title} de l’historique'**
  String brDeleteVisit(String title);

  /// No description provided for @brRemoveFavorite.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {title} des favoris'**
  String brRemoveFavorite(String title);

  /// No description provided for @brClearTitle.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l’historique du navigateur ?'**
  String get brClearTitle;

  /// No description provided for @brClearBody.
  ///
  /// In fr, this message translates to:
  /// **'Les pages visitées sont oubliées. Les téléchargements, la bibliothèque et les favoris restent.'**
  String get brClearBody;

  /// No description provided for @brCleared.
  ///
  /// In fr, this message translates to:
  /// **'Historique du navigateur effacé'**
  String get brCleared;

  /// No description provided for @brClearHistory.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l’historique'**
  String get brClearHistory;

  /// No description provided for @brFavAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get brFavAdd;

  /// No description provided for @brFavRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get brFavRemove;

  /// No description provided for @brFavAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté aux favoris'**
  String get brFavAdded;

  /// No description provided for @brFavRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Retiré des favoris'**
  String get brFavRemoved;

  /// No description provided for @brSites.
  ///
  /// In fr, this message translates to:
  /// **'Sites'**
  String get brSites;

  /// No description provided for @setExtension.
  ///
  /// In fr, this message translates to:
  /// **'Extension navigateur'**
  String get setExtension;

  /// No description provided for @extLead.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez une page ou une vidéo de Chrome ou Edge vers Miarina Media en un clic : l’analyse s’ouvre ici et vous choisissez le format.'**
  String get extLead;

  /// No description provided for @extAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter les liens envoyés par l’extension'**
  String get extAccept;

  /// No description provided for @extAcceptBody.
  ///
  /// In fr, this message translates to:
  /// **'Rien n’est capturé automatiquement.'**
  String get extAcceptBody;

  /// No description provided for @extSteps.
  ///
  /// In fr, this message translates to:
  /// **'Mise en route'**
  String get extSteps;

  /// No description provided for @extStep1.
  ///
  /// In fr, this message translates to:
  /// **'Installer l’extension'**
  String get extStep1;

  /// No description provided for @extStep1Body.
  ///
  /// In fr, this message translates to:
  /// **'Chrome · Edge : page Extensions, activez le mode développeur, puis « Charger l’extension non empaquetée » et choisissez ce dossier.'**
  String get extStep1Body;

  /// No description provided for @extOpenFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier'**
  String get extOpenFolder;

  /// No description provided for @extStep2.
  ///
  /// In fr, this message translates to:
  /// **'Connecter ce PC'**
  String get extStep2;

  /// No description provided for @extStep2Body.
  ///
  /// In fr, this message translates to:
  /// **'Chrome et Edge pourront envoyer des liens à Miarina Media sur cet ordinateur.'**
  String get extStep2Body;

  /// No description provided for @extConnected.
  ///
  /// In fr, this message translates to:
  /// **'Chrome et Edge sont connectés.'**
  String get extConnected;

  /// No description provided for @extOther.
  ///
  /// In fr, this message translates to:
  /// **'Une autre installation de Miarina Media est connectée ; Connecter la remplace.'**
  String get extOther;

  /// No description provided for @extConnect.
  ///
  /// In fr, this message translates to:
  /// **'Connecter'**
  String get extConnect;

  /// No description provided for @extDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get extDisconnect;

  /// No description provided for @extStep3.
  ///
  /// In fr, this message translates to:
  /// **'Tester la connexion'**
  String get extStep3;

  /// No description provided for @extTest.
  ///
  /// In fr, this message translates to:
  /// **'Tester'**
  String get extTest;

  /// No description provided for @extTestNever.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore testée.'**
  String get extTestNever;

  /// No description provided for @extTestOk.
  ///
  /// In fr, this message translates to:
  /// **'Dernier test : réussi à {time}'**
  String extTestOk(String time);

  /// No description provided for @extTestFailed.
  ///
  /// In fr, this message translates to:
  /// **'Dernier test : échoué à {time}'**
  String extTestFailed(String time);

  /// No description provided for @extTestDone.
  ///
  /// In fr, this message translates to:
  /// **'La connexion fonctionne.'**
  String get extTestDone;

  /// No description provided for @extTestBad.
  ///
  /// In fr, this message translates to:
  /// **'Le pont du navigateur ne répond pas. Déconnectez puis reconnectez.'**
  String get extTestBad;

  /// No description provided for @extNoBridge.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de Miarina Media n’inclut pas le pont du navigateur.'**
  String get extNoBridge;

  /// No description provided for @extFailed.
  ///
  /// In fr, this message translates to:
  /// **'La connexion n’a pas pu être modifiée.'**
  String get extFailed;

  /// No description provided for @extPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'L’extension ne lit rien dans les pages : seul le lien que vous envoyez part, et seulement vers Miarina Media sur cet ordinateur.'**
  String get extPrivacy;

  /// No description provided for @brTabs.
  ///
  /// In fr, this message translates to:
  /// **'Onglets'**
  String get brTabs;

  /// No description provided for @brTabsOpen.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 onglet ouvert} other{{n} onglets ouverts}}'**
  String brTabsOpen(int n);

  /// No description provided for @brBackToApp.
  ///
  /// In fr, this message translates to:
  /// **'Retour à Miarina Media'**
  String get brBackToApp;

  /// No description provided for @brDownloadCount.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger · {n}'**
  String brDownloadCount(int n);

  /// No description provided for @brDownloadHoldHint.
  ///
  /// In fr, this message translates to:
  /// **'Appui long : télécharger le média principal au format par défaut'**
  String get brDownloadHoldHint;

  /// No description provided for @brUnavailablePhone.
  ///
  /// In fr, this message translates to:
  /// **'Le navigateur n’a pas pu démarrer sur cet appareil.'**
  String get brUnavailablePhone;

  /// No description provided for @brStartBodyPhone.
  ///
  /// In fr, this message translates to:
  /// **'Quand une page contient une vidéo ou un fichier audio, un bouton Télécharger apparaît au-dessus de la page.'**
  String get brStartBodyPhone;

  /// No description provided for @getReorderNamed.
  ///
  /// In fr, this message translates to:
  /// **'Réordonner {title} (Alt + flèches haut et bas, ou glisser)'**
  String getReorderNamed(String title);

  /// No description provided for @torCapped.
  ///
  /// In fr, this message translates to:
  /// **'Partage plafonné, en Ko/s'**
  String get torCapped;

  /// No description provided for @torChecking.
  ///
  /// In fr, this message translates to:
  /// **'Vérification des fichiers'**
  String get torChecking;

  /// No description provided for @torDoneMeta.
  ///
  /// In fr, this message translates to:
  /// **'Terminé · {size}'**
  String torDoneMeta(String size);

  /// No description provided for @torDoneSharing.
  ///
  /// In fr, this message translates to:
  /// **'Terminé · {size} · partage en cours'**
  String torDoneSharing(String size);

  /// No description provided for @torDown.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get torDown;

  /// No description provided for @torDownLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite de réception'**
  String get torDownLimit;

  /// No description provided for @torEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vos torrents apparaîtront ici.'**
  String get torEmpty;

  /// No description provided for @torEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer la session'**
  String get torEnable;

  /// No description provided for @torError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur · le transfert s’est arrêté'**
  String get torError;

  /// No description provided for @torFailed.
  ///
  /// In fr, this message translates to:
  /// **'L’opération n’a pas pu aboutir.'**
  String get torFailed;

  /// No description provided for @torInactive.
  ///
  /// In fr, this message translates to:
  /// **'Session arrêtée'**
  String get torInactive;

  /// No description provided for @torInspect.
  ///
  /// In fr, this message translates to:
  /// **'Analyser le lien'**
  String get torInspect;

  /// No description provided for @torLeft.
  ///
  /// In fr, this message translates to:
  /// **'Reste'**
  String get torLeft;

  /// No description provided for @torLimitsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Limites appliquées'**
  String get torLimitsSaved;

  /// No description provided for @torMagnet.
  ///
  /// In fr, this message translates to:
  /// **'Lien magnet'**
  String get torMagnet;

  /// No description provided for @torOpenFile.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir un .torrent'**
  String get torOpenFile;

  /// No description provided for @torPausedMeta.
  ///
  /// In fr, this message translates to:
  /// **'En pause · {done} / {total}'**
  String torPausedMeta(String done, String total);

  /// No description provided for @torPeers.
  ///
  /// In fr, this message translates to:
  /// **'Pairs'**
  String get torPeers;

  /// No description provided for @torPreviewNote.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers sont enregistrés dans un nouveau dossier, sous votre dossier de téléchargement / Torrents. De petits morceaux en bordure de fichiers non choisis peuvent aussi être écrits.'**
  String get torPreviewNote;

  /// No description provided for @torRatio.
  ///
  /// In fr, this message translates to:
  /// **'Ratio'**
  String get torRatio;

  /// No description provided for @torRatioDesc.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt du partage au-delà · 0 = sans limite'**
  String get torRatioDesc;

  /// No description provided for @torRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get torRemove;

  /// No description provided for @torRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers téléchargés sont conservés. Le transfert et le partage s’arrêtent.'**
  String get torRemoveBody;

  /// No description provided for @torRemoveNamed.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name}'**
  String torRemoveNamed(String name);

  /// No description provided for @torRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce torrent ?'**
  String get torRemoveTitle;

  /// No description provided for @torResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get torResume;

  /// No description provided for @torSeedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt après la durée · 0 = sans limite'**
  String get torSeedDesc;

  /// No description provided for @torSeedTime.
  ///
  /// In fr, this message translates to:
  /// **'Durée de partage'**
  String get torSeedTime;

  /// No description provided for @torSequential.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les morceaux dans l’ordre'**
  String get torSequential;

  /// No description provided for @torSessionOff.
  ///
  /// In fr, this message translates to:
  /// **'Session arrêtée'**
  String get torSessionOff;

  /// No description provided for @torSessionOn.
  ///
  /// In fr, this message translates to:
  /// **'Session active'**
  String get torSessionOn;

  /// No description provided for @torSessionSharing.
  ///
  /// In fr, this message translates to:
  /// **'Session active · partage en cours'**
  String get torSessionSharing;

  /// No description provided for @torSharing.
  ///
  /// In fr, this message translates to:
  /// **'Partage'**
  String get torSharing;

  /// No description provided for @torStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer le téléchargement'**
  String get torStart;

  /// No description provided for @torStopAll.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter tout et le partage'**
  String get torStopAll;

  /// No description provided for @torStopSharing.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter le partage'**
  String get torStopSharing;

  /// No description provided for @torSub.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un lien magnet ou un fichier .torrent. Un torrent partage les morceaux téléchargés avec d’autres pairs, y compris après la fin : le partage est affiché et vous pouvez l’arrêter à tout moment.'**
  String get torSub;

  /// No description provided for @torTargetRatio.
  ///
  /// In fr, this message translates to:
  /// **'Ratio cible'**
  String get torTargetRatio;

  /// No description provided for @torUnlimited.
  ///
  /// In fr, this message translates to:
  /// **'0 = illimité, en Ko/s'**
  String get torUnlimited;

  /// No description provided for @torUp.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé'**
  String get torUp;

  /// No description provided for @torUpLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite d’envoi'**
  String get torUpLimit;

  /// No description provided for @torWait.
  ///
  /// In fr, this message translates to:
  /// **'Patientez…'**
  String get torWait;

  /// No description provided for @torLinkInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien magnet n’est pas valide.'**
  String get torLinkInvalid;

  /// No description provided for @torDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Ce torrent est déjà dans la liste.'**
  String get torDuplicate;

  /// No description provided for @torSelection.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez au moins un fichier.'**
  String get torSelection;

  /// No description provided for @torSessionChanged.
  ///
  /// In fr, this message translates to:
  /// **'La session a changé : analysez le lien à nouveau.'**
  String get torSessionChanged;

  /// No description provided for @torPlannedHint.
  ///
  /// In fr, this message translates to:
  /// **'Prévu dans un prochain lot : pas encore disponible.'**
  String get torPlannedHint;

  /// No description provided for @torPlanned.
  ///
  /// In fr, this message translates to:
  /// **'PRÉVU'**
  String get torPlanned;

  /// No description provided for @filterMissingCount.
  ///
  /// In fr, this message translates to:
  /// **'Introuvables · {count}'**
  String filterMissingCount(int count);

  /// No description provided for @filterAddedThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutés ce mois'**
  String get filterAddedThisMonth;

  /// No description provided for @selectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 sélectionné} other{{count} sélectionnés}}'**
  String selectedCount(int count);

  /// No description provided for @playNext.
  ///
  /// In fr, this message translates to:
  /// **'Lire ensuite'**
  String get playNext;

  /// No description provided for @addToQueue.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la file'**
  String get addToQueue;

  /// No description provided for @addTo.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à…'**
  String get addTo;

  /// No description provided for @addToPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à une playlist…'**
  String get addToPlaylist;

  /// No description provided for @addToPlaylistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à une playlist'**
  String get addToPlaylistTitle;

  /// No description provided for @newPlaylistEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle playlist…'**
  String get newPlaylistEllipsis;

  /// No description provided for @showInExplorer.
  ///
  /// In fr, this message translates to:
  /// **'Afficher dans l’Explorateur'**
  String get showInExplorer;

  /// No description provided for @removeEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Retirer…'**
  String get removeEllipsis;

  /// No description provided for @playNextDone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Le titre sera lu ensuite} other{Les {count} titres seront lus ensuite}}'**
  String playNextDone(int count);

  /// No description provided for @queueAddDone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 titre ajouté à la file} other{{count} titres ajoutés à la file}}'**
  String queueAddDone(int count);

  /// No description provided for @playlistAddDone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 titre ajouté à « {name} »} other{{count} titres ajoutés à « {name} »}}'**
  String playlistAddDone(int count, String name);

  /// No description provided for @sortByColumn.
  ///
  /// In fr, this message translates to:
  /// **'Trier par {column}'**
  String sortByColumn(String column);

  /// No description provided for @sortedAscending.
  ///
  /// In fr, this message translates to:
  /// **'tri croissant'**
  String get sortedAscending;

  /// No description provided for @sortedDescending.
  ///
  /// In fr, this message translates to:
  /// **'tri décroissant'**
  String get sortedDescending;

  /// No description provided for @clearSelection.
  ///
  /// In fr, this message translates to:
  /// **'Désélectionner'**
  String get clearSelection;

  /// No description provided for @playSelection.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get playSelection;

  /// No description provided for @keyEnter.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get keyEnter;

  /// No description provided for @keyCtrlEnter.
  ///
  /// In fr, this message translates to:
  /// **'Ctrl Entrée'**
  String get keyCtrlEnter;

  /// No description provided for @keyDelete.
  ///
  /// In fr, this message translates to:
  /// **'Suppr'**
  String get keyDelete;

  /// No description provided for @filterNeverPlayed.
  ///
  /// In fr, this message translates to:
  /// **'Jamais écoutés'**
  String get filterNeverPlayed;

  /// No description provided for @filterHiRes.
  ///
  /// In fr, this message translates to:
  /// **'Hi-res'**
  String get filterHiRes;

  /// No description provided for @groupSortAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutés récemment'**
  String get groupSortAdded;

  /// No description provided for @groupSortName.
  ///
  /// In fr, this message translates to:
  /// **'A → Z'**
  String get groupSortName;

  /// No description provided for @groupSortYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get groupSortYear;

  /// No description provided for @groupSortPlays.
  ///
  /// In fr, this message translates to:
  /// **'Les plus écoutés'**
  String get groupSortPlays;

  /// No description provided for @groupSortTracks.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de titres'**
  String get groupSortTracks;

  /// No description provided for @filterLossless.
  ///
  /// In fr, this message translates to:
  /// **'FLAC / hi-res'**
  String get filterLossless;

  /// No description provided for @filterDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargés avec Miarina Media'**
  String get filterDownloaded;

  /// No description provided for @filterCompilations.
  ///
  /// In fr, this message translates to:
  /// **'Compilations'**
  String get filterCompilations;

  /// No description provided for @filterNoCover.
  ///
  /// In fr, this message translates to:
  /// **'Sans pochette · {count}'**
  String filterNoCover(int count);

  /// No description provided for @filterEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien avec ce filtre'**
  String get filterEmptyTitle;

  /// No description provided for @filterEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez « Tous » pour revoir toute la liste.'**
  String get filterEmptyBody;

  /// No description provided for @viewGrid.
  ///
  /// In fr, this message translates to:
  /// **'Grille'**
  String get viewGrid;

  /// No description provided for @viewList.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get viewList;

  /// No description provided for @playsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucune écoute} =1{1 écoute} other{{count} écoutes}}'**
  String playsCount(int count);

  /// No description provided for @playedTimes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{écouté 1 fois} other{écouté {count} fois}}'**
  String playedTimes(int count);

  /// No description provided for @saveAsPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer en playlist'**
  String get saveAsPlaylist;

  /// No description provided for @editTags.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les tags'**
  String get editTags;

  /// No description provided for @tagFromName.
  ///
  /// In fr, this message translates to:
  /// **'Remplir depuis le nom du fichier'**
  String get tagFromName;

  /// No description provided for @tagRename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le fichier « Artiste - Titre »'**
  String get tagRename;

  /// No description provided for @fTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get fTitle;

  /// No description provided for @fArtist.
  ///
  /// In fr, this message translates to:
  /// **'Artiste'**
  String get fArtist;

  /// No description provided for @fAlbumArtist.
  ///
  /// In fr, this message translates to:
  /// **'Artiste de l’album'**
  String get fAlbumArtist;

  /// No description provided for @fAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Album'**
  String get fAlbum;

  /// No description provided for @fYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get fYear;

  /// No description provided for @fGenre.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get fGenre;

  /// No description provided for @fTrack.
  ///
  /// In fr, this message translates to:
  /// **'N° de piste'**
  String get fTrack;

  /// No description provided for @fDisc.
  ///
  /// In fr, this message translates to:
  /// **'N° de disque'**
  String get fDisc;

  /// No description provided for @fComment.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire'**
  String get fComment;

  /// No description provided for @fLyrics.
  ///
  /// In fr, this message translates to:
  /// **'Paroles (facultatif)'**
  String get fLyrics;

  /// No description provided for @fLyricsPh.
  ///
  /// In fr, this message translates to:
  /// **'Collez le texte ou le contenu d’un fichier .lrc'**
  String get fLyricsPh;

  /// No description provided for @tagNote.
  ///
  /// In fr, this message translates to:
  /// **'Modifier un tag ne change pas la qualité audio ou vidéo.'**
  String get tagNote;

  /// No description provided for @renameNote.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier sera renommé : {name}'**
  String renameNote(String name);

  /// No description provided for @tagWrite.
  ///
  /// In fr, this message translates to:
  /// **'Écrire aussi dans le fichier (sinon : bibliothèque Miarina Media seulement)'**
  String get tagWrite;

  /// No description provided for @tagWriteUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Ce format garde ses tags dans la bibliothèque Miarina Media seulement.'**
  String get tagWriteUnsupported;

  /// No description provided for @tagsSavedFile.
  ///
  /// In fr, this message translates to:
  /// **'Tags écrits dans le fichier.'**
  String get tagsSavedFile;

  /// No description provided for @tagsSavedLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Tags enregistrés dans la bibliothèque. Fichier inchangé.'**
  String get tagsSavedLibrary;

  /// No description provided for @invalidNumber.
  ///
  /// In fr, this message translates to:
  /// **'Nombre entier attendu'**
  String get invalidNumber;

  /// No description provided for @coverChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image…'**
  String get coverChoose;

  /// No description provided for @coverSource.
  ///
  /// In fr, this message translates to:
  /// **'Miniature de la source'**
  String get coverSource;

  /// No description provided for @coverNoSource.
  ///
  /// In fr, this message translates to:
  /// **'La source n’a pas fourni de miniature'**
  String get coverNoSource;

  /// No description provided for @coverRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la pochette'**
  String get coverRemove;

  /// No description provided for @coverNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pochette'**
  String get coverNone;

  /// No description provided for @coverWorking.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de la pochette…'**
  String get coverWorking;

  /// No description provided for @coverNote.
  ///
  /// In fr, this message translates to:
  /// **'JPEG, PNG, WebP, BMP ou GIF. Réduite à 1000 px et gardée dans la bibliothèque, appliquée tout de suite ; le fichier n’est pas modifié.'**
  String get coverNote;

  /// No description provided for @coverUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Pochette mise à jour'**
  String get coverUpdated;

  /// No description provided for @coverRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Pochette retirée'**
  String get coverRemoved;

  /// No description provided for @errTagsUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Ce type de fichier ne prend pas de tags : rien n’a été enregistré.'**
  String get errTagsUnsupported;

  /// No description provided for @errTagsWrite.
  ///
  /// In fr, this message translates to:
  /// **'Les tags n’ont pas pu être écrits dans le fichier : rien n’a été enregistré.'**
  String get errTagsWrite;

  /// No description provided for @errInvalidName.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom ne peut pas être utilisé.'**
  String get errInvalidName;

  /// No description provided for @errNotInLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Ce titre n’est plus dans la bibliothèque.'**
  String get errNotInLibrary;

  /// No description provided for @errCoverRefused.
  ///
  /// In fr, this message translates to:
  /// **'Cette image ne peut pas servir de pochette (format ou taille).'**
  String get errCoverRefused;

  /// No description provided for @errLibrary.
  ///
  /// In fr, this message translates to:
  /// **'La bibliothèque n’a pas pu faire ce changement.'**
  String get errLibrary;

  /// No description provided for @coverImageType.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get coverImageType;

  /// No description provided for @keyCtrlI.
  ///
  /// In fr, this message translates to:
  /// **'Ctrl I'**
  String get keyCtrlI;

  /// No description provided for @markSeasonSeen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer la saison comme vue'**
  String get markSeasonSeen;

  /// No description provided for @markSeasonUnseen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer la saison comme non vue'**
  String get markSeasonUnseen;

  /// No description provided for @markSeriesSeen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer la série comme vue'**
  String get markSeriesSeen;

  /// No description provided for @markSeriesUnseen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer la série comme non vue'**
  String get markSeriesUnseen;

  /// No description provided for @markSeen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme vu'**
  String get markSeen;

  /// No description provided for @markUnseen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme non vu'**
  String get markUnseen;

  /// No description provided for @fDirector.
  ///
  /// In fr, this message translates to:
  /// **'Réalisateur / auteur'**
  String get fDirector;

  /// No description provided for @fSeries.
  ///
  /// In fr, this message translates to:
  /// **'Série / collection'**
  String get fSeries;

  /// No description provided for @fLicense.
  ///
  /// In fr, this message translates to:
  /// **'Licence / commentaire'**
  String get fLicense;

  /// No description provided for @coverFrame.
  ///
  /// In fr, this message translates to:
  /// **'Capturer l’image à {time}'**
  String coverFrame(String time);

  /// No description provided for @bookmarkAddNote.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note…'**
  String get bookmarkAddNote;

  /// No description provided for @bookmarkEditNote.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la note…'**
  String get bookmarkEditNote;

  /// No description provided for @bookmarkNoteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Note du signet à {time}'**
  String bookmarkNoteTitle(String time);

  /// No description provided for @bookmarksExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter…'**
  String get bookmarksExport;

  /// No description provided for @bookmarksExported.
  ///
  /// In fr, this message translates to:
  /// **'Signets enregistrés : {path}'**
  String bookmarksExported(String path);

  /// No description provided for @bookmarksExportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les signets n’ont pas pu être enregistrés dans ce dossier.'**
  String get bookmarksExportFailed;

  /// No description provided for @dbProblemTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre bibliothèque n’a pas été ouverte'**
  String get dbProblemTitle;

  /// No description provided for @dbTooNew.
  ///
  /// In fr, this message translates to:
  /// **'Cette bibliothèque a été mise à jour par une version plus récente de Miarina Media : cette version ne peut pas l’ouvrir sans risque (schéma {found}, cette version s’arrête au schéma {supported}).\n\nVos données n’ont pas été modifiées. Installez la version la plus récente de Miarina Media.'**
  String dbTooNew(String found, String supported);

  /// No description provided for @dbUpgradeFailed.
  ///
  /// In fr, this message translates to:
  /// **'La mise à jour de votre bibliothèque a échoué. Elle a été annulée : vos données n’ont pas été modifiées.\n\nCopie de sauvegarde : {backup}\nDétail : {reason}\n\nRéinstallez la version précédente de Miarina Media pour continuer à utiliser cette bibliothèque.'**
  String dbUpgradeFailed(String backup, String reason);

  /// No description provided for @dbNoBackup.
  ///
  /// In fr, this message translates to:
  /// **'aucune'**
  String get dbNoBackup;

  /// No description provided for @dbBackupFailed.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media n’a pas pu copier votre bibliothèque avant de la mettre à jour : la mise à jour n’a pas été faite et vos données n’ont pas été modifiées.\n\nVérifiez l’espace libre sur le disque puis relancez Miarina Media.\nDétail : {reason}'**
  String dbBackupFailed(String reason);

  /// No description provided for @dbOpenFailed.
  ///
  /// In fr, this message translates to:
  /// **'La bibliothèque de Miarina Media n’a pas pu être ouverte.\n\nFichier : {file}\nDétail : {reason}'**
  String dbOpenFailed(String file, String reason);

  /// No description provided for @updConverting.
  ///
  /// In fr, this message translates to:
  /// **'Conversion en cours : l’installation sera possible quand elle sera terminée'**
  String get updConverting;

  /// No description provided for @updNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur de mises à jour perdue. Réessayez : un téléchargement reprend là où il s’est arrêté.'**
  String get updNetwork;

  /// No description provided for @updAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media {v} est disponible'**
  String updAvailable(String v);

  /// No description provided for @updBeta.
  ///
  /// In fr, this message translates to:
  /// **'Bêta'**
  String get updBeta;

  /// No description provided for @updActive.
  ///
  /// In fr, this message translates to:
  /// **'{n} téléchargement(s) en cours : interrompus pendant l’installation, retrouvés en pause au redémarrage. Bibliothèque et réglages conservés.'**
  String updActive(String n);

  /// No description provided for @updStopsPlayback.
  ///
  /// In fr, this message translates to:
  /// **'La lecture en cours sera arrêtée'**
  String get updStopsPlayback;

  /// No description provided for @updStopsSharing.
  ///
  /// In fr, this message translates to:
  /// **'Le partage torrent sera arrêté'**
  String get updStopsSharing;

  /// No description provided for @updReady.
  ///
  /// In fr, this message translates to:
  /// **'{v} est prête'**
  String updReady(String v);

  /// No description provided for @updDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement de {v}…'**
  String updDownloading(String v);

  /// No description provided for @updInstalled.
  ///
  /// In fr, this message translates to:
  /// **'Version installée {v} · canal {channel} · {size}'**
  String updInstalled(String v, String channel, String size);

  /// No description provided for @updBadgeReady.
  ///
  /// In fr, this message translates to:
  /// **'Prête'**
  String get updBadgeReady;

  /// No description provided for @updBadgeDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement'**
  String get updBadgeDownloading;

  /// No description provided for @updBadge.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get updBadge;

  /// No description provided for @updProgress.
  ///
  /// In fr, this message translates to:
  /// **'Progression de la mise à jour'**
  String get updProgress;

  /// No description provided for @updProgressText.
  ///
  /// In fr, this message translates to:
  /// **'{done} / {size} · vérification à la fin'**
  String updProgressText(String done, String size);

  /// No description provided for @updPartial.
  ///
  /// In fr, this message translates to:
  /// **'{done} / {size} déjà téléchargés : la suite reprend où elle s’est arrêtée.'**
  String updPartial(String done, String size);

  /// No description provided for @updVerified.
  ///
  /// In fr, this message translates to:
  /// **'Signature et SHA-256 vérifiées'**
  String get updVerified;

  /// No description provided for @updResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le téléchargement'**
  String get updResume;

  /// No description provided for @updDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger · {size}'**
  String updDownload(String size);

  /// No description provided for @updInstalling.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture de l’installation…'**
  String get updInstalling;

  /// No description provided for @updInstall.
  ///
  /// In fr, this message translates to:
  /// **'Installer maintenant'**
  String get updInstall;

  /// No description provided for @updLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get updLater;

  /// No description provided for @updKeptReady.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour gardée prête.'**
  String get updKeptReady;

  /// No description provided for @updWindowsNote.
  ///
  /// In fr, this message translates to:
  /// **'Windows ferme Miarina Media et ouvre l’installateur. Votre bibliothèque, vos playlists, vos positions de lecture et vos réglages sont conservés. Rien n’est installé sans votre accord.'**
  String get updWindowsNote;

  /// No description provided for @updChecking.
  ///
  /// In fr, this message translates to:
  /// **'Recherche…'**
  String get updChecking;

  /// No description provided for @updLatest.
  ///
  /// In fr, this message translates to:
  /// **'Vous utilisez la dernière version ({v}).'**
  String updLatest(String v);

  /// No description provided for @updAutoCheck.
  ///
  /// In fr, this message translates to:
  /// **'Recherche automatique au démarrage et toutes les six heures.'**
  String get updAutoCheck;

  /// No description provided for @updCheck.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une mise à jour'**
  String get updCheck;

  /// No description provided for @updChannel.
  ///
  /// In fr, this message translates to:
  /// **'Canal'**
  String get updChannel;

  /// No description provided for @updChannelDesc.
  ///
  /// In fr, this message translates to:
  /// **'La bêta reçoit les nouveautés avant validation complète.'**
  String get updChannelDesc;

  /// No description provided for @updAuto.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger automatiquement'**
  String get updAuto;

  /// No description provided for @updAutoDesc.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement en Wi-Fi ou réseau non limité. L’installation reste toujours à votre demande.'**
  String get updAutoDesc;

  /// No description provided for @setUpdates.
  ///
  /// In fr, this message translates to:
  /// **'Mises à jour'**
  String get setUpdates;

  /// No description provided for @updView.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get updView;

  /// No description provided for @updVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {v}'**
  String updVersion(String v);

  /// No description provided for @updDevBuild.
  ///
  /// In fr, this message translates to:
  /// **'Version de développement : les mises à jour sont désactivées.'**
  String get updDevBuild;

  /// No description provided for @deviceAccessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accédez à la musique et aux vidéos de ce téléphone'**
  String get deviceAccessTitle;

  /// No description provided for @deviceAccessBody.
  ///
  /// In fr, this message translates to:
  /// **'Miarina Media lit vos fichiers sur l\'appareil. Rien n\'est envoyé, aucun compte n\'est nécessaire.'**
  String get deviceAccessBody;

  /// No description provided for @deviceAccessMusic.
  ///
  /// In fr, this message translates to:
  /// **'Musique et audio'**
  String get deviceAccessMusic;

  /// No description provided for @deviceAccessMusicBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour afficher vos albums, podcasts et cours.'**
  String get deviceAccessMusicBody;

  /// No description provided for @deviceAccessVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get deviceAccessVideo;

  /// No description provided for @deviceAccessVideoBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour vos films, séries et vidéos perso.'**
  String get deviceAccessVideoBody;

  /// No description provided for @deviceAccessNotif.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get deviceAccessNotif;

  /// No description provided for @deviceAccessNotifBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour les commandes de lecture sur l\'écran verrouillé.'**
  String get deviceAccessNotifBody;

  /// No description provided for @deviceAccessAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser l\'accès'**
  String get deviceAccessAllow;

  /// No description provided for @deviceDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux fichiers refusé'**
  String get deviceDeniedTitle;

  /// No description provided for @deviceDeniedBody.
  ///
  /// In fr, this message translates to:
  /// **'Sans cette autorisation, Miarina Media ne voit pas la musique et les vidéos du téléphone. Vos playlists sont conservées.'**
  String get deviceDeniedBody;

  /// No description provided for @deviceDeniedSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les paramètres Android'**
  String get deviceDeniedSettings;

  /// No description provided for @dlNotifWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'une place libre'**
  String get dlNotifWaiting;

  /// No description provided for @dlNotifAnalyzing.
  ///
  /// In fr, this message translates to:
  /// **'Lecture des formats…'**
  String get dlNotifAnalyzing;

  /// No description provided for @dlNotifProcessing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation du fichier…'**
  String get dlNotifProcessing;

  /// No description provided for @dlNotifOf.
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total}'**
  String dlNotifOf(String done, String total);

  /// No description provided for @dlNotifSpeed.
  ///
  /// In fr, this message translates to:
  /// **'{speed} Mo/s'**
  String dlNotifSpeed(String speed);

  /// No description provided for @dlNotifLeftSoon.
  ///
  /// In fr, this message translates to:
  /// **'moins d\'une minute restante'**
  String get dlNotifLeftSoon;

  /// No description provided for @dlNotifLeftMin.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min restantes'**
  String dlNotifLeftMin(int minutes);

  /// No description provided for @dlNotifLeftHours.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes} min restantes'**
  String dlNotifLeftHours(int hours, int minutes);

  /// No description provided for @dlNotifTapToPlay.
  ///
  /// In fr, this message translates to:
  /// **'toucher pour lire'**
  String get dlNotifTapToPlay;

  /// No description provided for @dlNotifPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get dlNotifPause;

  /// No description provided for @dlNotifCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get dlNotifCancel;

  /// No description provided for @dlNotifPauseAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout mettre en pause'**
  String get dlNotifPauseAll;

  /// No description provided for @dlNotifComplete.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement terminé'**
  String get dlNotifComplete;

  /// No description provided for @dlNotifSeveral.
  ///
  /// In fr, this message translates to:
  /// **'%d en cours'**
  String get dlNotifSeveral;

  /// No description provided for @dlNotifChannelProgress.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements en cours'**
  String get dlNotifChannelProgress;

  /// No description provided for @dlNotifChannelDone.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements terminés'**
  String get dlNotifChannelDone;

  /// No description provided for @getPasteLinkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Coller un lien'**
  String get getPasteLinkTitle;

  /// No description provided for @getAnalyzeLink.
  ///
  /// In fr, this message translates to:
  /// **'Analyser le lien'**
  String get getAnalyzeLink;

  /// No description provided for @getShareHint.
  ///
  /// In fr, this message translates to:
  /// **'Ou partagez un lien vers Miarina Media depuis n\'importe quelle app.'**
  String get getShareHint;

  /// No description provided for @getDlCard.
  ///
  /// In fr, this message translates to:
  /// **'{running} en cours · {queued} en attente'**
  String getDlCard(int running, int queued);

  /// No description provided for @plCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 élément} other{{count} éléments}}'**
  String plCount(int count);

  /// No description provided for @plTruncated.
  ///
  /// In fr, this message translates to:
  /// **'Les {shown} premiers sur {total}'**
  String plTruncated(int shown, int total);

  /// No description provided for @plTruncatedUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Les {shown} premiers éléments'**
  String plTruncatedUnknown(int shown);

  /// No description provided for @plQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité pour tous les éléments'**
  String get plQuality;

  /// No description provided for @plQualityNote.
  ///
  /// In fr, this message translates to:
  /// **'Si un élément n’a pas cette qualité, la meilleure en dessous est prise.'**
  String get plQualityNote;

  /// No description provided for @plItems.
  ///
  /// In fr, this message translates to:
  /// **'Éléments'**
  String get plItems;

  /// No description provided for @plSelected.
  ///
  /// In fr, this message translates to:
  /// **'{selected} sur {total} sélectionnés'**
  String plSelected(int selected, int total);

  /// No description provided for @plSelectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get plSelectAll;

  /// No description provided for @plSelectNone.
  ///
  /// In fr, this message translates to:
  /// **'Tout désélectionner'**
  String get plSelectNone;

  /// No description provided for @plUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get plUnavailable;

  /// No description provided for @plItemFallback.
  ///
  /// In fr, this message translates to:
  /// **'Élément {index}'**
  String plItemFallback(int index);

  /// No description provided for @plOwnFolder.
  ///
  /// In fr, this message translates to:
  /// **'Dans un dossier « {name} »'**
  String plOwnFolder(String name);

  /// No description provided for @plDownload.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Télécharger} =1{Télécharger 1 élément} other{Télécharger {count} éléments}}'**
  String plDownload(int count);

  /// No description provided for @plPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation…'**
  String get plPreparing;

  /// No description provided for @plQueued.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 téléchargement ajouté à la file} other{{count} téléchargements ajoutés à la file}}'**
  String plQueued(int count);

  /// No description provided for @plQueueFull.
  ///
  /// In fr, this message translates to:
  /// **'La file est pleine. Terminez ou retirez des téléchargements, puis réessayez.'**
  String get plQueueFull;

  /// No description provided for @plFailed.
  ///
  /// In fr, this message translates to:
  /// **'La playlist n’a pas pu être ajoutée. Réessayez.'**
  String get plFailed;

  /// No description provided for @batchLead.
  ///
  /// In fr, this message translates to:
  /// **'Collez jusqu’à {max} liens, un par ligne. Chacun est analysé, puis ajouté à la file.'**
  String batchLead(int max);

  /// No description provided for @batchHint.
  ///
  /// In fr, this message translates to:
  /// **'https://…\nhttps://…'**
  String get batchHint;

  /// No description provided for @batchClear.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get batchClear;

  /// No description provided for @batchTruncated.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les {max} premiers liens sont gardés.'**
  String batchTruncated(int max);

  /// No description provided for @batchQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité pour les pages vidéo'**
  String get batchQuality;

  /// No description provided for @batchQualityNote.
  ///
  /// In fr, this message translates to:
  /// **'Un fichier direct est gardé tel quel. Si une page n’a pas cette qualité, la meilleure en dessous est prise.'**
  String get batchQualityNote;

  /// No description provided for @batchLinks.
  ///
  /// In fr, this message translates to:
  /// **'Liens'**
  String get batchLinks;

  /// No description provided for @batchValid.
  ///
  /// In fr, this message translates to:
  /// **'{valid} valides sur {total}'**
  String batchValid(int valid, int total);

  /// No description provided for @batchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Les liens collés apparaîtront ici.'**
  String get batchEmpty;

  /// No description provided for @batchAnalyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse…'**
  String get batchAnalyzing;

  /// No description provided for @batchAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à la file'**
  String get batchAdded;

  /// No description provided for @batchFailed.
  ///
  /// In fr, this message translates to:
  /// **'Pas ajouté'**
  String get batchFailed;

  /// No description provided for @batchIsPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'C’est une playlist : utilisez la tuile Playlist'**
  String get batchIsPlaylist;

  /// No description provided for @batchNeedsTools.
  ///
  /// In fr, this message translates to:
  /// **'Outils média à installer : analysez d’abord un lien seul'**
  String get batchNeedsTools;

  /// No description provided for @batchNoAudio.
  ///
  /// In fr, this message translates to:
  /// **'Fichier sans audio seul'**
  String get batchNoAudio;

  /// No description provided for @batchNoVideo.
  ///
  /// In fr, this message translates to:
  /// **'Fichier sans vidéo'**
  String get batchNoVideo;

  /// No description provided for @batchStart.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Télécharger} =1{Télécharger 1 lien} other{Télécharger {count} liens}}'**
  String batchStart(int count);

  /// No description provided for @batchRunning.
  ///
  /// In fr, this message translates to:
  /// **'Analyse des liens…'**
  String get batchRunning;

  /// No description provided for @batchDone.
  ///
  /// In fr, this message translates to:
  /// **'{added} ajoutés à la file · {failed} non ajoutés'**
  String batchDone(int added, int failed);

  /// No description provided for @getSpeedLimitDesc.
  ///
  /// In fr, this message translates to:
  /// **'Partagée entre les téléchargements en cours.'**
  String get getSpeedLimitDesc;

  /// No description provided for @getSpeedUnlimited.
  ///
  /// In fr, this message translates to:
  /// **'Illimitée'**
  String get getSpeedUnlimited;

  /// No description provided for @getNoteSubs.
  ///
  /// In fr, this message translates to:
  /// **'Un fichier de sous-titres par langue, enregistré à côté de vos vidéos. Pour les avoir dans la vidéo, activez Réglages › Téléchargements › Télécharger les sous-titres.'**
  String get getNoteSubs;

  /// No description provided for @crossfadeExclusive.
  ///
  /// In fr, this message translates to:
  /// **'Pas disponible avec la sortie audio exclusive.'**
  String get crossfadeExclusive;

  /// No description provided for @crossfadeSeconds.
  ///
  /// In fr, this message translates to:
  /// **'{s} s'**
  String crossfadeSeconds(int s);

  /// No description provided for @videoSettings.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get videoSettings;

  /// No description provided for @subtitleDelay.
  ///
  /// In fr, this message translates to:
  /// **'Décalage'**
  String get subtitleDelay;

  /// No description provided for @subtitleSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get subtitleSize;

  /// No description provided for @earlier.
  ///
  /// In fr, this message translates to:
  /// **'Plus tôt'**
  String get earlier;

  /// No description provided for @later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get later;

  /// No description provided for @smaller.
  ///
  /// In fr, this message translates to:
  /// **'Plus petit'**
  String get smaller;

  /// No description provided for @larger.
  ///
  /// In fr, this message translates to:
  /// **'Plus grand'**
  String get larger;

  /// No description provided for @slower.
  ///
  /// In fr, this message translates to:
  /// **'Plus lent'**
  String get slower;

  /// No description provided for @faster.
  ///
  /// In fr, this message translates to:
  /// **'Plus rapide'**
  String get faster;

  /// No description provided for @aspectRatio.
  ///
  /// In fr, this message translates to:
  /// **'Format d’image'**
  String get aspectRatio;

  /// No description provided for @aspectAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get aspectAuto;

  /// No description provided for @cropSetting.
  ///
  /// In fr, this message translates to:
  /// **'Recadrage'**
  String get cropSetting;

  /// No description provided for @cropNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get cropNone;

  /// No description provided for @cropFill.
  ///
  /// In fr, this message translates to:
  /// **'Remplir l’écran'**
  String get cropFill;

  /// No description provided for @audioSync.
  ///
  /// In fr, this message translates to:
  /// **'Synchro audio'**
  String get audioSync;

  /// No description provided for @hwDecoding.
  ///
  /// In fr, this message translates to:
  /// **'Décodage matériel'**
  String get hwDecoding;

  /// No description provided for @hwDecodingBody.
  ///
  /// In fr, this message translates to:
  /// **'Repli logiciel automatique en cas d’échec.'**
  String get hwDecodingBody;

  /// No description provided for @hwAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto ({decoder})'**
  String hwAuto(String decoder);

  /// No description provided for @hwSoftware.
  ///
  /// In fr, this message translates to:
  /// **'Logiciel'**
  String get hwSoftware;

  /// No description provided for @abLoop.
  ///
  /// In fr, this message translates to:
  /// **'Boucle A–B'**
  String get abLoop;

  /// No description provided for @abOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivée'**
  String get abOff;

  /// No description provided for @abFrom.
  ///
  /// In fr, this message translates to:
  /// **'A à {time}'**
  String abFrom(String time);

  /// No description provided for @abHintA.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour placer A à la position actuelle.'**
  String get abHintA;

  /// No description provided for @abHintB.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour placer B : la partie A–B se répète.'**
  String get abHintB;

  /// No description provided for @abHintOff.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour arrêter la boucle.'**
  String get abHintOff;

  /// No description provided for @smartSection.
  ///
  /// In fr, this message translates to:
  /// **'Playlists intelligentes'**
  String get smartSection;

  /// No description provided for @smartNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle playlist intelligente'**
  String get smartNewTitle;

  /// No description provided for @smartEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les règles'**
  String get smartEdit;

  /// No description provided for @smartText.
  ///
  /// In fr, this message translates to:
  /// **'Contient'**
  String get smartText;

  /// No description provided for @smartTextHint.
  ///
  /// In fr, this message translates to:
  /// **'Titre, artiste, album…'**
  String get smartTextHint;

  /// No description provided for @smartAny.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get smartAny;

  /// No description provided for @smartFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris uniquement'**
  String get smartFavorites;

  /// No description provided for @smartAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutés'**
  String get smartAdded;

  /// No description provided for @smartAddedAny.
  ///
  /// In fr, this message translates to:
  /// **'Depuis toujours'**
  String get smartAddedAny;

  /// No description provided for @smartAddedDays.
  ///
  /// In fr, this message translates to:
  /// **'{n} derniers jours'**
  String smartAddedDays(int n);

  /// No description provided for @smartSort.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get smartSort;

  /// No description provided for @smartLimit.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de titres'**
  String get smartLimit;

  /// No description provided for @smartLimitAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get smartLimitAll;

  /// No description provided for @smartLimitN.
  ///
  /// In fr, this message translates to:
  /// **'{n} titres'**
  String smartLimitN(int n);

  /// No description provided for @smartCount.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Aucun titre} =1{1 titre} other{{n} titres}} · mise à jour automatique'**
  String smartCount(int n);

  /// No description provided for @smartReading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture de la bibliothèque…'**
  String get smartReading;

  /// No description provided for @smartEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun titre pour ces règles'**
  String get smartEmptyTitle;

  /// No description provided for @smartEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'La playlist se remplira d’elle-même quand la bibliothèque aura des titres qui y correspondent.'**
  String get smartEmptyBody;

  /// No description provided for @smartDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Seules les règles sont supprimées : aucun fichier n’est touché.'**
  String get smartDeleteBody;

  /// No description provided for @smartQueueAddAll.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter les {n}'**
  String smartQueueAddAll(int n);

  /// No description provided for @addQueueOne.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la file'**
  String get addQueueOne;

  /// No description provided for @toolsGroup.
  ///
  /// In fr, this message translates to:
  /// **'Outils PC'**
  String get toolsGroup;

  /// No description provided for @navConvert.
  ///
  /// In fr, this message translates to:
  /// **'Convertir'**
  String get navConvert;

  /// No description provided for @convLead.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un format ou un outil, ajoutez vos fichiers, puis démarrez. Tout reste sur cet ordinateur.'**
  String get convLead;

  /// No description provided for @convRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get convRemove;

  /// No description provided for @convClear.
  ///
  /// In fr, this message translates to:
  /// **'Vider la liste'**
  String get convClear;

  /// No description provided for @convStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get convStart;

  /// No description provided for @convStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get convStop;

  /// No description provided for @catVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get catVideo;

  /// No description provided for @catAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get catAudio;

  /// No description provided for @catImage.
  ///
  /// In fr, this message translates to:
  /// **'Image'**
  String get catImage;

  /// No description provided for @fmtHelpMp4.
  ///
  /// In fr, this message translates to:
  /// **'H.264 + AAC, lisible partout'**
  String get fmtHelpMp4;

  /// No description provided for @fmtHelpMkv.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les pistes et sous-titres'**
  String get fmtHelpMkv;

  /// No description provided for @fmtHelpWebm.
  ///
  /// In fr, this message translates to:
  /// **'VP9 + Opus, pour le web'**
  String get fmtHelpWebm;

  /// No description provided for @fmtHelpAvi.
  ///
  /// In fr, this message translates to:
  /// **'Anciens lecteurs et TV'**
  String get fmtHelpAvi;

  /// No description provided for @fmtHelpMov.
  ///
  /// In fr, this message translates to:
  /// **'Montage, appareils Apple'**
  String get fmtHelpMov;

  /// No description provided for @fmtHelpGif.
  ///
  /// In fr, this message translates to:
  /// **'Animation courte sans son'**
  String get fmtHelpGif;

  /// No description provided for @fmtHelpMp3.
  ///
  /// In fr, this message translates to:
  /// **'Lisible partout'**
  String get fmtHelpMp3;

  /// No description provided for @fmtHelpM4a.
  ///
  /// In fr, this message translates to:
  /// **'AAC, appareils Apple'**
  String get fmtHelpM4a;

  /// No description provided for @fmtHelpFlac.
  ///
  /// In fr, this message translates to:
  /// **'Sans perte'**
  String get fmtHelpFlac;

  /// No description provided for @fmtHelpWav.
  ///
  /// In fr, this message translates to:
  /// **'Non compressé'**
  String get fmtHelpWav;

  /// No description provided for @fmtHelpOgg.
  ///
  /// In fr, this message translates to:
  /// **'Vorbis, format libre'**
  String get fmtHelpOgg;

  /// No description provided for @fmtHelpOpus.
  ///
  /// In fr, this message translates to:
  /// **'Très léger, voix et musique'**
  String get fmtHelpOpus;

  /// No description provided for @fmtHelpPng.
  ///
  /// In fr, this message translates to:
  /// **'Sans perte, transparence'**
  String get fmtHelpPng;

  /// No description provided for @fmtHelpJpg.
  ///
  /// In fr, this message translates to:
  /// **'Photos, léger'**
  String get fmtHelpJpg;

  /// No description provided for @fmtHelpWebp.
  ///
  /// In fr, this message translates to:
  /// **'Web, très léger'**
  String get fmtHelpWebp;

  /// No description provided for @fmtHelpIco.
  ///
  /// In fr, this message translates to:
  /// **'Icône Windows (256 px)'**
  String get fmtHelpIco;

  /// No description provided for @fmtHelpBmp.
  ///
  /// In fr, this message translates to:
  /// **'Non compressé'**
  String get fmtHelpBmp;

  /// No description provided for @toolJoin.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner'**
  String get toolJoin;

  /// No description provided for @toolCut.
  ///
  /// In fr, this message translates to:
  /// **'Découper'**
  String get toolCut;

  /// No description provided for @toolCrop.
  ///
  /// In fr, this message translates to:
  /// **'Rogner'**
  String get toolCrop;

  /// No description provided for @toolCompress.
  ///
  /// In fr, this message translates to:
  /// **'Compresser'**
  String get toolCompress;

  /// No description provided for @toolFrames.
  ///
  /// In fr, this message translates to:
  /// **'Exporter les images'**
  String get toolFrames;

  /// No description provided for @toolExtract.
  ///
  /// In fr, this message translates to:
  /// **'Extraire d’une vidéo'**
  String get toolExtract;

  /// No description provided for @toolResize.
  ///
  /// In fr, this message translates to:
  /// **'Redimensionner'**
  String get toolResize;

  /// No description provided for @toolHelpJoinVideo.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs vidéos bout à bout, en un MP4'**
  String get toolHelpJoinVideo;

  /// No description provided for @toolHelpJoinAudio.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs fichiers bout à bout, en un MP3'**
  String get toolHelpJoinAudio;

  /// No description provided for @toolHelpCut.
  ///
  /// In fr, this message translates to:
  /// **'Garder une partie, sans réencoder'**
  String get toolHelpCut;

  /// No description provided for @toolHelpCrop.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer au centre : 16:9, 4:3, 1:1, 9:16'**
  String get toolHelpCrop;

  /// No description provided for @toolHelpCompress.
  ///
  /// In fr, this message translates to:
  /// **'Fichier bien plus léger, qualité proche de l’original (AV1 ou H.264)'**
  String get toolHelpCompress;

  /// No description provided for @toolHelpFrames.
  ///
  /// In fr, this message translates to:
  /// **'Une image JPG toutes les quelques secondes'**
  String get toolHelpFrames;

  /// No description provided for @toolHelpExtract.
  ///
  /// In fr, this message translates to:
  /// **'Garder le son, en MP3'**
  String get toolHelpExtract;

  /// No description provided for @toolHelpResize.
  ///
  /// In fr, this message translates to:
  /// **'Changer la largeur, proportions gardées'**
  String get toolHelpResize;

  /// No description provided for @convTo.
  ///
  /// In fr, this message translates to:
  /// **'Convertir en {format}'**
  String convTo(String format);

  /// No description provided for @convNoFiles.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier. Ajoutez-en ou glissez-les ici.'**
  String get convNoFiles;

  /// No description provided for @convAddFiles.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des fichiers'**
  String get convAddFiles;

  /// No description provided for @convAddFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dossier'**
  String get convAddFolder;

  /// No description provided for @convAddToList.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Ajouter à la liste} other{Ajouter à la liste ({n})}}'**
  String convAddToList(int n);

  /// No description provided for @convJoinNeedsTwo.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins deux fichiers à fusionner.'**
  String get convJoinNeedsTwo;

  /// No description provided for @optQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get optQuality;

  /// No description provided for @optSource.
  ///
  /// In fr, this message translates to:
  /// **'Source'**
  String get optSource;

  /// No description provided for @optHigh.
  ///
  /// In fr, this message translates to:
  /// **'Haute'**
  String get optHigh;

  /// No description provided for @optMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne'**
  String get optMedium;

  /// No description provided for @optSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petite'**
  String get optSmall;

  /// No description provided for @optResolution.
  ///
  /// In fr, this message translates to:
  /// **'Résolution'**
  String get optResolution;

  /// No description provided for @optBitrate.
  ///
  /// In fr, this message translates to:
  /// **'Débit'**
  String get optBitrate;

  /// No description provided for @optKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder de… à…'**
  String get optKeep;

  /// No description provided for @optKeepHint.
  ///
  /// In fr, this message translates to:
  /// **'hh:mm:ss ; la fin vide = jusqu’au bout'**
  String get optKeepHint;

  /// No description provided for @optCrop.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get optCrop;

  /// No description provided for @optEvery.
  ///
  /// In fr, this message translates to:
  /// **'Une image toutes les'**
  String get optEvery;

  /// No description provided for @optWidth.
  ///
  /// In fr, this message translates to:
  /// **'Largeur'**
  String get optWidth;

  /// No description provided for @optOutDir.
  ///
  /// In fr, this message translates to:
  /// **'Dossier de sortie'**
  String get optOutDir;

  /// No description provided for @optSeconds.
  ///
  /// In fr, this message translates to:
  /// **'{n} s'**
  String optSeconds(int n);

  /// No description provided for @colPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get colPreview;

  /// No description provided for @colSource.
  ///
  /// In fr, this message translates to:
  /// **'Source · {n}'**
  String colSource(int n);

  /// No description provided for @colOutput.
  ///
  /// In fr, this message translates to:
  /// **'Sortie / état'**
  String get colOutput;

  /// No description provided for @stWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get stWaiting;

  /// No description provided for @stConverting.
  ///
  /// In fr, this message translates to:
  /// **'Conversion…'**
  String get stConverting;

  /// No description provided for @stDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get stDone;

  /// No description provided for @stStopped.
  ///
  /// In fr, this message translates to:
  /// **'Arrêté'**
  String get stStopped;

  /// No description provided for @stFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get stFailed;

  /// No description provided for @convLineFormat.
  ///
  /// In fr, this message translates to:
  /// **'Conversion · qualité {quality}'**
  String convLineFormat(String quality);

  /// No description provided for @convLineSame.
  ///
  /// In fr, this message translates to:
  /// **'Conversion · qualité identique à la source'**
  String get convLineSame;

  /// No description provided for @convFiles.
  ///
  /// In fr, this message translates to:
  /// **'{n} fichiers'**
  String convFiles(int n);

  /// No description provided for @convEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'La liste est vide'**
  String get convEmptyTitle;

  /// No description provided for @convEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un format à gauche, ou glissez des fichiers ici.'**
  String get convEmptyBody;

  /// No description provided for @convDropHint.
  ///
  /// In fr, this message translates to:
  /// **'Glissez des fichiers ici pour les ajouter avec le dernier format choisi'**
  String get convDropHint;

  /// No description provided for @convDropNoChoice.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez d’abord un format ou un outil à gauche.'**
  String get convDropNoChoice;

  /// No description provided for @convMulti.
  ///
  /// In fr, this message translates to:
  /// **'Multi-conversion'**
  String get convMulti;

  /// No description provided for @convElapsed.
  ///
  /// In fr, this message translates to:
  /// **'Temps écoulé'**
  String get convElapsed;

  /// No description provided for @convShutdown.
  ///
  /// In fr, this message translates to:
  /// **'Éteindre le PC à la fin'**
  String get convShutdown;

  /// No description provided for @convNotify.
  ///
  /// In fr, this message translates to:
  /// **'Notifier'**
  String get convNotify;

  /// No description provided for @convDone.
  ///
  /// In fr, this message translates to:
  /// **'Conversion terminée'**
  String get convDone;

  /// No description provided for @convOpenFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier'**
  String get convOpenFolder;

  /// No description provided for @convRemoveRunning.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » est en cours de conversion. La retirer arrête sa conversion.'**
  String convRemoveRunning(String name);

  /// No description provided for @convShutdownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le PC va s’éteindre'**
  String get convShutdownTitle;

  /// No description provided for @convShutdownBody.
  ///
  /// In fr, this message translates to:
  /// **'Les conversions sont terminées. Windows éteint le PC dans une minute.'**
  String get convShutdownBody;

  /// No description provided for @convShutdownCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l’arrêt'**
  String get convShutdownCancel;

  /// No description provided for @convToolsMissing.
  ///
  /// In fr, this message translates to:
  /// **'Les outils média ne sont pas installés : analysez un lien dans Obtenir pour les installer.'**
  String get convToolsMissing;

  /// No description provided for @convFailed.
  ///
  /// In fr, this message translates to:
  /// **'Ajout impossible : {reason}'**
  String convFailed(String reason);

  /// No description provided for @capTab.
  ///
  /// In fr, this message translates to:
  /// **'Capture d’écran'**
  String get capTab;

  /// No description provided for @capIntroTitle.
  ///
  /// In fr, this message translates to:
  /// **'Capture depuis n’importe quelle application'**
  String get capIntroTitle;

  /// No description provided for @capIntroBody.
  ///
  /// In fr, this message translates to:
  /// **'Les raccourcis fonctionnent même quand Miarina Media est réduite.'**
  String get capIntroBody;

  /// No description provided for @capTry.
  ///
  /// In fr, this message translates to:
  /// **'Essayer'**
  String get capTry;

  /// No description provided for @capRegion.
  ///
  /// In fr, this message translates to:
  /// **'Capturer une zone'**
  String get capRegion;

  /// No description provided for @capRegionDesc.
  ///
  /// In fr, this message translates to:
  /// **'Assombrit l’écran ; tracez la zone à garder.'**
  String get capRegionDesc;

  /// No description provided for @capFull.
  ///
  /// In fr, this message translates to:
  /// **'Capturer tout l’écran'**
  String get capFull;

  /// No description provided for @capFullDesc.
  ///
  /// In fr, this message translates to:
  /// **'Capture immédiate de l’écran où se trouve la souris.'**
  String get capFullDesc;

  /// No description provided for @capRecord.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer / arrêter l’enregistrement vidéo'**
  String get capRecord;

  /// No description provided for @capRecordDesc.
  ///
  /// In fr, this message translates to:
  /// **'Utilise les derniers réglages de l’enregistreur.'**
  String get capRecordDesc;

  /// No description provided for @capEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get capEdit;

  /// No description provided for @capCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get capCancel;

  /// No description provided for @capListening.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur la combinaison…'**
  String get capListening;

  /// No description provided for @capNoKey.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get capNoKey;

  /// No description provided for @capFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format de l’image'**
  String get capFormat;

  /// No description provided for @capFormatDesc.
  ///
  /// In fr, this message translates to:
  /// **'PNG garde tous les détails ; JPG et WebP sont plus légers.'**
  String get capFormatDesc;

  /// No description provided for @capDelay.
  ///
  /// In fr, this message translates to:
  /// **'Retardateur'**
  String get capDelay;

  /// No description provided for @capDelayDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le temps d’ouvrir un menu avant la capture.'**
  String get capDelayDesc;

  /// No description provided for @capDelayNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get capDelayNone;

  /// No description provided for @capDelaySecs.
  ///
  /// In fr, this message translates to:
  /// **'{n} s'**
  String capDelaySecs(int n);

  /// No description provided for @capSaveTo.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans'**
  String get capSaveTo;

  /// No description provided for @capOpenFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le dossier'**
  String get capOpenFolder;

  /// No description provided for @capCopySetting.
  ///
  /// In fr, this message translates to:
  /// **'Copier dans le presse-papiers'**
  String get capCopySetting;

  /// No description provided for @capCopySettingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Pour coller tout de suite avec Ctrl V.'**
  String get capCopySettingDesc;

  /// No description provided for @capPreview.
  ///
  /// In fr, this message translates to:
  /// **'Afficher un aperçu'**
  String get capPreview;

  /// No description provided for @capPreviewDesc.
  ///
  /// In fr, this message translates to:
  /// **'Une vignette apparaît en bas à droite pendant 4 secondes.'**
  String get capPreviewDesc;

  /// No description provided for @capSound.
  ///
  /// In fr, this message translates to:
  /// **'Son d’obturateur'**
  String get capSound;

  /// No description provided for @capCursor.
  ///
  /// In fr, this message translates to:
  /// **'Inclure le curseur'**
  String get capCursor;

  /// No description provided for @capNeedModifier.
  ///
  /// In fr, this message translates to:
  /// **'Il faut Ctrl, Alt ou Maj avec une autre touche.'**
  String get capNeedModifier;

  /// No description provided for @capKeyUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Cette touche ne peut pas servir de raccourci global.'**
  String get capKeyUnsupported;

  /// No description provided for @capConflict.
  ///
  /// In fr, this message translates to:
  /// **'{keys} sert déjà à « {action} ».'**
  String capConflict(String keys, String action);

  /// No description provided for @capTaken.
  ///
  /// In fr, this message translates to:
  /// **'{keys} est déjà pris par une autre application.'**
  String capTaken(String keys);

  /// No description provided for @capTakenShort.
  ///
  /// In fr, this message translates to:
  /// **'Pris par une autre application'**
  String get capTakenShort;

  /// No description provided for @capHelp.
  ///
  /// In fr, this message translates to:
  /// **'Glissez pour choisir une zone'**
  String get capHelp;

  /// No description provided for @capHelpEnter.
  ///
  /// In fr, this message translates to:
  /// **'capturer'**
  String get capHelpEnter;

  /// No description provided for @capHelpEsc.
  ///
  /// In fr, this message translates to:
  /// **'annuler'**
  String get capHelpEsc;

  /// No description provided for @capKeyEnter.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get capKeyEnter;

  /// No description provided for @capKeyEsc.
  ///
  /// In fr, this message translates to:
  /// **'Échap'**
  String get capKeyEsc;

  /// No description provided for @capWholeScreen.
  ///
  /// In fr, this message translates to:
  /// **'Tout l’écran'**
  String get capWholeScreen;

  /// No description provided for @capFilm.
  ///
  /// In fr, this message translates to:
  /// **'Filmer'**
  String get capFilm;

  /// No description provided for @capCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get capCopy;

  /// No description provided for @capSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get capSave;

  /// No description provided for @capClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get capClose;

  /// No description provided for @capCopied.
  ///
  /// In fr, this message translates to:
  /// **'Capture copiée dans le presse-papiers'**
  String get capCopied;

  /// No description provided for @capOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get capOpen;

  /// No description provided for @capFailed.
  ///
  /// In fr, this message translates to:
  /// **'La capture n’a pas pu être faite.'**
  String get capFailed;

  /// No description provided for @capPngFallback.
  ///
  /// In fr, this message translates to:
  /// **'{name} (JPG/WebP indisponible : enregistrée en PNG)'**
  String capPngFallback(String name);

  /// No description provided for @recNav.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l’écran'**
  String get recNav;

  /// No description provided for @recSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Filmez votre écran avec le son du PC et le micro. Les vidéos arrivent dans la bibliothèque.'**
  String get recSubtitle;

  /// No description provided for @recSourceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Source'**
  String get recSourceTitle;

  /// No description provided for @recScreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get recScreen;

  /// No description provided for @recScreenDesc.
  ///
  /// In fr, this message translates to:
  /// **'Écran {n} · {w} × {h}. Choisissez l’écran si vous en avez plusieurs.'**
  String recScreenDesc(int n, int w, int h);

  /// No description provided for @recScreenN.
  ///
  /// In fr, this message translates to:
  /// **'Écran {n}'**
  String recScreenN(int n);

  /// No description provided for @recWindow.
  ///
  /// In fr, this message translates to:
  /// **'Une fenêtre'**
  String get recWindow;

  /// No description provided for @recWindowDesc.
  ///
  /// In fr, this message translates to:
  /// **'Seule la fenêtre choisie est filmée.'**
  String get recWindowDesc;

  /// No description provided for @recPickWindow.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la fenêtre'**
  String get recPickWindow;

  /// No description provided for @recNoWindows.
  ///
  /// In fr, this message translates to:
  /// **'Aucune fenêtre à filmer.'**
  String get recNoWindows;

  /// No description provided for @recRegion.
  ///
  /// In fr, this message translates to:
  /// **'Une zone'**
  String get recRegion;

  /// No description provided for @recRegionDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tracez un rectangle sur l’écran avant de démarrer.'**
  String get recRegionDesc;

  /// No description provided for @recRegionSize.
  ///
  /// In fr, this message translates to:
  /// **'Zone {w} × {h}'**
  String recRegionSize(int w, int h);

  /// No description provided for @recDraw.
  ///
  /// In fr, this message translates to:
  /// **'Tracer la zone'**
  String get recDraw;

  /// No description provided for @recVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get recVideo;

  /// No description provided for @recFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get recFormat;

  /// No description provided for @recFps.
  ///
  /// In fr, this message translates to:
  /// **'Images par seconde'**
  String get recFps;

  /// No description provided for @recQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get recQuality;

  /// No description provided for @recQMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne'**
  String get recQMedium;

  /// No description provided for @recQHigh.
  ///
  /// In fr, this message translates to:
  /// **'Haute'**
  String get recQHigh;

  /// No description provided for @recQOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Originale'**
  String get recQOriginal;

  /// No description provided for @recFolder.
  ///
  /// In fr, this message translates to:
  /// **'Dossier'**
  String get recFolder;

  /// No description provided for @recSoundOptions.
  ///
  /// In fr, this message translates to:
  /// **'Son et options'**
  String get recSoundOptions;

  /// No description provided for @recSystemAudio.
  ///
  /// In fr, this message translates to:
  /// **'Son du PC'**
  String get recSystemAudio;

  /// No description provided for @recSystemAudioDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous entendez dans les haut-parleurs'**
  String get recSystemAudioDesc;

  /// No description provided for @recMic.
  ///
  /// In fr, this message translates to:
  /// **'Micro'**
  String get recMic;

  /// No description provided for @recMicDesc.
  ///
  /// In fr, this message translates to:
  /// **'Microphone par défaut de Windows'**
  String get recMicDesc;

  /// No description provided for @recCursor.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le curseur'**
  String get recCursor;

  /// No description provided for @recCursorDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le pointeur de la souris apparaît dans la vidéo'**
  String get recCursorDesc;

  /// No description provided for @recCountdown.
  ///
  /// In fr, this message translates to:
  /// **'Compte à rebours'**
  String get recCountdown;

  /// No description provided for @recCountdownDesc.
  ///
  /// In fr, this message translates to:
  /// **'3 secondes avant de démarrer'**
  String get recCountdownDesc;

  /// No description provided for @recStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer l’enregistrement'**
  String get recStart;

  /// No description provided for @recStopAt.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter · {time}'**
  String recStopAt(String time);

  /// No description provided for @recOrPress.
  ///
  /// In fr, this message translates to:
  /// **'ou appuyez sur'**
  String get recOrPress;

  /// No description provided for @recAnywhere.
  ///
  /// In fr, this message translates to:
  /// **'n’importe où'**
  String get recAnywhere;

  /// No description provided for @recFpsUnit.
  ///
  /// In fr, this message translates to:
  /// **'i/s'**
  String get recFpsUnit;

  /// No description provided for @recSumSystem.
  ///
  /// In fr, this message translates to:
  /// **'son du PC'**
  String get recSumSystem;

  /// No description provided for @recSumNoSystem.
  ///
  /// In fr, this message translates to:
  /// **'sans son du PC'**
  String get recSumNoSystem;

  /// No description provided for @recSumMic.
  ///
  /// In fr, this message translates to:
  /// **'micro'**
  String get recSumMic;

  /// No description provided for @recSumNoSound.
  ///
  /// In fr, this message translates to:
  /// **'sans son'**
  String get recSumNoSound;

  /// No description provided for @recRecent.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrements récents'**
  String get recRecent;

  /// No description provided for @recEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun enregistrement pour l’instant.'**
  String get recEmpty;

  /// No description provided for @recSaved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré'**
  String get recSaved;

  /// No description provided for @recMissing.
  ///
  /// In fr, this message translates to:
  /// **'Fichier introuvable'**
  String get recMissing;

  /// No description provided for @recPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get recPlay;

  /// No description provided for @recConvert.
  ///
  /// In fr, this message translates to:
  /// **'Convertir'**
  String get recConvert;

  /// No description provided for @recShowFolder.
  ///
  /// In fr, this message translates to:
  /// **'Afficher dans le dossier'**
  String get recShowFolder;

  /// No description provided for @recRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la liste'**
  String get recRemove;

  /// No description provided for @recRec.
  ///
  /// In fr, this message translates to:
  /// **'REC'**
  String get recRec;

  /// No description provided for @recPausedLabel.
  ///
  /// In fr, this message translates to:
  /// **'PAUSE'**
  String get recPausedLabel;

  /// No description provided for @recPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get recPause;

  /// No description provided for @recResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get recResume;

  /// No description provided for @recMicMute.
  ///
  /// In fr, this message translates to:
  /// **'Couper le micro'**
  String get recMicMute;

  /// No description provided for @recMicUnmute.
  ///
  /// In fr, this message translates to:
  /// **'Activer le micro'**
  String get recMicUnmute;

  /// No description provided for @recStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get recStop;

  /// No description provided for @recFinalizing.
  ///
  /// In fr, this message translates to:
  /// **'Finalisation…'**
  String get recFinalizing;

  /// No description provided for @recStarting.
  ///
  /// In fr, this message translates to:
  /// **'Démarrage dans'**
  String get recStarting;

  /// No description provided for @recSavedToast.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo enregistrée dans la bibliothèque'**
  String get recSavedToast;

  /// No description provided for @recGifSaved.
  ///
  /// In fr, this message translates to:
  /// **'GIF enregistré'**
  String get recGifSaved;

  /// No description provided for @recFailed.
  ///
  /// In fr, this message translates to:
  /// **'L’enregistrement n’a pas pu démarrer.'**
  String get recFailed;

  /// No description provided for @recFinishFailed.
  ///
  /// In fr, this message translates to:
  /// **'La vidéo n’a pas pu être finalisée ; les morceaux restent dans le dossier.'**
  String get recFinishFailed;

  /// No description provided for @recWindowGone.
  ///
  /// In fr, this message translates to:
  /// **'La fenêtre choisie n’est plus ouverte.'**
  String get recWindowGone;

  /// No description provided for @recNoScreen.
  ///
  /// In fr, this message translates to:
  /// **'Aucun écran trouvé.'**
  String get recNoScreen;

  /// No description provided for @recFileWord.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement'**
  String get recFileWord;

  /// No description provided for @recConvertPick.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un format ou un outil : le fichier sera ajouté.'**
  String get recConvertPick;

  /// No description provided for @toolRecord.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l’écran'**
  String get toolRecord;

  /// No description provided for @toolHelpRecord.
  ///
  /// In fr, this message translates to:
  /// **'Filmer l’écran, une fenêtre ou une zone.'**
  String get toolHelpRecord;

  /// No description provided for @videoGestures.
  ///
  /// In fr, this message translates to:
  /// **'Gestes vidéo'**
  String get videoGestures;

  /// No description provided for @videoGesturesBody.
  ///
  /// In fr, this message translates to:
  /// **'Glisser à gauche : luminosité ; à droite : volume. Double-toucher les côtés : ±10 s. Pincer : remplir l’écran.'**
  String get videoGesturesBody;

  /// No description provided for @gestBrightness.
  ///
  /// In fr, this message translates to:
  /// **'Luminosité'**
  String get gestBrightness;

  /// No description provided for @gestVolume.
  ///
  /// In fr, this message translates to:
  /// **'Volume'**
  String get gestVolume;

  /// No description provided for @gestJump.
  ///
  /// In fr, this message translates to:
  /// **'{sign}{n} s'**
  String gestJump(String sign, int n);

  /// No description provided for @lockControls.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller l’écran'**
  String get lockControls;

  /// No description provided for @unlockControls.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller'**
  String get unlockControls;

  /// No description provided for @pipEnter.
  ///
  /// In fr, this message translates to:
  /// **'Image dans l’image'**
  String get pipEnter;

  /// No description provided for @rotateScreen.
  ///
  /// In fr, this message translates to:
  /// **'Tourner l’écran'**
  String get rotateScreen;

  /// No description provided for @fillScreen.
  ///
  /// In fr, this message translates to:
  /// **'Remplir l’écran'**
  String get fillScreen;

  /// No description provided for @fitScreen.
  ///
  /// In fr, this message translates to:
  /// **'Image entière'**
  String get fitScreen;

  /// No description provided for @playlistExportAndroid.
  ///
  /// In fr, this message translates to:
  /// **'Exportée dans {path}'**
  String playlistExportAndroid(String path);

  /// No description provided for @videoTracksN.
  ///
  /// In fr, this message translates to:
  /// **'{n} pistes'**
  String videoTracksN(int n);

  /// No description provided for @videoSubsN.
  ///
  /// In fr, this message translates to:
  /// **'{n} ST'**
  String videoSubsN(int n);

  /// No description provided for @listenOnly.
  ///
  /// In fr, this message translates to:
  /// **'Écouter seulement'**
  String get listenOnly;

  /// No description provided for @showVideo.
  ///
  /// In fr, this message translates to:
  /// **'Revoir la vidéo'**
  String get showVideo;

  /// No description provided for @tourWelcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans Miarina Media'**
  String get tourWelcomeTitle;

  /// No description provided for @tourWelcomeBody.
  ///
  /// In fr, this message translates to:
  /// **'Une visite rapide des endroits principaux. Vous pouvez la passer et la revoir plus tard dans Réglages › Général.'**
  String get tourWelcomeBody;

  /// No description provided for @tourSpaceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Deux espaces'**
  String get tourSpaceTitle;

  /// No description provided for @tourSpaceBody.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir pour télécharger des vidéos et de la musique, Écouter pour votre bibliothèque. Passez de l’un à l’autre ici.'**
  String get tourSpaceBody;

  /// No description provided for @tourLinkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Coller un lien'**
  String get tourLinkTitle;

  /// No description provided for @tourLinkBody.
  ///
  /// In fr, this message translates to:
  /// **'Collez l’adresse d’une vidéo ou d’une playlist : Miarina Media l’analyse et vous propose les formats et qualités.'**
  String get tourLinkBody;

  /// No description provided for @tourToolsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Outils PC'**
  String get tourToolsTitle;

  /// No description provided for @tourToolsBody.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l’écran et convertir vos fichiers (MP4, MP3, 3GP…). La capture d’écran se règle dans Réglages.'**
  String get tourToolsBody;

  /// No description provided for @tourLibraryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre bibliothèque'**
  String get tourLibraryTitle;

  /// No description provided for @tourLibraryBody.
  ///
  /// In fr, this message translates to:
  /// **'Musique, films et séries, Focus pour les podcasts et les cours : tout ce que vous téléchargez ou ajoutez arrive ici.'**
  String get tourLibraryBody;

  /// No description provided for @tourSearchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get tourSearchTitle;

  /// No description provided for @tourSearchBody.
  ///
  /// In fr, this message translates to:
  /// **'Titres, albums, films et podcasts, depuis n’importe quel écran. Raccourci : Ctrl K.'**
  String get tourSearchBody;

  /// No description provided for @tourPlaybarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get tourPlaybarTitle;

  /// No description provided for @tourPlaybarBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui joue : pause, titre suivant, volume. Cliquez sur la pochette pour ouvrir le lecteur complet.'**
  String get tourPlaybarBody;

  /// No description provided for @tourSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get tourSettingsTitle;

  /// No description provided for @tourSettingsBody.
  ///
  /// In fr, this message translates to:
  /// **'Thème et langue, dossier des téléchargements, raccourcis, capture d’écran et mises à jour.'**
  String get tourSettingsBody;

  /// No description provided for @tourSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer la visite'**
  String get tourSkip;

  /// No description provided for @tourBack.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get tourBack;

  /// No description provided for @tourNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get tourNext;

  /// No description provided for @tourDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get tourDone;

  /// No description provided for @tourReplay.
  ///
  /// In fr, this message translates to:
  /// **'Visite guidée'**
  String get tourReplay;

  /// No description provided for @tourReplayBody.
  ///
  /// In fr, this message translates to:
  /// **'Revoir la présentation des écrans principaux.'**
  String get tourReplayBody;

  /// No description provided for @tourStart.
  ///
  /// In fr, this message translates to:
  /// **'Lancer'**
  String get tourStart;

  /// No description provided for @fmtHelp3gp.
  ///
  /// In fr, this message translates to:
  /// **'Anciens téléphones, fichier léger'**
  String get fmtHelp3gp;

  /// No description provided for @optCodec.
  ///
  /// In fr, this message translates to:
  /// **'Codec'**
  String get optCodec;

  /// No description provided for @optCodecAv1.
  ///
  /// In fr, this message translates to:
  /// **'AV1'**
  String get optCodecAv1;

  /// No description provided for @optCodecH264.
  ///
  /// In fr, this message translates to:
  /// **'H.264'**
  String get optCodecH264;

  /// No description provided for @optCodecAv1Note.
  ///
  /// In fr, this message translates to:
  /// **'20 à 35 % plus léger à qualité égale. Lisible sur Windows 10 et 11, Android 10 et plus, les navigateurs récents et Miarina Media. Encodage plus long (environ la moitié de la durée de la vidéo).'**
  String get optCodecAv1Note;

  /// No description provided for @optCodecH264Note.
  ///
  /// In fr, this message translates to:
  /// **'Lisible sur tous les appareils, même anciens. Fichier plus gros qu’en AV1 pour la même qualité.'**
  String get optCodecH264Note;

  /// No description provided for @optGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get optGoal;

  /// No description provided for @optGoalQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get optGoalQuality;

  /// No description provided for @optGoalSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille maximale'**
  String get optGoalSize;

  /// No description provided for @optBalanced.
  ///
  /// In fr, this message translates to:
  /// **'Équilibrée'**
  String get optBalanced;

  /// No description provided for @optTargetMb.
  ///
  /// In fr, this message translates to:
  /// **'Taille max. par fichier'**
  String get optTargetMb;

  /// No description provided for @optMb.
  ///
  /// In fr, this message translates to:
  /// **'Mo'**
  String get optMb;

  /// No description provided for @deviceBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'La musique de ce téléphone n\'est pas encore affichée'**
  String get deviceBannerTitle;

  /// No description provided for @deviceBannerAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser l\'accès'**
  String get deviceBannerAllow;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @shareFailed.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier ne peut pas être partagé'**
  String get shareFailed;

  /// No description provided for @deleteFromPhone.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer du téléphone'**
  String get deleteFromPhone;

  /// No description provided for @deleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n\'a pas pu être supprimé'**
  String get deleteFailed;

  /// No description provided for @deletedFromPhone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Supprimé du téléphone} other{{count} fichiers supprimés du téléphone}}'**
  String deletedFromPhone(int count);

  /// No description provided for @on.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get on;

  /// No description provided for @skipBack10.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 10 secondes'**
  String get skipBack10;

  /// No description provided for @skipForward10.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 10 secondes'**
  String get skipForward10;

  /// No description provided for @showVinyl.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le vinyle'**
  String get showVinyl;

  /// No description provided for @viewAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'album'**
  String get viewAlbum;

  /// No description provided for @viewArtist.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'artiste'**
  String get viewArtist;

  /// No description provided for @trackInfo.
  ///
  /// In fr, this message translates to:
  /// **'Infos du morceau'**
  String get trackInfo;

  /// No description provided for @trackPlays.
  ///
  /// In fr, this message translates to:
  /// **'Écoutes'**
  String get trackPlays;

  /// No description provided for @trackFile.
  ///
  /// In fr, this message translates to:
  /// **'Fichier'**
  String get trackFile;

  /// No description provided for @playbackSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get playbackSpeed;

  /// No description provided for @quickRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get quickRecent;

  /// No description provided for @quickMostPlayed.
  ///
  /// In fr, this message translates to:
  /// **'Plus joués'**
  String get quickMostPlayed;

  /// No description provided for @dailyMix.
  ///
  /// In fr, this message translates to:
  /// **'Mix du jour'**
  String get dailyMix;

  /// No description provided for @recentlyPlayed.
  ///
  /// In fr, this message translates to:
  /// **'Récemment joués'**
  String get recentlyPlayed;

  /// No description provided for @recentlyAddedAlbums.
  ///
  /// In fr, this message translates to:
  /// **'Récemment ajoutés'**
  String get recentlyAddedAlbums;

  /// No description provided for @mostPlayedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les plus joués'**
  String get mostPlayedTitle;

  /// No description provided for @yourArtists.
  ///
  /// In fr, this message translates to:
  /// **'Vos artistes'**
  String get yourArtists;

  /// No description provided for @counterNever.
  ///
  /// In fr, this message translates to:
  /// **'Jamais écoutés'**
  String get counterNever;

  /// No description provided for @counterAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutés ce mois'**
  String get counterAdded;

  /// No description provided for @discoverTitle.
  ///
  /// In fr, this message translates to:
  /// **'À découvrir'**
  String get discoverTitle;

  /// No description provided for @discoverCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 titre jamais écouté} other{{count} titres jamais écoutés}}'**
  String discoverCount(int count);

  /// No description provided for @shufflePlay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture aléatoire'**
  String get shufflePlay;

  /// No description provided for @randomAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Album au hasard'**
  String get randomAlbum;

  /// No description provided for @artistOfWeek.
  ///
  /// In fr, this message translates to:
  /// **'Artiste de la semaine'**
  String get artistOfWeek;

  /// No description provided for @last7Days.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get last7Days;

  /// No description provided for @shuffleAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout mélanger'**
  String get shuffleAll;

  /// No description provided for @addAllToQueue.
  ///
  /// In fr, this message translates to:
  /// **'Tout ajouter à la file'**
  String get addAllToQueue;

  /// No description provided for @noListenYet.
  ///
  /// In fr, this message translates to:
  /// **'Écoutez de la musique pour voir ici votre temps d\'écoute.'**
  String get noListenYet;

  /// No description provided for @minutesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 minute} =1{1 minute} other{{count} minutes}}'**
  String minutesCount(int count);

  /// No description provided for @phoneLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get phoneLibrary;

  /// No description provided for @updAllowInstall.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez Miarina Media à installer des applications (l\'écran vient de s\'ouvrir), puis appuyez de nouveau sur « Installer maintenant ».'**
  String get updAllowInstall;

  /// No description provided for @updAndroidNote.
  ///
  /// In fr, this message translates to:
  /// **'Android ouvre l\'installation : appuyez sur « Mettre à jour ». Votre bibliothèque, vos playlists, vos positions de lecture et vos réglages sont conservés. Rien n\'est installé sans votre accord.'**
  String get updAndroidNote;

  /// No description provided for @vinylChip.
  ///
  /// In fr, this message translates to:
  /// **'Vinyle'**
  String get vinylChip;

  /// No description provided for @navOnline.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get navOnline;

  /// No description provided for @onlinePlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un titre ou un artiste en ligne'**
  String get onlinePlaceholder;

  /// No description provided for @onlineRecent.
  ///
  /// In fr, this message translates to:
  /// **'Recherches récentes'**
  String get onlineRecent;

  /// No description provided for @onlineClearRecent.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get onlineClearRecent;

  /// No description provided for @onlineRemoveRecent.
  ///
  /// In fr, this message translates to:
  /// **'Retirer « {query} »'**
  String onlineRemoveRecent(String query);

  /// No description provided for @onlineNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat en ligne pour « {query} »'**
  String onlineNoResult(String query);

  /// No description provided for @onlineMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus de résultats'**
  String get onlineMore;

  /// No description provided for @onlineToolsTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'extracteur n\'est pas installé'**
  String get onlineToolsTitle;

  /// No description provided for @onlineToolsInstall.
  ///
  /// In fr, this message translates to:
  /// **'Installer les outils'**
  String get onlineToolsInstall;

  /// No description provided for @onlineOfflineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion'**
  String get onlineOfflineTitle;

  /// No description provided for @onlineOpenTracks.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes titres'**
  String get onlineOpenTracks;

  /// No description provided for @onlineBlockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'YouTube limite les requêtes'**
  String get onlineBlockedTitle;

  /// No description provided for @onlineBlockedBody.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez dans quelques minutes.'**
  String get onlineBlockedBody;

  /// No description provided for @onlineErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'La recherche en ligne a échoué'**
  String get onlineErrorTitle;

  /// No description provided for @onlineErrorBody.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez. Si cela continue, mettez à jour l\'extracteur dans Obtenir.'**
  String get onlineErrorBody;

  /// No description provided for @onlineObtainTitle.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir « {title} »'**
  String onlineObtainTitle(String title);

  /// No description provided for @onlineFormatOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Original'**
  String get onlineFormatOriginal;

  /// No description provided for @onlineFormatMp3High.
  ///
  /// In fr, this message translates to:
  /// **'MP3 320 kbps'**
  String get onlineFormatMp3High;

  /// No description provided for @onlineFormatMp3Low.
  ///
  /// In fr, this message translates to:
  /// **'MP3 128 kbps'**
  String get onlineFormatMp3Low;

  /// No description provided for @onlineFormatAlways.
  ///
  /// In fr, this message translates to:
  /// **'Toujours utiliser ce format'**
  String get onlineFormatAlways;

  /// No description provided for @onlineFormatAsk.
  ///
  /// In fr, this message translates to:
  /// **'Demander'**
  String get onlineFormatAsk;

  /// No description provided for @onlineObtainStarted.
  ///
  /// In fr, this message translates to:
  /// **'Obtention lancée : {title}'**
  String onlineObtainStarted(String title);

  /// No description provided for @onlineObtainAuto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté hors connexion : {title}'**
  String onlineObtainAuto(String title);

  /// No description provided for @onlineObtainFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'obtention n\'a pas pu démarrer.'**
  String get onlineObtainFailed;

  /// No description provided for @onlineSeeDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get onlineSeeDownloads;

  /// No description provided for @onlineOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion'**
  String get onlineOffline;

  /// No description provided for @onlineObtaining.
  ///
  /// In fr, this message translates to:
  /// **'Obtention…'**
  String get onlineObtaining;

  /// No description provided for @onlineSettingsSection.
  ///
  /// In fr, this message translates to:
  /// **'Écoute en ligne'**
  String get onlineSettingsSection;

  /// No description provided for @onlineAutoObtain.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir les titres écoutés en entier'**
  String get onlineAutoObtain;

  /// No description provided for @onlineObtainFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format d\'Obtenir'**
  String get onlineObtainFormat;

  /// No description provided for @onlineSlowTitle.
  ///
  /// In fr, this message translates to:
  /// **'YouTube ne répond pas'**
  String get onlineSlowTitle;

  /// No description provided for @onlineWifiOnly.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement en Wi-Fi'**
  String get onlineWifiOnly;

  /// No description provided for @onlineNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés'**
  String get onlineNew;

  /// No description provided for @onlineNewQuery.
  ///
  /// In fr, this message translates to:
  /// **'nouveauté gasy {year} clip officiel'**
  String onlineNewQuery(int year);

  /// No description provided for @onlineFromSearch.
  ///
  /// In fr, this message translates to:
  /// **'D\'après « {query} »'**
  String onlineFromSearch(String query);

  /// No description provided for @onlineLyricsSetting.
  ///
  /// In fr, this message translates to:
  /// **'Chercher les paroles en ligne'**
  String get onlineLyricsSetting;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'mg'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'fr':
      return L10nFr();
    case 'mg':
      return L10nMg();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

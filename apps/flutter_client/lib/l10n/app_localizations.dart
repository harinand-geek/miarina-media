import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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

  /// No description provided for @comingSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Cet écran arrive bientôt'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonBody.
  ///
  /// In fr, this message translates to:
  /// **'Il sera construit d\'après la maquette validée, dans un prochain lot. Rien n\'est simulé en attendant.'**
  String get comingSoonBody;

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

  /// No description provided for @comingSoonShort.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoonShort;

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
  /// **'Smart Queue, calculée sur l\'appareil'**
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

  /// No description provided for @lyricsNoneBody.
  ///
  /// In fr, this message translates to:
  /// **'Placez un fichier .lrc du même nom à côté du fichier audio : il sera lu automatiquement.'**
  String get lyricsNoneBody;

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
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

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
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

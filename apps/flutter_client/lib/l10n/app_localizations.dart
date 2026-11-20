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
  /// **'B ajoute un signet à la position courante.'**
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
  /// **'Périphérique utilisé par Miarina'**
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
  /// **'Cliquez sur une touche pour la modifier ; un conflit est signalé avant d\'être enregistré. Échap annule.'**
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
  /// **'Vous téléchargez avec Miarina ? Les fichiers obtenus arrivent ici automatiquement.'**
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
  /// **'Le système ne laisse pas Miarina lire ce fichier. Les autres fichiers fonctionnent.'**
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
  /// **'Miarina lit ces dossiers sans les modifier ni les déplacer. Les nouveaux fichiers apparaissent à chaque lancement.'**
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
  /// **'Cette page ne contient pas de média pris en charge, ou il demande une connexion, est protégé (DRM) ou est un direct. Miarina ne contourne pas ces protections.'**
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
  /// **'étape 2/2 · ffmpeg'**
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

  /// No description provided for @getReorderNamed.
  ///
  /// In fr, this message translates to:
  /// **'Réordonner {title} (Alt + flèches haut et bas, ou glisser)'**
  String getReorderNamed(String title);
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

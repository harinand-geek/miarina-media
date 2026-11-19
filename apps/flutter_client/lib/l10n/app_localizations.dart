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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Miarina Media';

  @override
  String get spaceGet => 'Get';

  @override
  String get spaceListen => 'Listen';

  @override
  String get navHome => 'Home';

  @override
  String get navSectionMusic => 'Music';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navTracks => 'Tracks';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navSectionCinema => 'Cinema';

  @override
  String get navMovies => 'Movies & series';

  @override
  String get navPersonalVideos => 'Personal videos';

  @override
  String get navSectionFocus => 'Focus';

  @override
  String get navPodcasts => 'Podcasts & courses';

  @override
  String get navAudiobooks => 'Audiobooks';

  @override
  String get navSettings => 'Settings';

  @override
  String get tabMusic => 'Music';

  @override
  String get tabCinema => 'Cinema';

  @override
  String get tabFocus => 'Focus';

  @override
  String get tabGet => 'Get';

  @override
  String get searchPlaceholder => 'Search tracks, movies, podcasts…';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get repeatOff => 'Repeat: off';

  @override
  String get repeatAll => 'Repeat: all';

  @override
  String get repeatOne => 'Repeat: this track';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get queue => 'Queue';

  @override
  String get miniPlayer => 'Mini player (Ctrl M)';

  @override
  String get volume => 'Volume';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get seek => 'Playback position';

  @override
  String get nothingPlaying => 'Nothing playing';

  @override
  String get openNowPlaying => 'Open Now playing';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get comingSoonTitle => 'This screen is coming soon';

  @override
  String get comingSoonBody =>
      'It will be built from the approved design in an upcoming lot. Nothing is simulated meanwhile.';

  @override
  String tracksSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get tracksEmptyTitle => 'No tracks yet';

  @override
  String get tracksEmptyBody =>
      'Add a music folder or download a track from Get.';

  @override
  String get colTitle => 'Title';

  @override
  String get colArtist => 'Artist';

  @override
  String get colAlbum => 'Album';

  @override
  String get colFormat => 'Format';

  @override
  String get colDuration => 'Duration';

  @override
  String get fileMissing => 'File not found';

  @override
  String get libraryError => 'The library could not be read.';

  @override
  String get retry => 'Retry';

  @override
  String get playbackUnsupported =>
      'Playback is not available on this platform yet.';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get filterAll => 'All';

  @override
  String get filterTracks => 'Filter tracks';

  @override
  String get playAll => 'Play all';

  @override
  String get comingSoonShort => 'Coming soon';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get back => 'Back';

  @override
  String get tabQueue => 'Queue';

  @override
  String get tabSound => 'Sound';

  @override
  String get nowCurrent => 'Now';

  @override
  String get upNext => 'Up next';

  @override
  String get clearQueue => 'Clear';

  @override
  String get smartQueueTitle => 'Continue with similar tracks';

  @override
  String get smartQueueBody => 'Smart Queue, computed on the device';

  @override
  String lyricsHint(String file) {
    return '$file · click a line to go there';
  }

  @override
  String get lyricsNoneTitle => 'No lyrics for this track';

  @override
  String get lyricsNoneBody =>
      'Put an .lrc file with the same name next to the audio file: it is read automatically.';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get equalizerBody => 'Applied to all audio playback';

  @override
  String get equalizerUnsupported =>
      'This device offers no equalizer for playback.';

  @override
  String get eqFlat => 'Flat';

  @override
  String get eqBass => 'Bass';

  @override
  String get eqVoice => 'Voice';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassic => 'Classical';

  @override
  String get eqCustom => 'Custom';

  @override
  String get speed => 'Speed';

  @override
  String get normalization => 'Volume normalization';

  @override
  String get normalizationBody => 'ReplayGain when present';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get sleepEndOfTrack => 'End of track';

  @override
  String get sleepOff => 'Turn off the timer';

  @override
  String sleepRemaining(String time) {
    return 'Stops in $time';
  }

  @override
  String get upNextEmpty => 'Nothing after this track.';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get closePlayer => 'Collapse the player';

  @override
  String get showLyrics => 'Show lyrics';

  @override
  String get showCover => 'Show the cover';

  @override
  String get moreOptions => 'More options';

  @override
  String albumsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
      zero: 'No albums',
    );
    return '$_temp0';
  }

  @override
  String artistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
      zero: 'No artists',
    );
    return '$_temp0';
  }

  @override
  String get artistsGrouping => 'grouped by the “Album artist” tag';

  @override
  String get albumsEmptyTitle => 'No albums yet';

  @override
  String get albumsEmptyBody =>
      'Albums come from the files\' tags (album, artist). No track of the library has them yet.';

  @override
  String get artistsEmptyTitle => 'No artists yet';

  @override
  String get artistsEmptyBody =>
      'Artists come from the files\' tags. No track of the library has them yet.';

  @override
  String get albumOverline => 'Album';

  @override
  String get albumTracks => 'Album tracks';

  @override
  String get artistTracks => 'Tracks';

  @override
  String get groupMissing => 'This item is no longer in the library.';

  @override
  String get playVerb => 'Play';

  @override
  String get homeResume => 'Resume';

  @override
  String homeResumeKind(String kind) {
    return 'Resume · $kind';
  }

  @override
  String homeResumeAt(String time) {
    return 'Resume at $time';
  }

  @override
  String minutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min left',
      one: '1 min left',
      zero: 'less than a minute left',
    );
    return '$_temp0';
  }

  @override
  String get openAlbum => 'Open album';

  @override
  String get autoLists => 'Your automatic lists';

  @override
  String get listMostPlayed => 'Played often';

  @override
  String get listRecentlyAdded => 'Recently added';

  @override
  String get listRecentlyAddedBody => 'The latest tracks added to the library';

  @override
  String get listFavoritesBody => 'Your favorite tracks';

  @override
  String andOthers(String names, int count) {
    return '$names and $count more';
  }

  @override
  String get fullQueue => 'Full queue';

  @override
  String get seeAll => 'See all';

  @override
  String get recentAlbums => 'Recent albums';

  @override
  String get homeEmptyTitle => 'Your listening space is ready';

  @override
  String get homeEmptyBody =>
      'Nothing has been played yet and the library is empty. Add music from Get, or open a file.';

  @override
  String get goTracks => 'See tracks';

  @override
  String get goGet => 'Get music';

  @override
  String get nowPlayingHint =>
      'Start a track: it shows here, with its lyrics and what comes next.';

  @override
  String filmsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count films',
      one: '1 film',
      zero: 'no films',
    );
    return '$_temp0';
  }

  @override
  String seriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 series',
      zero: 'no series',
    );
    return '$_temp0';
  }

  @override
  String videosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
      zero: 'no videos',
    );
    return '$_temp0';
  }

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seasons',
      one: '1 season',
    );
    return '$_temp0';
  }

  @override
  String get segAll => 'All';

  @override
  String get segFilms => 'Films';

  @override
  String get segSeries => 'Series';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAdded => 'Recently added';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get kindFilm => 'Film';

  @override
  String get kindPersonal => 'Personal video';

  @override
  String resumeAtShort(String time) {
    return 'resume at $time';
  }

  @override
  String episodeShort(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String episodeLabel(int episode, String title) {
    return 'E$episode · $title';
  }

  @override
  String episodeNumber(int episode) {
    return 'Episode $episode';
  }

  @override
  String get cinemaEmptyTitle => 'No films or series yet';

  @override
  String get cinemaEmptyBody =>
      'Videos of 40 minutes or more show up here as films. Files named like S01E04, or tagged with a series, make up series.';

  @override
  String get cinemaNoMatch => 'Nothing in this category yet.';

  @override
  String get personalEmptyTitle => 'No personal videos';

  @override
  String get personalEmptyBody =>
      'Short videos from the library (clips, phone videos) show up here.';

  @override
  String get seriesWord => 'Series';

  @override
  String get seriesMissing => 'This series is no longer in the library.';

  @override
  String resumeEpisode(int season, int episode, String time) {
    return 'Resume S$season · E$episode at $time';
  }

  @override
  String playEpisode(int season, int episode) {
    return 'Play S$season · E$episode';
  }

  @override
  String get fromStart => 'From the start';

  @override
  String seasonNumber(int season) {
    return 'Season $season';
  }

  @override
  String seenOf(int seen, int total) {
    return '$seen watched of $total';
  }

  @override
  String get watched => 'Watched';

  @override
  String resumeAtLeft(String time, String left) {
    return 'Resume at $time · $left';
  }

  @override
  String subtitlesLangs(String langs) {
    return 'Subtitles $langs';
  }

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesOff => 'Off';

  @override
  String get subtitlesLoad => 'Load an SRT / VTT / ASS file…';

  @override
  String get subtitlesExternal => 'external';

  @override
  String get audioTrack => 'Audio track';

  @override
  String get noTracks => 'No other track in this file';

  @override
  String get replay10 => 'Back 10 s';

  @override
  String get forward10 => 'Forward 10 s';

  @override
  String get fullscreen => 'Full screen (F)';

  @override
  String get fullscreenExit => 'Exit full screen (Esc)';

  @override
  String get chapters => 'Chapters';

  @override
  String get chaptersSoon => 'The file\'s chapters will show here.';

  @override
  String get nextEpisode => 'Next episode';

  @override
  String get autoNext => 'Plays automatically at the end';

  @override
  String get videoLoading => 'Opening the video…';

  @override
  String get videoUnavailable => 'No video playing';
}

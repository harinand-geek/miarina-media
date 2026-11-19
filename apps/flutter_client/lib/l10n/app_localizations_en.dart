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
}

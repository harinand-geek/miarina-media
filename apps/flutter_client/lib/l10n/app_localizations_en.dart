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

  @override
  String podcastsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts',
      one: '1 podcast',
      zero: 'no podcasts',
    );
    return '$_temp0';
  }

  @override
  String coursesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
      zero: 'no courses',
    );
    return '$_temp0';
  }

  @override
  String audiobooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audiobooks',
      one: '1 audiobook',
      zero: 'no audiobooks',
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
  String get segCourses => 'Courses';

  @override
  String get segBooks => 'Audiobooks';

  @override
  String get focusInProgress => 'In progress';

  @override
  String get focusLibrary => 'Library';

  @override
  String get kindPodcast => 'Podcast';

  @override
  String get kindCourse => 'Course';

  @override
  String get kindAudiobook => 'Audiobook';

  @override
  String episodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String partsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts',
      one: '1 part',
    );
    return '$_temp0';
  }

  @override
  String leftAtRate(String left, String rate) {
    return '$left left at $rate';
  }

  @override
  String get focusOrderHint =>
      'Order read from file numbers (01, 02…) or tags.';

  @override
  String get focusEmptyTitle => 'No podcasts, courses or audiobooks';

  @override
  String get focusEmptyBody =>
      'An audio file joins Focus through its genre (Podcast, Course, Audiobook), a folder named Podcasts, Courses or Audiobooks, or the .m4b format.';

  @override
  String get focusNoMatch => 'Nothing in this category yet.';

  @override
  String programPosition(String kind, int number, int total) {
    return '$kind $number of $total';
  }

  @override
  String estimatedEnd(String time, String rate) {
    return 'Ends at $time at $rate';
  }

  @override
  String get forward30 => 'Forward 30 s';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get bookmarkAdd => 'Add a bookmark (B)';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get bookmarkNoNote => 'Bookmark without a note';

  @override
  String get bookmarksEmpty => 'No bookmarks yet.';

  @override
  String get bookmarksHint => 'B adds a bookmark at the current position.';

  @override
  String get bookmarkRemove => 'Remove the bookmark';

  @override
  String get chaptersNone => 'This file has no chapters.';

  @override
  String get transcript => 'Text';

  @override
  String get futureBadge => 'FUTURE';

  @override
  String get transcriptTitle => 'Transcript — future feature';

  @override
  String get transcriptBody =>
      'A .txt or .vtt file with the same name next to the file is shown here. Local generation and search in transcripts will come later.';

  @override
  String get sleepEndOfChapter => 'Timer: end of chapter';

  @override
  String get sleepEndOfEpisode => 'Timer: end of file';

  @override
  String get skipSilence => 'Skip silences';

  @override
  String get voiceBoost => 'Voice boost';

  @override
  String get p1Later => 'for the last two';

  @override
  String get navHistory => 'History';

  @override
  String get historySubtitle => 'Plays and positions, kept on this device';

  @override
  String get historyClear => 'Clear history…';

  @override
  String get historyClearTitle => 'Clear history?';

  @override
  String get historyClearBody =>
      'The plays listed here are forgotten. No file, favorite or resume point is deleted.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String positionOf(String position, String total) {
    return '$position of $total';
  }

  @override
  String get finished => 'Finished';

  @override
  String get replay => 'Play again';

  @override
  String get historyEmptyTitle => 'Nothing played yet';

  @override
  String get historyEmptyBody =>
      'What you listen to and watch will show here, with the position where you stopped.';

  @override
  String searchTitle(String query) {
    return '“$query”';
  }

  @override
  String searchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'no results',
    );
    return '$_temp0 in the local library';
  }

  @override
  String get bestResult => 'Top result';

  @override
  String seeAllCount(int count) {
    return 'See all ($count)';
  }

  @override
  String get searchTranscripts => 'Search in transcripts';

  @override
  String searchEmptyTitle(String query) {
    return 'No results for “$query”';
  }

  @override
  String get searchEmptyBody =>
      'Search ignores accents and matches the start of words. Try another word.';

  @override
  String get searchHint => 'Type a title, an artist, a film or a podcast.';

  @override
  String get kindTrack => 'Track';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindArtist => 'Artist';

  @override
  String get searchClear => 'Clear the search';

  @override
  String get setGeneral => 'General';

  @override
  String get setAppearance => 'Appearance';

  @override
  String get setPlayback => 'Playback';

  @override
  String get setLibrary => 'Library';

  @override
  String get setShortcuts => 'Shortcuts';

  @override
  String get setData => 'Data and backup';

  @override
  String get setAbout => 'About';

  @override
  String get language => 'Language';

  @override
  String get languageBody => 'Interface language';

  @override
  String get languageSystem => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get playColor => 'Play color';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorRose => 'Pink';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorBlue => 'Blue';

  @override
  String get density => 'Density';

  @override
  String get densityBody => 'Compact: 40 px rows in lists';

  @override
  String get densityComfortable => 'Comfortable';

  @override
  String get densityCompact => 'Compact';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeBody => '90 to 130%';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionBody => 'Follows the system setting by default';

  @override
  String get reduceTransparency => 'Reduce transparency';

  @override
  String get reduceTransparencyBody => 'Opaque surfaces everywhere';

  @override
  String get coverBackdrop => 'Cover behind Now playing';

  @override
  String get coverBackdropBody => 'Blurred cover behind the player';

  @override
  String get engineSection => 'Engine and output';

  @override
  String get engine => 'Playback engine';

  @override
  String get engineBodyWindows =>
      'Built-in libmpv, hardware decoding with fallback';

  @override
  String get engineBodyAndroid => 'Media3, Android\'s player';

  @override
  String get engineValue => 'Built-in (recommended)';

  @override
  String get audioOutput => 'Audio output';

  @override
  String get audioOutputBody => 'Device Miarina plays to';

  @override
  String get systemDefault => 'System default';

  @override
  String get exclusive => 'WASAPI exclusive mode';

  @override
  String get exclusiveBody => 'For external DACs, mutes other sounds';

  @override
  String get chainSection => 'Continuity';

  @override
  String get resumeSetting => 'Resume where I left off';

  @override
  String get resumeSettingBody => 'Audio and video, when starting';

  @override
  String get gapless => 'Gapless playback';

  @override
  String get gaplessBody => 'Live and mixed albums';

  @override
  String get crossfade => 'Crossfade between tracks';

  @override
  String get crossfadeBody => '0 to 12 s';

  @override
  String get off => 'Off';

  @override
  String get normalizationSetting => 'Volume normalization';

  @override
  String get normalizationSettingBody => 'ReplayGain when present';

  @override
  String get videoSection => 'Video';

  @override
  String get defaultSubtitles => 'Default subtitles';

  @override
  String get defaultSubtitlesBody => 'Preferred language, otherwise none';

  @override
  String get none => 'None';

  @override
  String get sidecar => 'Load subtitles next to the file';

  @override
  String get sidecarBody => 'Same-name .srt, .vtt, .ass';

  @override
  String get p1Badge => 'P1';
}

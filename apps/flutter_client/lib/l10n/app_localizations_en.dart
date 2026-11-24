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
  String get bookmarksHint =>
      'B adds a bookmark at the current position. Exportable as text with the course.';

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
  String get audioOutputBody => 'Device Miarina Media plays to';

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

  @override
  String get keyPlayPause => 'Play / pause';

  @override
  String get keyPrevious => 'Previous track';

  @override
  String get keyNext => 'Next track';

  @override
  String get keySeekBack => 'Back 10 s';

  @override
  String get keySeekForward => 'Forward 10 s';

  @override
  String get keyVolumeUp => 'Volume up';

  @override
  String get keyVolumeDown => 'Volume down';

  @override
  String get keyMute => 'Mute';

  @override
  String get keySearch => 'Search';

  @override
  String get keyBack => 'Back';

  @override
  String get keyForward => 'Forward';

  @override
  String get keyToggleSidebar => 'Collapse the sidebar';

  @override
  String get keyNowPlaying => 'Now playing';

  @override
  String get keyFullscreen => 'Full screen';

  @override
  String get keySubtitles => 'Subtitles';

  @override
  String get keyAudioTrack => 'Audio track';

  @override
  String get keyFrameStep => 'Next frame (paused)';

  @override
  String get keyBookmark => 'Add a bookmark';

  @override
  String get keyLyrics => 'Lyrics';

  @override
  String get keyMiniPlayer => 'Mini player';

  @override
  String get keySpeedDown => 'Speed −';

  @override
  String get keySpeedUp => 'Speed +';

  @override
  String get keysPlayback => 'Playback';

  @override
  String get keysNavigation => 'Navigation';

  @override
  String get keysVideo => 'Video';

  @override
  String get keysFocus => 'Focus and windows';

  @override
  String get keysTitle => 'Keyboard shortcuts';

  @override
  String get keysSearch => 'Search shortcuts';

  @override
  String get keysReset => 'Restore defaults';

  @override
  String get keysHint =>
      'Click a key to change it; a conflict is shown before it is saved. Esc cancels. Keyboard media keys and headset buttons are supported (Windows media controls).';

  @override
  String get keyPress => 'Press a key…';

  @override
  String get keyNone => 'None';

  @override
  String get keyShift => 'Shift';

  @override
  String get keySpace => 'Space';

  @override
  String keyConflict(String key, String action) {
    return '$key is already used by “$action”.';
  }

  @override
  String get keyReplace => 'Replace';

  @override
  String get keyRemove => 'Remove the key';

  @override
  String get libraryTracks => 'Audio files';

  @override
  String get libraryVideos => 'Videos';

  @override
  String get dataFolder => 'Data folder';

  @override
  String get dataFolderBody => 'Library database, settings and covers';

  @override
  String get openFolder => 'Open the folder';

  @override
  String get playHistory => 'Play history';

  @override
  String get playHistoryBody => 'Plays and positions shown in History';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutDevBuild => 'Development build';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutLicenses => 'Component licenses';

  @override
  String get aboutLicensesBody => 'Bundled fonts, icons and libraries';

  @override
  String get show => 'Show';

  @override
  String get aboutLocal =>
      'Everything stays on this device: no account, no data sent.';

  @override
  String get aboutCompanyBody =>
      'Miarina Media is part of the Miarina ecosystem.';

  @override
  String get aboutDeveloper => 'Developer';

  @override
  String get playlistNew => 'New';

  @override
  String get playlistImport => 'Import M3U';

  @override
  String get playlistExport => 'Export';

  @override
  String playlistModified(String when) {
    return 'Playlist · changed $when';
  }

  @override
  String get agoNow => 'just now';

  @override
  String agoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String agoHours(int count) {
    return '$count h ago';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String titlesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'no tracks',
    );
    return '$_temp0';
  }

  @override
  String missingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missing tracks',
      one: '1 missing track',
    );
    return '$_temp0';
  }

  @override
  String get addTracks => 'Add tracks';

  @override
  String get playlistHint =>
      'Drag to reorder · Alt+↑/↓ on the keyboard · Del removes from the playlist (the file stays)';

  @override
  String get newPlaylistTitle => 'New playlist';

  @override
  String get playlistName => 'Name';

  @override
  String addQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add the $count tracks of the queue',
      one: 'Add the track of the queue',
    );
    return '$_temp0';
  }

  @override
  String get smartPlaylist => 'Smart playlist (rules)';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get save => 'Save';

  @override
  String get deletePlaylist => 'Delete the playlist';

  @override
  String deletePlaylistTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deletePlaylistBody =>
      'The playlist is deleted. The files stay in the library.';

  @override
  String get delete => 'Delete';

  @override
  String importDone(String name, int added, int skipped) {
    return '“$name”: $added tracks added, $skipped missing or online.';
  }

  @override
  String exportDone(String path) {
    return 'Playlist saved: $path';
  }

  @override
  String get playlistsEmptyTitle => 'No playlists';

  @override
  String get playlistsEmptyBody => 'Create a playlist or import an M3U file.';

  @override
  String get playlistEmpty => 'This playlist is empty. Add tracks.';

  @override
  String get addedShort => 'Added';

  @override
  String get removeFromPlaylist => 'Remove from the playlist';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get playlistFileType => 'M3U playlist';

  @override
  String playlistActionFailed(String error) {
    return 'The operation failed: $error';
  }

  @override
  String get close => 'Close';

  @override
  String get emptyOpenFiles => 'Open files…';

  @override
  String get emptyFormats =>
      'Formats read: MP3, M4A, FLAC, OGG, Opus, WAV, AAC, and for video MP4, MKV, WebM, MOV, AVI.';

  @override
  String get emptyNote =>
      'Downloading with Miarina Media? What you get arrives here automatically.';

  @override
  String get mediaFiles => 'Audio and video files';

  @override
  String get errFormatTitle => 'Format not supported';

  @override
  String get errFormatBody =>
      'The engine cannot decode this file. The file is not changed.';

  @override
  String get errDamagedTitle => 'Damaged file';

  @override
  String get errDamagedBody =>
      'Playback stopped: part of the file seems unreadable. The file is not changed.';

  @override
  String get errAccessTitle => 'Access denied';

  @override
  String get errAccessBody =>
      'The system does not let Miarina Media read this file. Other files still work.';

  @override
  String get errMissingTitle => 'File not found';

  @override
  String get errMissingBody =>
      'The file was moved, renamed, or its drive is unplugged. It keeps its place in the library.';

  @override
  String get errPlaybackTitle => 'Cannot play';

  @override
  String get errPlaybackBody =>
      'This file could not be played. Nothing was changed.';

  @override
  String get errLibraryRepairTitle => 'Library needs repair';

  @override
  String get errLibraryRepairBody =>
      'The library index could not open. Your files are not touched.';

  @override
  String get errLibraryTitle => 'The library does not open';

  @override
  String get errLibraryBody =>
      'Nothing was changed. Try again; if it keeps happening, copy the details for support.';

  @override
  String get copyDetails => 'Copy the details';

  @override
  String get detailsCopied => 'Details copied';

  @override
  String get skipNext => 'Skip to next';

  @override
  String get welcomeHeadline => 'Your music, films and courses, in one place.';

  @override
  String get welcomeLocal =>
      'Everything stays on this computer. No account, no data sent.';

  @override
  String get welcomeFoot =>
      'Local playback, no telemetry. Can be changed later in Settings.';

  @override
  String get stepAppearance => 'Language and appearance';

  @override
  String get stepFolders => 'Folders';

  @override
  String get stepScan => 'Scan';

  @override
  String get skip => 'Skip';

  @override
  String get continueLabel => 'Continue';

  @override
  String get analyse => 'Scan';

  @override
  String get themeFollow => 'Follow Windows';

  @override
  String get foldersTitle => 'Where are your files?';

  @override
  String get foldersBody =>
      'Miarina Media reads these folders without changing or moving anything. New files show up at each launch.';

  @override
  String folderFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio or video files',
      one: '1 audio or video file',
      zero: 'no audio or video files',
    );
    return '$_temp0';
  }

  @override
  String get kindVideo => 'Video';

  @override
  String get addFolder => 'Add a folder…';

  @override
  String foldersSummary(int folders, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders folders',
      one: '1 folder',
      zero: 'no folders',
    );
    return '$_temp0 · about $files files';
  }

  @override
  String get removeFolder => 'Remove this folder';

  @override
  String get scanTitle => 'Scanning your library';

  @override
  String get scanBody =>
      'You can start listening: the scan goes on in the background.';

  @override
  String scanProgress(int done, int total) {
    return '$done files of about $total';
  }

  @override
  String get statTracks => 'tracks';

  @override
  String get statAlbums => 'albums';

  @override
  String get statVideos => 'videos';

  @override
  String get statUnreadable => 'unreadable';

  @override
  String get readyNow => 'Ready now';

  @override
  String get scanEco =>
      'Scanning in the background, one file at a time (eco mode).';

  @override
  String get scanNoFfmpeg =>
      'FFmpeg is not installed next to the app: titles, artists and albums are read; durations and thumbnails will be once it is.';

  @override
  String get startListening => 'Start listening';

  @override
  String get libraryFolders => 'Followed folders';

  @override
  String get libraryFoldersBody =>
      'Scanned at each launch; nothing is changed or moved.';

  @override
  String get scanNow => 'Scan now';

  @override
  String get scanDone => 'Scan complete';

  @override
  String scanRunning(int done, int total) {
    return '$done of $total scanned';
  }

  @override
  String get noFolders => 'No followed folders yet.';

  @override
  String get navSectionLibrary => 'Library';

  @override
  String get navMissing => 'Missing';

  @override
  String get navDuplicates => 'Duplicates';

  @override
  String get healthGroup => 'Library health';

  @override
  String get missingTitle => 'Missing files';

  @override
  String missingSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count items were not found at the last check. Nothing was deleted.',
      one: '1 item was not found at the last check. Nothing was deleted.',
    );
    return '$_temp0';
  }

  @override
  String missingVolumeTitle(String volume) {
    return 'Drive $volume disconnected';
  }

  @override
  String missingVolumeBody(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count items from $folder. They come back when the drive is connected.',
      one: '1 item from $folder. It comes back when the drive is connected.',
    );
    return '$_temp0';
  }

  @override
  String get missingMovedTitle => 'Folder probably renamed';

  @override
  String missingMovedBody(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files found in $folder, with the same name and size.',
      one: '1 file found in $folder, with the same name and size.',
    );
    return '$_temp0';
  }

  @override
  String missingLostTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files not found',
      one: '1 file not found',
    );
    return '$_temp0';
  }

  @override
  String missingLostBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No match found. They may have been deleted.',
      one: 'No match found. It may have been deleted.',
    );
    return '$_temp0';
  }

  @override
  String get missingRelocate => 'Relocate…';

  @override
  String get missingHide => 'Hide';

  @override
  String get missingUpdatePaths => 'Update paths';

  @override
  String get missingIgnore => 'Ignore';

  @override
  String get missingLocate => 'Locate…';

  @override
  String get missingSearchFolder => 'Search a folder…';

  @override
  String get missingRemove => 'Remove from library';

  @override
  String get missingStatusVolume => 'drive absent';

  @override
  String get missingStatusFound => '→ found';

  @override
  String get missingStatusLost => 'not found';

  @override
  String missingMore(int count) {
    return 'and $count more';
  }

  @override
  String missingHiddenGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden groups',
      one: '1 hidden group',
    );
    return '$_temp0';
  }

  @override
  String get missingShowAll => 'Show all';

  @override
  String get missingEmptyTitle => 'All your files are here';

  @override
  String get missingEmptyBody =>
      'Files that were moved or sit on an unplugged drive show up here. Nothing is ever deleted automatically.';

  @override
  String missingPathsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paths updated',
      one: '1 path updated',
      zero: 'No path updated',
    );
    return '$_temp0';
  }

  @override
  String missingFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files found',
      one: '1 file found',
      zero: 'No file found',
    );
    return '$_temp0';
  }

  @override
  String missingLeftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count still missing',
      one: '1 still missing',
    );
    return '$_temp0';
  }

  @override
  String missingRemoveTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove these $count files from the library?',
      one: 'Remove this file from the library?',
    );
    return '$_temp0';
  }

  @override
  String get missingRemoveBody =>
      'They leave the library, the playlists and resume points. No file is deleted from disk: if they turn up again, open them to add them back.';

  @override
  String get remove => 'Remove';

  @override
  String missingSkipped(String title) {
    return '“$title” can’t be found, playing the next one';
  }

  @override
  String missingSkippedLast(String title) {
    return '“$title” can’t be found';
  }

  @override
  String get locate => 'Locate';

  @override
  String get fileLocated => 'File located';

  @override
  String get locateFailed =>
      'This file can’t be used in place of the original.';

  @override
  String get duplicatesTitle => 'Duplicates';

  @override
  String duplicatesSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count groups · $size to recover · same title, artist and duration',
      one: '1 group · $size to recover · same title, artist and duration',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesKeepBest => 'Keep the best quality everywhere';

  @override
  String duplicateVersions(int count) {
    return '$count versions';
  }

  @override
  String get duplicateKeep => 'Keep';

  @override
  String get duplicateHide => 'Hide';

  @override
  String get duplicateTrash => 'Move to Recycle Bin…';

  @override
  String get duplicatesNote =>
      'By default, duplicates are only hidden from the library: the file stays on disk. Deleting sends it to the Windows Recycle Bin.';

  @override
  String duplicatesHideAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hide the $count duplicates',
      one: 'Hide the duplicate',
    );
    return '$_temp0';
  }

  @override
  String duplicatesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count duplicates hidden, their playlists now use the kept version',
      one: '1 duplicate hidden, its playlists now use the kept version',
    );
    return '$_temp0';
  }

  @override
  String get duplicateTrashTitle => 'Move this file to the Recycle Bin?';

  @override
  String get duplicateTrashBody =>
      'Its playlists and favorite move to the kept version. You can restore it from the Windows Recycle Bin.';

  @override
  String get duplicateTrashed => 'File moved to the Recycle Bin';

  @override
  String get duplicatesEmptyTitle => 'No duplicates';

  @override
  String get duplicatesEmptyBody =>
      'Titles present in several versions (same title, artist and duration) show up here.';

  @override
  String get duplicatesNeedFfmpeg =>
      'Durations are read by FFmpeg, which this installation lacks: the duplicate search waits for it.';

  @override
  String sizeKb(String n) {
    return '$n KB';
  }

  @override
  String sizeMb(String n) {
    return '$n MB';
  }

  @override
  String sizeGb(String n) {
    return '$n GB';
  }

  @override
  String duplicatesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles in several versions',
      one: '1 title in several versions',
      zero: 'No duplicates found',
    );
    return '$_temp0';
  }

  @override
  String get miniPin => 'Keep on top';

  @override
  String get miniUnpin => 'Stop keeping on top';

  @override
  String get miniExpand => 'Restore the full window';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptyBody =>
      'Tap the heart of a track, in Tracks or Now playing, to find it here.';

  @override
  String get getNavHome => 'Home';

  @override
  String get getNavDownloads => 'Downloads';

  @override
  String get getNavBrowser => 'Browser';

  @override
  String get getNavTorrents => 'Torrents';

  @override
  String get getNavHistory => 'History';

  @override
  String get getHomeTitle => 'From link to library';

  @override
  String get getHomeSub => 'Paste a link, pick a format, play it offline.';

  @override
  String get getLinkLabel => 'Media link';

  @override
  String get getPaste => 'Paste';

  @override
  String get getAnalyze => 'Analyze';

  @override
  String get getHintPaste => 'to paste and analyze';

  @override
  String get getHintDrop => 'Drop a link onto the window';

  @override
  String get getHintExt => 'Or send it from the Chrome/Edge extension';

  @override
  String get getQAudio => 'Audio only';

  @override
  String get getQAudioDesc => 'MP3 up to 320 kbps, FLAC';

  @override
  String get getQPlaylist => 'Playlist';

  @override
  String get getQPlaylistDesc => 'Pick the items';

  @override
  String get getQBatch => 'Batch links';

  @override
  String get getQBatchDesc => 'One link per line';

  @override
  String get getQTorrent => 'Torrent / magnet';

  @override
  String get getQTorrentDesc => 'Files and sharing under control';

  @override
  String get getContinue => 'Continue';

  @override
  String get getSeeLibrary => 'Open library';

  @override
  String get getContinueEmpty => 'What you start playing will continue here.';

  @override
  String get getRecent => 'Recently downloaded';

  @override
  String get getHomeEmpty => 'Your downloads will appear here.';

  @override
  String getPlayTitle(String title) {
    return 'Play $title';
  }

  @override
  String getMinutesLeft(int n) {
    return '$n min left';
  }

  @override
  String get getLinkEmpty => 'Paste a link to analyze.';

  @override
  String get getLinkTooLong => 'This link is too long.';

  @override
  String get getLinkMalformed =>
      'This doesn’t look like a complete link. Check for a missing “https://”.';

  @override
  String get getLinkScheme => 'Only http and https links are supported.';

  @override
  String get getLinkCredentials =>
      'Links containing a user name or password are not accepted.';

  @override
  String get getLinkMissingHttps => 'This link is missing “https://”.';

  @override
  String get getAddHttps => 'Add https://';

  @override
  String get getClipboardEmpty => 'The clipboard is empty. Copy a link first.';

  @override
  String get getPlanned => 'PLANNED';

  @override
  String get getPlannedHint => 'Planned for a later lot: not available yet.';

  @override
  String get getBack => 'Back';

  @override
  String get getFmtVideo => 'Video';

  @override
  String get getFmtSubs => 'Subtitles';

  @override
  String get getNoVideoFormats => 'This source has no video formats.';

  @override
  String get getNoAudioFormats => 'This source has no audio-only formats.';

  @override
  String get getNoSubsFormats => 'This source has no subtitles.';

  @override
  String getUpTo(String q) {
    return 'Up to $q';
  }

  @override
  String get getSubsPlanned => 'Subtitles: download planned (DL-08)';

  @override
  String get getNoteAudio =>
      'Conversion runs after download; its progress is shown separately.';

  @override
  String get getNoteVideo => 'Sizes given by the source, or estimated.';

  @override
  String get getNeedsFfmpeg =>
      'Install FFmpeg to get more qualities (merged video + audio) and MP3 conversion.';

  @override
  String get getDirectResume => 'Direct file · can resume if interrupted';

  @override
  String get getDirectNoResume => 'Direct file · cannot resume if interrupted';

  @override
  String getOriginalFile(String ext) {
    return '$ext · original file';
  }

  @override
  String get getTagRecommended => 'Recommended';

  @override
  String get getTagBest => 'Best quality';

  @override
  String get getChange => 'Change';

  @override
  String get getAddToQueue => 'Add to queue';

  @override
  String get getStarting => 'Starting…';

  @override
  String getDownloadSize(String size) {
    return 'Download · $size';
  }

  @override
  String get getDownload => 'Download';

  @override
  String getAddedToQueue(String q) {
    return 'Added to queue · $q';
  }

  @override
  String get getView => 'View';

  @override
  String get getPrepTitle => 'Getting your file ready';

  @override
  String getPrepElapsed(int n) {
    return '$n s';
  }

  @override
  String getPrepStage1(String host) {
    return 'Reading the link on $host…';
  }

  @override
  String get getPrepStage2 =>
      'Looking for the available video and audio qualities…';

  @override
  String get getPrepStage3 =>
      'Some sites answer more slowly. Please hold on, it is still working.';

  @override
  String get getPrepStage4 =>
      'Still working. Long or very popular videos can take longer.';

  @override
  String get getPrepThisSite => 'this site';

  @override
  String get getPrepTip => 'TIP';

  @override
  String get getPrepTip1 =>
      'Choose “Audio only” to keep just the music, in a smaller file.';

  @override
  String get getPrepTip2 => 'Your downloads go straight to the library.';

  @override
  String get getPrepTip3 =>
      'The qualities offered are the ones the source publishes, nothing is made up.';

  @override
  String get getPrepTip4 =>
      'Several tracks? Use “Add to queue”: they download one after another.';

  @override
  String get getNoMediaTitle => 'No downloadable media found';

  @override
  String get getNoMediaBody =>
      'This page has no supported media, or it requires a login, is DRM-protected or is a live stream. Miarina Media does not bypass these protections.';

  @override
  String getNoMediaReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get getWhyNetwork =>
      'the website could not be reached; check the link and your connection';

  @override
  String getWhyHttp(String status) {
    return 'the website refused the request (HTTP $status)';
  }

  @override
  String get getWhyPlatform =>
      'web page extraction is not available on this device';

  @override
  String get getTryAgain => 'Try again';

  @override
  String get getToolsNeeded => 'This page needs the media tools';

  @override
  String get getToolsBody =>
      'Miarina Media reads web pages with yt-dlp and merges or converts files with FFmpeg. They are downloaded once from their official releases and checked against a fixed SHA-256 fingerprint before use.';

  @override
  String getBytesOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String get getNotNow => 'Not now';

  @override
  String get getDownloadingShort => 'Downloading…';

  @override
  String getDownloadTools(String size) {
    return 'Download tools · $size';
  }

  @override
  String getTabActive(int n) {
    return 'Active · $n';
  }

  @override
  String getTabDone(int n) {
    return 'Done · $n';
  }

  @override
  String getTabFailed(int n) {
    return 'Failed · $n';
  }

  @override
  String getDlSubRunning(int n, String speed) {
    return '$n active · $speed · auto-resume when the source allows it';
  }

  @override
  String get getDlSubPaused => 'All paused';

  @override
  String getDlSubIdle(int n) {
    return 'Nothing running · up to $n at once';
  }

  @override
  String get getPauseAll => 'Pause all';

  @override
  String get getResumeAll => 'Resume all';

  @override
  String get getDlNothing => 'Nothing here yet.';

  @override
  String getActRetry(String title) {
    return 'Retry $title';
  }

  @override
  String getActResume(String title) {
    return 'Resume $title';
  }

  @override
  String getActStart(String title) {
    return 'Start $title now';
  }

  @override
  String getActPause(String title) {
    return 'Pause $title';
  }

  @override
  String get getCannotPause => 'Cannot pause while preparing the file';

  @override
  String getRemoveNamed(String title) {
    return 'Remove $title';
  }

  @override
  String getCancelNamed(String title) {
    return 'Cancel $title';
  }

  @override
  String get getCancelTitle => 'Cancel download?';

  @override
  String getCancelBody(String title) {
    return '$title will be removed from the queue and its partial files deleted.';
  }

  @override
  String get getCancelConfirm => 'Cancel download';

  @override
  String get getKeepDownloading => 'Keep downloading';

  @override
  String getActRestart(String title) {
    return 'Start $title over from the beginning';
  }

  @override
  String get getOpenFolder => 'Open folder';

  @override
  String get getShowInFolder => 'Show in folder';

  @override
  String get getStDone => 'Done';

  @override
  String get getFileGone => 'This file is no longer in the library.';

  @override
  String get getStFailed => 'Failed';

  @override
  String getStResumeAt(int n) {
    return 'resumes at $n %';
  }

  @override
  String get getStOffline => 'Paused · offline';

  @override
  String getStRetry(int n) {
    return 'Connection lost · retrying in $n s';
  }

  @override
  String get getStDownloading => 'Downloading';

  @override
  String get getStConverting => 'Processing';

  @override
  String getStConvertingTo(String ext) {
    return 'Converting to $ext';
  }

  @override
  String getStFinalizing(String ext) {
    return 'Finalizing $ext';
  }

  @override
  String get getStStep => 'step 2/2 · ffmpeg';

  @override
  String get getStPaused => 'Paused';

  @override
  String get getStPausedRestart => 'Paused · will restart';

  @override
  String get getStDiskFull => 'Failed · disk full';

  @override
  String get getStAccessDenied => 'Failed · folder not writable';

  @override
  String get getStDiskFullHint => 'free some space, then retry';

  @override
  String get getStAccessDeniedHint => 'choose another folder';

  @override
  String get getStAnalyzing => 'Reading formats…';

  @override
  String get getStQueued => 'Queued';

  @override
  String get getWhyDiskFull => 'Disk full';

  @override
  String get getWhyNoSpace => 'Not enough disk space for this file';

  @override
  String get getWhyDenied => 'Destination folder is not writable';

  @override
  String getSumRunning(int n) {
    return '$n downloading';
  }

  @override
  String get getSumOffline => 'Paused · offline';

  @override
  String get getSumPaused => 'All paused';

  @override
  String get getSumIdle => 'No downloads';

  @override
  String getSumQueue(int n) {
    return '$n queued';
  }

  @override
  String get getDirRefused =>
      'This folder does not accept files. Choose another one.';

  @override
  String get getHistKind => 'History type';

  @override
  String get getHistDownloads => 'Downloads';

  @override
  String get getHistPlays => 'Plays';

  @override
  String get getClearHistory => 'Clear history';

  @override
  String get getClearDlTitle => 'Clear download history?';

  @override
  String get getClearDlBody =>
      'This removes the list of past downloads. Files already saved in your library are not deleted.';

  @override
  String get getHistEmptyDl =>
      'Finished, failed and cancelled downloads appear here.';

  @override
  String get getHistNoteDl => 'Clearing history deletes no files.';

  @override
  String getFailedBecause(String reason) {
    return 'Failed · $reason';
  }

  @override
  String get getStCanceled => 'Cancelled';

  @override
  String getActionsFor(String title) {
    return 'Actions for $title';
  }

  @override
  String get getCopySourceLink => 'Copy source link';

  @override
  String get getLinkCopied => 'Source link copied';

  @override
  String get getToday => 'Today';

  @override
  String get getYesterday => 'Yesterday';

  @override
  String get setDownloads => 'Downloads';

  @override
  String get getSaveTo => 'Save to';

  @override
  String get getDefaultVideoQuality => 'Default video quality';

  @override
  String get getDefaultVideoQualityDesc =>
      'Falls back to a lower quality when unavailable.';

  @override
  String get getDefaultAudio => 'Default audio format';

  @override
  String get getSimultaneous => 'Simultaneous downloads';

  @override
  String get getSimultaneousDesc => 'Others wait in the queue.';

  @override
  String get getSpeedLimit => 'Speed limit';

  @override
  String get getDownloadSubs => 'Download subtitles';

  @override
  String get getDownloadSubsDesc => 'Interface language first, when available.';

  @override
  String get getResourceMode => 'Resource mode';

  @override
  String get getModeEco => 'Eco';

  @override
  String get getModeBalanced => 'Balanced';

  @override
  String get getModePerformance => 'Performance';

  @override
  String getModeDesc(int n, int c) {
    return '$n simultaneous download(s), $c conversion(s) at a time.';
  }

  @override
  String get getMediaTools => 'Media tools';

  @override
  String get getAutoUpdated => 'updates automatically';

  @override
  String get getIncludedVerified => 'Included · verified';

  @override
  String get getInstalledVerified => 'Installed · verified';

  @override
  String getToDownload(String size) {
    return '$size download';
  }

  @override
  String get getToolsInstalled => 'Media tools installed and verified';

  @override
  String get getUpdCheck => 'Check for updates';

  @override
  String get getUpdChecking => 'Checking…';

  @override
  String getYtdlpLatest(String v) {
    return 'yt-dlp is up to date ($v)';
  }

  @override
  String getYtdlpUpdated(String v) {
    return 'yt-dlp updated to $v · signature verified';
  }

  @override
  String get getUpdFailed => 'yt-dlp could not be updated. Try again later.';

  @override
  String get getInstallFailed =>
      'The tools could not be downloaded. Check the connection and try again.';

  @override
  String get getLess => 'Fewer';

  @override
  String get getMore => 'More';

  @override
  String get brAddressPh => 'Search or type a web address';

  @override
  String brCloseTab(String title) {
    return 'Close tab $title';
  }

  @override
  String get brNewTab => 'New tab (Ctrl T)';

  @override
  String get brStartTab => 'New tab';

  @override
  String get brStop => 'Stop loading';

  @override
  String get brBack => 'Back';

  @override
  String get brForward => 'Forward';

  @override
  String get brReload => 'Reload';

  @override
  String get brHome => 'Start page';

  @override
  String get brMediaOne => '1 media';

  @override
  String brMediaMany(int n) {
    return '$n media';
  }

  @override
  String get brStartTitle => 'Search or open a web page';

  @override
  String get brStartBody =>
      'When a page has a video or audio file, a download bar appears below the page.';

  @override
  String get brLegalHint =>
      'Only download media you own or have permission to save.';

  @override
  String brDownloadFound(int n) {
    return 'Download media found on this page ($n)';
  }

  @override
  String brMediaFound(int n) {
    return '$n media found';
  }

  @override
  String get brMediaFoundOne => '1 media found';

  @override
  String get brChooseMedia => 'Choose media and format';

  @override
  String get brSheetTitle => 'Download from this page';

  @override
  String get brKindVideo => 'Video';

  @override
  String get brKindAudio => 'Audio';

  @override
  String get brKindHls => 'Stream (HLS)';

  @override
  String get brKindDash => 'Stream (DASH)';

  @override
  String get brKindPage => 'Page player';

  @override
  String get brItemProtected =>
      'This item may be protected or need a login. Try another item on the page.';

  @override
  String get brClosePanel => 'Close the panel';

  @override
  String get brTooManyTabs => '12 tabs at most: close one to open another.';

  @override
  String get brUnsupported =>
      'Only web pages (http, https) open in the browser.';

  @override
  String get brUnavailable =>
      'The browser could not start: WebView2 is missing or did not answer.';

  @override
  String get brHistory => 'History';

  @override
  String get brFavorites => 'Favorites';

  @override
  String get brHistoryViews => 'History or favorites';

  @override
  String get brHistorySearch => 'Search visited pages';

  @override
  String brNoMatch(String q) {
    return 'Nothing matches “$q”.';
  }

  @override
  String get brHistoryEmpty => 'Pages you visit appear here.';

  @override
  String get brFavoritesEmpty =>
      'Star a page in the address bar to add it to favorites.';

  @override
  String get brHistoryNote =>
      'Kept on this device only. Clearing it deletes no file or download.';

  @override
  String brDeleteVisit(String title) {
    return 'Remove $title from history';
  }

  @override
  String brRemoveFavorite(String title) {
    return 'Remove $title from favorites';
  }

  @override
  String get brClearTitle => 'Clear browser history?';

  @override
  String get brClearBody =>
      'Visited pages are forgotten. Downloads, the library and favorites stay.';

  @override
  String get brCleared => 'Browser history cleared';

  @override
  String get brClearHistory => 'Clear history';

  @override
  String get brFavAdd => 'Add to favorites';

  @override
  String get brFavRemove => 'Remove from favorites';

  @override
  String get brFavAdded => 'Added to favorites';

  @override
  String get brFavRemoved => 'Removed from favorites';

  @override
  String get brSites => 'Sites';

  @override
  String get setExtension => 'Browser extension';

  @override
  String get extLead =>
      'Send a page or video from Chrome or Edge to Miarina Media in one click: the analysis opens here and you choose the format.';

  @override
  String get extAccept => 'Accept links sent by the extension';

  @override
  String get extAcceptBody => 'Nothing is captured automatically.';

  @override
  String get extSteps => 'Getting started';

  @override
  String get extStep1 => 'Install the extension';

  @override
  String get extStep1Body =>
      'Chrome · Edge: Extensions page, turn on developer mode, then “Load unpacked” and choose this folder.';

  @override
  String get extOpenFolder => 'Open folder';

  @override
  String get extStep2 => 'Connect this PC';

  @override
  String get extStep2Body =>
      'Chrome and Edge will be able to send links to Miarina Media on this computer.';

  @override
  String get extConnected => 'Chrome and Edge are connected.';

  @override
  String get extOther =>
      'Another Miarina Media installation is connected; Connect replaces it.';

  @override
  String get extConnect => 'Connect';

  @override
  String get extDisconnect => 'Disconnect';

  @override
  String get extStep3 => 'Test the connection';

  @override
  String get extTest => 'Test';

  @override
  String get extTestNever => 'Not tested yet.';

  @override
  String extTestOk(String time) {
    return 'Last test: succeeded at $time';
  }

  @override
  String extTestFailed(String time) {
    return 'Last test: failed at $time';
  }

  @override
  String get extTestDone => 'The connection works.';

  @override
  String get extTestBad =>
      'The browser bridge does not answer. Disconnect, then connect again.';

  @override
  String get extNoBridge =>
      'This version of Miarina Media does not include the browser bridge.';

  @override
  String get extFailed => 'The connection could not be changed.';

  @override
  String get extPrivacy =>
      'The extension reads nothing from pages: only the link you send leaves, and only to Miarina Media on this computer.';

  @override
  String get brTabs => 'Tabs';

  @override
  String brTabsOpen(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n open tabs',
      one: '1 open tab',
    );
    return '$_temp0';
  }

  @override
  String get brBackToApp => 'Back to Miarina Media';

  @override
  String brDownloadCount(int n) {
    return 'Download · $n';
  }

  @override
  String get brDownloadHoldHint =>
      'Long press: download the main media in the default format';

  @override
  String get brUnavailablePhone =>
      'The browser could not start on this device.';

  @override
  String get brStartBodyPhone =>
      'When a page has a video or an audio file, a Download button appears over the page.';

  @override
  String getReorderNamed(String title) {
    return 'Reorder $title (Alt + Up and Down arrows, or drag)';
  }

  @override
  String get torCapped => 'Sharing capped, in KB/s';

  @override
  String get torChecking => 'Checking files';

  @override
  String torDoneMeta(String size) {
    return 'Done · $size';
  }

  @override
  String torDoneSharing(String size) {
    return 'Done · $size · sharing';
  }

  @override
  String get torDown => 'Down';

  @override
  String get torDownLimit => 'Download limit';

  @override
  String get torEmpty => 'Your torrents will appear here.';

  @override
  String get torEnable => 'Enable session';

  @override
  String get torError => 'Error · the transfer stopped';

  @override
  String get torFailed => 'The operation could not be completed.';

  @override
  String get torInactive => 'Session stopped';

  @override
  String get torInspect => 'Inspect link';

  @override
  String get torLeft => 'Left';

  @override
  String get torLimitsSaved => 'Limits applied';

  @override
  String get torMagnet => 'Magnet link';

  @override
  String get torOpenFile => 'Open .torrent';

  @override
  String torPausedMeta(String done, String total) {
    return 'Paused · $done / $total';
  }

  @override
  String get torPeers => 'Peers';

  @override
  String get torPreviewNote =>
      'Files are saved in a new folder under your download folder / Torrents. Small boundary pieces of unselected files may also be written.';

  @override
  String get torRatio => 'Ratio';

  @override
  String get torRatioDesc => 'Stop sharing above · 0 = no limit';

  @override
  String get torRemove => 'Remove';

  @override
  String get torRemoveBody =>
      'The downloaded files will be kept. The transfer and sharing will stop.';

  @override
  String torRemoveNamed(String name) {
    return 'Remove $name';
  }

  @override
  String get torRemoveTitle => 'Remove torrent?';

  @override
  String get torResume => 'Resume';

  @override
  String get torSeedDesc => 'Stop after time · 0 = no limit';

  @override
  String get torSeedTime => 'Seeding time';

  @override
  String get torSequential => 'Download pieces in order';

  @override
  String get torSessionOff => 'Session stopped';

  @override
  String get torSessionOn => 'Session on';

  @override
  String get torSessionSharing => 'Session on · sharing';

  @override
  String get torSharing => 'Sharing';

  @override
  String get torStart => 'Start download';

  @override
  String get torStopAll => 'Stop all and sharing';

  @override
  String get torStopSharing => 'Stop sharing';

  @override
  String get torSub =>
      'Add a magnet link or a .torrent file. Torrents share downloaded pieces with peers, even after completion: sharing is shown and you can stop it at any time.';

  @override
  String get torTargetRatio => 'Target ratio';

  @override
  String get torUnlimited => '0 = unlimited, in KB/s';

  @override
  String get torUp => 'Up';

  @override
  String get torUpLimit => 'Upload limit';

  @override
  String get torWait => 'Please wait…';

  @override
  String get torLinkInvalid => 'This magnet link is not valid.';

  @override
  String get torDuplicate => 'This torrent is already in the list.';

  @override
  String get torSelection => 'Select at least one file.';

  @override
  String get torSessionChanged =>
      'The session changed: inspect the link again.';

  @override
  String get torPlannedHint => 'Planned for a later lot: not available yet.';

  @override
  String get torPlanned => 'PLANNED';

  @override
  String filterMissingCount(int count) {
    return 'Missing · $count';
  }

  @override
  String get filterAddedThisMonth => 'Added this month';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get playNext => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addTo => 'Add to…';

  @override
  String get addToPlaylist => 'Add to a playlist…';

  @override
  String get addToPlaylistTitle => 'Add to a playlist';

  @override
  String get newPlaylistEllipsis => 'New playlist…';

  @override
  String get showInExplorer => 'Show in File Explorer';

  @override
  String get removeEllipsis => 'Remove…';

  @override
  String playNextDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The $count tracks will play next',
      one: 'The track will play next',
    );
    return '$_temp0';
  }

  @override
  String queueAddDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to the queue',
      one: '1 track added to the queue',
    );
    return '$_temp0';
  }

  @override
  String playlistAddDone(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to “$name”',
      one: '1 track added to “$name”',
    );
    return '$_temp0';
  }

  @override
  String sortByColumn(String column) {
    return 'Sort by $column';
  }

  @override
  String get sortedAscending => 'ascending';

  @override
  String get sortedDescending => 'descending';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get playSelection => 'Play';

  @override
  String get keyEnter => 'Enter';

  @override
  String get keyCtrlEnter => 'Ctrl Enter';

  @override
  String get keyDelete => 'Del';

  @override
  String get filterNeverPlayed => 'Never played';

  @override
  String get filterHiRes => 'Hi-res';

  @override
  String get groupSortAdded => 'Recently added';

  @override
  String get groupSortName => 'A → Z';

  @override
  String get groupSortYear => 'Year';

  @override
  String get groupSortPlays => 'Most played';

  @override
  String get groupSortTracks => 'Number of tracks';

  @override
  String get filterLossless => 'FLAC / hi-res';

  @override
  String get filterDownloaded => 'Downloaded with Miarina Media';

  @override
  String get filterCompilations => 'Compilations';

  @override
  String filterNoCover(int count) {
    return 'No cover · $count';
  }

  @override
  String get filterEmptyTitle => 'Nothing with this filter';

  @override
  String get filterEmptyBody => 'Choose “All” to see the whole list again.';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewList => 'List';

  @override
  String playsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String playedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'played $count times',
      one: 'played once',
    );
    return '$_temp0';
  }

  @override
  String get saveAsPlaylist => 'Save as playlist';

  @override
  String get editTags => 'Edit tags';

  @override
  String get tagFromName => 'Fill from file name';

  @override
  String get tagRename => 'Rename file “Artist - Title”';

  @override
  String get fTitle => 'Title';

  @override
  String get fArtist => 'Artist';

  @override
  String get fAlbumArtist => 'Album artist';

  @override
  String get fAlbum => 'Album';

  @override
  String get fYear => 'Year';

  @override
  String get fGenre => 'Genre';

  @override
  String get fTrack => 'Track #';

  @override
  String get fDisc => 'Disc #';

  @override
  String get fComment => 'Comment';

  @override
  String get fLyrics => 'Lyrics (optional)';

  @override
  String get fLyricsPh => 'Paste text or the content of an .lrc file';

  @override
  String get tagNote => 'Editing tags does not change audio or video quality.';

  @override
  String renameNote(String name) {
    return 'File will be renamed: $name';
  }

  @override
  String get tagWrite =>
      'Also write to the file (otherwise: Miarina Media library only)';

  @override
  String get tagWriteUnsupported =>
      'This format keeps its tags in the Miarina Media library only.';

  @override
  String get tagsSavedFile => 'Tags written to the file.';

  @override
  String get tagsSavedLibrary => 'Tags saved in the library. File unchanged.';

  @override
  String get invalidNumber => 'Whole number expected';

  @override
  String get coverChoose => 'Choose an image…';

  @override
  String get coverSource => 'Source thumbnail';

  @override
  String get coverNoSource => 'The source gave no thumbnail';

  @override
  String get coverRemove => 'Remove cover';

  @override
  String get coverNone => 'No cover';

  @override
  String get coverWorking => 'Preparing the cover…';

  @override
  String get coverNote =>
      'JPEG, PNG, WebP, BMP or GIF. Resized to 1000 px and kept in the library, applied at once; the file is not changed.';

  @override
  String get coverUpdated => 'Cover updated';

  @override
  String get coverRemoved => 'Cover removed';

  @override
  String get errTagsUnsupported =>
      'Tags cannot be written into this file type; they were not saved.';

  @override
  String get errTagsWrite =>
      'The tags could not be written into the file; they were not saved.';

  @override
  String get errInvalidName => 'This name cannot be used.';

  @override
  String get errNotInLibrary => 'This item is no longer in the library.';

  @override
  String get errCoverRefused =>
      'This picture cannot be used as a cover (format or size).';

  @override
  String get errLibrary => 'The library could not make this change.';

  @override
  String get coverImageType => 'Pictures';

  @override
  String get keyCtrlI => 'Ctrl I';

  @override
  String get markSeasonSeen => 'Mark season as watched';

  @override
  String get markSeasonUnseen => 'Mark season as not watched';

  @override
  String get markSeriesSeen => 'Mark series as watched';

  @override
  String get markSeriesUnseen => 'Mark series as not watched';

  @override
  String get markSeen => 'Mark as watched';

  @override
  String get markUnseen => 'Mark as not watched';

  @override
  String get fDirector => 'Director / author';

  @override
  String get fSeries => 'Series / collection';

  @override
  String get fLicense => 'License / comment';

  @override
  String coverFrame(String time) {
    return 'Capture frame at $time';
  }

  @override
  String get bookmarkAddNote => 'Add a note…';

  @override
  String get bookmarkEditNote => 'Edit the note…';

  @override
  String bookmarkNoteTitle(String time) {
    return 'Bookmark note at $time';
  }

  @override
  String get bookmarksExport => 'Export…';

  @override
  String bookmarksExported(String path) {
    return 'Bookmarks saved: $path';
  }

  @override
  String get bookmarksExportFailed =>
      'The bookmarks could not be saved in this folder.';

  @override
  String get dbProblemTitle => 'Your library was not opened';

  @override
  String dbTooNew(String found, String supported) {
    return 'This library was updated by a newer version of Miarina Media: this version cannot open it safely (schema $found, this version supports up to schema $supported).\n\nYour data was not changed. Install the latest version of Miarina Media.';
  }

  @override
  String dbUpgradeFailed(String backup, String reason) {
    return 'Updating your library failed. The update was rolled back: your data was not changed.\n\nBackup copy: $backup\nDetails: $reason\n\nReinstall the previous version of Miarina Media to keep using this library.';
  }

  @override
  String get dbNoBackup => 'none';

  @override
  String dbBackupFailed(String reason) {
    return 'Miarina Media could not copy your library before updating it: the update was not applied and your data was not changed.\n\nCheck the free disk space, then start Miarina Media again.\nDetails: $reason';
  }

  @override
  String dbOpenFailed(String file, String reason) {
    return 'The Miarina Media library could not be opened.\n\nFile: $file\nDetails: $reason';
  }

  @override
  String get updConverting =>
      'A conversion is running: you can install once it is finished';

  @override
  String get updNetwork =>
      'Lost the connection to the update server. Try again: a download resumes where it stopped.';

  @override
  String updAvailable(String v) {
    return 'Miarina Media $v is available';
  }

  @override
  String get updBeta => 'Beta';

  @override
  String updActive(String n) {
    return '$n active download(s): interrupted during the install, found paused on restart. Library and settings are kept.';
  }

  @override
  String get updStopsPlayback => 'Current playback will stop';

  @override
  String get updStopsSharing => 'Torrent sharing will stop';

  @override
  String updReady(String v) {
    return '$v is ready';
  }

  @override
  String updDownloading(String v) {
    return 'Downloading $v…';
  }

  @override
  String updInstalled(String v, String channel, String size) {
    return 'Installed version $v · $channel channel · $size';
  }

  @override
  String get updBadgeReady => 'Ready';

  @override
  String get updBadgeDownloading => 'Downloading';

  @override
  String get updBadge => 'Available';

  @override
  String get updProgress => 'Update progress';

  @override
  String updProgressText(String done, String size) {
    return '$done / $size · verified at the end';
  }

  @override
  String updPartial(String done, String size) {
    return '$done / $size already downloaded: the rest resumes where it stopped.';
  }

  @override
  String get updVerified => 'Signature and SHA-256 verified';

  @override
  String get updResume => 'Resume download';

  @override
  String updDownload(String size) {
    return 'Download · $size';
  }

  @override
  String get updInstalling => 'Opening the installer…';

  @override
  String get updInstall => 'Install now';

  @override
  String get updLater => 'Later';

  @override
  String get updKeptReady => 'Update kept ready.';

  @override
  String get updWindowsNote =>
      'Windows closes Miarina Media and opens the installer. Your library, playlists, playback positions and settings are kept. Nothing is installed without your consent.';

  @override
  String get updChecking => 'Checking…';

  @override
  String updLatest(String v) {
    return 'You are on the latest version ($v).';
  }

  @override
  String get updAutoCheck =>
      'Checked automatically at startup and every six hours.';

  @override
  String get updCheck => 'Check for updates';

  @override
  String get updChannel => 'Channel';

  @override
  String get updChannelDesc => 'Beta gets new features before full validation.';

  @override
  String get updAuto => 'Download automatically';

  @override
  String get updAutoDesc =>
      'Only on Wi-Fi or unmetered networks. Installation always waits for you.';

  @override
  String get setUpdates => 'Updates';

  @override
  String get updView => 'View';

  @override
  String updVersion(String v) {
    return 'Version $v';
  }

  @override
  String get updDevBuild => 'Development build: updates are turned off.';

  @override
  String get deviceAccessTitle => 'Access the music and videos on this phone';

  @override
  String get deviceAccessBody =>
      'Miarina Media reads your files on the device. Nothing is sent, no account is needed.';

  @override
  String get deviceAccessMusic => 'Music and audio';

  @override
  String get deviceAccessMusicBody =>
      'To show your albums, podcasts and courses.';

  @override
  String get deviceAccessVideo => 'Videos';

  @override
  String get deviceAccessVideoBody =>
      'For your films, series and personal videos.';

  @override
  String get deviceAccessNotif => 'Notifications';

  @override
  String get deviceAccessNotifBody =>
      'For playback controls on the lock screen.';

  @override
  String get deviceAccessAllow => 'Allow access';

  @override
  String get deviceDeniedTitle => 'File access denied';

  @override
  String get deviceDeniedBody =>
      'Without this permission, Miarina Media cannot see the music and videos on the phone. Your playlists are kept.';

  @override
  String get deviceDeniedSettings => 'Open Android settings';

  @override
  String get dlNotifWaiting => 'Waiting for a free slot';

  @override
  String get dlNotifAnalyzing => 'Reading the formats…';

  @override
  String get dlNotifProcessing => 'Preparing the file…';

  @override
  String dlNotifOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String dlNotifSpeed(String speed) {
    return '$speed MB/s';
  }

  @override
  String get dlNotifLeftSoon => 'less than a minute left';

  @override
  String dlNotifLeftMin(int minutes) {
    return '$minutes min left';
  }

  @override
  String dlNotifLeftHours(int hours, int minutes) {
    return '$hours h $minutes min left';
  }

  @override
  String get dlNotifTapToPlay => 'tap to play';

  @override
  String get dlNotifPause => 'Pause';

  @override
  String get dlNotifCancel => 'Cancel';

  @override
  String get dlNotifPauseAll => 'Pause all';

  @override
  String get dlNotifComplete => 'Download complete';

  @override
  String get dlNotifSeveral => '%d downloading';

  @override
  String get dlNotifChannelProgress => 'Downloads in progress';

  @override
  String get dlNotifChannelDone => 'Finished downloads';

  @override
  String get getPasteLinkTitle => 'Paste a link';

  @override
  String get getAnalyzeLink => 'Analyze the link';

  @override
  String get getShareHint => 'Or share a link to Miarina Media from any app.';

  @override
  String getDlCard(int running, int queued) {
    return '$running running · $queued waiting';
  }

  @override
  String plCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String plTruncated(int shown, int total) {
    return 'First $shown of $total';
  }

  @override
  String plTruncatedUnknown(int shown) {
    return 'First $shown items';
  }

  @override
  String get plQuality => 'Quality for every item';

  @override
  String get plQualityNote =>
      'If an item does not have this quality, the best one below it is used.';

  @override
  String get plItems => 'Items';

  @override
  String plSelected(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get plSelectAll => 'Select all';

  @override
  String get plSelectNone => 'Select none';

  @override
  String get plUnavailable => 'Unavailable';

  @override
  String plItemFallback(int index) {
    return 'Item $index';
  }

  @override
  String plOwnFolder(String name) {
    return 'In a folder “$name”';
  }

  @override
  String plDownload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count items',
      one: 'Download 1 item',
      zero: 'Download',
    );
    return '$_temp0';
  }

  @override
  String get plPreparing => 'Preparing…';

  @override
  String plQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads added to the queue',
      one: '1 download added to the queue',
    );
    return '$_temp0';
  }

  @override
  String get plQueueFull =>
      'The queue is full. Finish or remove some downloads, then try again.';

  @override
  String get plFailed => 'The playlist could not be added. Try again.';

  @override
  String batchLead(int max) {
    return 'Paste up to $max links, one per line. Each is analysed, then added to the queue.';
  }

  @override
  String get batchHint => 'https://…\nhttps://…';

  @override
  String get batchClear => 'Clear';

  @override
  String batchTruncated(int max) {
    return 'Only the first $max links are kept.';
  }

  @override
  String get batchQuality => 'Quality for video pages';

  @override
  String get batchQualityNote =>
      'A direct file is kept as it is. If a page does not have this quality, the best one below it is used.';

  @override
  String get batchLinks => 'Links';

  @override
  String batchValid(int valid, int total) {
    return '$valid valid of $total';
  }

  @override
  String get batchEmpty => 'Pasted links will appear here.';

  @override
  String get batchAnalyzing => 'Analysing…';

  @override
  String get batchAdded => 'Added to the queue';

  @override
  String get batchFailed => 'Not added';

  @override
  String get batchIsPlaylist => 'This is a playlist: use the Playlist tile';

  @override
  String get batchNeedsTools =>
      'Media tools needed: analyse a single link first';

  @override
  String get batchNoAudio => 'No audio-only file';

  @override
  String get batchNoVideo => 'No video in this file';

  @override
  String batchStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count links',
      one: 'Download 1 link',
      zero: 'Download',
    );
    return '$_temp0';
  }

  @override
  String get batchRunning => 'Analysing links…';

  @override
  String batchDone(int added, int failed) {
    return '$added added to the queue · $failed not added';
  }

  @override
  String get getSpeedLimitDesc => 'Shared between the running downloads.';

  @override
  String get getSpeedUnlimited => 'Unlimited';

  @override
  String get getNoteSubs =>
      'One subtitle file per language, saved next to your videos. To have them inside the video, turn on Settings › Downloads › Download subtitles.';

  @override
  String get crossfadeExclusive => 'Not available with exclusive audio output.';

  @override
  String crossfadeSeconds(int s) {
    return '$s s';
  }

  @override
  String get videoSettings => 'Video';

  @override
  String get subtitleDelay => 'Delay';

  @override
  String get subtitleSize => 'Size';

  @override
  String get earlier => 'Earlier';

  @override
  String get later => 'Later';

  @override
  String get smaller => 'Smaller';

  @override
  String get larger => 'Larger';

  @override
  String get slower => 'Slower';

  @override
  String get faster => 'Faster';

  @override
  String get aspectRatio => 'Aspect ratio';

  @override
  String get aspectAuto => 'Auto';

  @override
  String get cropSetting => 'Crop';

  @override
  String get cropNone => 'None';

  @override
  String get cropFill => 'Fill the screen';

  @override
  String get audioSync => 'Audio sync';

  @override
  String get hwDecoding => 'Hardware decoding';

  @override
  String get hwDecodingBody => 'Automatic software fallback on failure.';

  @override
  String hwAuto(String decoder) {
    return 'Auto ($decoder)';
  }

  @override
  String get hwSoftware => 'Software';

  @override
  String get abLoop => 'A–B loop';

  @override
  String get abOff => 'Off';

  @override
  String abFrom(String time) {
    return 'A at $time';
  }

  @override
  String get abHintA => 'Tap to set A at the current position.';

  @override
  String get abHintB => 'Tap to set B: the A–B part repeats.';

  @override
  String get abHintOff => 'Tap to stop the loop.';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malagasy (`mg`).
class L10nMg extends L10n {
  L10nMg([String locale = 'mg']) : super(locale);

  @override
  String get appTitle => 'Miarina Media';

  @override
  String get spaceGet => 'Haka';

  @override
  String get spaceListen => 'Hihaino';

  @override
  String get navHome => 'Fandraisana';

  @override
  String get navSectionMusic => 'Mozika';

  @override
  String get navAlbums => 'Rakikira';

  @override
  String get navArtists => 'Mpanakanto';

  @override
  String get navTracks => 'Hira';

  @override
  String get navPlaylists => 'Lisitra';

  @override
  String get navFavorites => 'Tiako indrindra';

  @override
  String get navSectionCinema => 'Sinema';

  @override
  String get navMovies => 'Sarimihetsika sy andian-tantara';

  @override
  String get navPersonalVideos => 'Horonan-tsariko';

  @override
  String get navSectionFocus => 'Focus';

  @override
  String get navPodcasts => 'Podcast sy lesona';

  @override
  String get navAudiobooks => 'Boky azo henoina';

  @override
  String get navSettings => 'Fikirana';

  @override
  String get tabMusic => 'Mozika';

  @override
  String get tabCinema => 'Sinema';

  @override
  String get tabFocus => 'Focus';

  @override
  String get tabGet => 'Haka';

  @override
  String get searchPlaceholder => 'Hitady hira, sarimihetsika, podcast…';

  @override
  String get play => 'Alefa';

  @override
  String get pause => 'Ijanona';

  @override
  String get previous => 'Teo aloha';

  @override
  String get next => 'Manaraka';

  @override
  String get shuffle => 'Mifangaro';

  @override
  String get repeatOff => 'Averina : tsia';

  @override
  String get repeatAll => 'Averina : daholo';

  @override
  String get repeatOne => 'Averina : ity hira ity';

  @override
  String get lyrics => 'Tononkira';

  @override
  String get queue => 'Filaharana';

  @override
  String get miniPlayer => 'Mpamaky kely (Ctrl M)';

  @override
  String get volume => 'Feo';

  @override
  String get mute => 'Vonoy ny feo';

  @override
  String get unmute => 'Avereno ny feo';

  @override
  String get favoriteAdd => 'Ampidiro amin\'ny tiako indrindra';

  @override
  String get favoriteRemove => 'Esory amin\'ny tiako indrindra';

  @override
  String get seek => 'Toerana amin\'ny fandefasana';

  @override
  String get nothingPlaying => 'Tsy misy mandeha';

  @override
  String get openNowPlaying => 'Sokafy ny mandeha';

  @override
  String get windowMinimize => 'Ahenoy';

  @override
  String get windowMaximize => 'Halehibeazo';

  @override
  String get windowRestore => 'Averina';

  @override
  String get windowClose => 'Hidio';

  @override
  String tracksSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hira $count',
      one: 'Hira 1',
      zero: 'Tsy misy hira',
    );
    return '$_temp0';
  }

  @override
  String get tracksEmptyTitle => 'Mbola tsy misy hira';

  @override
  String get tracksEmptyBody =>
      'Ampio lahatahiry mozika na misintona hira avy amin\'ny Haka.';

  @override
  String get colTitle => 'Lohateny';

  @override
  String get colArtist => 'Mpanakanto';

  @override
  String get colAlbum => 'Rakikira';

  @override
  String get colFormat => 'Endrika';

  @override
  String get colDuration => 'Faharetany';

  @override
  String get fileMissing => 'Tsy hita ny rakitra';

  @override
  String get libraryError => 'Tsy voavaky ny tahiry.';

  @override
  String get retry => 'Andramo indray';

  @override
  String get playbackUnsupported =>
      'Mbola tsy azo atao amin\'ity sehatra ity ny fandefasana.';

  @override
  String get unknownArtist => 'Mpanakanto tsy fantatra';

  @override
  String get filterAll => 'Daholo';

  @override
  String get filterTracks => 'Sivano ny hira';

  @override
  String get playAll => 'Alefaso daholo';

  @override
  String get nowPlaying => 'Mandeha';

  @override
  String get back => 'Hiverina';

  @override
  String get tabQueue => 'Filaharana';

  @override
  String get tabSound => 'Feo';

  @override
  String get nowCurrent => 'Mandeha ankehitriny';

  @override
  String get upNext => 'Manaraka';

  @override
  String get clearQueue => 'Foano';

  @override
  String get smartQueueTitle => 'Tohizo amin\'ny hira mitovitovy';

  @override
  String get smartQueueBody =>
      'Mpanakanto na rakikira mitovy, kajiana ao amin\'ny fitaovana';

  @override
  String lyricsHint(String file) {
    return '$file · tsindrio andalana iray hankanesana any';
  }

  @override
  String get lyricsNoneTitle => 'Tsy misy tononkira ity hira ity';

  @override
  String get lyricsNoneBody =>
      'Apetraho eo akaikin\'ny rakitra feo ny rakitra .lrc mitovy anarana : ho vakiana ho azy izy.';

  @override
  String get equalizer => 'Mpandanja feo';

  @override
  String get equalizerBody => 'Ampiharina amin\'ny fandefasana feo rehetra';

  @override
  String get equalizerUnsupported =>
      'Tsy manana mpandanja feo ho an\'ny fandefasana ity fitaovana ity.';

  @override
  String get eqFlat => 'Tsotra';

  @override
  String get eqBass => 'Feo ambany';

  @override
  String get eqVoice => 'Feo olona';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassic => 'Klasika';

  @override
  String get eqCustom => 'Namboarina';

  @override
  String get speed => 'Hafainganana';

  @override
  String get normalization => 'Fampitoviana ny haben\'ny feo';

  @override
  String get normalizationBody => 'ReplayGain raha misy';

  @override
  String get sleepTimer => 'Fameram-potoana';

  @override
  String sleepMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get sleepEndOfTrack => 'Fiafaran\'ny hira';

  @override
  String get sleepOff => 'Ajanony ny fameram-potoana';

  @override
  String sleepRemaining(String time) {
    return 'Hijanona afaka $time';
  }

  @override
  String get upNextEmpty => 'Tsy misy manaraka ity hira ity.';

  @override
  String get removeFromQueue => 'Esory amin\'ny filaharana';

  @override
  String get closePlayer => 'Ahenoy ny mpamaky';

  @override
  String get showLyrics => 'Asehoy ny tononkira';

  @override
  String get showCover => 'Asehoy ny fonony';

  @override
  String get moreOptions => 'Safidy hafa';

  @override
  String albumsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rakikira $count',
      one: 'Rakikira 1',
      zero: 'Tsy misy rakikira',
    );
    return '$_temp0';
  }

  @override
  String artistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mpanakanto $count',
      one: 'Mpanakanto 1',
      zero: 'Tsy misy mpanakanto',
    );
    return '$_temp0';
  }

  @override
  String get artistsGrouping =>
      'voavondrona araka ny marika « Mpanakanton\'ny rakikira »';

  @override
  String get albumsEmptyTitle => 'Mbola tsy misy rakikira';

  @override
  String get albumsEmptyBody =>
      'Avy amin\'ny marika ao amin\'ny rakitra (rakikira, mpanakanto) ny rakikira. Mbola tsy misy hira ao amin\'ny tahiry manana izany.';

  @override
  String get artistsEmptyTitle => 'Mbola tsy misy mpanakanto';

  @override
  String get artistsEmptyBody =>
      'Avy amin\'ny marika ao amin\'ny rakitra ny mpanakanto. Mbola tsy misy hira ao amin\'ny tahiry manana izany.';

  @override
  String get albumOverline => 'Rakikira';

  @override
  String get albumTracks => 'Hiran\'ny rakikira';

  @override
  String get artistTracks => 'Hira';

  @override
  String get groupMissing => 'Tsy ao amin\'ny tahiry intsony ity singa ity.';

  @override
  String get playVerb => 'Alefa';

  @override
  String get homeResume => 'Tohizo';

  @override
  String homeResumeKind(String kind) {
    return 'Tohizo · $kind';
  }

  @override
  String homeResumeAt(String time) {
    return 'Tohizo amin\'ny $time';
  }

  @override
  String minutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min sisa',
      one: '1 min sisa',
      zero: 'latsaky ny iray minitra sisa',
    );
    return '$_temp0';
  }

  @override
  String get openAlbum => 'Jereo ny rakikira';

  @override
  String get autoLists => 'Ireo lisitra mandeha ho azy';

  @override
  String get listMostPlayed => 'Matetika henoina';

  @override
  String get listRecentlyAdded => 'Vao nampidirina';

  @override
  String get listRecentlyAddedBody =>
      'Ireo hira farany tonga tao amin\'ny tahiry';

  @override
  String get listFavoritesBody => 'Ireo hira tianao indrindra';

  @override
  String andOthers(String names, int count) {
    return '$names sy $count hafa';
  }

  @override
  String get fullQueue => 'Filaharana feno';

  @override
  String get seeAll => 'Jereo daholo';

  @override
  String get recentAlbums => 'Rakikira vao haingana';

  @override
  String get homeEmptyTitle => 'Vonona ny toerana fihainoanao';

  @override
  String get homeEmptyBody =>
      'Mbola tsy nisy nohenoina ary foana ny tahiry. Ampio mozika avy amin\'ny Haka, na sokafy rakitra iray.';

  @override
  String get goTracks => 'Jereo ny hira';

  @override
  String get goGet => 'Haka mozika';

  @override
  String get nowPlayingHint =>
      'Alefaso hira iray : hiseho eto izy, miaraka amin\'ny tononkirany sy ny manaraka ao amin\'ny filaharana.';

  @override
  String filmsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sarimihetsika $count',
      one: 'sarimihetsika 1',
      zero: 'tsy misy sarimihetsika',
    );
    return '$_temp0';
  }

  @override
  String seriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'andian-tantara $count',
      one: 'andian-tantara 1',
      zero: 'tsy misy andian-tantara',
    );
    return '$_temp0';
  }

  @override
  String videosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'horonan-tsary $count',
      one: 'horonan-tsary 1',
      zero: 'tsy misy horonan-tsary',
    );
    return '$_temp0';
  }

  @override
  String seasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fizarana $count',
      one: 'fizarana 1',
    );
    return '$_temp0';
  }

  @override
  String get segAll => 'Daholo';

  @override
  String get segFilms => 'Sarimihetsika';

  @override
  String get segSeries => 'Andian-tantara';

  @override
  String get sortBy => 'Alaharo';

  @override
  String get sortTitle => 'Lohateny';

  @override
  String get sortAdded => 'Vao nampidirina';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get kindFilm => 'Sarimihetsika';

  @override
  String get kindPersonal => 'Horonan-tsariko';

  @override
  String resumeAtShort(String time) {
    return 'tohizo amin\'ny $time';
  }

  @override
  String episodeShort(int season, int episode) {
    return 'F$season T$episode';
  }

  @override
  String episodeLabel(int episode, String title) {
    return 'T$episode · $title';
  }

  @override
  String episodeNumber(int episode) {
    return 'Tapany $episode';
  }

  @override
  String get cinemaEmptyTitle =>
      'Mbola tsy misy sarimihetsika na andian-tantara';

  @override
  String get cinemaEmptyBody =>
      'Miseho eto ho sarimihetsika ireo horonan-tsary 40 minitra na mihoatra. Ireo rakitra antsoina hoe S01E04, na manana ny marika Andian-tantara, no mamorona andian-tantara.';

  @override
  String get cinemaNoMatch =>
      'Mbola tsy misy na inona na inona amin\'ity sokajy ity.';

  @override
  String get personalEmptyTitle => 'Tsy misy horonan-tsarinao';

  @override
  String get personalEmptyBody =>
      'Miseho eto ireo horonan-tsary fohy ao amin\'ny tahiry (clip, horonan-tsary avy amin\'ny finday).';

  @override
  String get seriesWord => 'Andian-tantara';

  @override
  String get seriesMissing =>
      'Tsy ao amin\'ny tahiry intsony ity andian-tantara ity.';

  @override
  String resumeEpisode(int season, int episode, String time) {
    return 'Tohizo F$season · T$episode amin\'ny $time';
  }

  @override
  String playEpisode(int season, int episode) {
    return 'Alefaso F$season · T$episode';
  }

  @override
  String get fromStart => 'Hatramin\'ny voalohany';

  @override
  String seasonNumber(int season) {
    return 'Fizarana $season';
  }

  @override
  String seenOf(int seen, int total) {
    return '$seen hita amin\'ny $total';
  }

  @override
  String get watched => 'Hita';

  @override
  String resumeAtLeft(String time, String left) {
    return 'Tohizo amin\'ny $time · $left';
  }

  @override
  String subtitlesLangs(String langs) {
    return 'Dikanteny $langs';
  }

  @override
  String get subtitles => 'Dikanteny';

  @override
  String get subtitlesOff => 'Tsy alefa';

  @override
  String get subtitlesLoad => 'Hampiditra rakitra SRT / VTT / ASS…';

  @override
  String get subtitlesExternal => 'ivelany';

  @override
  String get audioTrack => 'Lalan-peo';

  @override
  String get noTracks => 'Tsy misy lalan-peo hafa ato amin\'ity rakitra ity';

  @override
  String get replay10 => 'Miverina 10 s';

  @override
  String get forward10 => 'Mandroso 10 s';

  @override
  String get fullscreen => 'Efijery feno (F)';

  @override
  String get fullscreenExit => 'Hiala amin\'ny efijery feno (Échap)';

  @override
  String get chapters => 'Toko';

  @override
  String get chaptersSoon => 'Hiseho eto ireo tokon\'ny rakitra.';

  @override
  String get nextEpisode => 'Tapany manaraka';

  @override
  String get autoNext => 'Mandeha ho azy rehefa tapitra';

  @override
  String get videoLoading => 'Manokatra ny horonan-tsary…';

  @override
  String get videoUnavailable => 'Tsy misy horonan-tsary mandeha';

  @override
  String podcastsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'podcast $count',
      one: 'podcast 1',
      zero: 'tsy misy podcast',
    );
    return '$_temp0';
  }

  @override
  String coursesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lesona $count',
      one: 'lesona 1',
      zero: 'tsy misy lesona',
    );
    return '$_temp0';
  }

  @override
  String audiobooksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'boky azo henoina $count',
      one: 'boky azo henoina 1',
      zero: 'tsy misy boky azo henoina',
    );
    return '$_temp0';
  }

  @override
  String hoursTotal(int hours) {
    return '$hours ora';
  }

  @override
  String get segPodcasts => 'Podcast';

  @override
  String get segCourses => 'Lesona';

  @override
  String get segBooks => 'Boky azo henoina';

  @override
  String get focusInProgress => 'Mbola mandeha';

  @override
  String get focusLibrary => 'Tahiry';

  @override
  String get kindPodcast => 'Podcast';

  @override
  String get kindCourse => 'Lesona';

  @override
  String get kindAudiobook => 'Boky azo henoina';

  @override
  String episodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tapany $count',
      one: 'tapany 1',
    );
    return '$_temp0';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'lesona $count',
      one: 'lesona 1',
    );
    return '$_temp0';
  }

  @override
  String partsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ampahany $count',
      one: 'ampahany 1',
    );
    return '$_temp0';
  }

  @override
  String leftAtRate(String left, String rate) {
    return '$left sisa amin\'ny $rate';
  }

  @override
  String get focusOrderHint =>
      'Ny filaharana dia vakiana avy amin\'ny laharan\'ny rakitra (01, 02…) na ny marika.';

  @override
  String get focusEmptyTitle => 'Tsy misy podcast, lesona na boky azo henoina';

  @override
  String get focusEmptyBody =>
      'Miditra ao amin\'ny Focus ny rakitra feo iray noho ny karazany (Podcast, Lesona, Boky azo henoina), noho ny lahatahiry antsoina hoe Podcasts, Cours na Livres audio, na raha endrika .m4b izy.';

  @override
  String get focusNoMatch =>
      'Mbola tsy misy na inona na inona amin\'ity sokajy ity.';

  @override
  String programPosition(String kind, int number, int total) {
    return '$kind $number amin\'ny $total';
  }

  @override
  String estimatedEnd(String time, String rate) {
    return 'Tapitra eo ho eo amin\'ny $time amin\'ny $rate';
  }

  @override
  String get forward30 => 'Mandroso 30 s';

  @override
  String get bookmark => 'Marika';

  @override
  String get bookmarkAdd => 'Hanisy marika (B)';

  @override
  String get bookmarks => 'Marika';

  @override
  String get bookmarkNoNote => 'Marika tsy misy fanamarihana';

  @override
  String get bookmarksEmpty => 'Mbola tsy misy marika.';

  @override
  String get bookmarksHint =>
      'B no manisy marika eo amin\'ny toerana misy anao. Azo avoaka ho lahatsoratra miaraka amin\'ny lesona.';

  @override
  String get bookmarkRemove => 'Fafao ny marika';

  @override
  String get chaptersNone => 'Tsy misy toko ity rakitra ity.';

  @override
  String get transcript => 'Lahatsoratra';

  @override
  String get futureBadge => 'HO AVY';

  @override
  String get transcriptTitle => 'Fandikana an-tsoratra — asa ho avy';

  @override
  String get transcriptBody =>
      'Miseho eto ny rakitra .txt na .vtt mitovy anarana apetraka eo akaikin\'ny rakitra. Ho avy any aoriana ny famoronana eo an-toerana sy ny fikarohana ao anatin\'ny fandikana an-tsoratra.';

  @override
  String get sleepEndOfChapter => 'Fameram-potoana : fiafaran\'ny toko';

  @override
  String get sleepEndOfEpisode => 'Fameram-potoana : fiafaran\'ny rakitra';

  @override
  String get skipSilence => 'Dinganina ny fahanginana';

  @override
  String get voiceBoost => 'Hamafisina ny feo';

  @override
  String get p1Later => 'ho an\'ireo roa farany';

  @override
  String get navHistory => 'Tantara';

  @override
  String get historySubtitle =>
      'Fandefasana sy toerana, voatahiry ao amin\'ity fitaovana ity';

  @override
  String get historyClear => 'Fafao ny tantara…';

  @override
  String get historyClearTitle => 'Hofafana ve ny tantara ?';

  @override
  String get historyClearBody =>
      'Hadino ireo fandefasana voatanisa eto. Tsy misy rakitra, tiako indrindra na toerana fanohizana voafafa.';

  @override
  String get cancel => 'Foanana';

  @override
  String get clear => 'Fafana';

  @override
  String get today => 'Androany';

  @override
  String get yesterday => 'Omaly';

  @override
  String positionOf(String position, String total) {
    return '$position amin\'ny $total';
  }

  @override
  String get finished => 'Vita';

  @override
  String get replay => 'Jereo indray';

  @override
  String get historyEmptyTitle => 'Mbola tsy nisy nalefa';

  @override
  String get historyEmptyBody =>
      'Hiseho eto izay henoinao sy jerenao, miaraka amin\'ny toerana nijanonanao.';

  @override
  String searchTitle(String query) {
    return '« $query »';
  }

  @override
  String searchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'valiny $count',
      one: 'valiny 1',
      zero: 'tsy misy valiny',
    );
    return '$_temp0 ao amin\'ny tahiry eto an-toerana';
  }

  @override
  String get bestResult => 'Valiny tsara indrindra';

  @override
  String seeAllCount(int count) {
    return 'Jereo daholo ($count)';
  }

  @override
  String get searchTranscripts =>
      'Fikarohana ao amin\'ny fandikana an-tsoratra';

  @override
  String searchEmptyTitle(String query) {
    return 'Tsy misy valiny ho an\'ny « $query »';
  }

  @override
  String get searchEmptyBody =>
      'Tsy mijery ny marika amin\'ny litera ny fikarohana ary mahita ny fiandohan\'ny teny. Andramo teny hafa.';

  @override
  String get searchHint =>
      'Soraty ny lohatenin\'ny hira, mpanakanto, sarimihetsika na podcast.';

  @override
  String get kindTrack => 'Hira';

  @override
  String get kindAlbum => 'Rakikira';

  @override
  String get kindArtist => 'Mpanakanto';

  @override
  String get searchClear => 'Fafao ny fikarohana';

  @override
  String get setGeneral => 'Ankapobeny';

  @override
  String get setAppearance => 'Endrika';

  @override
  String get setPlayback => 'Fandefasana';

  @override
  String get setLibrary => 'Tahiry';

  @override
  String get setShortcuts => 'Hitsin-dalana';

  @override
  String get setData => 'Angona sy fitehirizana';

  @override
  String get setAbout => 'Momba azy';

  @override
  String get language => 'Fiteny';

  @override
  String get languageBody => 'Fitenin\'ny fampiasana';

  @override
  String get languageSystem => 'Rafitra';

  @override
  String get theme => 'Loko ankapobeny';

  @override
  String get themeDark => 'Maizina';

  @override
  String get themeLight => 'Mazava';

  @override
  String get themeSystem => 'Rafitra';

  @override
  String get playColor => 'Lokon\'ny fandefasana';

  @override
  String get colorCoral => 'Koraly';

  @override
  String get colorRose => 'Mavokely';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorBlue => 'Manga';

  @override
  String get density => 'Hatevina';

  @override
  String get densityBody => 'Mifanakaiky : andalana 40 px ao amin\'ny lisitra';

  @override
  String get densityComfortable => 'Malalaka';

  @override
  String get densityCompact => 'Mifanakaiky';

  @override
  String get textSize => 'Haben\'ny soratra';

  @override
  String get textSizeBody => '90 hatramin\'ny 130 %';

  @override
  String get reduceMotion => 'Ahenoy ny fihetsehana';

  @override
  String get reduceMotionBody => 'Manaraka ny fikirana Windows raha tsy misy';

  @override
  String get reduceTransparency => 'Ahenoy ny fangarahana';

  @override
  String get reduceTransparencyBody => 'Tsy mangarahara na aiza na aiza';

  @override
  String get coverBackdrop => 'Fonony ho ambadika ao amin\'ny Mandeha';

  @override
  String get coverBackdropBody => 'Fonony manjavozavo ao ambadiky ny mpamaky';

  @override
  String get engineSection => 'Motera sy fivoahana';

  @override
  String get engine => 'Motera fandefasana';

  @override
  String get engineBodyWindows =>
      'libmpv ao anatiny, famadihana amin\'ny fitaovana miaraka amin\'ny fiverenana';

  @override
  String get engineBodyAndroid => 'Media3, ny mpamakin\'i Android';

  @override
  String get engineValue => 'Ao anatiny (soso-kevitra)';

  @override
  String get audioOutput => 'Fivoahan\'ny feo';

  @override
  String get audioOutputBody => 'Fitaovana ampiasain\'i Miarina Media';

  @override
  String get systemDefault => 'Ny an\'ny rafitra';

  @override
  String get exclusive => 'Fomba manokana WASAPI';

  @override
  String get exclusiveBody => 'Ho an\'ny DAC ivelany, mamono ny feo hafa';

  @override
  String get chainSection => 'Fifandimbiasana';

  @override
  String get resumeSetting => 'Tohizo amin\'ny nijanonako';

  @override
  String get resumeSettingBody => 'Feo sy horonan-tsary, rehefa manomboka';

  @override
  String get gapless => 'Fandefasana tsy misy elanelana (gapless)';

  @override
  String get gaplessBody => 'Rakikira live sy mifangaro';

  @override
  String get crossfade => 'Fifandimbiasana malefaka eo amin\'ny hira';

  @override
  String get crossfadeBody => '0 hatramin\'ny 12 s';

  @override
  String get off => 'Tsy alefa';

  @override
  String get normalizationSetting => 'Fampitoviana ny haben\'ny feo';

  @override
  String get normalizationSettingBody => 'ReplayGain raha misy';

  @override
  String get videoSection => 'Horonan-tsary';

  @override
  String get defaultSubtitles => 'Dikanteny tsotra';

  @override
  String get defaultSubtitlesBody => 'Fiteny tiana, raha tsy izany tsy misy';

  @override
  String get none => 'Tsy misy';

  @override
  String get sidecar => 'Hampiditra ny dikanteny eo akaikin\'ny rakitra';

  @override
  String get sidecarBody => '.srt, .vtt, .ass mitovy anarana';

  @override
  String get p1Badge => 'P1';

  @override
  String get keyPlayPause => 'Alefa / ijanona';

  @override
  String get keyPrevious => 'Hira teo aloha';

  @override
  String get keyNext => 'Hira manaraka';

  @override
  String get keySeekBack => 'Miverina 10 s';

  @override
  String get keySeekForward => 'Mandroso 10 s';

  @override
  String get keyVolumeUp => 'Ampiakarina ny feo';

  @override
  String get keyVolumeDown => 'Ampidinina ny feo';

  @override
  String get keyMute => 'Vonoy ny feo';

  @override
  String get keySearch => 'Hitady';

  @override
  String get keyBack => 'Hiverina';

  @override
  String get keyForward => 'Handroso';

  @override
  String get keyToggleSidebar => 'Aforony ny tsanganana anila';

  @override
  String get keyNowPlaying => 'Mandeha';

  @override
  String get keyFullscreen => 'Efijery feno';

  @override
  String get keySubtitles => 'Dikanteny';

  @override
  String get keyAudioTrack => 'Lalan-peo';

  @override
  String get keyFrameStep => 'Sary manaraka (ijanona)';

  @override
  String get keyBookmark => 'Hanisy marika';

  @override
  String get keyLyrics => 'Tononkira';

  @override
  String get keyMiniPlayer => 'Mpamaky kely';

  @override
  String get keySpeedDown => 'Hafainganana −';

  @override
  String get keySpeedUp => 'Hafainganana +';

  @override
  String get keysPlayback => 'Fandefasana';

  @override
  String get keysNavigation => 'Fivezivezena';

  @override
  String get keysVideo => 'Horonan-tsary';

  @override
  String get keysFocus => 'Focus sy varavarankely';

  @override
  String get keysTitle => 'Hitsin-dalana amin\'ny fitendry';

  @override
  String get keysSearch => 'Hitady hitsin-dalana';

  @override
  String get keysReset => 'Averina ny teo aloha';

  @override
  String get keysHint =>
      'Tsindrio ny fanalahidy iray hanovana azy ; voalaza mialoha ny fitehirizana ny fifandonana. Échap no manafoana. Raisina ireo fanalahidy multimédia amin\'ny fitendry sy ny écouteur (fanaraha-maso media an\'i Windows).';

  @override
  String get keyPress => 'Tsindrio fanalahidy iray…';

  @override
  String get keyNone => 'Tsy misy';

  @override
  String get keyShift => 'Maj';

  @override
  String get keySpace => 'Elanelana';

  @override
  String keyConflict(String key, String action) {
    return 'Efa ampiasain\'ny « $action » ny $key.';
  }

  @override
  String get keyReplace => 'Soloy';

  @override
  String get keyRemove => 'Esory ny fanalahidy';

  @override
  String get libraryTracks => 'Hira';

  @override
  String get libraryVideos => 'Horonan-tsary';

  @override
  String get dataFolder => 'Lahatahirin\'ny angona';

  @override
  String get dataFolderBody => 'Fototry ny tahiry, fikirana ary fonony';

  @override
  String get openFolder => 'Sokafy ny lahatahiry';

  @override
  String get playHistory => 'Tantaran\'ny fandefasana';

  @override
  String get playHistoryBody =>
      'Fandefasana sy toerana aseho ao amin\'ny Tantara';

  @override
  String get aboutVersion => 'Kinova';

  @override
  String get aboutDevBuild => 'Kinova fampandrosoana';

  @override
  String get aboutLicense => 'Fahazoan-dalana';

  @override
  String get aboutLicenses => 'Fahazoan-dalan\'ireo singa';

  @override
  String get aboutLicensesBody => 'Endri-tsoratra, kisary ary boky ao anatiny';

  @override
  String get show => 'Asehoy';

  @override
  String get aboutLocal =>
      'Mijanona ao amin\'ity fitaovana ity ny zava-drehetra : tsy misy kaonty, tsy misy angona alefa.';

  @override
  String get aboutCompanyBody => 'Anisan\'ny tontolo Miarina i Miarina Media.';

  @override
  String get aboutDeveloper => 'Mpamorona';

  @override
  String get playlistNew => 'Vaovao';

  @override
  String get playlistImport => 'Hampiditra M3U';

  @override
  String get playlistExport => 'Havoaka';

  @override
  String playlistModified(String when) {
    return 'Lisitra · novaina $when';
  }

  @override
  String get agoNow => 'izao vao izao';

  @override
  String agoMinutes(int count) {
    return '$count min lasa izay';
  }

  @override
  String agoHours(int count) {
    return '$count ora lasa izay';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count andro lasa izay',
      one: 'omaly',
    );
    return '$_temp0';
  }

  @override
  String titlesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hira $count',
      one: 'hira 1',
      zero: 'tsy misy hira',
    );
    return '$_temp0';
  }

  @override
  String missingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hira $count tsy hita',
      one: 'hira 1 tsy hita',
    );
    return '$_temp0';
  }

  @override
  String get addTracks => 'Hanampy hira';

  @override
  String get playlistHint =>
      'Tariho hanovana ny filaharana · Alt+↑/↓ amin\'ny fitendry · Suppr manala ao amin\'ny lisitra (mijanona ny rakitra)';

  @override
  String get newPlaylistTitle => 'Lisitra vaovao';

  @override
  String get playlistName => 'Anarana';

  @override
  String addQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ampio ireo hira $count ao amin\'ny filaharana',
      one: 'Ampio ny hira ao amin\'ny filaharana',
    );
    return '$_temp0';
  }

  @override
  String get smartPlaylist => 'Lisitra marani-tsaina (fitsipika)';

  @override
  String get create => 'Mamorona';

  @override
  String get rename => 'Ovay anarana';

  @override
  String get save => 'Tehirizo';

  @override
  String get deletePlaylist => 'Fafao ny lisitra';

  @override
  String deletePlaylistTitle(String name) {
    return 'Hofafana ve ny « $name » ?';
  }

  @override
  String get deletePlaylistBody =>
      'Voafafa ny lisitra. Mijanona ao amin\'ny tahiry ny rakitra.';

  @override
  String get delete => 'Fafao';

  @override
  String importDone(String name, int added, int skipped) {
    return '« $name » : hira $added nampidirina, $skipped tsy hita na an-tserasera.';
  }

  @override
  String exportDone(String path) {
    return 'Voatahiry ny lisitra : $path';
  }

  @override
  String get playlistsEmptyTitle => 'Tsy misy lisitra';

  @override
  String get playlistsEmptyBody => 'Mamorona lisitra na mampidira rakitra M3U.';

  @override
  String get playlistEmpty => 'Foana ity lisitra ity. Ampio hira.';

  @override
  String get addedShort => 'Nampidirina';

  @override
  String get removeFromPlaylist => 'Esory ao amin\'ny lisitra';

  @override
  String get moveUp => 'Ampiakarina';

  @override
  String get moveDown => 'Ampidinina';

  @override
  String get playlistFileType => 'Lisitra M3U';

  @override
  String playlistActionFailed(String error) {
    return 'Tsy nahomby ny asa : $error';
  }

  @override
  String get close => 'Hidio';

  @override
  String get emptyOpenFiles => 'Sokafy rakitra…';

  @override
  String get emptyFormats =>
      'Endrika vakiana : MP3, M4A, FLAC, OGG, Opus, WAV, AAC, ary amin\'ny horonan-tsary MP4, MKV, WebM, MOV, AVI.';

  @override
  String get emptyNote =>
      'Misintona amin\'ny Miarina Media ve ianao ? Tonga eto ho azy ny rakitra azonao.';

  @override
  String get mediaFiles => 'Rakitra feo sy horonan-tsary';

  @override
  String get errFormatTitle => 'Endrika tsy raisina';

  @override
  String get errFormatBody =>
      'Tsy hain\'ny motera ny mamaky ity rakitra ity. Tsy novaina ny rakitra.';

  @override
  String get errDamagedTitle => 'Rakitra simba';

  @override
  String get errDamagedBody =>
      'Nijanona ny fandefasana : toa tsy azo vakiana ny ampahany amin\'ny rakitra. Tsy novaina ny rakitra.';

  @override
  String get errAccessTitle => 'Tsy nahazo alalana';

  @override
  String get errAccessBody =>
      'Tsy avelan\'ny rafitra hamaky ity rakitra ity i Miarina Media. Mandeha tsara ny rakitra hafa.';

  @override
  String get errMissingTitle => 'Tsy hita ny rakitra';

  @override
  String get errMissingBody =>
      'Nafindra, novana anarana, na tsy mifandray ny kapila misy azy ny rakitra. Mitazona ny toerany ao amin\'ny tahiry izy.';

  @override
  String get errPlaybackTitle => 'Tsy azo alefa';

  @override
  String get errPlaybackBody =>
      'Tsy voavaky ity rakitra ity. Tsy nisy novaina.';

  @override
  String get errLibraryRepairTitle => 'Tahiry tokony amboarina';

  @override
  String get errLibraryRepairBody =>
      'Tsy nisokatra ny fanondroana ny tahiry. Tsy nokasihina ny rakitrao.';

  @override
  String get errLibraryTitle => 'Tsy misokatra ny tahiry';

  @override
  String get errLibraryBody =>
      'Tsy nisy novaina. Andramo indray ; raha mitohy, adikao ny antsipiriany ho an\'ny fanampiana.';

  @override
  String get copyDetails => 'Adikao ny antsipiriany';

  @override
  String get detailsCopied => 'Voadika ny antsipiriany';

  @override
  String get skipNext => 'Mandehana amin\'ny manaraka';

  @override
  String get welcomeHeadline =>
      'Ny mozikanao, ny sarimihetsikanao ary ny lesonao, amin\'ny toerana iray.';

  @override
  String get welcomeLocal =>
      'Mijanona ao amin\'ity solosaina ity ny zava-drehetra. Tsy misy kaonty, tsy misy angona alefa.';

  @override
  String get welcomeFoot =>
      'Fandefasana eto an-toerana, tsy misy fanaraha-maso. Azo ovaina any aoriana ao amin\'ny Fikirana.';

  @override
  String get stepAppearance => 'Fiteny sy endrika';

  @override
  String get stepFolders => 'Lahatahiry';

  @override
  String get stepScan => 'Fandinihana';

  @override
  String get skip => 'Dinganina';

  @override
  String get continueLabel => 'Tohizo';

  @override
  String get analyse => 'Diniho';

  @override
  String get themeFollow => 'Manaraka an\'i Windows';

  @override
  String get foldersTitle => 'Aiza ny rakitrao ?';

  @override
  String get foldersBody =>
      'Mamaky ireo lahatahiry ireo i Miarina Media nefa tsy manova na mamindra azy. Miseho isaky ny manomboka ny rakitra vaovao.';

  @override
  String folderFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'rakitra feo na horonan-tsary $count',
      one: 'rakitra feo na horonan-tsary 1',
      zero: 'tsy misy rakitra feo na horonan-tsary',
    );
    return '$_temp0';
  }

  @override
  String get kindVideo => 'Horonan-tsary';

  @override
  String get addFolder => 'Hanampy lahatahiry…';

  @override
  String foldersSummary(int folders, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: 'lahatahiry $folders',
      one: 'lahatahiry 1',
      zero: 'tsy misy lahatahiry',
    );
    return '$_temp0 · rakitra $files eo ho eo';
  }

  @override
  String get removeFolder => 'Esory ity lahatahiry ity';

  @override
  String get scanTitle => 'Fandinihana ny tahirinao';

  @override
  String get scanBody =>
      'Afaka manomboka mihaino ianao : mitohy ao ambadika ny fandinihana.';

  @override
  String scanProgress(int done, int total) {
    return 'Rakitra $done amin\'ny $total eo ho eo';
  }

  @override
  String get statTracks => 'hira';

  @override
  String get statAlbums => 'rakikira';

  @override
  String get statVideos => 'horonan-tsary';

  @override
  String get statUnreadable => 'tsy azo vakiana';

  @override
  String get readyNow => 'Efa vonona';

  @override
  String get scanEco =>
      'Fandinihana ao ambadika, rakitra iray isaky ny mandeha (fomba mitsitsy).';

  @override
  String get scanNoFfmpeg =>
      'Tsy voapetraka eo akaikin\'ny rindranasa ny FFmpeg : vakiana ny lohateny, mpanakanto ary rakikira ; ny faharetany sy ny sary kely rehefa voapetraka izy.';

  @override
  String get startListening => 'Manomboka mihaino';

  @override
  String get libraryFolders => 'Lahatahiry arahina';

  @override
  String get libraryFoldersBody =>
      'Dinihina isaky ny manomboka ; tsy misy ovaina na afindra.';

  @override
  String get scanNow => 'Diniho izao';

  @override
  String get scanDone => 'Vita ny fandinihana';

  @override
  String scanRunning(int done, int total) {
    return '$done amin\'ny $total voadinika';
  }

  @override
  String get noFolders => 'Mbola tsy misy lahatahiry arahina.';

  @override
  String get navSectionLibrary => 'Tahiry';

  @override
  String get navMissing => 'Tsy hita';

  @override
  String get navDuplicates => 'Mitovy roa';

  @override
  String get healthGroup => 'Toetry ny tahiry';

  @override
  String get missingTitle => 'Rakitra tsy hita';

  @override
  String missingSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Singa $count no tsy hita tamin\'ny fandinihana farany. Tsy nisy voafafa.',
      one:
          'Singa 1 no tsy hita tamin\'ny fandinihana farany. Tsy nisy voafafa.',
    );
    return '$_temp0';
  }

  @override
  String missingVolumeTitle(String volume) {
    return 'Tsy mifandray ny kapila $volume';
  }

  @override
  String missingVolumeBody(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Singa $count avy ao amin\'ny $folder. Hiseho indray rehefa ampifandraisina.',
      one:
          'Singa 1 avy ao amin\'ny $folder. Hiseho indray rehefa ampifandraisina.',
    );
    return '$_temp0';
  }

  @override
  String get missingMovedTitle => 'Lahatahiry toa novana anarana';

  @override
  String missingMovedBody(int count, String folder) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Rakitra $count hita tao amin\'ny $folder, mitovy anarana sy habe.',
      one: 'Rakitra 1 hita tao amin\'ny $folder, mitovy anarana sy habe.',
    );
    return '$_temp0';
  }

  @override
  String missingLostTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rakitra $count tsy hita',
      one: 'Rakitra 1 tsy hita',
    );
    return '$_temp0';
  }

  @override
  String missingLostBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tsy nahitana mifanandrify. Mety efa voafafa izy ireo.',
      one: 'Tsy nahitana mifanandrify. Mety efa voafafa izy.',
    );
    return '$_temp0';
  }

  @override
  String get missingRelocate => 'Tadiavo ny toerany…';

  @override
  String get missingHide => 'Afeno';

  @override
  String get missingUpdatePaths => 'Havaozina ny lalana';

  @override
  String get missingIgnore => 'Tsy raharahiana';

  @override
  String get missingLocate => 'Tadiavo…';

  @override
  String get missingSearchFolder => 'Tadiavo ao amin\'ny lahatahiry iray…';

  @override
  String get missingRemove => 'Esory ao amin\'ny tahiry';

  @override
  String get missingStatusVolume => 'tsy eo ny kapila';

  @override
  String get missingStatusFound => '→ hita';

  @override
  String get missingStatusLost => 'tsy hita';

  @override
  String missingMore(int count) {
    return 'sy $count hafa';
  }

  @override
  String missingHiddenGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vondrona $count nafenina',
      one: 'vondrona 1 nafenina',
    );
    return '$_temp0';
  }

  @override
  String get missingShowAll => 'Asehoy daholo';

  @override
  String get missingEmptyTitle => 'Eo daholo ny rakitrao';

  @override
  String get missingEmptyBody =>
      'Hiseho eto ireo rakitra nafindra na voatahiry amin\'ny kapila tsy mifandray. Tsy misy na inona na inona voafafa ho azy.';

  @override
  String missingPathsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lalana $count nohavaozina',
      one: 'Lalana 1 nohavaozina',
      zero: 'Tsy nisy lalana nohavaozina',
    );
    return '$_temp0';
  }

  @override
  String missingFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rakitra $count hita',
      one: 'Rakitra 1 hita',
      zero: 'Tsy nisy rakitra hita',
    );
    return '$_temp0';
  }

  @override
  String missingLeftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mbola tsy hita',
      one: '1 mbola tsy hita',
    );
    return '$_temp0';
  }

  @override
  String missingRemoveTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hesorina ao amin\'ny tahiry ve ireo rakitra $count ireo ?',
      one: 'Hesorina ao amin\'ny tahiry ve ity rakitra ity ?',
    );
    return '$_temp0';
  }

  @override
  String get missingRemoveBody =>
      'Miala ao amin\'ny tahiry, ny lisitra ary ny fanohizana izy ireo. Tsy misy rakitra voafafa ao amin\'ny kapila : raha miseho indray izy, sokafy hampidirina indray.';

  @override
  String get remove => 'Esory';

  @override
  String missingSkipped(String title) {
    return 'Tsy hita « $title », hira manaraka';
  }

  @override
  String missingSkippedLast(String title) {
    return 'Tsy hita « $title »';
  }

  @override
  String get locate => 'Tadiavo';

  @override
  String get fileLocated => 'Hita ny rakitra';

  @override
  String get locateFailed =>
      'Tsy azo ampiasaina ho solon\'ny tany am-boalohany ity rakitra ity.';

  @override
  String get duplicatesTitle => 'Mitovy roa';

  @override
  String duplicatesSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vondrona $count · $size azo averina · lohateny, mpanakanto ary faharetany mitovy',
      one:
          'Vondrona 1 · $size azo averina · lohateny, mpanakanto ary faharetany mitovy',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesKeepBest =>
      'Tazony hatraiza hatraiza ny kalitao tsara indrindra';

  @override
  String duplicateVersions(int count) {
    return 'Kinova $count';
  }

  @override
  String get duplicateKeep => 'Tazony';

  @override
  String get duplicateHide => 'Afeno';

  @override
  String get duplicateTrash => 'Ataovy ao amin\'ny Fanariam-pako…';

  @override
  String get duplicatesNote =>
      'Raha tsy misy fanovana, afenina ao amin\'ny tahiry fotsiny ny mitovy roa : mijanona ao amin\'ny kapila ny rakitra. Mankany amin\'ny Fanariam-pakon\'i Windows ny famafana.';

  @override
  String duplicatesHideAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afeno ireo mitovy $count',
      one: 'Afeno ny mitovy',
    );
    return '$_temp0';
  }

  @override
  String duplicatesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Mitovy $count nafenina, mankany amin\'ny kinova notazonina ny lisitra misy azy',
      one: 'Mitovy 1 nafenina, mankany amin\'ny kinova notazonina ny lisitra misy azy',
    );
    return '$_temp0';
  }

  @override
  String get duplicateTrashTitle =>
      'Hapetraka ao amin\'ny Fanariam-pako ve ity rakitra ity ?';

  @override
  String get duplicateTrashBody =>
      'Mankany amin\'ny kinova notazonina ny lisitra sy ny tiako indrindra misy azy. Azonao averina avy ao amin\'ny Fanariam-pakon\'i Windows izy.';

  @override
  String get duplicateTrashed =>
      'Napetraka ao amin\'ny Fanariam-pako ny rakitra';

  @override
  String get duplicatesEmptyTitle => 'Tsy misy mitovy roa';

  @override
  String get duplicatesEmptyBody =>
      'Hiseho eto ireo hira misy kinova maromaro (lohateny, mpanakanto ary faharetany mitovy).';

  @override
  String get duplicatesNeedFfmpeg =>
      'FFmpeg no mamaky ny faharetany, tsy ao amin\'ity fametrahana ity : miandry ny fitadiavana mitovy roa.';

  @override
  String sizeKb(String n) {
    return '$n Ko';
  }

  @override
  String sizeMb(String n) {
    return '$n Mo';
  }

  @override
  String sizeGb(String n) {
    return '$n Go';
  }

  @override
  String duplicatesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hira $count misy kinova maromaro',
      one: 'Hira 1 misy kinova maromaro',
      zero: 'Tsy nahitana mitovy roa',
    );
    return '$_temp0';
  }

  @override
  String get miniPin => 'Tazony eo ambony foana';

  @override
  String get miniUnpin => 'Aza tazonina eo ambony intsony';

  @override
  String get miniExpand => 'Halehibeazo ny varavarankely';

  @override
  String get favoritesEmptyTitle => 'Mbola tsy misy tiako indrindra';

  @override
  String get favoritesEmptyBody =>
      'Tsindrio ny fon\'ny hira iray, ao amin\'ny Hira na Mandeha, mba hahitanao azy eto.';

  @override
  String get getNavHome => 'Fandraisana';

  @override
  String get getNavDownloads => 'Fisintonana';

  @override
  String get getNavBrowser => 'Mpitety tranonkala';

  @override
  String get getNavTorrents => 'Torrent';

  @override
  String get getNavHistory => 'Tantara';

  @override
  String get getHomeTitle => 'Avy amin\'ny rohy mankany amin\'ny tahirinao';

  @override
  String get getHomeSub =>
      'Apetaho ny rohy, fidio ny endrika, henoy na jereo tsy misy aterineto.';

  @override
  String get getLinkLabel => 'Rohin\'ny media';

  @override
  String get getPaste => 'Apetaho';

  @override
  String get getAnalyze => 'Diniho';

  @override
  String get getHintPaste => 'hametaka sy handinika';

  @override
  String get getHintDrop => 'Tariho ao amin\'ny varavarankely ny rohy';

  @override
  String get getHintExt => 'Na alefaso avy amin\'ny fanitarana Chrome/Edge';

  @override
  String get getQAudio => 'Feo fotsiny';

  @override
  String get getQAudioDesc => 'MP3 hatramin\'ny 320 kbps, FLAC';

  @override
  String get getQPlaylist => 'Lisitra';

  @override
  String get getQPlaylistDesc => 'Fidio ireo singa';

  @override
  String get getQBatch => 'Rohy maromaro';

  @override
  String get getQBatchDesc => 'Rohy iray isaky ny andalana';

  @override
  String get getQTorrent => 'Torrent / magnet';

  @override
  String get getQTorrentDesc => 'Rakitra sy fizarana voafehy';

  @override
  String get getContinue => 'Tohizo';

  @override
  String get getSeeLibrary => 'Jereo ny tahiry';

  @override
  String get getContinueEmpty =>
      'Hotohizana eto izay manomboka henoinao na jerenao.';

  @override
  String get getRecent => 'Vao nosintonina';

  @override
  String get getHomeEmpty => 'Hiseho eto ny fisintonanao.';

  @override
  String getPlayTitle(String title) {
    return 'Alefaso $title';
  }

  @override
  String getMinutesLeft(int n) {
    return '$n min sisa';
  }

  @override
  String get getLinkEmpty => 'Apetaho rohy iray hodinihina.';

  @override
  String get getLinkTooLong => 'Lava loatra ity rohy ity.';

  @override
  String get getLinkMalformed =>
      'Toa tsy feno ity rohy ity. Hamarino fa manomboka amin\'ny « https:// » izy.';

  @override
  String get getLinkScheme => 'Ny rohy http sy https ihany no raisina.';

  @override
  String get getLinkCredentials =>
      'Tsy raisina ny rohy misy anaran\'ny mpampiasa na teny miafina.';

  @override
  String get getLinkMissingHttps => 'Tsy misy « https:// » ity rohy ity.';

  @override
  String get getAddHttps => 'Ampio https://';

  @override
  String get getClipboardEmpty =>
      'Foana ny fitahirizana vonjimaika. Adikao aloha ny rohy iray.';

  @override
  String get getPlanned => 'KASAINA';

  @override
  String get getPlannedHint =>
      'Kasaina ho amin\'ny dingana manaraka : mbola tsy misy.';

  @override
  String get getBack => 'Hiverina';

  @override
  String get getFmtVideo => 'Horonan-tsary';

  @override
  String get getFmtSubs => 'Dikanteny';

  @override
  String get getNoVideoFormats =>
      'Tsy manolotra endrika horonan-tsary ity loharano ity.';

  @override
  String get getNoAudioFormats =>
      'Tsy manolotra endrika feo fotsiny ity loharano ity.';

  @override
  String get getNoSubsFormats => 'Tsy manolotra dikanteny ity loharano ity.';

  @override
  String getUpTo(String q) {
    return 'Hatramin\'ny $q';
  }

  @override
  String get getSubsPlanned => 'Dikanteny : kasaina ny fisintonana (DL-08)';

  @override
  String get getNoteAudio =>
      'Manaraka ny fisintonana ny famadihana ; aseho mitokana ny fandrosoany.';

  @override
  String get getNoteVideo => 'Habe nomen\'ny loharano, na tombana.';

  @override
  String get getNeedsFfmpeg =>
      'Apetraho ny FFmpeg mba hahazoana kalitao bebe kokoa (horonan-tsary sy feo atambatra) sy famadihana MP3.';

  @override
  String get getDirectResume => 'Rakitra mivantana · azo tohizana raha tapaka';

  @override
  String get getDirectNoResume =>
      'Rakitra mivantana · tsy azo tohizana raha tapaka';

  @override
  String getOriginalFile(String ext) {
    return '$ext · rakitra tany am-boalohany';
  }

  @override
  String get getTagRecommended => 'Soso-kevitra';

  @override
  String get getTagBest => 'Kalitao tsara indrindra';

  @override
  String get getChange => 'Ovay';

  @override
  String get getAddToQueue => 'Ampio ao amin\'ny filaharana';

  @override
  String get getStarting => 'Manomboka…';

  @override
  String getDownloadSize(String size) {
    return 'Sintony · $size';
  }

  @override
  String get getDownload => 'Sintony';

  @override
  String getAddedToQueue(String q) {
    return 'Nampidirina tao amin\'ny filaharana · $q';
  }

  @override
  String get getView => 'Jereo';

  @override
  String get getPrepTitle => 'Fanomanana ny rakitrao';

  @override
  String getPrepElapsed(int n) {
    return '$n s';
  }

  @override
  String getPrepStage1(String host) {
    return 'Mamaky ny rohy ao amin\'ny $host…';
  }

  @override
  String get getPrepStage2 => 'Mitady ireo kalitao horonan-tsary sy feo misy…';

  @override
  String get getPrepStage3 =>
      'Miadana kokoa ny famalian\'ny tranonkala sasany. Andraso kely azafady, mbola mandeha.';

  @override
  String get getPrepStage4 =>
      'Mbola mandeha. Mety haharitra kokoa ny horonan-tsary lava na tadiavina be.';

  @override
  String get getPrepThisSite => 'ity tranonkala ity';

  @override
  String get getPrepTip => 'TORO-HEVITRA';

  @override
  String get getPrepTip1 =>
      'Fidio ny « Feo fotsiny » raha ny mozika ihany no tianao hotazonina, ao anaty rakitra maivana kokoa.';

  @override
  String get getPrepTip2 =>
      'Tonga mivantana ao amin\'ny tahiry ny fisintonanao.';

  @override
  String get getPrepTip3 =>
      'Ireo kalitao atolotra dia izay avoakan\'ny loharano, tsy misy noforonina.';

  @override
  String get getPrepTip4 =>
      'Hira maromaro ? Ampio « Ao amin\'ny filaharana » izy ireo : misesy ny fisintonana azy.';

  @override
  String get getNoMediaTitle => 'Tsy nahitana media azo sintonina';

  @override
  String get getNoMediaBody =>
      'Tsy misy media raisina ity pejy ity, na mitaky fidirana, voaaro (DRM) na mivantana izy. Tsy mandingana ireo fiarovana ireo i Miarina Media.';

  @override
  String getNoMediaReason(String reason) {
    return 'Antony : $reason';
  }

  @override
  String get getWhyNetwork =>
      'tsy tratra ny tranonkala ; hamarino ny rohy sy ny fifandraisanao';

  @override
  String getWhyHttp(String status) {
    return 'nolavin\'ny tranonkala ny fangatahana (HTTP $status)';
  }

  @override
  String get getWhyPlatform =>
      'tsy azo atao amin\'ity fitaovana ity ny famakiana pejy web';

  @override
  String get getTryAgain => 'Andramo indray';

  @override
  String get getToolsNeeded => 'Mila ireo fitaovana media ity pejy ity';

  @override
  String get getToolsBody =>
      'Mamaky pejy web amin\'ny yt-dlp i Miarina Media ary manambatra na mamadika rakitra amin\'ny FFmpeg. Sintonina indray mandeha avy amin\'ny famoahana ofisialiny izy ireo ary hamarinina amin\'ny dian-tanana SHA-256 raikitra alohan\'ny hampiasana azy.';

  @override
  String getBytesOf(String done, String total) {
    return '$done amin\'ny $total';
  }

  @override
  String get getNotNow => 'Any aoriana';

  @override
  String get getDownloadingShort => 'Misintona…';

  @override
  String getDownloadTools(String size) {
    return 'Sintony ny fitaovana · $size';
  }

  @override
  String getTabActive(int n) {
    return 'Mandeha · $n';
  }

  @override
  String getTabDone(int n) {
    return 'Vita · $n';
  }

  @override
  String getTabFailed(int n) {
    return 'Tsy nahomby · $n';
  }

  @override
  String getDlSubRunning(int n, String speed) {
    return '$n mandeha · $speed · tohizana ho azy raha ekena ny loharano';
  }

  @override
  String get getDlSubPaused => 'Mijanona daholo';

  @override
  String getDlSubIdle(int n) {
    return 'Tsy misy mandeha · hatramin\'ny $n miaraka';
  }

  @override
  String get getPauseAll => 'Ajanony daholo';

  @override
  String get getResumeAll => 'Tohizo daholo';

  @override
  String get getDlNothing => 'Tsy misy na inona na inona eto aloha.';

  @override
  String getActRetry(String title) {
    return 'Andramo indray $title';
  }

  @override
  String getActResume(String title) {
    return 'Tohizo $title';
  }

  @override
  String getActStart(String title) {
    return 'Atombohy izao $title';
  }

  @override
  String getActPause(String title) {
    return 'Ajanony $title';
  }

  @override
  String get getCannotPause =>
      'Tsy azo ajanona mandritra ny fanomanana ny rakitra';

  @override
  String getRemoveNamed(String title) {
    return 'Esory $title';
  }

  @override
  String getCancelNamed(String title) {
    return 'Foano $title';
  }

  @override
  String get getCancelTitle => 'Hofoanana ve ny fisintonana ?';

  @override
  String getCancelBody(String title) {
    return 'Hesorina ao amin\'ny filaharana $title ary hofafana ny rakitra tsy feno.';
  }

  @override
  String get getCancelConfirm => 'Foano ny fisintonana';

  @override
  String get getKeepDownloading => 'Tohizo';

  @override
  String getActRestart(String title) {
    return 'Avereno hatramin\'ny voalohany $title';
  }

  @override
  String get getOpenFolder => 'Sokafy ny lahatahiry';

  @override
  String get getShowInFolder => 'Asehoy ao amin\'ny lahatahiry';

  @override
  String get getStDone => 'Vita';

  @override
  String get getFileGone => 'Tsy ao amin\'ny tahiry intsony ity rakitra ity.';

  @override
  String get getStFailed => 'Tsy nahomby';

  @override
  String getStResumeAt(int n) {
    return 'tohizana $n %';
  }

  @override
  String get getStOffline => 'Mijanona · tsy misy aterineto';

  @override
  String getStRetry(int n) {
    return 'Tapaka ny fifandraisana · andrana vaovao $n s';
  }

  @override
  String get getStDownloading => 'Misintona';

  @override
  String get getStConverting => 'Famadihana';

  @override
  String getStConvertingTo(String ext) {
    return 'Famadihana $ext';
  }

  @override
  String getStFinalizing(String ext) {
    return 'Famaranana $ext';
  }

  @override
  String get getStStep => 'dingana 2/2 · ffmpeg';

  @override
  String get getStPaused => 'Mijanona';

  @override
  String get getStPausedRestart => 'Mijanona · hanomboka indray';

  @override
  String get getStDiskFull => 'Tsy nahomby · feno ny kapila';

  @override
  String get getStAccessDenied => 'Tsy nahomby · tsy azo idirana ny lahatahiry';

  @override
  String get getStDiskFullHint => 'manalà toerana dia andramo indray';

  @override
  String get getStAccessDeniedHint => 'misafidiana lahatahiry hafa';

  @override
  String get getStAnalyzing => 'Mandinika ireo endrika…';

  @override
  String get getStQueued => 'Miandry';

  @override
  String get getWhyDiskFull => 'Feno ny kapila';

  @override
  String get getWhyNoSpace =>
      'Tsy ampy toerana amin\'ny kapila ho an\'ity rakitra ity';

  @override
  String get getWhyDenied => 'Tsy azo anoratana ny lahatahiry halehany';

  @override
  String getSumRunning(int n) {
    return '$n mandeha';
  }

  @override
  String get getSumOffline => 'Mijanona · tsy misy aterineto';

  @override
  String get getSumPaused => 'Mijanona daholo';

  @override
  String get getSumIdle => 'Tsy misy fisintonana';

  @override
  String getSumQueue(int n) {
    return '$n miandry';
  }

  @override
  String get getDirRefused =>
      'Tsy mandray rakitra ity lahatahiry ity. Misafidiana hafa.';

  @override
  String get getHistKind => 'Karazana tantara';

  @override
  String get getHistDownloads => 'Fisintonana';

  @override
  String get getHistPlays => 'Fandefasana';

  @override
  String get getClearHistory => 'Fafao ny tantara';

  @override
  String get getClearDlTitle => 'Hofafana ve ny tantaran\'ny fisintonana ?';

  @override
  String get getClearDlBody =>
      'Voafafa ny lisitry ny fisintonana taloha. Tsy voafafa ireo rakitra efa voatahiry ao amin\'ny tahirinao.';

  @override
  String get getHistEmptyDl =>
      'Miseho eto ny fisintonana vita, tsy nahomby na nofoanana.';

  @override
  String get getHistNoteDl => 'Tsy mamafa rakitra ny famafana ny tantara.';

  @override
  String getFailedBecause(String reason) {
    return 'Tsy nahomby · $reason';
  }

  @override
  String get getStCanceled => 'Nofoanana';

  @override
  String getActionsFor(String title) {
    return 'Asa ho an\'ny $title';
  }

  @override
  String get getCopySourceLink => 'Adikao ny rohy loharano';

  @override
  String get getLinkCopied => 'Voadika ny rohy loharano';

  @override
  String get getToday => 'Androany';

  @override
  String get getYesterday => 'Omaly';

  @override
  String get setDownloads => 'Fisintonana';

  @override
  String get getSaveTo => 'Tehirizina ao amin\'ny';

  @override
  String get getDefaultVideoQuality => 'Kalitao horonan-tsary tsotra';

  @override
  String get getDefaultVideoQualityDesc =>
      'Kalitao ambany kokoa raha tsy misy.';

  @override
  String get getDefaultAudio => 'Endrika feo tsotra';

  @override
  String get getSimultaneous => 'Fisintonana miaraka';

  @override
  String get getSimultaneousDesc =>
      'Miandry ao amin\'ny filaharana ireo manaraka.';

  @override
  String get getSpeedLimit => 'Fetran\'ny hafainganana';

  @override
  String get getDownloadSubs => 'Sintony ny dikanteny';

  @override
  String get getDownloadSubsDesc =>
      'Laharam-pahamehana ny fitenin\'ny fampiasana, raha misy.';

  @override
  String get getResourceMode => 'Fomba fampiasana ny loharanon-karena';

  @override
  String get getModeEco => 'Mitsitsy';

  @override
  String get getModeBalanced => 'Voalanjalanja';

  @override
  String get getModePerformance => 'Mahery';

  @override
  String getModeDesc(int n, int c) {
    return 'Fisintonana $n miaraka, famadihana $c miaraka.';
  }

  @override
  String get getMediaTools => 'Fitaovana media';

  @override
  String get getAutoUpdated => 'havaozina ho azy';

  @override
  String get getIncludedVerified => 'Tafiditra · voamarina';

  @override
  String get getInstalledVerified => 'Voapetraka · voamarina';

  @override
  String getToDownload(String size) {
    return '$size hosintonina';
  }

  @override
  String get getToolsInstalled => 'Voapetraka sy voamarina ny fitaovana media';

  @override
  String get getUpdCheck => 'Hitady fanavaozana';

  @override
  String get getUpdChecking => 'Mitady…';

  @override
  String getYtdlpLatest(String v) {
    return 'Vaovao indrindra ny yt-dlp ($v)';
  }

  @override
  String getYtdlpUpdated(String v) {
    return 'Nohavaozina ho $v ny yt-dlp · voamarina ny sonia';
  }

  @override
  String get getUpdFailed =>
      'Tsy vita ny fanavaozana ny yt-dlp. Andramo indray any aoriana.';

  @override
  String get getInstallFailed =>
      'Tsy voasintona ireo fitaovana. Hamarino ny fifandraisana dia andramo indray.';

  @override
  String get getLess => 'Kely kokoa';

  @override
  String get getMore => 'Bebe kokoa';

  @override
  String get brAddressPh => 'Hitady na hanoratra adiresy web';

  @override
  String brCloseTab(String title) {
    return 'Hidio ny tabilao $title';
  }

  @override
  String get brNewTab => 'Tabilao vaovao (Ctrl T)';

  @override
  String get brStartTab => 'Tabilao vaovao';

  @override
  String get brStop => 'Ajanony ny fampidirana';

  @override
  String get brBack => 'Teo aloha';

  @override
  String get brForward => 'Manaraka';

  @override
  String get brReload => 'Avereno ampidirina';

  @override
  String get brHome => 'Pejy fanombohana';

  @override
  String get brMediaOne => 'Media 1';

  @override
  String brMediaMany(int n) {
    return 'Media $n';
  }

  @override
  String get brStartTitle => 'Hitady na hanokatra pejy web';

  @override
  String get brStartBody =>
      'Rehefa misy horonan-tsary na rakitra feo ny pejy iray, misy tsipika fisintonana miseho eo ambanin\'ny pejy.';

  @override
  String get brLegalHint =>
      'Sintony ihany ireo media anao na izay manana zo hitehirizana ianao.';

  @override
  String brDownloadFound(int n) {
    return 'Sintony ireo media hita ato amin\'ity pejy ity ($n)';
  }

  @override
  String brMediaFound(int n) {
    return 'Media $n hita';
  }

  @override
  String get brMediaFoundOne => 'Media 1 hita';

  @override
  String get brChooseMedia => 'Fidio ny media sy ny endrika';

  @override
  String get brSheetTitle => 'Misintona avy amin\'ity pejy ity';

  @override
  String get brKindVideo => 'Horonan-tsary';

  @override
  String get brKindAudio => 'Feo';

  @override
  String get brKindHls => 'Fikorianana (HLS)';

  @override
  String get brKindDash => 'Fikorianana (DASH)';

  @override
  String get brKindPage => 'Mpamakin\'ny pejy';

  @override
  String get brItemProtected =>
      'Mety voaaro na mitaky fidirana ity singa ity. Andramo singa hafa ao amin\'ny pejy.';

  @override
  String get brClosePanel => 'Hidio ny tontonana';

  @override
  String get brTooManyTabs =>
      'Tabilao 12 farafahabetsany : hidio ny iray hanokafana hafa.';

  @override
  String get brUnsupported =>
      'Pejy web (http, https) ihany no misokatra ao amin\'ny mpitety.';

  @override
  String get brUnavailable =>
      'Tsy nanomboka ny mpitety : tsy hita na tsy namaly ny WebView2.';

  @override
  String get brHistory => 'Tantara';

  @override
  String get brFavorites => 'Tiako indrindra';

  @override
  String get brHistoryViews => 'Tantara na tiako indrindra';

  @override
  String get brHistorySearch => 'Hitady ao amin\'ny pejy notsidihina';

  @override
  String brNoMatch(String q) {
    return 'Tsy misy mifanaraka amin\'ny « $q ».';
  }

  @override
  String get brHistoryEmpty => 'Miseho eto ireo pejy tsidihinao.';

  @override
  String get brFavoritesEmpty =>
      'Ampidiro ho tiako indrindra ny pejy iray amin\'ny kintana ao amin\'ny tsipika adiresy.';

  @override
  String get brHistoryNote =>
      'Voatahiry ao amin\'ity fitaovana ity ihany. Tsy mamafa rakitra na fisintonana ny famafana azy.';

  @override
  String brDeleteVisit(String title) {
    return 'Esory ao amin\'ny tantara $title';
  }

  @override
  String brRemoveFavorite(String title) {
    return 'Esory ao amin\'ny tiako indrindra $title';
  }

  @override
  String get brClearTitle => 'Hofafana ve ny tantaran\'ny mpitety ?';

  @override
  String get brClearBody =>
      'Hadino ireo pejy notsidihina. Mijanona ny fisintonana, ny tahiry ary ny tiako indrindra.';

  @override
  String get brCleared => 'Voafafa ny tantaran\'ny mpitety';

  @override
  String get brClearHistory => 'Fafao ny tantara';

  @override
  String get brFavAdd => 'Ampidiro amin\'ny tiako indrindra';

  @override
  String get brFavRemove => 'Esory amin\'ny tiako indrindra';

  @override
  String get brFavAdded => 'Nampidirina tao amin\'ny tiako indrindra';

  @override
  String get brFavRemoved => 'Nesorina tao amin\'ny tiako indrindra';

  @override
  String get brSites => 'Tranonkala';

  @override
  String get setExtension => 'Fanitarana mpitety';

  @override
  String get extLead =>
      'Alefaso amin\'ny tsindry iray avy amin\'ny Chrome na Edge mankany amin\'ny Miarina Media ny pejy na horonan-tsary iray : misokatra eto ny fandinihana ary ianao no misafidy ny endrika.';

  @override
  String get extAccept => 'Raiso ireo rohy alefan\'ny fanitarana';

  @override
  String get extAcceptBody => 'Tsy misy alaina ho azy.';

  @override
  String get extSteps => 'Fanombohana';

  @override
  String get extStep1 => 'Apetraho ny fanitarana';

  @override
  String get extStep1Body =>
      'Chrome · Edge : pejy Extensions, alefaso ny fomba mpamorona, avy eo « Charger l\'extension non empaquetée » ary fidio ity lahatahiry ity.';

  @override
  String get extOpenFolder => 'Sokafy ny lahatahiry';

  @override
  String get extStep2 => 'Ampifandraiso ity PC ity';

  @override
  String get extStep2Body =>
      'Afaka mandefa rohy any amin\'ny Miarina Media ao amin\'ity solosaina ity ny Chrome sy Edge.';

  @override
  String get extConnected => 'Mifandray ny Chrome sy Edge.';

  @override
  String get extOther =>
      'Fametrahana Miarina Media hafa no mifandray ; ny Ampifandraiso no manolo azy.';

  @override
  String get extConnect => 'Ampifandraiso';

  @override
  String get extDisconnect => 'Fanapaho';

  @override
  String get extStep3 => 'Andramo ny fifandraisana';

  @override
  String get extTest => 'Andramo';

  @override
  String get extTestNever => 'Mbola tsy nandramana.';

  @override
  String extTestOk(String time) {
    return 'Andrana farany : nahomby tamin\'ny $time';
  }

  @override
  String extTestFailed(String time) {
    return 'Andrana farany : tsy nahomby tamin\'ny $time';
  }

  @override
  String get extTestDone => 'Mandeha ny fifandraisana.';

  @override
  String get extTestBad =>
      'Tsy mamaly ny tetezan\'ny mpitety. Fanapaho dia ampifandraiso indray.';

  @override
  String get extNoBridge =>
      'Tsy ahitana ny tetezan\'ny mpitety ity kinova Miarina Media ity.';

  @override
  String get extFailed => 'Tsy azo novaina ny fifandraisana.';

  @override
  String get extPrivacy =>
      'Tsy mamaky na inona na inona ao amin\'ny pejy ny fanitarana : ny rohy alefanao ihany no lasa, ary mankany amin\'ny Miarina Media ao amin\'ity solosaina ity ihany.';

  @override
  String get brTabs => 'Tabilao';

  @override
  String brTabsOpen(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Tabilao $n misokatra',
      one: 'Tabilao 1 misokatra',
    );
    return '$_temp0';
  }

  @override
  String get brBackToApp => 'Hiverina any amin\'ny Miarina Media';

  @override
  String brDownloadCount(int n) {
    return 'Sintony · $n';
  }

  @override
  String get brDownloadHoldHint =>
      'Tsindrio ela : sintony amin\'ny endrika tsotra ny media lehibe';

  @override
  String get brUnavailablePhone =>
      'Tsy nanomboka tamin\'ity fitaovana ity ny mpitety.';

  @override
  String get brStartBodyPhone =>
      'Rehefa misy horonan-tsary na rakitra feo ny pejy iray, misy bokotra Sintony miseho eo ambonin\'ny pejy.';

  @override
  String getReorderNamed(String title) {
    return 'Ovay ny filaharan\'ny $title (Alt + zana-tsipika ambony sy ambany, na tariho)';
  }

  @override
  String get torCapped => 'Fizarana voafetra, amin\'ny Ko/s';

  @override
  String get torChecking => 'Manamarina ny rakitra';

  @override
  String torDoneMeta(String size) {
    return 'Vita · $size';
  }

  @override
  String torDoneSharing(String size) {
    return 'Vita · $size · mizara';
  }

  @override
  String get torDown => 'Voaray';

  @override
  String get torDownLimit => 'Fetran\'ny fandraisana';

  @override
  String get torEmpty => 'Hiseho eto ny torrent-nao.';

  @override
  String get torEnable => 'Alefaso ny fotoam-piasana';

  @override
  String get torError => 'Hadisoana · nijanona ny famindrana';

  @override
  String get torFailed => 'Tsy nahomby ny asa.';

  @override
  String get torInactive => 'Fotoam-piasana mijanona';

  @override
  String get torInspect => 'Diniho ny rohy';

  @override
  String get torLeft => 'Sisa';

  @override
  String get torLimitsSaved => 'Voampihatra ny fetra';

  @override
  String get torMagnet => 'Rohy magnet';

  @override
  String get torOpenFile => 'Sokafy .torrent';

  @override
  String torPausedMeta(String done, String total) {
    return 'Mijanona · $done / $total';
  }

  @override
  String get torPeers => 'Mpiara-mizara';

  @override
  String get torPreviewNote =>
      'Voatahiry ao anaty lahatahiry vaovao ny rakitra, ao ambanin\'ny lahatahiry fisintonanao / Torrents. Mety ho voasoratra koa ireo ampahany kely eo amin\'ny sisin\'ny rakitra tsy nofidina.';

  @override
  String get torRatio => 'Tahan\'ny fizarana';

  @override
  String get torRatioDesc =>
      'Ajanona ny fizarana raha mihoatra · 0 = tsy misy fetra';

  @override
  String get torRemove => 'Esory';

  @override
  String get torRemoveBody =>
      'Tazonina ireo rakitra voasintona. Mijanona ny famindrana sy ny fizarana.';

  @override
  String torRemoveNamed(String name) {
    return 'Esory $name';
  }

  @override
  String get torRemoveTitle => 'Hesorina ve ity torrent ity ?';

  @override
  String get torResume => 'Tohizo';

  @override
  String get torSeedDesc =>
      'Ajanona aorian\'ny faharetany · 0 = tsy misy fetra';

  @override
  String get torSeedTime => 'Faharetan\'ny fizarana';

  @override
  String get torSequential => 'Sintony araka ny filaharana ireo ampahany';

  @override
  String get torSessionOff => 'Fotoam-piasana mijanona';

  @override
  String get torSessionOn => 'Fotoam-piasana mandeha';

  @override
  String get torSessionSharing => 'Fotoam-piasana mandeha · mizara';

  @override
  String get torSharing => 'Fizarana';

  @override
  String get torStart => 'Atombohy ny fisintonana';

  @override
  String get torStopAll => 'Ajanony daholo sy ny fizarana';

  @override
  String get torStopSharing => 'Ajanony ny fizarana';

  @override
  String get torSub =>
      'Ampio rohy magnet na rakitra .torrent. Mizara amin\'ny mpiara-mizara hafa ireo ampahany voasintona ny torrent, na dia efa vita aza : aseho ny fizarana ary azonao ajanona amin\'ny fotoana rehetra.';

  @override
  String get torTargetRatio => 'Tahan\'ny fizarana kendrena';

  @override
  String get torUnlimited => '0 = tsy misy fetra, amin\'ny Ko/s';

  @override
  String get torUp => 'Nalefa';

  @override
  String get torUpLimit => 'Fetran\'ny fandefasana';

  @override
  String get torWait => 'Andraso…';

  @override
  String get torLinkInvalid => 'Tsy manan-kery ity rohy magnet ity.';

  @override
  String get torDuplicate => 'Efa ao amin\'ny lisitra ity torrent ity.';

  @override
  String get torSelection => 'Misafidiana rakitra iray farafahakeliny.';

  @override
  String get torSessionChanged =>
      'Niova ny fotoam-piasana : diniho indray ny rohy.';

  @override
  String get torPlannedHint =>
      'Kasaina ho amin\'ny dingana manaraka : mbola tsy misy.';

  @override
  String get torPlanned => 'KASAINA';

  @override
  String filterMissingCount(int count) {
    return 'Tsy hita · $count';
  }

  @override
  String get filterAddedThisMonth => 'Nampidirina tamin\'ity volana ity';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voafidy',
      one: '1 voafidy',
    );
    return '$_temp0';
  }

  @override
  String get playNext => 'Alefaso manaraka';

  @override
  String get addToQueue => 'Ampio ao amin\'ny filaharana';

  @override
  String get addTo => 'Ampio ao amin\'ny…';

  @override
  String get addToPlaylist => 'Ampio ao amin\'ny lisitra…';

  @override
  String get addToPlaylistTitle => 'Ampio ao amin\'ny lisitra';

  @override
  String get newPlaylistEllipsis => 'Lisitra vaovao…';

  @override
  String get showInExplorer => 'Asehoy ao amin\'ny Explorateur';

  @override
  String get removeEllipsis => 'Esory…';

  @override
  String playNextDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Halefa manaraka ireo hira $count',
      one: 'Halefa manaraka ny hira',
    );
    return '$_temp0';
  }

  @override
  String queueAddDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hira $count nampidirina tao amin\'ny filaharana',
      one: 'Hira 1 nampidirina tao amin\'ny filaharana',
    );
    return '$_temp0';
  }

  @override
  String playlistAddDone(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hira $count nampidirina tao amin\'ny « $name »',
      one: 'Hira 1 nampidirina tao amin\'ny « $name »',
    );
    return '$_temp0';
  }

  @override
  String sortByColumn(String column) {
    return 'Alaharo araka ny $column';
  }

  @override
  String get sortedAscending => 'filaharana miakatra';

  @override
  String get sortedDescending => 'filaharana midina';

  @override
  String get clearSelection => 'Foano ny safidy';

  @override
  String get playSelection => 'Alefa';

  @override
  String get keyEnter => 'Entrée';

  @override
  String get keyCtrlEnter => 'Ctrl Entrée';

  @override
  String get keyDelete => 'Suppr';

  @override
  String get filterNeverPlayed => 'Mbola tsy nohenoina';

  @override
  String get filterHiRes => 'Hi-res';

  @override
  String get groupSortAdded => 'Vao nampidirina';

  @override
  String get groupSortName => 'A → Z';

  @override
  String get groupSortYear => 'Taona';

  @override
  String get groupSortPlays => 'Henoina indrindra';

  @override
  String get groupSortTracks => 'Isan\'ny hira';

  @override
  String get filterLossless => 'FLAC / hi-res';

  @override
  String get filterDownloaded => 'Nosintonina tamin\'ny Miarina Media';

  @override
  String get filterCompilations => 'Fanangonana';

  @override
  String filterNoCover(int count) {
    return 'Tsy misy fonony · $count';
  }

  @override
  String get filterEmptyTitle => 'Tsy misy amin\'ity sivana ity';

  @override
  String get filterEmptyBody =>
      'Fidio ny « Daholo » hijerena ny lisitra iray manontolo.';

  @override
  String get viewGrid => 'Takelaka';

  @override
  String get viewList => 'Lisitra';

  @override
  String playsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fihainoana $count',
      one: 'fihainoana 1',
    );
    return '$_temp0';
  }

  @override
  String playedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nohenoina in-$count',
      one: 'nohenoina indray mandeha',
    );
    return '$_temp0';
  }

  @override
  String get saveAsPlaylist => 'Tehirizo ho lisitra';

  @override
  String get editTags => 'Ovay ny marika';

  @override
  String get tagFromName => 'Fenoy avy amin\'ny anaran\'ny rakitra';

  @override
  String get tagRename => 'Ovay anarana ny rakitra « Mpanakanto - Lohateny »';

  @override
  String get fTitle => 'Lohateny';

  @override
  String get fArtist => 'Mpanakanto';

  @override
  String get fAlbumArtist => 'Mpanakanton\'ny rakikira';

  @override
  String get fAlbum => 'Rakikira';

  @override
  String get fYear => 'Taona';

  @override
  String get fGenre => 'Karazany';

  @override
  String get fTrack => 'Laharan\'ny hira';

  @override
  String get fDisc => 'Laharan\'ny kapila';

  @override
  String get fComment => 'Fanamarihana';

  @override
  String get fLyrics => 'Tononkira (tsy voatery)';

  @override
  String get fLyricsPh =>
      'Apetaho ny lahatsoratra na ny votoatin\'ny rakitra .lrc';

  @override
  String get tagNote =>
      'Tsy manova ny kalitaon\'ny feo na horonan-tsary ny fanovana marika.';

  @override
  String renameNote(String name) {
    return 'Hovana anarana ny rakitra : $name';
  }

  @override
  String get tagWrite =>
      'Soraty ao amin\'ny rakitra koa (raha tsy izany : ao amin\'ny tahirin\'ny Miarina Media ihany)';

  @override
  String get tagWriteUnsupported =>
      'Ao amin\'ny tahirin\'ny Miarina Media ihany no itazonan\'ity endrika ity ny marika.';

  @override
  String get tagsSavedFile => 'Voasoratra ao amin\'ny rakitra ny marika.';

  @override
  String get tagsSavedLibrary =>
      'Voatahiry ao amin\'ny tahiry ny marika. Tsy niova ny rakitra.';

  @override
  String get invalidNumber => 'Isa feno no andrasana';

  @override
  String get coverChoose => 'Misafidiana sary…';

  @override
  String get coverSource => 'Sary kelin\'ny loharano';

  @override
  String get coverNoSource => 'Tsy nanome sary kely ny loharano';

  @override
  String get coverRemove => 'Esory ny fonony';

  @override
  String get coverNone => 'Tsy misy fonony';

  @override
  String get coverWorking => 'Manomana ny fonony…';

  @override
  String get coverNote =>
      'JPEG, PNG, WebP, BMP na GIF. Ahena ho 1000 px ary tazonina ao amin\'ny tahiry, ampiharina avy hatrany ; tsy ovaina ny rakitra.';

  @override
  String get coverUpdated => 'Nohavaozina ny fonony';

  @override
  String get coverRemoved => 'Nesorina ny fonony';

  @override
  String get errTagsUnsupported =>
      'Tsy mandray marika ity karazana rakitra ity : tsy nisy voatahiry.';

  @override
  String get errTagsWrite =>
      'Tsy voasoratra tao amin\'ny rakitra ny marika : tsy nisy voatahiry.';

  @override
  String get errInvalidName => 'Tsy azo ampiasaina ity anarana ity.';

  @override
  String get errNotInLibrary => 'Tsy ao amin\'ny tahiry intsony ity hira ity.';

  @override
  String get errCoverRefused =>
      'Tsy azo atao fonony ity sary ity (endrika na habe).';

  @override
  String get errLibrary => 'Tsy vitan\'ny tahiry ity fanovana ity.';

  @override
  String get coverImageType => 'Sary';

  @override
  String get keyCtrlI => 'Ctrl I';

  @override
  String get markSeasonSeen => 'Mariho ho efa hita ny fizarana';

  @override
  String get markSeasonUnseen => 'Mariho ho mbola tsy hita ny fizarana';

  @override
  String get markSeriesSeen => 'Mariho ho efa hita ny andian-tantara';

  @override
  String get markSeriesUnseen => 'Mariho ho mbola tsy hita ny andian-tantara';

  @override
  String get markSeen => 'Mariho ho efa hita';

  @override
  String get markUnseen => 'Mariho ho mbola tsy hita';

  @override
  String get fDirector => 'Mpitantana / mpanoratra';

  @override
  String get fSeries => 'Andian-tantara / fanangonana';

  @override
  String get fLicense => 'Fahazoan-dalana / fanamarihana';

  @override
  String coverFrame(String time) {
    return 'Alaivo ny sary amin\'ny $time';
  }

  @override
  String get bookmarkAddNote => 'Hanampy fanamarihana…';

  @override
  String get bookmarkEditNote => 'Ovay ny fanamarihana…';

  @override
  String bookmarkNoteTitle(String time) {
    return 'Fanamarihan\'ny marika amin\'ny $time';
  }

  @override
  String get bookmarksExport => 'Havoaka…';

  @override
  String bookmarksExported(String path) {
    return 'Voatahiry ny marika : $path';
  }

  @override
  String get bookmarksExportFailed =>
      'Tsy voatahiry tao amin\'ity lahatahiry ity ny marika.';

  @override
  String get dbProblemTitle => 'Tsy nisokatra ny tahirinao';

  @override
  String dbTooNew(String found, String supported) {
    return 'Nohavaozin\'ny kinova Miarina Media vaovao kokoa ity tahiry ity : tsy afaka manokatra azy tsy misy loza ity kinova ity (fandrafetana $found, mijanona amin\'ny fandrafetana $supported ity kinova ity).\n\nTsy novaina ny angonao. Apetraho ny kinova Miarina Media farany.';
  }

  @override
  String dbUpgradeFailed(String backup, String reason) {
    return 'Tsy nahomby ny fanavaozana ny tahirinao. Nofoanana izy : tsy novaina ny angonao.\n\nDika tahiry : $backup\nAntsipiriany : $reason\n\nApetraho indray ny kinova Miarina Media teo aloha raha te hampiasa ity tahiry ity ianao.';
  }

  @override
  String get dbNoBackup => 'tsy misy';

  @override
  String dbBackupFailed(String reason) {
    return 'Tsy nahavita nandika ny tahirinao i Miarina Media talohan\'ny nanavaozana azy : tsy natao ny fanavaozana ary tsy novaina ny angonao.\n\nHamarino ny toerana malalaka ao amin\'ny kapila dia alefaso indray i Miarina Media.\nAntsipiriany : $reason';
  }

  @override
  String dbOpenFailed(String file, String reason) {
    return 'Tsy nisokatra ny tahirin\'ny Miarina Media.\n\nRakitra : $file\nAntsipiriany : $reason';
  }

  @override
  String get updConverting =>
      'Misy famadihana mandeha : azo atao ny fametrahana rehefa vita izy';

  @override
  String get updNetwork =>
      'Tapaka ny fifandraisana amin\'ny mpizara fanavaozana. Andramo indray : manohy eo amin\'izay nijanonany ny fisintonana.';

  @override
  String updAvailable(String v) {
    return 'Misy ny Miarina Media $v';
  }

  @override
  String get updBeta => 'Bêta';

  @override
  String updActive(String n) {
    return 'Fisintonana $n mandeha : tapaka mandritra ny fametrahana, hita mijanona rehefa manomboka indray. Voatahiry ny tahiry sy ny fikirana.';
  }

  @override
  String get updStopsPlayback => 'Hajanona ny fandefasana mandeha';

  @override
  String get updStopsSharing => 'Hajanona ny fizarana torrent';

  @override
  String updReady(String v) {
    return 'Vonona ny $v';
  }

  @override
  String updDownloading(String v) {
    return 'Misintona ny $v…';
  }

  @override
  String updInstalled(String v, String channel, String size) {
    return 'Kinova voapetraka $v · lalana $channel · $size';
  }

  @override
  String get updBadgeReady => 'Vonona';

  @override
  String get updBadgeDownloading => 'Misintona';

  @override
  String get updBadge => 'Misy';

  @override
  String get updProgress => 'Fandrosoan\'ny fanavaozana';

  @override
  String updProgressText(String done, String size) {
    return '$done / $size · hamarinina amin\'ny farany';
  }

  @override
  String updPartial(String done, String size) {
    return '$done / $size efa voasintona : manohy eo amin\'izay nijanonany ny ambiny.';
  }

  @override
  String get updVerified => 'Voamarina ny sonia sy ny SHA-256';

  @override
  String get updResume => 'Tohizo ny fisintonana';

  @override
  String updDownload(String size) {
    return 'Sintony · $size';
  }

  @override
  String get updInstalling => 'Manokatra ny fametrahana…';

  @override
  String get updInstall => 'Apetraho izao';

  @override
  String get updLater => 'Any aoriana';

  @override
  String get updKeptReady => 'Notazonina ho vonona ny fanavaozana.';

  @override
  String get updWindowsNote =>
      'Hidin\'i Windows ny Miarina Media ary sokafany ny mpametraka. Tazonina ny tahirinao, ny lisitrao, ny toerana fandefasanao ary ny fikiranao. Tsy misy apetraka raha tsy ekenao.';

  @override
  String get updChecking => 'Mitady…';

  @override
  String updLatest(String v) {
    return 'Ny kinova farany ($v) no ampiasainao.';
  }

  @override
  String get updAutoCheck =>
      'Mitady ho azy rehefa manomboka ary isaky ny enina ora.';

  @override
  String get updCheck => 'Hitady fanavaozana';

  @override
  String get updChannel => 'Lalana';

  @override
  String get updChannelDesc =>
      'Mahazo ny vaovao alohan\'ny fanamarinana feno ny bêta.';

  @override
  String get updAuto => 'Sintony ho azy';

  @override
  String get updAutoDesc =>
      'Amin\'ny Wi-Fi na tambajotra tsy voafetra ihany. Ianao foana no manapaka ny fametrahana.';

  @override
  String get setUpdates => 'Fanavaozana';

  @override
  String get updView => 'Jereo';

  @override
  String updVersion(String v) {
    return 'Kinova $v';
  }

  @override
  String get updDevBuild => 'Kinova fampandrosoana : tsy alefa ny fanavaozana.';

  @override
  String get deviceAccessTitle =>
      'Midira amin\'ny mozika sy horonan-tsary ao amin\'ity finday ity';

  @override
  String get deviceAccessBody =>
      'Mamaky ny rakitrao ao amin\'ny fitaovana i Miarina Media. Tsy misy alefa, tsy mila kaonty.';

  @override
  String get deviceAccessMusic => 'Mozika sy feo';

  @override
  String get deviceAccessMusicBody =>
      'Hampisehoana ny rakikira, podcast ary lesonao.';

  @override
  String get deviceAccessVideo => 'Horonan-tsary';

  @override
  String get deviceAccessVideoBody =>
      'Ho an\'ny sarimihetsika, andian-tantara ary horonan-tsarinao.';

  @override
  String get deviceAccessNotif => 'Fampandrenesana';

  @override
  String get deviceAccessNotifBody =>
      'Ho an\'ny fanaraha-maso ny fandefasana eo amin\'ny efijery mihidy.';

  @override
  String get deviceAccessAllow => 'Omeo alalana';

  @override
  String get deviceDeniedTitle => 'Tsy nahazo alalana hiditra amin\'ny rakitra';

  @override
  String get deviceDeniedBody =>
      'Raha tsy misy io alalana io, tsy hitan\'ny Miarina Media ny mozika sy horonan-tsary ao amin\'ny finday. Voatahiry ny lisitrao.';

  @override
  String get deviceDeniedSettings => 'Sokafy ny fikirana Android';

  @override
  String get dlNotifWaiting => 'Miandry toerana malalaka';

  @override
  String get dlNotifAnalyzing => 'Mamaky ireo endrika…';

  @override
  String get dlNotifProcessing => 'Manomana ny rakitra…';

  @override
  String dlNotifOf(String done, String total) {
    return '$done amin\'ny $total';
  }

  @override
  String dlNotifSpeed(String speed) {
    return '$speed Mo/s';
  }

  @override
  String get dlNotifLeftSoon => 'latsaky ny iray minitra sisa';

  @override
  String dlNotifLeftMin(int minutes) {
    return '$minutes min sisa';
  }

  @override
  String dlNotifLeftHours(int hours, int minutes) {
    return '$hours ora $minutes min sisa';
  }

  @override
  String get dlNotifTapToPlay => 'tsindrio hamakiana';

  @override
  String get dlNotifPause => 'Ijanona';

  @override
  String get dlNotifCancel => 'Foano';

  @override
  String get dlNotifPauseAll => 'Ajanony daholo';

  @override
  String get dlNotifComplete => 'Vita ny fisintonana';

  @override
  String get dlNotifSeveral => '%d mandeha';

  @override
  String get dlNotifChannelProgress => 'Fisintonana mandeha';

  @override
  String get dlNotifChannelDone => 'Fisintonana vita';

  @override
  String get getPasteLinkTitle => 'Apetaho rohy';

  @override
  String get getAnalyzeLink => 'Diniho ny rohy';

  @override
  String get getShareHint =>
      'Na zarao rohy mankany amin\'ny Miarina Media avy amin\'ny rindranasa rehetra.';

  @override
  String getDlCard(int running, int queued) {
    return '$running mandeha · $queued miandry';
  }

  @override
  String plCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'singa $count',
      one: 'singa 1',
    );
    return '$_temp0';
  }

  @override
  String plTruncated(int shown, int total) {
    return 'Ireo $shown voalohany amin\'ny $total';
  }

  @override
  String plTruncatedUnknown(int shown) {
    return 'Ireo singa $shown voalohany';
  }

  @override
  String get plQuality => 'Kalitao ho an\'ny singa rehetra';

  @override
  String get plQualityNote =>
      'Raha tsy manana io kalitao io ny singa iray, ny tsara indrindra ambaniny no raisina.';

  @override
  String get plItems => 'Singa';

  @override
  String plSelected(int selected, int total) {
    return '$selected amin\'ny $total voafidy';
  }

  @override
  String get plSelectAll => 'Fidio daholo';

  @override
  String get plSelectNone => 'Foano ny safidy rehetra';

  @override
  String get plUnavailable => 'Tsy misy';

  @override
  String plItemFallback(int index) {
    return 'Singa $index';
  }

  @override
  String plOwnFolder(String name) {
    return 'Ao anaty lahatahiry « $name »';
  }

  @override
  String plDownload(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sintony singa $count',
      one: 'Sintony singa 1',
      zero: 'Sintony',
    );
    return '$_temp0';
  }

  @override
  String get plPreparing => 'Manomana…';

  @override
  String plQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fisintonana $count nampidirina tao amin\'ny filaharana',
      one: 'Fisintonana 1 nampidirina tao amin\'ny filaharana',
    );
    return '$_temp0';
  }

  @override
  String get plQueueFull =>
      'Feno ny filaharana. Vitao na esory ny fisintonana sasany, dia andramo indray.';

  @override
  String get plFailed => 'Tsy voampy ny lisitra. Andramo indray.';

  @override
  String batchLead(int max) {
    return 'Apetaho rohy hatramin\'ny $max, iray isaky ny andalana. Dinihina tsirairay izy ireo, avy eo ampidirina ao amin\'ny filaharana.';
  }

  @override
  String get batchHint => 'https://…\nhttps://…';

  @override
  String get batchClear => 'Foano';

  @override
  String batchTruncated(int max) {
    return 'Ireo rohy $max voalohany ihany no tazonina.';
  }

  @override
  String get batchQuality => 'Kalitao ho an\'ny pejy horonan-tsary';

  @override
  String get batchQualityNote =>
      'Tazonina toy izao ny rakitra mivantana. Raha tsy manana io kalitao io ny pejy iray, ny tsara indrindra ambaniny no raisina.';

  @override
  String get batchLinks => 'Rohy';

  @override
  String batchValid(int valid, int total) {
    return '$valid manan-kery amin\'ny $total';
  }

  @override
  String get batchEmpty => 'Hiseho eto ireo rohy apetaka.';

  @override
  String get batchAnalyzing => 'Mandinika…';

  @override
  String get batchAdded => 'Nampidirina tao amin\'ny filaharana';

  @override
  String get batchFailed => 'Tsy nampidirina';

  @override
  String get batchIsPlaylist => 'Lisitra ity : ampiasao ny takelaka Lisitra';

  @override
  String get batchNeedsTools =>
      'Fitaovana media hapetraka : diniho aloha rohy iray irery';

  @override
  String get batchNoAudio => 'Rakitra tsy misy feo fotsiny';

  @override
  String get batchNoVideo => 'Rakitra tsy misy horonan-tsary';

  @override
  String batchStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sintony rohy $count',
      one: 'Sintony rohy 1',
      zero: 'Sintony',
    );
    return '$_temp0';
  }

  @override
  String get batchRunning => 'Mandinika ireo rohy…';

  @override
  String batchDone(int added, int failed) {
    return '$added nampidirina tao amin\'ny filaharana · $failed tsy nampidirina';
  }

  @override
  String get getSpeedLimitDesc => 'Zaraina amin\'ireo fisintonana mandeha.';

  @override
  String get getSpeedUnlimited => 'Tsy voafetra';

  @override
  String get getNoteSubs =>
      'Rakitra dikanteny iray isaky ny fiteny, voatahiry eo akaikin\'ny horonan-tsarinao. Raha tianao ho ao anatin\'ny horonan-tsary izy, alefaso ny Fikirana › Fisintonana › Sintony ny dikanteny.';

  @override
  String get crossfadeExclusive =>
      'Tsy azo atao miaraka amin\'ny fivoahan\'ny feo manokana.';

  @override
  String crossfadeSeconds(int s) {
    return '$s s';
  }

  @override
  String get videoSettings => 'Horonan-tsary';

  @override
  String get subtitleDelay => 'Fihemorana';

  @override
  String get subtitleSize => 'Habe';

  @override
  String get earlier => 'Aloha kokoa';

  @override
  String get later => 'Aoriana kokoa';

  @override
  String get smaller => 'Kely kokoa';

  @override
  String get larger => 'Lehibe kokoa';

  @override
  String get slower => 'Miadana kokoa';

  @override
  String get faster => 'Haingana kokoa';

  @override
  String get aspectRatio => 'Endriky ny sary';

  @override
  String get aspectAuto => 'Ho azy';

  @override
  String get cropSetting => 'Fanapahana';

  @override
  String get cropNone => 'Tsy misy';

  @override
  String get cropFill => 'Fenoy ny efijery';

  @override
  String get audioSync => 'Fampifanarahana ny feo';

  @override
  String get hwDecoding => 'Famadihana amin\'ny fitaovana';

  @override
  String get hwDecodingBody =>
      'Miverina ho azy amin\'ny rindrambaiko raha tsy mandeha.';

  @override
  String hwAuto(String decoder) {
    return 'Ho azy ($decoder)';
  }

  @override
  String get hwSoftware => 'Rindrambaiko';

  @override
  String get abLoop => 'Fiverimberenana A–B';

  @override
  String get abOff => 'Tsy alefa';

  @override
  String abFrom(String time) {
    return 'A amin\'ny $time';
  }

  @override
  String get abHintA =>
      'Tsindrio hametrahana ny A eo amin\'ny toerana misy anao.';

  @override
  String get abHintB =>
      'Tsindrio hametrahana ny B : miverimberina ny ampahany A–B.';

  @override
  String get abHintOff => 'Tsindrio hampijanonana ny fiverimberenana.';

  @override
  String get smartSection => 'Lisitra marani-tsaina';

  @override
  String get smartNewTitle => 'Lisitra marani-tsaina vaovao';

  @override
  String get smartEdit => 'Ovay ny fitsipika';

  @override
  String get smartText => 'Misy';

  @override
  String get smartTextHint => 'Lohateny, mpanakanto, rakikira…';

  @override
  String get smartAny => 'Daholo';

  @override
  String get smartFavorites => 'Tiako indrindra ihany';

  @override
  String get smartAdded => 'Nampidirina';

  @override
  String get smartAddedAny => 'Hatramin\'izay';

  @override
  String smartAddedDays(int n) {
    return '$n andro farany';
  }

  @override
  String get smartSort => 'Alaharo araka ny';

  @override
  String get smartLimit => 'Isan\'ny hira';

  @override
  String get smartLimitAll => 'Daholo';

  @override
  String smartLimitN(int n) {
    return 'Hira $n';
  }

  @override
  String smartCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Hira $n',
      one: 'Hira 1',
      zero: 'Tsy misy hira',
    );
    return '$_temp0 · havaozina ho azy';
  }

  @override
  String get smartReading => 'Mamaky ny tahiry…';

  @override
  String get smartEmptyTitle =>
      'Tsy misy hira mifanaraka amin\'ireo fitsipika ireo';

  @override
  String get smartEmptyBody =>
      'Hifeno ho azy ny lisitra rehefa manana hira mifanaraka aminy ny tahiry.';

  @override
  String get smartDeleteBody =>
      'Ny fitsipika ihany no voafafa : tsy misy rakitra kasihina.';

  @override
  String smartQueueAddAll(int n) {
    return 'Ampio daholo ireo $n';
  }

  @override
  String get addQueueOne => 'Ampio ao amin\'ny filaharana';

  @override
  String get toolsGroup => 'Fitaovana PC';

  @override
  String get navConvert => 'Hamadika';

  @override
  String get convLead =>
      'Fidio ny endrika na fitaovana, ampio ny rakitrao, avy eo atombohy. Mijanona ao amin\'ity solosaina ity ny zava-drehetra.';

  @override
  String get convRemove => 'Esory';

  @override
  String get convClear => 'Foano ny lisitra';

  @override
  String get convStart => 'Atombohy';

  @override
  String get convStop => 'Ajanony';

  @override
  String get catVideo => 'Horonan-tsary';

  @override
  String get catAudio => 'Feo';

  @override
  String get catImage => 'Sary';

  @override
  String get fmtHelpMp4 => 'H.264 + AAC, azo vakiana na aiza na aiza';

  @override
  String get fmtHelpMkv => 'Ny lalan-peo sy dikanteny rehetra';

  @override
  String get fmtHelpWebm => 'VP9 + Opus, ho an\'ny web';

  @override
  String get fmtHelpAvi => 'Mpamaky taloha sy TV';

  @override
  String get fmtHelpMov => 'Fanovana, fitaovana Apple';

  @override
  String get fmtHelpGif => 'Sary mihetsika fohy tsy misy feo';

  @override
  String get fmtHelpMp3 => 'Azo vakiana na aiza na aiza';

  @override
  String get fmtHelpM4a => 'AAC, fitaovana Apple';

  @override
  String get fmtHelpFlac => 'Tsy misy very';

  @override
  String get fmtHelpWav => 'Tsy voatery';

  @override
  String get fmtHelpOgg => 'Vorbis, endrika malalaka';

  @override
  String get fmtHelpOpus => 'Maivana be, feo olona sy mozika';

  @override
  String get fmtHelpPng => 'Tsy misy very, mangarahara';

  @override
  String get fmtHelpJpg => 'Sary, maivana';

  @override
  String get fmtHelpWebp => 'Web, maivana be';

  @override
  String get fmtHelpIco => 'Kisary Windows (256 px)';

  @override
  String get fmtHelpBmp => 'Tsy voatery';

  @override
  String get toolJoin => 'Atambatra';

  @override
  String get toolCut => 'Tapatapahina';

  @override
  String get toolCrop => 'Hetezina';

  @override
  String get toolCompress => 'Ahena ny habeny';

  @override
  String get toolFrames => 'Havoaka ho sary';

  @override
  String get toolExtract => 'Alaina avy amin\'ny horonan-tsary';

  @override
  String get toolResize => 'Ovay ny habeny';

  @override
  String get toolHelpJoinVideo =>
      'Horonan-tsary maromaro mifanohy, ho MP4 iray';

  @override
  String get toolHelpJoinAudio => 'Rakitra maromaro mifanohy, ho MP3 iray';

  @override
  String get toolHelpCut => 'Tazony ny ampahany iray, tsy averina amboarina';

  @override
  String get toolHelpCrop => 'Hetezina eo afovoany : 16:9, 4:3, 1:1, 9:16';

  @override
  String get toolHelpCompress =>
      'Rakitra maivana kokoa be, kalitao akaiky ny tany am-boalohany (AV1 na H.264)';

  @override
  String get toolHelpFrames => 'Sary JPG iray isaky ny segondra vitsivitsy';

  @override
  String get toolHelpExtract => 'Tazony ny feo, ho MP3';

  @override
  String get toolHelpResize => 'Ovay ny sakany, tazonina ny tahan\'ny endrika';

  @override
  String convTo(String format) {
    return 'Avadiho ho $format';
  }

  @override
  String get convNoFiles => 'Tsy misy rakitra. Ampio na tariho eto.';

  @override
  String get convAddFiles => 'Hanampy rakitra';

  @override
  String get convAddFolder => 'Hanampy lahatahiry';

  @override
  String convAddToList(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ampio ao amin\'ny lisitra ($n)',
      zero: 'Ampio ao amin\'ny lisitra',
    );
    return '$_temp0';
  }

  @override
  String get convJoinNeedsTwo => 'Ampio rakitra roa farafahakeliny hatambatra.';

  @override
  String get optQuality => 'Kalitao';

  @override
  String get optSource => 'Loharano';

  @override
  String get optHigh => 'Ambony';

  @override
  String get optMedium => 'Antonony';

  @override
  String get optSmall => 'Kely';

  @override
  String get optResolution => 'Fahamazavana';

  @override
  String get optBitrate => 'Tahan\'ny angona';

  @override
  String get optKeep => 'Tazony hatramin\'ny… ka hatramin\'ny…';

  @override
  String get optKeepHint => 'hh:mm:ss ; fiafarana foana = hatramin\'ny farany';

  @override
  String get optCrop => 'Endrika';

  @override
  String get optEvery => 'Sary iray isaky ny';

  @override
  String get optWidth => 'Sakany';

  @override
  String get optOutDir => 'Lahatahiry fivoahana';

  @override
  String optSeconds(int n) {
    return '$n s';
  }

  @override
  String get colPreview => 'Topimaso';

  @override
  String colSource(int n) {
    return 'Loharano · $n';
  }

  @override
  String get colOutput => 'Vokatra / toetra';

  @override
  String get stWaiting => 'Miandry';

  @override
  String get stConverting => 'Mamadika…';

  @override
  String get stDone => 'Vita';

  @override
  String get stStopped => 'Najanona';

  @override
  String get stFailed => 'Tsy nahomby';

  @override
  String convLineFormat(String quality) {
    return 'Famadihana · kalitao $quality';
  }

  @override
  String get convLineSame => 'Famadihana · kalitao mitovy amin\'ny loharano';

  @override
  String convFiles(int n) {
    return 'Rakitra $n';
  }

  @override
  String get convEmptyTitle => 'Foana ny lisitra';

  @override
  String get convEmptyBody =>
      'Fidio ny endrika eo ankavia, na tariho eto ny rakitra.';

  @override
  String get convDropHint =>
      'Tariho eto ny rakitra hampidirina miaraka amin\'ny endrika farany nofidina';

  @override
  String get convDropNoChoice =>
      'Fidio aloha ny endrika na fitaovana eo ankavia.';

  @override
  String get convMulti => 'Famadihana maromaro';

  @override
  String get convElapsed => 'Fotoana lany';

  @override
  String get convShutdown => 'Vonoy ny PC rehefa vita';

  @override
  String get convNotify => 'Ampandrenesina';

  @override
  String get convDone => 'Vita ny famadihana';

  @override
  String get convOpenFolder => 'Sokafy ny lahatahiry';

  @override
  String convRemoveRunning(String name) {
    return 'Eo am-pamadihana « $name ». Ny fanesorana azy dia mampijanona ny famadihana.';
  }

  @override
  String get convShutdownTitle => 'Hovonoina ny PC';

  @override
  String get convShutdownBody =>
      'Vita ny famadihana. Hovonoin\'i Windows afaka iray minitra ny PC.';

  @override
  String get convShutdownCancel => 'Foano ny famonoana';

  @override
  String get convToolsMissing =>
      'Tsy voapetraka ny fitaovana media : diniho rohy iray ao amin\'ny Haka hametrahana azy.';

  @override
  String convFailed(String reason) {
    return 'Tsy azo ampidirina : $reason';
  }

  @override
  String get capTab => 'Sary efijery';

  @override
  String get capIntroTitle => 'Maka sary avy amin\'ny rindranasa rehetra';

  @override
  String get capIntroBody =>
      'Mandeha ireo hitsin-dalana na dia ahena aza i Miarina Media.';

  @override
  String get capTry => 'Andramo';

  @override
  String get capRegion => 'Maka sarin\'ny faritra iray';

  @override
  String get capRegionDesc =>
      'Manamaizina ny efijery ; sorito ny faritra hotazonina.';

  @override
  String get capFull => 'Maka sarin\'ny efijery manontolo';

  @override
  String get capFullDesc => 'Sary avy hatrany amin\'ny efijery misy ny totozy.';

  @override
  String get capRecord => 'Atombohy / ajanony ny fandraketana horonan-tsary';

  @override
  String get capRecordDesc =>
      'Mampiasa ny fikirana farany an\'ny mpandrakitra.';

  @override
  String get capEdit => 'Ovay';

  @override
  String get capCancel => 'Foano';

  @override
  String get capListening => 'Tsindrio ny fitambaran\'ny fanalahidy…';

  @override
  String get capNoKey => 'Tsy misy';

  @override
  String get capFormat => 'Endriky ny sary';

  @override
  String get capFormatDesc =>
      'Mitazona ny antsipiriany rehetra ny PNG ; maivana kokoa ny JPG sy WebP.';

  @override
  String get capDelay => 'Fanemorana';

  @override
  String get capDelayDesc => 'Fotoana hanokafana menio alohan\'ny haka sary.';

  @override
  String get capDelayNone => 'Tsy misy';

  @override
  String capDelaySecs(int n) {
    return '$n s';
  }

  @override
  String get capSaveTo => 'Tehirizina ao amin\'ny';

  @override
  String get capOpenFolder => 'Sokafy ny lahatahiry';

  @override
  String get capCopySetting => 'Adikao ao amin\'ny fitahirizana vonjimaika';

  @override
  String get capCopySettingDesc => 'Hametahana avy hatrany amin\'ny Ctrl V.';

  @override
  String get capPreview => 'Asehoy ny topimaso';

  @override
  String get capPreviewDesc =>
      'Misy sary kely miseho eo ambany ankavanana mandritra ny 4 segondra.';

  @override
  String get capSound => 'Feon\'ny fakana sary';

  @override
  String get capCursor => 'Ampidiro ny tondro';

  @override
  String get capNeedModifier =>
      'Ilaina ny Ctrl, Alt na Maj miaraka amin\'ny fanalahidy hafa.';

  @override
  String get capKeyUnsupported =>
      'Tsy azo atao hitsin-dalana ankapobeny ity fanalahidy ity.';

  @override
  String capConflict(String keys, String action) {
    return 'Efa ampiasaina ho an\'ny « $action » ny $keys.';
  }

  @override
  String capTaken(String keys) {
    return 'Efa nalain\'ny rindranasa hafa ny $keys.';
  }

  @override
  String get capTakenShort => 'Nalain\'ny rindranasa hafa';

  @override
  String get capHelp => 'Tariho hifidianana faritra iray';

  @override
  String get capHelpEnter => 'haka sary';

  @override
  String get capHelpEsc => 'hanafoana';

  @override
  String get capKeyEnter => 'Entrée';

  @override
  String get capKeyEsc => 'Échap';

  @override
  String get capWholeScreen => 'Efijery manontolo';

  @override
  String get capFilm => 'Raketo';

  @override
  String get capCopy => 'Adikao';

  @override
  String get capSave => 'Tehirizo';

  @override
  String get capClose => 'Hidio';

  @override
  String get capCopied => 'Voadika ao amin\'ny fitahirizana vonjimaika ny sary';

  @override
  String get capOpen => 'Sokafy';

  @override
  String get capFailed => 'Tsy vita ny fakana sary.';

  @override
  String capPngFallback(String name) {
    return '$name (tsy misy JPG/WebP : voatahiry ho PNG)';
  }

  @override
  String get recNav => 'Raketo ny efijery';

  @override
  String get recSubtitle =>
      'Raketo ny efijerinao miaraka amin\'ny feon\'ny PC sy ny mikrô. Tonga ao amin\'ny tahiry ny horonan-tsary.';

  @override
  String get recSourceTitle => 'Loharano';

  @override
  String get recScreen => 'Efijery feno';

  @override
  String recScreenDesc(int n, int w, int h) {
    return 'Efijery $n · $w × $h. Fidio ny efijery raha maro no anananao.';
  }

  @override
  String recScreenN(int n) {
    return 'Efijery $n';
  }

  @override
  String get recWindow => 'Varavarankely iray';

  @override
  String get recWindowDesc => 'Ny varavarankely nofidina ihany no voarakitra.';

  @override
  String get recPickWindow => 'Fidio ny varavarankely';

  @override
  String get recNoWindows => 'Tsy misy varavarankely azo raketina.';

  @override
  String get recRegion => 'Faritra iray';

  @override
  String get recRegionDesc =>
      'Sorito amin\'ny efijery ny efamira alohan\'ny hanombohana.';

  @override
  String recRegionSize(int w, int h) {
    return 'Faritra $w × $h';
  }

  @override
  String get recDraw => 'Sorito ny faritra';

  @override
  String get recVideo => 'Horonan-tsary';

  @override
  String get recFormat => 'Endrika';

  @override
  String get recFps => 'Sary isan-tsegondra';

  @override
  String get recQuality => 'Kalitao';

  @override
  String get recQMedium => 'Antonony';

  @override
  String get recQHigh => 'Ambony';

  @override
  String get recQOriginal => 'Tany am-boalohany';

  @override
  String get recFolder => 'Lahatahiry';

  @override
  String get recSoundOptions => 'Feo sy safidy';

  @override
  String get recSystemAudio => 'Feon\'ny PC';

  @override
  String get recSystemAudioDesc => 'Izay renao amin\'ny fanamafisam-peo';

  @override
  String get recMic => 'Mikrô';

  @override
  String get recMicDesc => 'Mikrô tsotran\'i Windows';

  @override
  String get recCursor => 'Asehoy ny tondro';

  @override
  String get recCursorDesc =>
      'Miseho ao amin\'ny horonan-tsary ny tondron\'ny totozy';

  @override
  String get recCountdown => 'Fanisana mihemotra';

  @override
  String get recCountdownDesc => '3 segondra alohan\'ny hanombohana';

  @override
  String get recStart => 'Atombohy ny fandraketana';

  @override
  String recStopAt(String time) {
    return 'Ajanony · $time';
  }

  @override
  String get recOrPress => 'na tsindrio ny';

  @override
  String get recAnywhere => 'na aiza na aiza';

  @override
  String get recFpsUnit => 's/s';

  @override
  String get recSumSystem => 'feon\'ny PC';

  @override
  String get recSumNoSystem => 'tsy misy feon\'ny PC';

  @override
  String get recSumMic => 'mikrô';

  @override
  String get recSumNoSound => 'tsy misy feo';

  @override
  String get recRecent => 'Fandraketana vao haingana';

  @override
  String get recEmpty => 'Mbola tsy misy fandraketana.';

  @override
  String get recSaved => 'Voatahiry';

  @override
  String get recMissing => 'Tsy hita ny rakitra';

  @override
  String get recPlay => 'Alefa';

  @override
  String get recConvert => 'Avadiho';

  @override
  String get recShowFolder => 'Asehoy ao amin\'ny lahatahiry';

  @override
  String get recRemove => 'Esory ao amin\'ny lisitra';

  @override
  String get recRec => 'REC';

  @override
  String get recPausedLabel => 'MIJANONA';

  @override
  String get recPause => 'Ijanona';

  @override
  String get recResume => 'Tohizo';

  @override
  String get recMicMute => 'Vonoy ny mikrô';

  @override
  String get recMicUnmute => 'Alefaso ny mikrô';

  @override
  String get recStop => 'Ajanony';

  @override
  String get recFinalizing => 'Famaranana…';

  @override
  String get recStarting => 'Manomboka afaka';

  @override
  String get recSavedToast => 'Voatahiry ao amin\'ny tahiry ny horonan-tsary';

  @override
  String get recGifSaved => 'Voatahiry ny GIF';

  @override
  String get recFailed => 'Tsy nanomboka ny fandraketana.';

  @override
  String get recFinishFailed =>
      'Tsy vita ny famaranana ny horonan-tsary ; mijanona ao amin\'ny lahatahiry ireo ampahany.';

  @override
  String get recWindowGone =>
      'Tsy misokatra intsony ny varavarankely nofidina.';

  @override
  String get recNoScreen => 'Tsy nahitana efijery.';

  @override
  String get recFileWord => 'Fandraketana';

  @override
  String get recConvertPick =>
      'Fidio ny endrika na fitaovana : hampidirina ny rakitra.';

  @override
  String get toolRecord => 'Raketo ny efijery';

  @override
  String get toolHelpRecord =>
      'Raketo ny efijery, varavarankely iray na faritra iray.';

  @override
  String get videoGestures => 'Fihetsika amin\'ny horonan-tsary';

  @override
  String get videoGesturesBody =>
      'Tariho eo ankavia : hazavana ; eo ankavanana : feo. Tsindrio indroa ny sisiny : ±10 s. Tsongoina : fenoy ny efijery.';

  @override
  String get gestBrightness => 'Hazavana';

  @override
  String get gestVolume => 'Feo';

  @override
  String gestJump(String sign, int n) {
    return '$sign$n s';
  }

  @override
  String get lockControls => 'Hidio ny efijery';

  @override
  String get unlockControls => 'Sokafy';

  @override
  String get pipEnter => 'Sary ao anaty sary';

  @override
  String get rotateScreen => 'Ahodino ny efijery';

  @override
  String get fillScreen => 'Fenoy ny efijery';

  @override
  String get fitScreen => 'Sary feno';

  @override
  String playlistExportAndroid(String path) {
    return 'Navoaka tao amin\'ny $path';
  }

  @override
  String videoTracksN(int n) {
    return 'Lalan-peo $n';
  }

  @override
  String videoSubsN(int n) {
    return 'Dikanteny $n';
  }

  @override
  String get listenOnly => 'Henoina fotsiny';

  @override
  String get showVideo => 'Jereo indray ny horonan-tsary';

  @override
  String get tourWelcomeTitle => 'Tongasoa eto amin\'ny Miarina Media';

  @override
  String get tourWelcomeBody =>
      'Fitetezana haingana ireo toerana lehibe. Azonao dinganina izy ary jerena indray any aoriana ao amin\'ny Fikirana › Ankapobeny.';

  @override
  String get tourSpaceTitle => 'Toerana roa';

  @override
  String get tourSpaceBody =>
      'Haka hisintonana horonan-tsary sy mozika, Hihaino ho an\'ny tahirinao. Mifamadika eto ianao.';

  @override
  String get tourLinkTitle => 'Apetaho rohy';

  @override
  String get tourLinkBody =>
      'Apetaho ny adiresin\'ny horonan-tsary na lisitra iray : dinihin\'ny Miarina Media ary atolony anao ireo endrika sy kalitao.';

  @override
  String get tourToolsTitle => 'Fitaovana PC';

  @override
  String get tourToolsBody =>
      'Raketo ny efijery ary avadiho ny rakitrao (MP4, MP3, 3GP…). Ao amin\'ny Fikirana no amboarina ny sary efijery.';

  @override
  String get tourLibraryTitle => 'Ny tahirinao';

  @override
  String get tourLibraryBody =>
      'Mozika, sarimihetsika sy andian-tantara, Focus ho an\'ny podcast sy lesona : tonga eto daholo izay sintoninao na ampidirinao.';

  @override
  String get tourSearchTitle => 'Hitady';

  @override
  String get tourSearchBody =>
      'Hira, rakikira, sarimihetsika ary podcast, avy amin\'ny efijery rehetra. Hitsin-dalana : Ctrl K.';

  @override
  String get tourPlaybarTitle => 'Fandefasana';

  @override
  String get tourPlaybarBody =>
      'Izay mandeha : ijanona, hira manaraka, feo. Tsindrio ny fonony hanokafana ny mpamaky feno.';

  @override
  String get tourSettingsTitle => 'Fikirana';

  @override
  String get tourSettingsBody =>
      'Loko sy fiteny, lahatahiry fisintonana, hitsin-dalana, sary efijery ary fanavaozana.';

  @override
  String get tourSkip => 'Dinganina ny fitetezana';

  @override
  String get tourBack => 'Teo aloha';

  @override
  String get tourNext => 'Manaraka';

  @override
  String get tourDone => 'Vita';

  @override
  String get tourReplay => 'Fitetezana voatarika';

  @override
  String get tourReplayBody =>
      'Jereo indray ny fanazavana ireo efijery lehibe.';

  @override
  String get tourStart => 'Atombohy';

  @override
  String get fmtHelp3gp => 'Finday taloha, rakitra maivana';

  @override
  String get optCodec => 'Codec';

  @override
  String get optCodecAv1 => 'AV1';

  @override
  String get optCodecH264 => 'H.264';

  @override
  String get optCodecAv1Note =>
      'Maivana 20 hatramin\'ny 35 % amin\'ny kalitao mitovy. Azo vakiana amin\'ny Windows 10 sy 11, Android 10 no mihoatra, ireo mpitety vaovao ary Miarina Media. Maharitra kokoa ny famadihana (eo ho eo amin\'ny antsasaky ny faharetan\'ny horonan-tsary).';

  @override
  String get optCodecH264Note =>
      'Azo vakiana amin\'ny fitaovana rehetra, na dia taloha aza. Lehibe kokoa noho ny AV1 amin\'ny kalitao mitovy.';

  @override
  String get optGoal => 'Tanjona';

  @override
  String get optGoalQuality => 'Kalitao';

  @override
  String get optGoalSize => 'Habe ambony indrindra';

  @override
  String get optBalanced => 'Voalanjalanja';

  @override
  String get optTargetMb => 'Habe ambony isaky ny rakitra';

  @override
  String get optMb => 'Mo';

  @override
  String get deviceBannerTitle =>
      'Mbola tsy aseho ny hira ato amin\'ity finday ity';

  @override
  String get deviceBannerAllow => 'Omeo alalana';

  @override
  String get share => 'Zarao';

  @override
  String get shareFailed => 'Tsy azo zaraina ity rakitra ity';

  @override
  String get deleteFromPhone => 'Fafao ao amin\'ny finday';

  @override
  String get deleteFailed => 'Tsy voafafa ilay rakitra';

  @override
  String deletedFromPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rakitra $count voafafa ao amin\'ny finday',
      one: 'Voafafa ao amin\'ny finday',
    );
    return '$_temp0';
  }

  @override
  String get on => 'Alefa';

  @override
  String get skipBack10 => 'Hiverina 10 segondra';

  @override
  String get skipForward10 => 'Handroso 10 segondra';

  @override
  String get showVinyl => 'Asehoy ho kapila';

  @override
  String get viewAlbum => 'Jereo ny rakikira';

  @override
  String get viewArtist => 'Jereo ny mpanakanto';

  @override
  String get trackInfo => 'Momba ilay hira';

  @override
  String get trackPlays => 'Fihainoana';

  @override
  String get trackFile => 'Rakitra';

  @override
  String get playbackSpeed => 'Hafainganam-pamakiana';

  @override
  String get quickRecent => 'Vao haino';

  @override
  String get quickMostPlayed => 'Matetika haino';

  @override
  String get dailyMix => 'Fifangaroana androany';

  @override
  String get recentlyPlayed => 'Vao nohenoina';

  @override
  String get recentlyAddedAlbums => 'Vao nampidirina';

  @override
  String get mostPlayedTitle => 'Matetika henoina';

  @override
  String get yourArtists => 'Ireo mpanakantonao';

  @override
  String get counterNever => 'Mbola tsy nohenoina';

  @override
  String get counterAdded => 'Vao nampidirina';

  @override
  String get discoverTitle => 'Hojerena';

  @override
  String discoverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hira $count mbola tsy nohenoina',
      one: 'Hira 1 mbola tsy nohenoina',
    );
    return '$_temp0';
  }

  @override
  String get shufflePlay => 'Vakio kisendrasendra';

  @override
  String get randomAlbum => 'Rakikira kisendrasendra';

  @override
  String get artistOfWeek => 'Mpanakanton\'ny herinandro';

  @override
  String get last7Days => 'Andro 7 farany';

  @override
  String get shuffleAll => 'Afangaro daholo';

  @override
  String get addAllToQueue => 'Ampidiro daholo amin\'ny filaharana';

  @override
  String get noListenYet =>
      'Mihainoa mozika dia hiseho eto ny fotoana nihainoanao.';

  @override
  String minutesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'minitra $count',
      one: 'minitra 1',
    );
    return '$_temp0';
  }
}

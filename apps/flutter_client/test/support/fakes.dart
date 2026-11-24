import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/browser/browser_data.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/playlists/playlists_data.dart';
import 'package:miarina_media/features/search/search_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/cinema.dart';
import 'package:miarina_media/src/rust/api/focus.dart';
import 'package:miarina_media/src/rust/api/indexer.dart';
import 'package:miarina_media/src/rust/api/library.dart';
import 'package:miarina_media/src/rust/api/playlists.dart';
import 'package:miarina_media/src/rust/api/search.dart';

class FakePlaybackStore implements PlaybackStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(Map<String, String?> changes) async {
    for (final e in changes.entries) {
      final v = e.value;
      v == null ? values.remove(e.key) : values[e.key] = v;
    }
  }
}

class FakeSettingsStore implements SettingsStore {
  final values = <String, Object?>{};

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

class FakeEngine implements MediaEngine {
  final opened = <MediaSource>[];
  final starts = <Duration?>[];
  final seeks = <Duration>[];
  final _controller = StreamController<PlaybackSnapshot>.broadcast();
  PlaybackSnapshot _state = const PlaybackSnapshot();
  RepeatSetting engineRepeat = RepeatSetting.off;

  void emit(PlaybackSnapshot s) {
    _state = s;
    _controller.add(s);
  }

  @override
  final EngineCapabilities capabilities = const EngineCapabilities(
    video: true,
    speed: true,
    audioTrackSelection: true,
    embeddedSubtitles: true,
    externalSubtitles: true,
    assSubtitles: false,
    chapters: false,
    equalizer: true,
    backgroundPlayback: true,
    audioOutputs: true,
    exclusiveAudio: true,
    sidecarSubtitles: true,
    subtitleLanguage: true,
    frameStep: true,
  );

  @override
  PlaybackSnapshot get current => _state;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> open(
    MediaSource media, {
    bool autoplay = true,
    Duration? startAt,
  }) async {
    opened.add(media);
    starts.add(startAt);
    emit(
      PlaybackSnapshot(
        status: PlaybackStatus.playing,
        source: media,
        duration: const Duration(minutes: 4),
        position: startAt ?? Duration.zero,
        // Like libmpv and Media3, the speed carries over to the next file.
        speed: _state.speed,
      ),
    );
  }

  @override
  Future<void> play() async =>
      emit(_state.copyWith(status: PlaybackStatus.playing));

  @override
  Future<void> pause() async =>
      emit(_state.copyWith(status: PlaybackStatus.paused));

  @override
  Future<void> stop() async => emit(const PlaybackSnapshot());

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    emit(_state.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double value) async =>
      emit(_state.copyWith(volume: value));

  @override
  Future<void> setSpeed(double value) async =>
      emit(_state.copyWith(speed: value));

  @override
  Future<void> setRepeatMode(RepeatSetting mode) async => engineRepeat = mode;

  final audioSelections = <String>[];
  final subtitleSelections = <String?>[];

  @override
  Future<void> selectAudioTrack(String trackId) async {
    audioSelections.add(trackId);
    emit(_state.copyWith(selectedAudio: trackId));
  }

  @override
  Future<void> selectSubtitleTrack(String? trackId) async {
    subtitleSelections.add(trackId);
    emit(_state.copyWith(selectedSubtitle: trackId));
  }

  @override
  Future<void> loadExternalSubtitle(Uri uri) async {}

  @override
  Future<void> setSubtitleEnabled(bool enabled) async {}

  List<double>? equalizer;
  bool equalizerSupported = true;

  @override
  Future<bool?> setEqualizer(List<double>? gainsDb) async {
    equalizer = gainsDb;
    return equalizerSupported;
  }

  EnginePreferences? preferences;
  List<AudioOutput> outputs = const [
    AudioOutput(id: 'auto', label: ''),
    AudioOutput(id: 'wasapi/dac', label: 'DAC USB'),
  ];

  @override
  Future<List<AudioOutput>> audioOutputs() async => outputs;

  int frameSteps = 0;

  @override
  Future<void> frameStep() async => frameSteps++;

  @override
  Future<void> applyPreferences(EnginePreferences p) async => preferences = p;

  @override
  Widget buildVideoView({BoxFit fit = BoxFit.contain}) => const SizedBox();

  @override
  Future<void> dispose() async => _controller.close();
}

LibraryItem track(
  int id,
  String title, {
  String? artist,
  String? album,
  int? trackNo,
  bool missing = false,
  bool favorite = false,
  int plays = 0,
  String format = 'FLAC',
}) => LibraryItem(
  id: id,
  title: title,
  path: 'C:/Musique/$title.flac',
  isVideo: false,
  durationSecs: 245,
  artist: artist,
  album: album ?? 'Album $id',
  format: format,
  missing: missing,
  favorite: favorite,
  plays: plays,
  trackNo: trackNo,
);

/// Same rules as the core: albums grouped by name (case-insensitive) with
/// their album artist; artists with their number of albums.
class FakeLibraryApi implements LibraryApi {
  FakeLibraryApi(this.items);

  final List<LibraryItem> items;
  final favoriteCalls = <(int, bool)>[];

  /// Ids counted as added since any date asked ("Ajoutés ce mois").
  Set<int> addedRecently = {};

  /// Ids never played, and beyond CD quality, for the quick filters.
  Set<int> played = {};
  Set<int> hiResIds = {};
  final notedPlays = <int>[];

  @override
  Future<void> notePlayed(int mediaId) async => notedPlays.add(mediaId);

  /// Sorts asked, in order.
  final sorts = <(TrackSort, bool)>[];

  @override
  Future<LibraryPage> tracks({
    required String search,
    required bool favoritesOnly,
    required int offset,
    required int limit,
    String? album,
    String? artist,
    bool recent = false,
    TrackSort sort = TrackSort.title,
    bool reverse = false,
    DateTime? addedSince,
    bool neverPlayed = false,
    bool hiRes = false,
  }) async {
    bool same(String? a, String? b) => a?.toLowerCase() == b?.toLowerCase();
    if (offset == 0) sorts.add((sort, reverse));
    var list = items
        .where((i) => !favoritesOnly || i.favorite)
        .where((i) => album == null || same(i.album, album))
        .where((i) => artist == null || same(i.artist, artist))
        .where((i) => addedSince == null || addedRecently.contains(i.id))
        .where((i) => !neverPlayed || !played.contains(i.id))
        .where((i) => !hiRes || hiResIds.contains(i.id))
        .toList();
    if (search.isNotEmpty) {
      list = list
          .where((i) => i.title.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    if (album != null) {
      list.sort((a, b) => (a.trackNo ?? 9999).compareTo(b.trackNo ?? 9999));
    } else if (recent) {
      // Newest first: higher ids were added later in these fixtures.
      list.sort((a, b) => b.id.compareTo(a.id));
    } else if (sort != TrackSort.title || reverse) {
      int by(LibraryItem a, LibraryItem b) => switch (sort) {
        TrackSort.artist => (a.artist ?? '~').compareTo(b.artist ?? '~'),
        TrackSort.album => (a.album ?? '~').compareTo(b.album ?? '~'),
        TrackSort.format => (a.format ?? '~').compareTo(b.format ?? '~'),
        TrackSort.duration => (b.durationSecs ?? -1).compareTo(
          a.durationSecs ?? -1,
        ),
        TrackSort.added => b.id.compareTo(a.id),
        TrackSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
      };
      list.sort(reverse ? (a, b) => by(b, a) : by);
    }
    final page = list.skip(offset).take(limit).toList();
    return LibraryPage(items: page, total: BigInt.from(list.length));
  }

  @override
  Future<LibraryItem?> itemByPath(String path) async =>
      items.where((i) => i.path == path).firstOrNull;

  @override
  Future<LibraryItem?> item(int id) async =>
      items.where((i) => i.id == id).firstOrNull;

  @override
  Future<List<LibraryGroup>> groups(GroupKind kind) async {
    final by = <String, List<LibraryItem>>{};
    for (final i in items) {
      final key = kind == GroupKind.album ? i.album : i.artist;
      if (key != null && !i.missing) (by[key.toLowerCase()] ??= []).add(i);
    }
    final keys = by.keys.toList()..sort();
    return [
      for (final k in keys)
        LibraryGroup(
          name: kind == GroupKind.album
              ? by[k]!.first.album!
              : by[k]!.first.artist!,
          detail: kind == GroupKind.album
              ? by[k]!.first.artist
              : '${by[k]!.map((i) => i.album).toSet().length}',
          count: BigInt.from(by[k]!.length),
          durationSecs: by[k]!.fold(0.0, (t, i) => t + (i.durationSecs ?? 0)),
          year: null,
          thumbnail: null,
          // Higher ids were added later in these fixtures.
          addedAt: by[k]!.map((i) => i.id).reduce((a, b) => a > b ? a : b),
          plays: BigInt.from(by[k]!.fold<int>(0, (n, i) => n + i.plays)),
          sizeBytes: BigInt.from(by[k]!.length * 1000000),
          lossless: by[k]!.any((i) => i.format?.startsWith('FLAC') ?? false),
          downloaded: downloadedGroups.contains(k),
          compilation: compilations.contains(k),
        ),
    ];
  }

  /// Group names (lower case) marked downloaded / compilation.
  Set<String> downloadedGroups = {};
  Set<String> compilations = {};

  @override
  Future<void> setFavorite(int mediaId, {required bool favorite}) async {
    favoriteCalls.add((mediaId, favorite));
    // Applied, as the core does.
    final i = items.indexWhere((e) => e.id == mediaId);
    if (i >= 0) items[i] = items[i].withFavorite(favorite);
  }

  final addedFiles = <String>[];

  @override
  Future<int> addFile(String path, {required bool isVideo}) async {
    addedFiles.add(path);
    final id = 1000 + addedFiles.length;
    items.add(
      LibraryItem(
        id: id,
        title: path.split(RegExp(r'[\\/]')).last.split('.').first,
        path: path,
        isVideo: isVideo,
        missing: false,
        favorite: false,
        plays: 0,
      ),
    );
    return id;
  }

  @override
  Future<LibrarySummary> summary() async => LibrarySummary(
    schemaVersion: 9,
    total: BigInt.from(items.length),
    audioCount: BigInt.from(items.length),
    videoCount: BigInt.zero,
    items: const [],
  );
}

CinemaItem video(
  int id,
  String title, {
  CinemaKind kind = CinemaKind.film,
  String? series,
  int? season,
  int? episode,
  String? episodeTitle,
  double minutes = 50,
  bool missing = false,
  List<String> subtitles = const [],
}) => CinemaItem(
  item: LibraryItem(
    id: id,
    title: title,
    path: 'D:/Vidéos/$title.mkv',
    isVideo: true,
    durationSecs: minutes * 60,
    format: 'MKV',
    missing: missing,
    favorite: false,
    plays: 0,
  ),
  kind: kind,
  series: series,
  season: season,
  episode: episode,
  episodeTitle: episodeTitle,
  addedAt: id,
  subtitleLanguages: subtitles,
);

/// Cinema library built from a list of classified videos, like the core.
class FakeCinemaApi implements CinemaApi {
  FakeCinemaApi(this.videos);

  final List<CinemaItem> videos;

  List<CinemaItem> _episodes(String name) =>
      videos
          .where(
            (v) =>
                v.kind == CinemaKind.episode &&
                v.series?.toLowerCase() == name.toLowerCase(),
          )
          .toList()
        ..sort(
          (a, b) => (a.season! * 1000 + a.episode!).compareTo(
            b.season! * 1000 + b.episode!,
          ),
        );

  @override
  Future<CinemaLibrary> library() async {
    final names = {
      for (final v in videos)
        if (v.kind == CinemaKind.episode) v.series!,
    }.toList()..sort();
    return CinemaLibrary(
      films: videos.where((v) => v.kind == CinemaKind.film).toList(),
      series: [
        for (final n in names)
          SeriesSummary(
            name: n,
            seasons: _episodes(n).map((e) => e.season).toSet().length,
            episodes: _episodes(n).length,
            latestAdded: 0,
          ),
      ],
      personal: videos.where((v) => v.kind == CinemaKind.personal).toList(),
    );
  }

  @override
  Future<SeriesDetail?> series(String name) async {
    final eps = _episodes(name);
    if (eps.isEmpty) return null;
    return SeriesDetail(
      name: eps.first.series!,
      episodes: eps,
      subtitleLanguages: const ['FR', 'EN'],
      subtitleFormats: const ['SRT'],
      videoLabel: '1080p HEVC',
    );
  }

  @override
  Future<CinemaItem?> item(int id) async =>
      videos.where((v) => v.item.id == id).firstOrNull;
}

FocusItem lesson(
  int id,
  String title, {
  FocusKind kind = FocusKind.course,
  String program = 'Architecture des systèmes',
  int number = 1,
  int of = 1,
  double minutes = 84,
}) => FocusItem(
  item: LibraryItem(
    id: id,
    title: title,
    path: 'D:/Cours/$program/$title.mp3',
    isVideo: false,
    durationSecs: minutes * 60,
    format: 'MP3',
    missing: false,
    favorite: false,
    plays: 0,
  ),
  kind: kind,
  program: program,
  number: number,
  of: of,
  addedAt: id,
);

/// Focus library built from classified items, like the core.
class FakeFocusApi implements FocusApi {
  FakeFocusApi([this.items = const []]);

  final List<FocusItem> items;

  @override
  Future<FocusLibrary> library() async {
    final names = <String, FocusItem>{};
    for (final f in items) {
      names.putIfAbsent(f.program, () => f);
    }
    final sorted = names.keys.toList()..sort();
    int count(FocusKind k) => sorted.where((n) => names[n]!.kind == k).length;
    return FocusLibrary(
      programs: [
        for (final n in sorted)
          FocusProgram(
            name: n,
            kind: names[n]!.kind,
            artist: 'Pr. Andry',
            count: items.where((f) => f.program == n).length,
            durationSecs: items
                .where((f) => f.program == n)
                .fold(0.0, (t, f) => t + (f.item.durationSecs ?? 0)),
            latestAdded: 0,
          ),
      ],
      podcastCount: count(FocusKind.podcast),
      courseCount: count(FocusKind.course),
      audiobookCount: count(FocusKind.audiobook),
      durationSecs: items.fold(0.0, (t, f) => t + (f.item.durationSecs ?? 0)),
    );
  }

  @override
  Future<List<FocusItem>> program(String name) async =>
      items.where((f) => f.program.toLowerCase() == name.toLowerCase()).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  @override
  Future<FocusItem?> entry(int id) async =>
      items.where((f) => f.item.id == id).firstOrNull;
}

/// Search over fixed hits with the core's rule (every word starts a word).
class FakeSearchApi implements SearchApi {
  FakeSearchApi(this.hits);

  final List<SearchHit> hits;

  @override
  Future<SearchResults> search(String query, {int limit = 200}) async {
    final found = [
      for (final h in hits)
        if (matchesWords(h.item.title, query)) h,
    ];
    return SearchResults(
      hits: found.take(limit).toList(),
      total: BigInt.from(found.length),
    );
  }
}

/// Playlists in memory, same rules as the core (order kept, duplicates
/// allowed, removing never touches the library).
class FakePlaylistApi implements PlaylistApi {
  FakePlaylistApi(this.library);

  final List<LibraryItem> library;
  final names = <int, String>{};
  final entries = <int, List<int>>{};
  var _next = 1;

  int seed(String name, List<int> ids) {
    final id = _next++;
    names[id] = name;
    entries[id] = [...ids];
    return id;
  }

  LibraryItem _item(int id) => library.firstWhere((i) => i.id == id);

  PlaylistInfo _info(int id) {
    final items = entries[id]!.map(_item).toList();
    return PlaylistInfo(
      id: id,
      name: names[id]!,
      count: items.length,
      durationSecs: items.fold(0.0, (t, i) => t + (i.durationSecs ?? 0)),
      covers: const [],
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<PlaylistInfo>> list() async => [
    for (final id in names.keys) _info(id),
  ];

  @override
  Future<PlaylistDetail?> get(int id) async => names.containsKey(id)
      ? PlaylistDetail(info: _info(id), items: entries[id]!.map(_item).toList())
      : null;

  @override
  Future<PlaylistInfo> create(String name, List<int> mediaIds) async =>
      _info(seed(name, mediaIds));

  @override
  Future<void> rename(int id, String name) async => names[id] = name;

  @override
  Future<void> delete(int id) async {
    names.remove(id);
    entries.remove(id);
  }

  @override
  Future<void> add(int id, List<int> mediaIds) async =>
      entries[id]!.addAll(mediaIds);

  @override
  Future<void> remove(int id, int index) async => entries[id]!.removeAt(index);

  @override
  Future<void> move(int id, int from, int to) async {
    final list = entries[id]!;
    list.insert(to, list.removeAt(from));
  }

  @override
  Future<ImportReport> importM3u(String path) async =>
      throw UnimplementedError('file dialogs are not used in widget tests');

  @override
  Future<void> exportM3u(int id, String path) async {}
}

/// Indexing without the core: folders hold [files] media each; a scan adds
/// them all, and the worker is instantly done.
class FakeIndexerApi implements IndexerApi {
  FakeIndexerApi({this.files = const {}});

  final Map<String, int> files;
  final scanned = <List<String>>[];
  var focusFolders = <String>[];
  var _total = 0;
  var _generation = BigInt.zero;

  @override
  Future<void> start() async {}

  final _indexed = <String>{};

  /// Like the core, a folder scanned again adds nothing new.
  @override
  Future<ScanTotals> scan(List<String> folders) async {
    scanned.add(folders);
    var added = 0;
    for (final f in folders) {
      if (_indexed.add(f)) added += files[f] ?? 0;
    }
    _total += added;
    _generation += BigInt.one;
    return ScanTotals(added: added, missing: 0, restored: 0);
  }

  final synced = <List<String>>[];

  @override
  Future<ScanTotals> syncListed(List<String> paths) async {
    synced.add(paths);
    _total = paths.length;
    _generation += BigInt.one;
    return ScanTotals(added: paths.length, missing: 0, restored: 0);
  }

  @override
  Future<int> count(String folder) async => files[folder] ?? 0;

  @override
  Future<IndexStatus> status() async => IndexStatus(
    total: BigInt.from(_total),
    toTag: BigInt.zero,
    toProbe: BigInt.zero,
    unreadable: BigInt.zero,
    audio: BigInt.from(_total),
    video: BigInt.zero,
    albums: BigInt.zero,
    hasFfmpeg: true,
  );

  @override
  Future<BigInt> generation() async => _generation;

  @override
  Future<void> setFocusFolders(List<String> folders) async =>
      focusFolders = folders;
}

/// Library health (W-O2) in memory: missing groups and duplicates, with
/// every call recorded.
class FakeHealthApi implements HealthApi {
  FakeHealthApi({
    List<MissingGroupInfo> missing = const [],
    List<DuplicateSet> duplicates = const [],
    this.absent = const {},
  }) : groups = [...missing],
       sets = [...duplicates];

  final List<MissingGroupInfo> groups;
  final List<DuplicateSet> sets;

  /// Library ids whose file is gone (checked before playing).
  final Set<int> absent;
  final relocated = <(int, String)>[];
  final searched = <(List<int>, String)>[];
  final removed = <int>[];
  final setAsides = <(int, int, bool)>[];
  final checked = <int>[];

  void _forget(Iterable<int> ids) {
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      final left = [
        for (final f in g.files)
          if (!ids.contains(f.id)) f,
      ];
      if (left.isEmpty) {
        groups.removeAt(i);
      } else if (left.length != g.files.length) {
        groups[i] = MissingGroupInfo(
          cause: g.cause,
          key: g.key,
          folder: g.folder,
          target: g.target,
          files: left,
        );
      }
    }
  }

  @override
  Future<List<MissingGroupInfo>> missing() async => [...groups];

  @override
  Future<void> relocate(int id, String file) async {
    relocated.add((id, file));
    _forget([id]);
  }

  @override
  Future<int> relocateFound(List<int> ids, List<String> files) async {
    for (var i = 0; i < ids.length; i++) {
      relocated.add((ids[i], files[i]));
    }
    _forget(ids);
    return ids.length;
  }

  @override
  Future<RelocateResult> relocateIn(List<int> ids, String folder) async {
    searched.add((ids, folder));
    // The first one is found there, the others not.
    _forget(ids.take(1));
    return RelocateResult(found: 1, left: ids.length - 1);
  }

  @override
  Future<void> remove(List<int> ids) async {
    removed.addAll(ids);
    _forget(ids);
  }

  @override
  Future<List<DuplicateSet>> duplicates() async => [...sets];

  @override
  Future<void> setAside(int keep, int drop, {bool deleteFile = false}) async {
    setAsides.add((keep, drop, deleteFile));
    for (var i = sets.length - 1; i >= 0; i--) {
      final s = sets[i];
      final left = [
        for (final v in s.versions)
          if (v.item.id != drop) v,
      ];
      if (left.length < 2) {
        sets.removeAt(i);
      } else {
        sets[i] = DuplicateSet(
          isVideo: s.isVideo,
          title: s.title,
          artist: s.artist,
          album: s.album,
          versions: left,
        );
      }
    }
  }

  /// Times the sidebar badges were read (each library refresh).
  var countReads = 0;

  @override
  Future<HealthCounts> counts() async {
    countReads++;
    return HealthCounts(
      missing: BigInt.from(groups.fold<int>(0, (n, g) => n + g.files.length)),
      duplicates: sets.length,
    );
  }

  @override
  Future<bool> check(int id) async {
    checked.add(id);
    return !absent.contains(id);
  }
}

DuplicateVersion version(
  int id,
  String path, {
  required int size,
  String codec = 'mp3',
  bool lossless = false,
  int? kbps,
}) => DuplicateVersion(
  item: LibraryItem(
    id: id,
    title: 'Marée haute',
    path: path,
    isVideo: false,
    durationSecs: 240,
    artist: 'Nafy Rakoto',
    album: 'Saisons de sel',
    missing: false,
    favorite: false,
    plays: 0,
  ),
  sizeBytes: BigInt.from(size),
  codec: codec,
  lossless: lossless,
  bitrateKbps: kbps,
);

/// Obtenir in memory: link checks like the core, a scripted analysis,
/// recorded requests and events pushed by the test.
class FakeGetApi implements GetApi {
  FakeGetApi({this.analysis});

  Analysis? analysis;
  final events_ = StreamController<GetEvent>.broadcast();
  final started = <StartRequest>[];
  final actions = <(String, String)>[];
  final pauses = <bool>[];
  var tasks_ = <TaskInfo>[];
  var history_ = <HistoryInfo>[];
  var installs = 0;
  var analyzed = <String>[];
  var dir = r'C:\Users\Hery\Downloads\Miarina';

  /// When set, the manager starts only once it completes.
  Completer<void>? startGate;

  /// When set, the analysis fails with it.
  Object? analysisError;

  @override
  Future<void> start() async => startGate?.future;

  @override
  Stream<GetEvent> events() => events_.stream;

  @override
  Future<LinkCheck> checkLink(String url) async {
    final v = url.trim();
    String? error;
    if (v.isEmpty) {
      error = 'empty';
    } else if (v.contains('@')) {
      error = 'contains_credentials';
    } else if (v.contains('://') && !RegExp(r'^https?://').hasMatch(v)) {
      error = 'unsupported_scheme';
    } else if (!RegExp(r'^https?://[^/\s]+\.[^/\s]+').hasMatch(v)) {
      error = 'malformed';
    }
    return LinkCheck(
      url: error == null ? v : null,
      host: error == null ? Uri.parse(v).host : null,
      error: error,
    );
  }

  @override
  Future<Analysis> analyze(String url) async {
    analyzed.add(url);
    if (analysisError != null) throw analysisError!;
    return analysisOf?.call(url) ?? analysis!;
  }

  /// Qualities offered by Plusieurs liens.
  PresetOffers presets = PresetOffers(
    video: [
      FormatOffer(
        id: 'p1080',
        quality: '1080p',
        detail: 'MP4',
        sizeBytes: null,
        extension_: 'mp4',
        tag: 'Recommended',
      ),
      FormatOffer(
        id: 'p720',
        quality: '720p',
        detail: 'MP4',
        sizeBytes: null,
        extension_: 'mp4',
        tag: null,
      ),
    ],
    audio: [
      FormatOffer(
        id: 'p320',
        quality: 'MP3 · 320 kbps',
        detail: 'MP3',
        sizeBytes: null,
        extension_: 'mp3',
        tag: 'Recommended',
      ),
    ],
    needsFfmpeg: false,
  );

  /// When set, analyses answer per link (Plusieurs liens).
  Analysis Function(String url)? analysisOf;

  @override
  PresetOffers presetOffers() => presets;

  @override
  Future<Analysis> analyzePlaylist(String url) async {
    analyzed.add('playlist $url');
    if (analysisError != null) throw analysisError!;
    return analysis!;
  }

  @override
  Future<void> installTools() async => installs++;

  @override
  Future<TaskInfo> startDownload(StartRequest request) async {
    started.add(request);
    return taskInfo('t${started.length}', request.title, state: 'queued');
  }

  final playlists = <WebPlaylistStart>[];

  /// When set, a playlist is refused with it.
  Object? playlistError;

  @override
  Future<int> startPlaylist(WebPlaylistStart request) async {
    if (playlistError != null) throw playlistError!;
    playlists.add(request);
    return request.items.length;
  }

  @override
  Future<List<TaskInfo>> tasks() async => tasks_;

  @override
  Future<List<HistoryInfo>> history() async => history_;

  @override
  Future<void> action(String id, String action) async =>
      actions.add((id, action));

  @override
  Future<void> move(String id, int index) async => moves.add((id, index));

  final moves = <(String, int)>[];

  @override
  Future<void> pauseAll(bool pause) async => pauses.add(pause);

  @override
  Future<GetSettings> settings() async => GetSettings(
    downloadDir: dir,
    concurrency: concurrency,
    resourceMode: mode,
    maxDownloads: mode == 'eco' ? 1 : concurrency,
    maxConversions: mode == 'eco' ? 1 : 2,
    maxConcurrency: 8,
  );

  @override
  Future<GetSettings> setDownloadDir(String path) async {
    dir = path;
    return settings();
  }

  var concurrency = 3;
  var mode = 'balanced';
  var tools_ = <ToolStatus>[];
  var updates = 0;
  var cleared = 0;

  @override
  Future<GetSettings> setConcurrency(int value) async {
    concurrency = value;
    return settings();
  }

  @override
  Future<GetSettings> setResourceMode(String m) async {
    mode = m;
    return settings();
  }

  @override
  Future<List<ToolStatus>> tools() async => tools_;

  @override
  Future<YtDlpUpdate> updateYtDlp() async {
    updates++;
    return YtDlpUpdate(updated: false, version: '2026.08.19');
  }

  @override
  Future<void> clearHistory() async {
    cleared++;
    history_ = [];
  }
}

TaskInfo taskInfo(
  String id,
  String title, {
  String state = 'downloading',
  int position = 0,
  int? total,
  int downloaded = 0,
  bool audio = false,
  String format = 'MP4 · 1080p',
}) => TaskInfo(
  id: id,
  url: 'https://example.org/$id',
  sourceHost: 'example.org',
  title: title,
  isAudio: audio,
  engine: 'ytdlp',
  formatLabel: format,
  state: state,
  position: position,
  destDir: r'C:\Users\Hery\Downloads\Miarina',
  fileName: '$title.${audio ? 'mp3' : 'mp4'}',
  totalBytes: total == null ? null : BigInt.from(total),
  downloadedBytes: BigInt.from(downloaded),
  supportsResume: true,
  createdAt: 0,
);

GetEvent getEvent(
  GetEventKind kind, {
  String id = '',
  TaskInfo? task,
  HistoryInfo? history,
}) => GetEvent(
  kind: kind,
  id: id,
  downloaded: BigInt.zero,
  bytesPerSec: 0,
  supportsResume: false,
  retryInSecs: BigInt.zero,
  offline: false,
  task: task,
  history: history,
);

/// The built-in browser in memory: tabs and pages as the core reports
/// them, every call recorded.
class FakeBrowserApi implements BrowserApi {
  final events_ = StreamController<BrowserEvent>.broadcast();
  final shows = <(int, int, int, int)>[];
  var hides = 0;
  final navigated = <String>[];
  final actions = <String>[];
  var newTabs = <String?>[];
  late BrowserSnapshot current = snap();

  static BrowserSnapshot snap({
    String kind = 'start',
    String url = '',
    String title = '',
    List<DetectedMediaInfo> media = const [],
    bool streamPlayer = false,
    int tabs = 1,
  }) => BrowserSnapshot(
    kind: kind,
    url: url,
    title: title,
    loading: false,
    canGoBack: kind == 'web',
    canGoForward: false,
    media: media,
    streamPlayer: streamPlayer,
    tabs: [
      for (var i = 1; i <= tabs; i++)
        BrowserTab(
          id: i,
          kind: i == tabs ? kind : 'start',
          title: i == tabs ? title : '',
          url: i == tabs ? url : '',
          media: i == tabs ? media.length : 0,
          loading: false,
          active: i == tabs,
        ),
    ],
  );

  /// The core reports a change.
  void push(BrowserSnapshot s) {
    current = s;
    events_.add(BrowserEvent(snapshot: s));
  }

  @override
  Future<bool> init() async => true;

  @override
  Stream<BrowserEvent> events() => events_.stream;

  @override
  BrowserSnapshot snapshot() => current;

  @override
  void show(int x, int y, int width, int height) =>
      shows.add((x, y, width, height));

  @override
  void hide() => hides++;

  @override
  String navigate(String address) {
    navigated.add(address);
    if (address.startsWith('file:')) throw Exception('unsupported_address');
    push(snap(kind: 'web', url: address, title: 'Page'));
    return address;
  }

  @override
  void nav(String action) => actions.add(action);

  @override
  void tabNew([String? url]) {
    newTabs.add(url);
    push(snap(tabs: current.tabs.length + 1));
  }

  @override
  void tabClose(int id) => actions.add('close $id');

  @override
  void tabSelect(int id) => actions.add('select $id');

  @override
  void cycle(int step) => actions.add('cycle $step');

  @override
  void scan() {}

  var favorites_ = <BrowserFavorite>[];
  var visits = <BrowserVisit>[];
  var historyTabs = 0;
  var cleared = 0;

  @override
  void tabHistory() {
    historyTabs++;
    push(snap(kind: 'history', tabs: current.tabs.length));
  }

  @override
  List<BrowserFavorite> favorites() => favorites_;

  @override
  List<BrowserFavorite> favoriteToggle(String url, String title) {
    final at = favorites_.indexWhere((f) => f.url == url);
    favorites_ = at >= 0
        ? ([...favorites_]..removeAt(at))
        : [BrowserFavorite(url: url, title: title), ...favorites_];
    return favorites_;
  }

  @override
  List<BrowserVisit> history(String query) => [
    for (final v in visits)
      if (query.isEmpty ||
          v.title.toLowerCase().contains(query.toLowerCase()) ||
          v.url.contains(query))
        v,
  ];

  @override
  void historyDelete(int id) => visits.removeWhere((v) => v.id == id);

  @override
  void historyClear() {
    cleared++;
    visits = [];
  }

  final reports = <(String, Map<Object?, Object?>)>[];

  @override
  void pageReport(String type, Map<Object?, Object?> report) =>
      reports.add((type, report));
}

/// The Android native pages: orders received, reports sent back.
class FakeBrowserPages implements BrowserPages {
  final commands = <String>[];
  void Function(String, Map<Object?, Object?>)? onReport;

  @override
  void listen(void Function(String, Map<Object?, Object?>) onReport) =>
      this.onReport = onReport;

  @override
  Future<void> command(BrowserPageCommand c) async =>
      commands.add('${c.action} ${c.tab}${c.url.isEmpty ? '' : ' ${c.url}'}');
}

DetectedMediaInfo detected(String url, {String kind = 'video', int? size}) =>
    DetectedMediaInfo(
      kind: kind,
      url: url,
      host: Uri.parse(url).host,
      name: url.split('/').last,
      sizeBytes: size == null ? null : BigInt.from(size),
    );

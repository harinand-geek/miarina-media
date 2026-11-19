import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/cinema.dart';
import 'package:miarina_media/src/rust/api/focus.dart';
import 'package:miarina_media/src/rust/api/library.dart';

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
}) => LibraryItem(
  id: id,
  title: title,
  path: 'C:/Musique/$title.flac',
  isVideo: false,
  durationSecs: 245,
  artist: artist,
  album: album ?? 'Album $id',
  format: 'FLAC',
  missing: missing,
  favorite: favorite,
  trackNo: trackNo,
);

/// Same rules as the core: albums grouped by name (case-insensitive) with
/// their album artist; artists with their number of albums.
class FakeLibraryApi implements LibraryApi {
  FakeLibraryApi(this.items);

  final List<LibraryItem> items;
  final favoriteCalls = <(int, bool)>[];

  @override
  Future<LibraryPage> tracks({
    required String search,
    required bool favoritesOnly,
    required int offset,
    required int limit,
    String? album,
    String? artist,
    bool recent = false,
  }) async {
    bool same(String? a, String? b) => a?.toLowerCase() == b?.toLowerCase();
    var list = items
        .where((i) => !favoritesOnly || i.favorite)
        .where((i) => album == null || same(i.album, album))
        .where((i) => artist == null || same(i.artist, artist))
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
        ),
    ];
  }

  @override
  Future<void> setFavorite(int mediaId, {required bool favorite}) async =>
      favoriteCalls.add((mediaId, favorite));

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

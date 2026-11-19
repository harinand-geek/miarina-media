import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/library.dart';

class FakeSettingsStore implements SettingsStore {
  final values = <String, Object?>{};

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

class FakeEngine implements MediaEngine {
  final opened = <MediaSource>[];
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
    emit(
      PlaybackSnapshot(
        status: PlaybackStatus.playing,
        source: media,
        duration: const Duration(minutes: 4),
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

  @override
  Future<void> selectAudioTrack(String trackId) async {}

  @override
  Future<void> selectSubtitleTrack(String? trackId) async {}

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
    }
    final page = list.skip(offset).take(limit).toList();
    return LibraryPage(items: page, total: BigInt.from(list.length));
  }

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

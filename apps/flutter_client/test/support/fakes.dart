import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/src/rust/api/library.dart';

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
    equalizer: false,
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

  @override
  Widget buildVideoView({BoxFit fit = BoxFit.contain}) => const SizedBox();

  @override
  Future<void> dispose() async => _controller.close();
}

LibraryItem track(
  int id,
  String title, {
  String? artist,
  bool missing = false,
  bool favorite = false,
}) => LibraryItem(
  id: id,
  title: title,
  path: 'C:/Musique/$title.flac',
  isVideo: false,
  durationSecs: 245,
  artist: artist,
  album: 'Album $id',
  format: 'FLAC',
  missing: missing,
  favorite: favorite,
);

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
  }) async {
    var list = items.where((i) => !favoritesOnly || i.favorite).toList();
    if (search.isNotEmpty) {
      list = list
          .where((i) => i.title.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    final page = list.skip(offset).take(limit).toList();
    return LibraryPage(items: page, total: BigInt.from(list.length));
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

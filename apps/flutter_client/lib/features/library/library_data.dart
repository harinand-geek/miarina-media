import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../engine/media_engine.dart';
import '../../src/rust/api/library.dart';
import '../playback/playback.dart';

/// Where the library database lives. Development builds point MM_DATA_DIR at
/// a scratch folder (or a copy of a 0.1.x data folder); the live Tauri
/// database is never opened while both apps coexist.
final dataDirProvider = FutureProvider<String>((ref) async {
  const override = String.fromEnvironment('MM_DATA_DIR');
  if (override.isNotEmpty) return override;
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return dir.path;
});

final dbPathProvider = FutureProvider<String>(
  (ref) async =>
      '${await ref.watch(dataDirProvider.future)}${Platform.pathSeparator}miarina.db',
);

/// What the screens need from the library; the real one goes through the
/// Rust core, tests use an in-memory one.
abstract interface class LibraryApi {
  Future<LibraryPage> tracks({
    required String search,
    required bool favoritesOnly,
    required int offset,
    required int limit,
  });
  Future<void> setFavorite(int mediaId, {required bool favorite});
  Future<LibrarySummary> summary();
}

class RustLibraryApi implements LibraryApi {
  RustLibraryApi(this._ref);

  final Ref _ref;

  Future<String> get _db => _ref.read(dbPathProvider.future);

  @override
  Future<LibraryPage> tracks({
    required String search,
    required bool favoritesOnly,
    required int offset,
    required int limit,
  }) async => libraryTracks(
    dbPath: await _db,
    search: search,
    favoritesOnly: favoritesOnly,
    offset: offset,
    limit: limit,
  );

  @override
  Future<void> setFavorite(int mediaId, {required bool favorite}) async =>
      librarySetFavorite(
        dbPath: await _db,
        mediaId: mediaId,
        favorite: favorite,
      );

  @override
  Future<LibrarySummary> summary() async =>
      librarySummary(dbPath: await _db, limit: 0);
}

final libraryApiProvider = Provider<LibraryApi>(RustLibraryApi.new);

/// Counters for the navigation; only what the core can really give.
final libraryStatsProvider = FutureProvider<LibrarySummary>(
  (ref) => ref.watch(libraryApiProvider).summary(),
);

QueueEntry queueEntryOf(LibraryItem item, {required String unknownArtist}) =>
    QueueEntry(
      source: MediaSource.file(item.path, title: item.title),
      title: item.title,
      subtitle: item.artist ?? unknownArtist,
      libraryId: item.id,
      favorite: item.favorite,
    );

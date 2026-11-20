import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/launch_args.dart' show fileTitle;
import '../../engine/media_engine.dart';
import '../../src/rust/api/library.dart';
import '../playback/playback.dart';

/// Where the app keeps its data. Windows: the 0.1.x folder,
/// `%APPDATA%\org.miarina.media`, so a 0.1.x library, its settings,
/// downloads and torrents carry over (plan R1). Development builds point
/// MM_DATA_DIR at a scratch folder; they never open the real one.
Future<String> appDataDir() async {
  const override = String.fromEnvironment('MM_DATA_DIR');
  if (override.isNotEmpty) return override;
  final roaming = Platform.isWindows ? Platform.environment['APPDATA'] : null;
  final dir = roaming != null && roaming.isNotEmpty
      ? Directory('$roaming${Platform.pathSeparator}org.miarina.media')
      : await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return dir.path;
}

final dataDirProvider = FutureProvider<String>((ref) => appDataDir());

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
    String? album,
    String? artist,
    bool recent = false,
    TrackSort sort = TrackSort.title,
    bool reverse = false,
    DateTime? addedSince,
    bool neverPlayed = false,
    bool hiRes = false,
  });

  /// One entry by id; null when it is no longer in the library.
  Future<LibraryItem?> item(int id);

  /// The entry of a file path, when the library knows the file.
  Future<LibraryItem?> itemByPath(String path);

  /// Albums or artists, alphabetical.
  Future<List<LibraryGroup>> groups(GroupKind kind);
  Future<void> setFavorite(int mediaId, {required bool favorite});

  /// One play of an entry (the player calls it once per play).
  Future<void> notePlayed(int mediaId);
  Future<LibrarySummary> summary();

  /// Adds a local file to the library (title from its name, tags and
  /// technical details read later) and returns its id.
  Future<int> addFile(String path, {required bool isVideo});
}

enum GroupKind { album, artist }

/// Columns the Titres table sorts by (W-M1c); [added] = newest first.
enum TrackSort { title, artist, album, format, duration, added }

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
    String? album,
    String? artist,
    bool recent = false,
    TrackSort sort = TrackSort.title,
    bool reverse = false,
    DateTime? addedSince,
    bool neverPlayed = false,
    bool hiRes = false,
  }) async => libraryTracks(
    dbPath: await _db,
    search: search,
    favoritesOnly: favoritesOnly,
    album: album,
    artist: artist,
    sort: recent ? TrackSort.added.name : sort.name,
    reverse: reverse,
    addedSince: addedSince?.millisecondsSinceEpoch,
    neverPlayed: neverPlayed,
    hiRes: hiRes,
    offset: offset,
    limit: limit,
  );

  @override
  Future<LibraryItem?> itemByPath(String path) async =>
      libraryItemByPath(dbPath: await _db, path: path);

  @override
  Future<LibraryItem?> item(int id) async =>
      libraryItem(dbPath: await _db, mediaId: id);

  @override
  Future<List<LibraryGroup>> groups(GroupKind kind) async =>
      libraryGroups(dbPath: await _db, by: kind.name);

  @override
  Future<void> notePlayed(int mediaId) async =>
      libraryNotePlayed(dbPath: await _db, mediaId: mediaId);

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

  @override
  Future<int> addFile(String path, {required bool isVideo}) async {
    final file = File(path);
    return (await libraryAddFile(
      dbPath: await _db,
      path: file.absolute.path,
      title: fileTitle(path),
      isVideo: isVideo,
      sizeBytes: BigInt.from(await file.length()),
    )).toInt();
  }
}

final libraryApiProvider = Provider<LibraryApi>(RustLibraryApi.new);

/// Counters for the navigation; only what the core can really give.
final libraryStatsProvider = FutureProvider<LibrarySummary>(
  (ref) => ref.watch(libraryApiProvider).summary(),
);

/// Number of favorite tracks (sidebar, Favoris). Read again when a heart
/// changes and with every library refresh.
final favoritesCountProvider = FutureProvider<int>((ref) async {
  final page = await ref
      .watch(libraryApiProvider)
      .tracks(search: '', favoritesOnly: true, offset: 0, limit: 1);
  return page.total.toInt();
});

QueueEntry queueEntryOf(LibraryItem item, {String? unknownArtist}) =>
    QueueEntry(
      source: MediaSource.file(item.path, title: item.title),
      title: item.title,
      subtitle: item.artist ?? unknownArtist,
      libraryId: item.id,
      favorite: item.favorite,
      album: item.album,
      duration: item.durationSecs == null
          ? null
          : Duration(milliseconds: (item.durationSecs! * 1000).round()),
      format: item.format,
      artwork: item.thumbnail,
      isVideo: item.isVideo,
    );

extension LibraryItemCopy on LibraryItem {
  LibraryItem withFavorite(bool value) => LibraryItem(
    id: id,
    title: title,
    path: path,
    isVideo: isVideo,
    durationSecs: durationSecs,
    artist: artist,
    album: album,
    format: format,
    missing: missing,
    favorite: value,
    thumbnail: thumbnail,
    trackNo: trackNo,
    plays: plays,
  );
}

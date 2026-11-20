import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../src/rust/api/indexer.dart';
import '../cinema/cinema_data.dart';
import '../focus/focus_data.dart';
import '../home/home_data.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../playback/settings_store.dart';
import '../playlists/playlists_data.dart';

/// How the user typed a folder at import (W-O1b).
enum FolderKind { music, video, focus }

@immutable
class WatchedFolder {
  const WatchedFolder(this.path, this.kind);

  final String path;
  final FolderKind kind;

  Map<String, String> toJson() => {'path': path, 'kind': kind.name};

  static WatchedFolder? fromJson(Object? raw) {
    if (raw is! Map || raw['path'] is! String) return null;
    return WatchedFolder(
      raw['path'] as String,
      FolderKind.values.asNameMap()[raw['kind']] ?? FolderKind.music,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WatchedFolder && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);
}

/// The core's indexing; tests use an in-memory one.
abstract interface class IndexerApi {
  Future<void> start();
  Future<ScanTotals> scan(List<String> folders);
  Future<int> count(String folder);
  Future<IndexStatus> status();
  Future<BigInt> generation();
  Future<void> setFocusFolders(List<String> folders);
}

class RustIndexerApi implements IndexerApi {
  RustIndexerApi(this._ref);

  final Ref _ref;

  @override
  Future<void> start() async => indexerStart(
    dbPath: await _ref.read(dbPathProvider.future),
    dataDir: await _ref.read(dataDirProvider.future),
    toolsDir: toolsDir(),
  );

  @override
  Future<ScanTotals> scan(List<String> folders) =>
      indexerScan(folders: folders);

  @override
  Future<int> count(String folder) => indexerCount(folder: folder);

  @override
  Future<IndexStatus> status() async =>
      indexerStatus(dbPath: await _ref.read(dbPathProvider.future));

  @override
  Future<BigInt> generation() => indexerGeneration();

  @override
  Future<void> setFocusFolders(List<String> folders) =>
      indexerSetFocusFolders(folders: folders);
}

/// `tools/` next to the executable: FFmpeg shipped with the app, laid out
/// as in the Tauri app (`tools/ffmpeg/<version>/ffmpeg.exe`).
String? toolsDir() {
  if (!Platform.isWindows) return null;
  final exe = File(Platform.resolvedExecutable).parent.path;
  return '$exe${Platform.pathSeparator}tools';
}

final indexerApiProvider = Provider<IndexerApi>(RustIndexerApi.new);

/// Folders followed by the library (settings table, `libraryFolders`).
final libraryFoldersProvider =
    AsyncNotifierProvider<LibraryFoldersController, List<WatchedFolder>>(
      LibraryFoldersController.new,
    );

class LibraryFoldersController extends AsyncNotifier<List<WatchedFolder>> {
  static const key = 'libraryFolders';

  @override
  Future<List<WatchedFolder>> build() async {
    final raw = await ref.read(settingsStoreProvider).read(key);
    return [
      if (raw is List)
        for (final e in raw) ?WatchedFolder.fromJson(e),
    ];
  }

  Future<void> _save(List<WatchedFolder> next) async {
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).write(key, [
      for (final f in next) f.toJson(),
    ]);
    await ref.read(indexerApiProvider).setFocusFolders([
      for (final f in next)
        if (f.kind == FolderKind.focus) f.path,
    ]);
  }

  /// Adds (or retypes) a folder; the same path is never listed twice.
  Future<void> add(String path, FolderKind kind) async {
    final list = [...await future]..removeWhere((f) => f.path == path);
    await _save([...list, WatchedFolder(path, kind)]);
  }

  Future<void> remove(String path) async =>
      _save([...await future]..removeWhere((f) => f.path == path));

  Future<void> setKind(String path, FolderKind kind) async => _save([
    for (final f in await future)
      f.path == path ? WatchedFolder(path, kind) : f,
  ]);
}

/// Every screen built on the library reads it again.
void refreshLibraryWith(void Function(ProviderOrFamily) invalidate) {
  invalidate(libraryStatsProvider);
  invalidate(groupsProvider);
  invalidate(cinemaLibraryProvider);
  invalidate(focusLibraryProvider);
  invalidate(homeProvider);
  invalidate(playlistsProvider);
}

/// Starts indexing at launch: the followed folders are scanned again in the
/// background (new files in, vanished ones marked missing), then the
/// library screens refresh whenever the worker changes rows (checked every
/// 2 s, one cheap read). Watched by the app root on Windows.
final indexingProvider = Provider<void>((ref) {
  final api = ref.watch(indexerApiProvider);
  Timer? poll;
  BigInt? seen;
  ref.onDispose(() => poll?.cancel());
  Future<void> run() async {
    try {
      await api.start();
      final folders = await ref.read(libraryFoldersProvider.future);
      await api.setFocusFolders([
        for (final f in folders)
          if (f.kind == FolderKind.focus) f.path,
      ]);
      if (folders.isNotEmpty) {
        unawaited(api.scan([for (final f in folders) f.path]));
      }
      poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        final g = await api.generation();
        if (seen != null && g != seen) refreshLibraryWith(ref.invalidate);
        seen = g;
      });
    } catch (e) {
      debugPrint('indexing not started: $e');
    }
  }

  unawaited(run());
});

/// Whether the first-launch screens (W-O1) were completed or skipped.
final onboardingProvider = AsyncNotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);

class OnboardingController extends AsyncNotifier<bool> {
  static const key = 'onboardingDone';

  @override
  Future<bool> build() async =>
      (await ref.read(settingsStoreProvider).read(key)) == true;

  Future<void> finish() async {
    // Wait for the stored value first, or its late read would undo this.
    await future;
    state = const AsyncData(true);
    await ref.read(settingsStoreProvider).write(key, true);
  }
}

/// Usual Windows folders proposed at import when they hold media.
Future<List<WatchedFolder>> suggestedFolders(IndexerApi api) async {
  if (!Platform.isWindows) return const [];
  final home = Platform.environment['USERPROFILE'];
  if (home == null) return const [];
  final out = <WatchedFolder>[];
  for (final (name, kind) in const [
    ('Music', FolderKind.music),
    ('Videos', FolderKind.video),
  ]) {
    final path = '$home${Platform.pathSeparator}$name';
    if (Directory(path).existsSync() && await api.count(path) > 0) {
      out.add(WatchedFolder(path, kind));
    }
  }
  return out;
}

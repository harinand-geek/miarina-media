import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show Int64List;

import '../../src/rust/api/playlists.dart';
import '../library/library_data.dart';

/// Playlists of the core (shared with the 0.1.x app); tests use an
/// in-memory one.
abstract interface class PlaylistApi {
  Future<List<PlaylistInfo>> list();
  Future<PlaylistDetail?> get(int id);
  Future<PlaylistInfo> create(String name, List<int> mediaIds);
  Future<void> rename(int id, String name);
  Future<void> delete(int id);
  Future<void> add(int id, List<int> mediaIds);
  Future<void> remove(int id, int index);
  Future<void> move(int id, int from, int to);
  Future<ImportReport> importM3u(String path);
  Future<void> exportM3u(int id, String path);
}

class RustPlaylistApi implements PlaylistApi {
  RustPlaylistApi(this._ref);

  final Ref _ref;

  Future<String> get _db => _ref.read(dbPathProvider.future);

  @override
  Future<List<PlaylistInfo>> list() async => playlistsList(dbPath: await _db);

  @override
  Future<PlaylistDetail?> get(int id) async =>
      playlistGet(dbPath: await _db, id: id);

  @override
  Future<PlaylistInfo> create(String name, List<int> mediaIds) async =>
      playlistCreate(
        dbPath: await _db,
        name: name,
        mediaIds: Int64List.fromList(mediaIds),
      );

  @override
  Future<void> rename(int id, String name) async =>
      playlistRename(dbPath: await _db, id: id, name: name);

  @override
  Future<void> delete(int id) async =>
      playlistDelete(dbPath: await _db, id: id);

  @override
  Future<void> add(int id, List<int> mediaIds) async => playlistAdd(
    dbPath: await _db,
    id: id,
    mediaIds: Int64List.fromList(mediaIds),
  );

  @override
  Future<void> remove(int id, int index) async =>
      playlistRemove(dbPath: await _db, id: id, index: index);

  @override
  Future<void> move(int id, int from, int to) async =>
      playlistMove(dbPath: await _db, id: id, from: from, to: to);

  @override
  Future<ImportReport> importM3u(String path) async =>
      playlistImportM3U(dbPath: await _db, path: path);

  @override
  Future<void> exportM3u(int id, String path) async =>
      playlistExportM3U(dbPath: await _db, id: id, path: path);
}

final playlistApiProvider = Provider<PlaylistApi>(RustPlaylistApi.new);

final playlistsProvider = FutureProvider<List<PlaylistInfo>>(
  (ref) => ref.watch(playlistApiProvider).list(),
);

final playlistProvider = FutureProvider.family<PlaylistDetail?, int>(
  (ref, id) => ref.watch(playlistApiProvider).get(id),
);

/// Runs a change, then refreshes the list and that playlist.
Future<T> editPlaylists<T>(
  WidgetRef ref,
  Future<T> Function(PlaylistApi api) change, {
  int? id,
}) async {
  final result = await change(ref.read(playlistApiProvider));
  ref.invalidate(playlistsProvider);
  if (id != null) ref.invalidate(playlistProvider(id));
  return result;
}

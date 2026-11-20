import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/torrents.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;
import '../get/get_data.dart' show downloadsProvider;
import '../library/library_data.dart' show dataDirProvider;

export '../../src/rust/api/torrents.dart'
    show TorrentFile, TorrentPreview, TorrentRow, TorrentSnapshot;

/// Torrents in the core (`mdm-torrent`, Windows); tests use a fake.
abstract interface class TorrentsApi {
  Future<void> enable();
  Future<void> disable();
  Future<rust.TorrentSnapshot> list();

  /// A magnet link, or a .torrent file path.
  Future<rust.TorrentPreview> preview({String? magnet, String? file});
  Future<void> start(String hash, List<int> files, {required bool sequential});

  /// pause, resume, remove.
  Future<void> action(String hash, String action);

  /// Bytes per second, 0 = unlimited.
  Future<void> limits(int download, int upload);
}

class RustTorrentsApi implements TorrentsApi {
  RustTorrentsApi(this._ref);

  final Ref _ref;

  @override
  Future<void> enable() async {
    if (!Platform.isWindows || !RustLib.instance.initialized) {
      throw StateError('unsupported_platform');
    }
    // The session shares the database opened by the download manager.
    await _ref.read(downloadsProvider.notifier).started;
    await rust.torrentsEnable(dataDir: await _ref.read(dataDirProvider.future));
  }

  @override
  Future<void> disable() => rust.torrentsDisable();

  @override
  Future<rust.TorrentSnapshot> list() async {
    if (!RustLib.instance.initialized) {
      return rust.TorrentSnapshot(
        enabled: false,
        rows: const [],
        downloadLimit: BigInt.zero,
        uploadLimit: BigInt.zero,
      );
    }
    await _ref.read(downloadsProvider.notifier).started;
    return rust.torrentsList();
  }

  @override
  Future<rust.TorrentPreview> preview({String? magnet, String? file}) =>
      rust.torrentsPreview(magnet: magnet, file: file);

  @override
  Future<void> start(
    String hash,
    List<int> files, {
    required bool sequential,
  }) => rust.torrentsStart(hash: hash, files: files, sequential: sequential);

  @override
  Future<void> action(String hash, String action) =>
      rust.torrentsAction(hash: hash, action: action);

  @override
  Future<void> limits(int download, int upload) => rust.torrentsLimits(
    download: BigInt.from(download),
    upload: BigInt.from(upload),
  );
}

final torrentsApiProvider = Provider<TorrentsApi>(RustTorrentsApi.new);

/// "Ouvrir un .torrent": the file chosen by the user (tests answer it).
final torrentFilePickerProvider = Provider<Future<String?> Function(String)>(
  (_) =>
      (label) async => (await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: label, extensions: const ['torrent']),
        ],
      ))?.path,
);

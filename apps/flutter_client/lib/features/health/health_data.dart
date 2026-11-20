import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show Int64List;

import '../../src/rust/api/health.dart';
import '../playback/settings_store.dart';

export '../../src/rust/api/health.dart'
    show
        DuplicateSet,
        DuplicateVersion,
        HealthCounts,
        MissingCause,
        MissingFileInfo,
        MissingGroupInfo,
        RelocateResult;

/// Library health (W-O2) in the core; tests use an in-memory one.
abstract interface class HealthApi {
  Future<List<MissingGroupInfo>> missing();
  Future<void> relocate(int id, String file);
  Future<int> relocateFound(List<int> ids, List<String> files);
  Future<RelocateResult> relocateIn(List<int> ids, String folder);
  Future<void> remove(List<int> ids);
  Future<List<DuplicateSet>> duplicates();
  Future<void> setAside(int keep, int drop, {bool deleteFile = false});
  Future<HealthCounts> counts();

  /// Whether the file of a library entry is still there.
  Future<bool> check(int id);
}

class RustHealthApi implements HealthApi {
  const RustHealthApi();

  @override
  Future<List<MissingGroupInfo>> missing() => healthMissing();

  @override
  Future<void> relocate(int id, String file) =>
      healthRelocate(id: id, file: file);

  @override
  Future<int> relocateFound(List<int> ids, List<String> files) =>
      healthRelocateFound(ids: Int64List.fromList(ids), files: files);

  @override
  Future<RelocateResult> relocateIn(List<int> ids, String folder) =>
      healthRelocateIn(ids: Int64List.fromList(ids), folder: folder);

  @override
  Future<void> remove(List<int> ids) =>
      healthRemove(ids: Int64List.fromList(ids));

  @override
  Future<List<DuplicateSet>> duplicates() => healthDuplicates();

  @override
  Future<void> setAside(int keep, int drop, {bool deleteFile = false}) =>
      healthSetAside(keep: keep, dropId: drop, deleteFile: deleteFile);

  @override
  Future<HealthCounts> counts() => healthCounts();

  @override
  Future<bool> check(int id) => healthCheck(id: id);
}

final healthApiProvider = Provider<HealthApi>((_) => const RustHealthApi());

/// W-O2a: missing files by probable cause.
final missingProvider = FutureProvider<List<MissingGroupInfo>>(
  (ref) => ref.watch(healthApiProvider).missing(),
);

/// W-O2b: titles present in several versions.
final duplicatesProvider = FutureProvider<List<DuplicateSet>>(
  (ref) => ref.watch(healthApiProvider).duplicates(),
);

/// Badges of the sidebar; nothing shown when the core cannot tell.
final healthCountsProvider = FutureProvider<HealthCounts?>((ref) async {
  try {
    return await ref.watch(healthApiProvider).counts();
  } catch (_) {
    return null;
  }
});

/// Groups of missing files the user chose to hide ("Masquer",
/// "Ignorer"), by key (settings table, `missingDismissed`).
final missingDismissedProvider =
    AsyncNotifierProvider<MissingDismissedController, Set<String>>(
      MissingDismissedController.new,
    );

class MissingDismissedController extends AsyncNotifier<Set<String>> {
  static const key = 'missingDismissed';

  @override
  Future<Set<String>> build() async {
    final raw = await ref.read(settingsStoreProvider).read(key);
    return {
      if (raw is List)
        for (final k in raw)
          if (k is String) k,
    };
  }

  Future<void> _save(Set<String> next) async {
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).write(key, next.toList());
  }

  Future<void> dismiss(String group) async => _save({...await future, group});

  Future<void> showAll() => _save(const {});
}

/// Version kept in a duplicate group: the user's choice (by group key),
/// else the best quality.
int keptOf(DuplicateSet set, Map<String, int> choices) {
  final chosen = choices[duplicateKey(set)];
  return set.versions.any((v) => v.item.id == chosen)
      ? chosen!
      : set.versions.first.item.id;
}

String duplicateKey(DuplicateSet set) => set.versions
    .map((v) => v.item.id)
    .reduce((a, b) => a < b ? a : b)
    .toString();

/// Bytes freed by setting aside every version not kept.
int recoverableBytes(List<DuplicateSet> sets, Map<String, int> choices) {
  var total = 0;
  for (final s in sets) {
    final keep = keptOf(s, choices);
    for (final v in s.versions) {
      if (v.item.id != keep) total += v.sizeBytes.toInt();
    }
  }
  return total;
}

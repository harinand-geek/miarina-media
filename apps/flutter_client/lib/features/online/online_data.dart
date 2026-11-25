import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException;

import '../../app/router.dart';
import '../../src/rust/api/online.dart';
import '../../src/rust/frb_generated.dart';
import '../get/get_data.dart';
import '../playback/settings_store.dart';

export '../../src/rust/api/online.dart' show OnlineTrack;

/// Online listening (decision 0011): YouTube results played in the app's
/// own player; Obtenir keeps a track for offline listening.

/// Error codes of `api/online.rs` (`"<code>: <detail>"`).
enum OnlineFailureKind { tools, network, blocked, unavailable, canceled, other }

class OnlineFailure implements Exception {
  const OnlineFailure(this.kind, [this.detail = '']);

  /// Reads the code the core puts in front of its message.
  factory OnlineFailure.of(Object error) {
    if (error is OnlineFailure) return error;
    final text = (error is AnyhowException ? error.message : '$error').trim();
    final m = RegExp(r'^([a-z]+):\s?(.*)', dotAll: true).firstMatch(text);
    final kind = OnlineFailureKind.values.firstWhere(
      (k) => k.name == m?.group(1),
      orElse: () => OnlineFailureKind.other,
    );
    final detail = (m?.group(2) ?? text).split('\n').first.trim();
    return OnlineFailure(kind, detail);
  }

  final OnlineFailureKind kind;
  final String detail;

  @override
  String toString() => '${kind.name}: $detail';
}

/// The core's online functions; tests use an in-memory one.
abstract interface class OnlineApi {
  /// The extractor is installed and Obtenir has started.
  bool available();

  /// Throws an [OnlineFailure].
  Future<List<OnlineTrack>> search(String query, {int limit = 20});
}

class RustOnlineApi implements OnlineApi {
  RustOnlineApi(this._ref);

  final Ref _ref;

  @override
  bool available() {
    // Widget tests run without the native core.
    if (!RustLib.instance.initialized) return false;
    try {
      return onlineAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    // The extractor belongs to Obtenir, started with the app.
    await _ref.read(downloadsProvider.notifier).started;
    try {
      return (await onlineSearch(query: query, limit: limit)).tracks;
    } catch (e) {
      throw OnlineFailure.of(e);
    }
  }
}

final onlineApiProvider = Provider<OnlineApi>(RustOnlineApi.new);

enum OnlineStatus {
  /// Obtenir is still starting: nothing can be said yet.
  starting,
  ready,

  /// The extractor is missing: the page offers to install it.
  noTools,
}

final onlineStatusProvider = Provider<OnlineStatus>((ref) {
  final started = ref.watch(downloadsProvider.select((s) => s.ready));
  if (ref.watch(onlineApiProvider).available()) return OnlineStatus.ready;
  return started ? OnlineStatus.noTools : OnlineStatus.starting;
});

/// Results asked for first, and with « Plus de résultats » (the core's
/// maximum).
const onlinePageSize = 20;
const onlineMaxResults = 30;

typedef OnlineQuery = ({String query, int limit});

final onlineSearchProvider = FutureProvider.autoDispose
    .family<List<OnlineTrack>, OnlineQuery>(
      (ref, q) async {
        final query = q.query.trim();
        if (query.isEmpty) return const [];
        return ref.watch(onlineApiProvider).search(query, limit: q.limit);
      },
      // Each try starts the extractor: the page offers « Réessayer » instead
      // of retrying on its own (Riverpod 3 retries failures by default).
      retry: (_, _) => null,
    );

String onlineUri(String query) => Uri(
  path: Routes.online,
  queryParameters: query.isEmpty ? null : {'q': query},
).toString();

/// Searches the user ran from the En ligne page (newest first), kept in
/// the library's settings like the other preferences; never sent anywhere.
const recentOnlineKey = 'online.recent';
const recentOnlineMax = 10;

class RecentOnlineSearches extends AsyncNotifier<List<String>> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  Future<List<String>> build() async {
    try {
      final raw = await _store.read(recentOnlineKey);
      if (raw is! List) return const [];
      return [
        for (final q in raw)
          if (q is String && q.trim().isNotEmpty) q.trim(),
      ].take(recentOnlineMax).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final now = await future;
    await _save(
      [
        q,
        for (final o in now)
          if (o.toLowerCase() != q.toLowerCase()) o,
      ].take(recentOnlineMax).toList(),
    );
  }

  Future<void> remove(String query) async {
    final now = await future;
    await _save([
      for (final o in now)
        if (o != query) o,
    ]);
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> list) async {
    state = AsyncData(list);
    try {
      await _store.write(recentOnlineKey, list);
    } catch (_) {
      // Remembered for this session only.
    }
  }
}

final recentOnlineProvider =
    AsyncNotifierProvider<RecentOnlineSearches, List<String>>(
      RecentOnlineSearches.new,
    );

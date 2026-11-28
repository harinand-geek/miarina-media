import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher, Locale;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../home/phone_home_data.dart' show daySeed;
import '../library/library_data.dart';
import 'playback.dart';
import 'playback_memory.dart';
import 'smart_queue.dart';
import 'taste.dart';

/// Android Auto (decision 0013, proposal 11): the lists a car shows to
/// play from, written for the player service (AutoLibrary.kt) so they are
/// there with the app closed.
abstract interface class AutoLibraryApi {
  Future<void> write(String json);
}

class ChannelAutoLibraryApi implements AutoLibraryApi {
  static const _channel = MethodChannel('org.miarina.media/auto');

  @override
  Future<void> write(String json) async {
    try {
      await _channel.invokeMethod<void>('library', json);
    } catch (_) {
      // No car side (an older build): nothing to offer.
    }
  }
}

final autoLibraryApiProvider = Provider<AutoLibraryApi?>(
  (_) => Platform.isAndroid ? ChannelAutoLibraryApi() : null,
);

/// The tracks of one list, as the player service reads them.
Map<String, Object?> autoSection(
  String id,
  String title,
  List<LibraryItem> items,
) => {
  'id': id,
  'title': title,
  'items': [
    for (final i in items)
      {
        'id': '${i.id}',
        'title': i.title,
        'artist': i.artist ?? '',
        'album': i.album ?? '',
        'path': i.path,
      },
  ],
};

/// Builds the car's lists: the day's mix, favourites, recently played and
/// every title (by title, at most [allMax]).
Future<String> buildAutoLibrary(Ref ref, L10n t, {int allMax = 500}) async {
  final api = ref.read(libraryApiProvider);
  final page = await api.tracks(
    search: '',
    favoritesOnly: false,
    offset: 0,
    limit: 3000,
  );
  final music = [
    for (final i in page.items)
      if (!i.isVideo && !i.missing) i,
  ];
  final byId = {for (final i in music) i.id: i};
  await ref.read(tasteProvider.notifier).ready();
  final plays = await ref.read(playbackMemoryProvider).history();
  final now = DateTime.now();
  final mix = dailyMixPicks(
    library: music,
    taste: ref.read(tasteProvider),
    recentIds: [for (final p in plays) p.id],
    random: math.Random(daySeed(now)),
    now: now,
  );
  final recent = <LibraryItem>[];
  final seen = <int>{};
  for (final p in plays) {
    final i = byId[p.id];
    if (i != null && seen.add(i.id)) recent.add(i);
    if (recent.length >= 30) break;
  }
  final all = [...music]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return jsonEncode({
    'sections': [
      autoSection('mix', t.dailyMix, mix),
      autoSection(
        'favorites',
        t.navFavorites,
        [
          for (final i in music)
            if (i.favorite) i,
        ].take(200).toList(),
      ),
      autoSection('recent', t.recentlyPlayed, recent),
      autoSection('all', t.navTracks, all.take(allMax).toList()),
    ],
  });
}

/// Writes the car's lists at launch and when another title starts, at most
/// every ten minutes; watched by the app root.
final autoLibraryProvider = Provider<void>((ref) {
  final api = ref.watch(autoLibraryApiProvider);
  if (api == null) return;
  DateTime? last;
  var busy = false;
  Future<void> write() async {
    final now = DateTime.now();
    if (busy || (last != null && now.difference(last!).inMinutes < 10)) {
      return;
    }
    busy = true;
    last = now;
    try {
      final lang = PlatformDispatcher.instance.locale.languageCode;
      final t = lookupL10n(
        Locale(const {'fr', 'en', 'mg'}.contains(lang) ? lang : 'fr'),
      );
      await api.write(await buildAutoLibrary(ref, t));
    } catch (_) {
      // The library could not be read: the car keeps the previous lists.
    } finally {
      busy = false;
    }
  }

  // A little after launch, not while the first screen draws.
  final first = Timer(const Duration(seconds: 8), () => unawaited(write()));
  ref.onDispose(first.cancel);
  ref.listen(
    queueProvider.select((q) => q.current?.libraryId),
    (_, _) => unawaited(write()),
  );
});

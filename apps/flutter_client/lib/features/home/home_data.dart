import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/cinema.dart';
import '../../src/rust/api/library.dart';
import '../cinema/cinema_data.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';

@immutable
class ResumeItem {
  const ResumeItem(this.item, this.position, {this.video});

  final LibraryItem item;
  final Duration position;

  /// Cinema details of a video (series, episode), for its title.
  final CinemaItem? video;

  Duration? get remaining {
    final secs = item.durationSecs;
    if (secs == null) return null;
    final left = Duration(milliseconds: (secs * 1000).round()) - position;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    final secs = item.durationSecs;
    if (secs == null || secs <= 0) return 0;
    return (position.inMilliseconds / (secs * 1000)).clamp(0.0, 1.0);
  }
}

/// An automatic list of W-00 / A-00, built only from real data.
@immutable
class AutoList {
  const AutoList({
    required this.kind,
    required this.items,
    required this.count,
  });

  final AutoListKind kind;

  /// Tracks to play, in list order (at most 50).
  final List<LibraryItem> items;

  /// Number shown on the card badge.
  final int count;
}

enum AutoListKind { mostPlayed, recentlyAdded, favorites }

@immutable
class HomeData {
  const HomeData({
    required this.resume,
    required this.lists,
    required this.recentAlbums,
    required this.isEmpty,
  });

  final List<ResumeItem> resume;
  final List<AutoList> lists;
  final List<LibraryGroup> recentAlbums;

  /// Nothing played and nothing in the library.
  final bool isEmpty;
}

const _listMax = 50;

/// Ids of the most played audio entries of [history], ties broken by the
/// most recent play (the 0.1.x autoLists rule).
List<int> mostPlayedIds(List<PlayEntry> history) {
  final counts = <int, int>{};
  for (final e in history.where((e) => e.kind == 'audio')) {
    counts[e.id] = (counts[e.id] ?? 0) + 1;
  }
  final ids = counts.keys.toList();
  // Map keeps first-seen (newest) order; List.sort is stable.
  ids.sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return ids.take(_listMax).toList();
}

final homeProvider = FutureProvider<HomeData>((ref) async {
  // Recomputed when another track starts: resume points and history moved.
  ref.watch(queueProvider.select((q) => q.current?.libraryId));
  final api = ref.watch(libraryApiProvider);
  final memory = ref.watch(playbackMemoryProvider);
  final history = await memory.history();

  final resume = <ResumeItem>[];
  final seen = <int>{};
  for (final e in history) {
    if (resume.length >= 3 || !seen.add(e.id)) continue;
    final at = await memory.savedPosition(e.id);
    if (at == null) continue;
    final item = await api.item(e.id);
    if (item == null || item.missing) continue;
    final video = item.isVideo
        ? await ref.read(cinemaApiProvider).item(item.id)
        : null;
    resume.add(ResumeItem(item, at, video: video));
  }

  final most = <LibraryItem>[];
  for (final id in mostPlayedIds(history).take(12)) {
    final item = await api.item(id);
    if (item != null && !item.missing) most.add(item);
  }
  final recent = await api.tracks(
    search: '',
    favoritesOnly: false,
    offset: 0,
    limit: _listMax,
    recent: true,
  );
  final favorites = await api.tracks(
    search: '',
    favoritesOnly: true,
    offset: 0,
    limit: _listMax,
  );

  final albums = await api.groups(GroupKind.album);
  final byName = {for (final a in albums) a.name.toLowerCase(): a};
  final recentAlbums = <LibraryGroup>[];
  for (final i in recent.items) {
    final a = byName[i.album?.toLowerCase()];
    if (a != null && !recentAlbums.contains(a)) recentAlbums.add(a);
    if (recentAlbums.length == 4) break;
  }

  return HomeData(
    resume: resume,
    lists: [
      if (most.isNotEmpty)
        AutoList(
          kind: AutoListKind.mostPlayed,
          items: most,
          count: most.length,
        ),
      if (recent.items.isNotEmpty)
        AutoList(
          kind: AutoListKind.recentlyAdded,
          items: recent.items,
          count: recent.items.length,
        ),
      if (favorites.items.isNotEmpty)
        AutoList(
          kind: AutoListKind.favorites,
          items: favorites.items,
          count: favorites.total.toInt(),
        ),
    ],
    recentAlbums: recentAlbums,
    isEmpty: history.isEmpty && recent.total == BigInt.zero,
  );
});

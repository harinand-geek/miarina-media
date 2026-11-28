import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/library.dart';
import '../cinema/cinema_data.dart';
import '../focus/focus_data.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../playback/listen_journal.dart';
import '../playback/playback_memory.dart';
import '../playback/smart_queue.dart';
import '../playback/taste.dart';
import 'home_data.dart';

/// Everything the phone's Music home shows (expressive redesign,
/// 2026-11-25), from the library, the play history and the listening
/// journal only. Each section is empty when there is nothing true to show.
@immutable
class PhoneHome {
  const PhoneHome({
    required this.recent,
    required this.mostPlayed,
    required this.recentAlbums,
    required this.artists,
    required this.mix,
    this.mixPart = 1,
    required this.neverPlayed,
    required this.favorites,
    required this.addedMonth,
    required this.discover,
    required this.randomAlbum,
    required this.week,
    required this.topArtist,
    required this.topArtistGroup,
    required this.history,
    required this.isEmpty,
  });

  /// Last things played, newest first (one per title), with their resume
  /// point when there is one.
  final List<ResumeItem> recent;
  final List<LibraryItem> mostPlayed;
  final List<LibraryGroup> recentAlbums;

  /// Artists by plays, then by number of titles.
  final List<LibraryGroup> artists;

  /// « Mix du jour »: 30 titles from the listener's taste (dailyMixPicks),
  /// the same all day, new ones tomorrow.
  final List<LibraryItem> mix;

  /// The part of the day the mix is made for ([dayPart]).
  final int mixPart;
  final int neverPlayed;
  final int favorites;
  final int addedMonth;

  /// Titles never played, shuffled for the day.
  final List<LibraryItem> discover;
  final LibraryGroup? randomAlbum;

  /// The last seven days (oldest first) and their seconds of music.
  final List<(DateTime, int)> week;
  final (String, int)? topArtist;
  final LibraryGroup? topArtistGroup;

  /// The three last plays with when they happened.
  final List<(LibraryItem, DateTime)> history;
  final bool isEmpty;

  int get weekSeconds => week.fold(0, (a, d) => a + d.$2);
  int get todaySeconds => week.isEmpty ? 0 : week.last.$2;
}

/// Seed of the day: the same picks from morning to night.
int daySeed(DateTime now) => now.year * 10000 + now.month * 100 + now.day;

/// [items] shuffled with [seed] (stable for a given seed and order).
List<T> seededShuffle<T>(List<T> items, int seed) =>
    List<T>.of(items)..shuffle(math.Random(seed));

/// The mix of the moment, its day and part of the day, kept so it stays
/// the same until the next part of the day although the taste moves.
const dailyMixKey = 'mm:dailyMix:v1';

Future<List<LibraryItem>> _dailyMix(
  Ref ref,
  List<LibraryItem> tracks,
  List<PlayEntry> plays,
  DateTime now,
) async {
  final store = ref.read(playbackStoreProvider);
  final day = ListenJournal.dayKey(now);
  final part = dayPart(now);
  final byId = {for (final t in tracks) t.id: t};
  try {
    final json = jsonDecode(await store.read(dailyMixKey) ?? '');
    if (json is Map &&
        json['day'] == day &&
        json['part'] == part &&
        json['ids'] is List) {
      final kept = [
        for (final id in json['ids'] as List)
          if (id is int && byId[id] != null) byId[id]!,
      ];
      if (kept.isNotEmpty && kept.length >= math.min(10, tracks.length)) {
        return kept;
      }
    }
  } catch (_) {}
  await ref.read(tasteProvider.notifier).ready();
  final mix = dailyMixPicks(
    library: tracks,
    taste: ref.read(tasteProvider),
    recentIds: [for (final p in plays) p.id],
    random: math.Random(daySeed(now) * 4 + part),
    now: now,
    part: part,
  );
  try {
    await store.write({
      dailyMixKey: jsonEncode({
        'day': day,
        'part': part,
        'ids': [for (final i in mix) i.id],
      }),
    });
  } catch (_) {}
  return mix;
}

final phoneHomeProvider = FutureProvider<PhoneHome>((ref) async {
  // Recomputed when another title starts: history and counts moved.
  ref.watch(queueProvider.select((q) => q.current?.libraryId));
  final api = ref.watch(libraryApiProvider);
  final memory = ref.watch(playbackMemoryProvider);
  final now = DateTime.now();
  final seed = daySeed(now);
  final plays = await memory.history();

  final recent = <ResumeItem>[];
  final history = <(LibraryItem, DateTime)>[];
  final seen = <int>{};
  final items = <int, LibraryItem?>{};
  Future<LibraryItem?> item(int id) async =>
      items.containsKey(id) ? items[id] : items[id] = await api.item(id);
  for (final e in plays) {
    if (recent.length >= 8 || !seen.add(e.id)) continue;
    final it = await item(e.id);
    if (it == null || it.missing) continue;
    if (history.length < 3) history.add((it, e.at));
    final at = await memory.savedPosition(e.id);
    final video = it.isVideo
        ? await ref.read(cinemaApiProvider).item(it.id)
        : null;
    final focus = it.isVideo
        ? null
        : await ref.read(focusApiProvider).entry(it.id);
    recent.add(ResumeItem(it, at ?? Duration.zero, video: video, focus: focus));
  }

  final most = <LibraryItem>[];
  for (final id in mostPlayedIds(plays).take(50)) {
    final it = await item(id);
    if (it != null && !it.missing && !it.isVideo) most.add(it);
  }

  final library = await api.tracks(
    search: '',
    favoritesOnly: false,
    offset: 0,
    limit: 1500,
  );
  final tracks = library.items.where((i) => !i.missing).toList();
  final never = await api.tracks(
    search: '',
    favoritesOnly: false,
    offset: 0,
    limit: 200,
    neverPlayed: true,
  );
  final favorites = await api.tracks(
    search: '',
    favoritesOnly: true,
    offset: 0,
    limit: 1,
  );
  final added = await api.tracks(
    search: '',
    favoritesOnly: false,
    offset: 0,
    limit: 1,
    addedSince: now.subtract(const Duration(days: 30)),
  );

  final albums = await api.groups(GroupKind.album);
  final artists = await api.groups(GroupKind.artist);
  final recentAlbums = [...albums]
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  final byPlays = [...artists]
    ..sort((a, b) {
      final p = b.plays.compareTo(a.plays);
      return p != 0 ? p : b.count.compareTo(a.count);
    });
  final withCover = albums.where((a) => a.thumbnail != null).toList();
  final pool = withCover.isNotEmpty ? withCover : albums;

  final journal = await memory.listenJournal();
  final top = journal.topArtist(now);
  LibraryGroup? topGroup;
  if (top != null) {
    final name = top.$1.toLowerCase();
    for (final a in artists) {
      if (a.name.toLowerCase() == name) topGroup = a;
    }
  }

  return PhoneHome(
    recent: recent,
    mostPlayed: most,
    recentAlbums: recentAlbums.take(8).toList(),
    artists: byPlays.take(8).toList(),
    mix: await _dailyMix(ref, tracks, plays, now),
    mixPart: dayPart(now),
    neverPlayed: never.total.toInt(),
    favorites: favorites.total.toInt(),
    addedMonth: added.total.toInt(),
    discover: seededShuffle(
      never.items.where((i) => !i.missing).toList(),
      seed,
    ),
    randomAlbum: pool.isEmpty
        ? null
        : pool[math.Random(seed).nextInt(pool.length)],
    week: journal.lastDays(now),
    topArtist: top,
    topArtistGroup: topGroup,
    history: history,
    isEmpty: tracks.isEmpty && recent.isEmpty,
  );
});

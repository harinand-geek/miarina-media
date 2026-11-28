import 'dart:math' as math;

import '../../src/rust/api/library.dart' show LibraryItem;
import 'playback.dart' show QueueEntry;
import 'taste.dart';

/// Smart shuffle, radio and automatic continuation (2026-11-28): pure
/// functions over the queue, the library and the [Taste] learnt on the
/// device, so they are tested without an engine.

/// What the algorithms compare between two tracks.
class TrackKey {
  const TrackKey({this.id, this.artist, this.album, this.folder});

  factory TrackKey.ofEntry(QueueEntry e) => TrackKey(
    id: e.libraryId,
    artist: _norm(e.subtitle),
    album: _norm(e.album),
    folder: e.source.uri.scheme == 'file'
        ? _folder(e.source.uri.toFilePath())
        : null,
  );

  factory TrackKey.ofItem(LibraryItem i) => TrackKey(
    id: i.id,
    artist: _norm(i.artist),
    album: _norm(i.album),
    folder: _folder(i.path),
  );

  final int? id;
  final String? artist;
  final String? album;
  final String? folder;

  static String? _norm(String? s) {
    final v = s?.trim().toLowerCase();
    return v == null || v.isEmpty ? null : v;
  }

  static String? _folder(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i <= 0 ? null : path.substring(0, i).toLowerCase();
  }
}

/// How much more (or less) often a track is drawn, from what the listener
/// did with it: liked ×1.5 to ×3, often passed ×0.25, heard in the last
/// [recentGap] ×0.3, favourite ×1.4.
double tasteWeight(
  Taste taste,
  int? id,
  DateTime now, {
  bool favorite = false,
  Duration recentGap = const Duration(hours: 3),
}) {
  if (id == null) return favorite ? 1.4 : 1;
  final s = taste.score(id, now).clamp(-4.0, 3.0);
  var w = math.exp(0.35 * s);
  if (favorite) w *= 1.4;
  final last = taste.lastPlayed(id);
  if (last != null && now.difference(last) < recentGap) w *= 0.3;
  return w;
}

/// A random order of [weights.length] items where heavier ones tend to come
/// first (Efraimidis–Spirakis: key = u^(1/w)).
List<int> weightedOrder(List<double> weights, math.Random random) {
  final keys = [
    for (final w in weights)
      math.pow(1 - random.nextDouble(), 1 / math.max(w, 1e-6)).toDouble(),
  ];
  return List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) => keys[b].compareTo(keys[a]));
}

/// Reorders [order] so the same artist (or album) does not come twice in a
/// row when another choice exists within the next [lookahead] items; at
/// most [maxRun] of one artist follow each other.
List<int> spreadArtists(
  List<int> order,
  List<TrackKey> keys, {
  int lookahead = 8,
  int maxRun = 1,
  TrackKey? before,
}) {
  final pending = List.of(order);
  final out = <int>[];
  var run = before?.artist != null ? 1 : 0;
  String? lastArtist = before?.artist;
  String? lastAlbum = before?.album;
  while (pending.isNotEmpty) {
    int pick;
    // One artist with more tracks left than all the others plus one would
    // end up in a row at the end: it goes now (when it may).
    final counts = <String, int>{};
    for (final j in pending) {
      final a = keys[j].artist;
      if (a != null) counts[a] = (counts[a] ?? 0) + 1;
    }
    String? crowded;
    for (final e in counts.entries) {
      if (e.value * 2 > pending.length) crowded = e.key;
    }
    if (crowded != null && (crowded != lastArtist || run < maxRun)) {
      final chosen = pending.removeAt(
        pending.indexWhere((j) => keys[j].artist == crowded),
      );
      run = crowded == lastArtist ? run + 1 : 1;
      lastArtist = crowded;
      lastAlbum = keys[chosen].album;
      out.add(chosen);
      continue;
    }
    bool fits(int j) {
      final k = keys[j];
      final sameArtist = k.artist != null && k.artist == lastArtist;
      final sameAlbum = k.album != null && k.album == lastAlbum;
      return (!sameArtist || run < maxRun) && !sameAlbum;
    }

    // The draw's order is kept as much as possible: the first that fits
    // among the next few, else further, else the next one anyway.
    var near = -1;
    for (var i = 0; i < pending.length && i < lookahead; i++) {
      if (fits(pending[i])) {
        near = i;
        break;
      }
    }
    pick = near >= 0 ? near : math.max(0, pending.indexWhere(fits));
    final chosen = pending.removeAt(pick);
    final k = keys[chosen];
    run = k.artist != null && k.artist == lastArtist ? run + 1 : 1;
    lastArtist = k.artist;
    lastAlbum = k.album;
    out.add(chosen);
  }
  return out;
}

/// Smart shuffle of [entries] starting with [first]: liked tracks come
/// sooner, often passed ones later, the last heard ones near the end; never
/// the same artist or album twice in a row when it can be helped.
List<int> smartShuffleOrder(
  List<QueueEntry> entries, {
  required int first,
  required Taste taste,
  required math.Random random,
  required DateTime now,
}) {
  final rest = [
    for (var i = 0; i < entries.length; i++)
      if (i != first) i,
  ];
  final weights = [
    for (final i in rest)
      tasteWeight(
        taste,
        entries[i].libraryId,
        now,
        favorite: entries[i].favorite,
      ),
  ];
  final drawn = [for (final j in weightedOrder(weights, random)) rest[j]];
  final keys = [for (final e in entries) TrackKey.ofEntry(e)];
  final spread = spreadArtists(
    drawn,
    keys,
    before: first >= 0 && first < entries.length ? keys[first] : null,
  );
  return [if (first >= 0 && first < entries.length) first, ...spread];
}

/// How close [c] is to the [seeds]: same artist, same album, same folder,
/// and above all heard together before (co-listening).
double similarity(List<TrackKey> seeds, TrackKey c, Taste taste) {
  var best = 0.0;
  var together = 0.0;
  for (final s in seeds) {
    var v = 0.0;
    if (s.artist != null && s.artist == c.artist) v += 3;
    if (s.album != null && s.album == c.album) v += 1.2;
    if (s.folder != null && s.folder == c.folder) v += 0.6;
    best = math.max(best, v);
    if (s.id != null && c.id != null) together += taste.together(s.id!, c.id!);
  }
  // 1 time together ≈ 0.8, 3 times ≈ 1.5, toward 2.5.
  return best + 2.5 * together / (together + 2);
}

/// [count] tracks of [library] for a radio started from [seeds] (the most
/// recent first): close ones mostly, a few further ones for discovery,
/// weighted by taste, none of [exclude], at most two of one artist in a row.
List<LibraryItem> radioPicks({
  required List<TrackKey> seeds,
  required List<LibraryItem> library,
  required Taste taste,
  required math.Random random,
  required DateTime now,
  Set<int> exclude = const {},
  int count = 25,
}) {
  final pool = [
    for (final i in library)
      if (!i.isVideo && !i.missing && !exclude.contains(i.id)) i,
  ];
  if (pool.isEmpty || count <= 0) return const [];
  final keys = [for (final i in pool) TrackKey.ofItem(i)];
  final weights = [
    for (var j = 0; j < pool.length; j++)
      (0.15 + similarity(seeds, keys[j], taste)) *
          tasteWeight(taste, pool[j].id, now, favorite: pool[j].favorite),
  ];
  final drawn = weightedOrder(weights, random).take(count).toList();
  final spread = spreadArtists(
    drawn,
    keys,
    maxRun: 2,
    before: seeds.isEmpty ? null : seeds.first,
  );
  return [for (final j in spread) pool[j]];
}

/// « Mix du jour » (2026-11-28, proposal 3): [count] tracks of [library]
/// made of what the listener loves (half), tracks close to what was heard
/// lately (a third: [recentIds], newest first) and forgotten favourites
/// (liked, a favourite or played often, but not heard for 45 days), mixed
/// with no artist twice in a row. With nothing learnt yet, favourites and
/// plays lead, then chance.
List<LibraryItem> dailyMixPicks({
  required List<LibraryItem> library,
  required Taste taste,
  required List<int> recentIds,
  required math.Random random,
  required DateTime now,
  int count = 30,
}) {
  final pool = [
    for (final i in library)
      if (!i.isVideo && !i.missing) i,
  ];
  if (pool.isEmpty) return const [];
  final chosen = <int>{};
  final out = <LibraryItem>[];

  void takeWeighted(List<LibraryItem> from, List<double> weights, int n) {
    for (final j in weightedOrder(weights, random)) {
      if (n <= 0) return;
      if (chosen.add(from[j].id)) {
        out.add(from[j]);
        n--;
      }
    }
  }

  double loved(LibraryItem i) =>
      tasteWeight(
        taste,
        i.id,
        now,
        favorite: i.favorite,
        recentGap: const Duration(hours: 12),
      ) *
      (1 + 0.5 * math.log(1 + i.plays));

  // Forgotten favourites first (they are few), then close, then loved.
  final heardLately = recentIds.toSet();
  final forgotten = [
    for (final i in pool)
      if ((taste.score(i.id, now) > 0.5 || i.favorite || i.plays >= 3) &&
          !heardLately.contains(i.id) &&
          (taste.lastPlayed(i.id) == null ||
              now.difference(taste.lastPlayed(i.id)!).inDays >= 45))
        i,
  ];
  takeWeighted(forgotten, [for (final i in forgotten) loved(i)], count ~/ 5);

  final byId = {for (final i in pool) i.id: i};
  final seeds = [
    for (final id in recentIds.take(5))
      if (byId[id] case final i?) TrackKey.ofItem(i),
  ];
  if (seeds.isNotEmpty) {
    for (final i in radioPicks(
      seeds: seeds,
      library: pool,
      taste: taste,
      random: random,
      now: now,
      exclude: {...chosen, ...recentIds.take(5)},
      count: count ~/ 3,
    )) {
      if (chosen.add(i.id)) out.add(i);
    }
  }
  takeWeighted(pool, [for (final i in pool) loved(i)], count - out.length);

  final keys = [for (final i in out) TrackKey.ofItem(i)];
  final mixed = weightedOrder(List.filled(out.length, 1.0), random);
  return [for (final j in spreadArtists(mixed, keys)) out[j]];
}

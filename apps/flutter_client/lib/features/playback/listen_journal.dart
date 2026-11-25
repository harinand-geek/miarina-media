import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Listening journal (phone home, 2026-11-25): music seconds really heard,
/// per local day and per artist, for « 7 derniers jours » and « Artiste de
/// la semaine ». Kept on the device in the playback store, 35 days at most;
/// podcasts, courses, books and videos are not counted.
const listenJournalKey = 'mm:listenJournal:v1';

/// Days kept.
const listenJournalDays = 35;

/// Artists kept per day (the others still count in the day's total).
const _artistsPerDay = 40;

@immutable
class ListenDay {
  const ListenDay(this.seconds, this.artists);

  final int seconds;
  final Map<String, int> artists;
}

@immutable
class ListenJournal {
  const ListenJournal(this.days);

  /// "2026-11-25" → day.
  final Map<String, ListenDay> days;

  static const empty = ListenJournal({});

  static String dayKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';

  static ListenJournal parse(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      final days = <String, ListenDay>{};
      for (final e in json.entries) {
        final v = e.value;
        if (e.key is! String || v is! Map) continue;
        final secs = v['s'];
        final artists = <String, int>{};
        final a = v['a'];
        if (a is Map) {
          for (final x in a.entries) {
            if (x.key is String && x.value is int && x.value > 0) {
              artists[x.key as String] = x.value as int;
            }
          }
        }
        if (secs is int && secs > 0) {
          days[e.key as String] = ListenDay(secs, artists);
        }
      }
      return ListenJournal(days);
    } catch (_) {
      return empty;
    }
  }

  String encode() => jsonEncode({
    for (final e in days.entries)
      e.key: {'s': e.value.seconds, 'a': e.value.artists},
  });

  /// [seconds] more heard on [now]'s day, by [artist] when known; days older
  /// than [listenJournalDays] are dropped.
  ListenJournal add(DateTime now, int seconds, {String? artist}) {
    if (seconds <= 0) return this;
    final key = dayKey(now);
    final day = days[key] ?? const ListenDay(0, {});
    final artists = Map<String, int>.of(day.artists);
    final name = artist?.trim();
    if (name != null && name.isNotEmpty) {
      artists[name] = (artists[name] ?? 0) + seconds;
      if (artists.length > _artistsPerDay) {
        final sorted = artists.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        artists
          ..clear()
          ..addEntries(sorted.take(_artistsPerDay));
      }
    }
    final oldest = dayKey(
      now.subtract(const Duration(days: listenJournalDays)),
    );
    final next = <String, ListenDay>{
      for (final e in days.entries)
        if (e.key.compareTo(oldest) > 0) e.key: e.value,
    };
    next[key] = ListenDay(day.seconds + seconds, artists);
    return ListenJournal(next);
  }

  /// The last [count] days up to [now], oldest first, with their seconds
  /// (0 when nothing was heard).
  List<(DateTime, int)> lastDays(DateTime now, {int count = 7}) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return (d, days[dayKey(d)]?.seconds ?? 0);
        }(),
    ];
  }

  /// The artist heard the most over the last [count] days, with seconds.
  (String, int)? topArtist(DateTime now, {int count = 7}) {
    final totals = <String, int>{};
    for (final (d, _) in lastDays(now, count: count)) {
      final day = days[dayKey(d)];
      if (day == null) continue;
      for (final e in day.artists.entries) {
        totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    if (totals.isEmpty) return null;
    final best = totals.entries.reduce((a, b) => b.value > a.value ? b : a);
    return (best.key, best.value);
  }
}

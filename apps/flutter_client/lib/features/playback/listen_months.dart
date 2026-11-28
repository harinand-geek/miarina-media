import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Monthly listening recap (2026-11-28, decision 0013 proposal 10): music
/// seconds really heard per month, per day of the month, per artist and
/// per library track, kept [listenMonthsKept] months on the device (the
/// daily journal only keeps 35 days). Written with the journal.
const listenMonthsKey = 'mm:listenMonths:v1';

const listenMonthsKept = 24;
const _artistsPerMonth = 50;
const _tracksPerMonth = 100;

@immutable
class ListenMonth {
  const ListenMonth({
    required this.seconds,
    required this.days,
    required this.artists,
    required this.tracks,
  });

  final int seconds;

  /// Day of the month (1..31) → seconds.
  final Map<int, int> days;
  final Map<String, int> artists;

  /// Library id → seconds.
  final Map<int, int> tracks;

  static const empty = ListenMonth(
    seconds: 0,
    days: {},
    artists: {},
    tracks: {},
  );

  /// Most heard first.
  List<MapEntry<String, int>> get topArtists =>
      artists.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  List<MapEntry<int, int>> get topTracks =>
      tracks.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  int get activeDays => days.values.where((s) => s > 0).length;

  /// The day heard the most, with its seconds.
  MapEntry<int, int>? get bestDay => days.isEmpty
      ? null
      : days.entries.reduce((a, b) => b.value > a.value ? b : a);
}

@immutable
class ListenMonths {
  const ListenMonths(this.months);

  /// "2026-11" → month.
  final Map<String, ListenMonth> months;

  static const empty = ListenMonths({});

  static String monthKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}';

  /// The first day of a [monthKey].
  static DateTime? monthOf(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    return y == null || m == null ? null : DateTime(y, m);
  }

  /// Months with music heard, newest first.
  List<String> get keys => [
    for (final e in months.entries)
      if (e.value.seconds > 0) e.key,
  ]..sort((a, b) => b.compareTo(a));

  ListenMonth operator [](String key) => months[key] ?? ListenMonth.empty;

  /// [seconds] more heard at [now], by [artist] and of the library track
  /// [trackId] when known; months beyond [listenMonthsKept] are dropped.
  ListenMonths add(DateTime now, int seconds, {String? artist, int? trackId}) {
    if (seconds <= 0) return this;
    final key = monthKey(now);
    final m = months[key] ?? ListenMonth.empty;
    final days = Map<int, int>.of(m.days);
    days[now.day] = (days[now.day] ?? 0) + seconds;
    final artists = Map<String, int>.of(m.artists);
    final name = artist?.trim();
    if (name != null && name.isNotEmpty) {
      artists[name] = (artists[name] ?? 0) + seconds;
      _keepTop(artists, _artistsPerMonth);
    }
    final tracks = Map<int, int>.of(m.tracks);
    if (trackId != null) {
      tracks[trackId] = (tracks[trackId] ?? 0) + seconds;
      _keepTop(tracks, _tracksPerMonth);
    }
    final next = Map<String, ListenMonth>.of(months)
      ..[key] = ListenMonth(
        seconds: m.seconds + seconds,
        days: days,
        artists: artists,
        tracks: tracks,
      );
    if (next.length > listenMonthsKept) {
      final sorted = next.keys.toList()..sort();
      for (final k in sorted.take(next.length - listenMonthsKept)) {
        next.remove(k);
      }
    }
    return ListenMonths(next);
  }

  static void _keepTop<K>(Map<K, int> map, int keep) {
    if (map.length <= keep) return;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    map
      ..clear()
      ..addEntries(sorted.take(keep));
  }

  static ListenMonths parse(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      Map<K, int> ints<K>(Object? v, K? Function(String) key) {
        final out = <K, int>{};
        if (v is Map) {
          for (final e in v.entries) {
            final k = key('${e.key}');
            if (k != null && e.value is int && e.value > 0) {
              out[k] = e.value as int;
            }
          }
        }
        return out;
      }

      final months = <String, ListenMonth>{};
      for (final e in json.entries) {
        final v = e.value;
        if (e.key is! String || v is! Map || v['s'] is! int) continue;
        months[e.key as String] = ListenMonth(
          seconds: v['s'] as int,
          days: ints(v['d'], int.tryParse),
          artists: ints(v['a'], (k) => k),
          tracks: ints(v['t'], int.tryParse),
        );
      }
      return ListenMonths(months);
    } catch (_) {
      return empty;
    }
  }

  String encode() => jsonEncode({
    for (final e in months.entries)
      e.key: {
        's': e.value.seconds,
        'd': {for (final d in e.value.days.entries) '${d.key}': d.value},
        'a': e.value.artists,
        't': {for (final x in e.value.tracks.entries) '${x.key}': x.value},
      },
  });
}

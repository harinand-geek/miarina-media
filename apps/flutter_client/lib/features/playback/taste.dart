import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback_memory.dart';

/// What the listener seems to like, learnt on the device from how tracks
/// end (2026-11-28, owner's « algorithmes avancés »): a track heard to the
/// end gains, one passed in its first seconds loses; tracks heard one after
/// the other in a session become neighbours. Read by the smart shuffle, the
/// radio and the automatic continuation; nothing leaves the device.
///
/// Stored in the playback store under [tasteKey]:
/// per track id `[score, scoreAtMs, lastPlayedMs, parts]` under "t" (parts:
/// listens heard to the end at night, in the morning, the afternoon and the
/// evening), and neighbours with their weights under "n".
const tasteKey = 'mm:taste:v1';

/// A score halves in this time without new signals: old habits fade.
const tasteHalfLife = Duration(days: 45);

/// Gained by a track heard to the end, lost by one passed quickly.
const finishedGain = 1.0;
const skippedLoss = 1.0;

/// Scores stay within these bounds (a few signals already tell a lot).
const _minScore = -5.0, _maxScore = 10.0;

/// Tracks remembered; beyond, the least telling ones are forgotten.
const _maxTracks = 3000;

/// Tracks with neighbours, and neighbours per track.
const _maxLinked = 800;
const _maxNeighbours = 16;

/// Part of the day: 0 night (0–6 h), 1 morning (6–12 h), 2 afternoon
/// (12–18 h), 3 evening (18–24 h).
int dayPart(DateTime local) => local.hour ~/ 6;

@immutable
class TrackTaste {
  const TrackTaste(
    this.score,
    this.scoreAt,
    this.lastPlayed, [
    this.parts = const [0, 0, 0, 0],
  ]);

  /// Times heard to the end in each [dayPart].
  final List<int> parts;

  /// Score as it was at [scoreAt]; see [Taste.score] for today's.
  final double score;
  final DateTime scoreAt;
  final DateTime? lastPlayed;
}

@immutable
class Taste {
  const Taste(this.tracks, this.neighbours);

  final Map<int, TrackTaste> tracks;

  /// Co-listening: how often two tracks were heard to the end in the same
  /// session, one after the other (both ways).
  final Map<int, Map<int, double>> neighbours;

  static const empty = Taste({}, {});

  /// Score of [id] at [now], faded by [tasteHalfLife]; 0 when unknown.
  double score(int id, DateTime now) {
    final t = tracks[id];
    if (t == null) return 0;
    return _decayed(t.score, t.scoreAt, now);
  }

  DateTime? lastPlayed(int id) => tracks[id]?.lastPlayed;

  /// The share (0..1) of [id]'s full listens made in [part] of the day; 0
  /// when never heard to the end.
  double partShare(int id, int part) {
    final p = tracks[id]?.parts;
    if (p == null) return 0;
    final total = p.fold(0, (a, b) => a + b);
    return total == 0 ? 0 : p[part] / total;
  }

  /// How strongly [a] and [b] go together (0 when never heard together).
  double together(int a, int b) => neighbours[a]?[b] ?? 0;

  static double _decayed(double score, DateTime at, DateTime now) {
    final days = now.difference(at).inMinutes / (24 * 60);
    if (days <= 0) return score;
    return score * math.pow(0.5, days / tasteHalfLife.inDays).toDouble();
  }

  Taste _withScore(int id, DateTime now, double delta, {bool full = false}) {
    final before = tracks[id];
    final value = (score(id, now) + delta).clamp(_minScore, _maxScore);
    final next = Map<int, TrackTaste>.of(tracks)
      ..[id] = TrackTaste(value.toDouble(), now, before?.lastPlayed, [
        for (var i = 0; i < 4; i++)
          (before?.parts[i] ?? 0) + (full && i == dayPart(now) ? 1 : 0),
      ]);
    return Taste(_bounded(next, now), neighbours);
  }

  /// [id] heard to the end at [now]; [after], heard to the end just before
  /// in the same session, becomes its neighbour.
  Taste finished(int id, DateTime now, {int? after}) {
    var next = _withScore(id, now, finishedGain, full: true);
    if (after != null && after != id) next = next._linked(after, id);
    return next;
  }

  /// [id] passed in its first seconds at [now].
  Taste skipped(int id, DateTime now) => _withScore(id, now, -skippedLoss);

  /// [id] started at [now] (the shuffle and the radio avoid it for a while).
  Taste started(int id, DateTime now) {
    final before = tracks[id];
    final next = Map<int, TrackTaste>.of(tracks)
      ..[id] = TrackTaste(
        before?.score ?? 0,
        before?.scoreAt ?? now,
        now,
        before?.parts ?? const [0, 0, 0, 0],
      );
    return Taste(_bounded(next, now), neighbours);
  }

  Taste _linked(int a, int b) {
    final next = {
      for (final e in neighbours.entries) e.key: Map<int, double>.of(e.value),
    };
    void add(int x, int y) {
      final m = next.putIfAbsent(x, () => {});
      m[y] = (m[y] ?? 0) + 1;
      if (m.length > _maxNeighbours) {
        final weakest = m.entries.reduce((p, q) => q.value < p.value ? q : p);
        m.remove(weakest.key);
      }
    }

    add(a, b);
    add(b, a);
    if (next.length > _maxLinked) {
      double weight(Map<int, double> m) => m.values.fold(0.0, (s, v) => s + v);
      final sorted = next.entries.toList()
        ..sort((p, q) => weight(p.value).compareTo(weight(q.value)));
      for (final e in sorted.take(next.length - _maxLinked)) {
        next.remove(e.key);
      }
    }
    return Taste(tracks, next);
  }

  /// At most [_maxTracks]: the least telling (score near 0, not played for
  /// the longest) go first.
  static Map<int, TrackTaste> _bounded(
    Map<int, TrackTaste> tracks,
    DateTime now,
  ) {
    if (tracks.length <= _maxTracks) return tracks;
    double telling(TrackTaste t) =>
        _decayed(t.score, t.scoreAt, now).abs() +
        (t.lastPlayed != null && now.difference(t.lastPlayed!).inDays < 7
            ? 1
            : 0);
    final sorted = tracks.entries.toList()
      ..sort((a, b) => telling(a.value).compareTo(telling(b.value)));
    return Map.fromEntries(sorted.skip(tracks.length - _maxTracks));
  }

  static Taste parse(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      final tracks = <int, TrackTaste>{};
      final t = json['t'];
      if (t is Map) {
        for (final e in t.entries) {
          final id = int.tryParse('${e.key}');
          final v = e.value;
          if (id == null || v is! List || v.length < 3) continue;
          final score = v[0], at = v[1], last = v[2];
          if (score is! num || at is! num) continue;
          final parts = v.length > 3 ? v[3] : null;
          tracks[id] = TrackTaste(
            score.toDouble().clamp(_minScore, _maxScore),
            DateTime.fromMillisecondsSinceEpoch(at.toInt()),
            last is num
                ? DateTime.fromMillisecondsSinceEpoch(last.toInt())
                : null,
            parts is List &&
                    parts.length == 4 &&
                    parts.every((x) => x is int && x >= 0)
                ? List<int>.from(parts)
                : const [0, 0, 0, 0],
          );
        }
      }
      final neighbours = <int, Map<int, double>>{};
      final n = json['n'];
      if (n is Map) {
        for (final e in n.entries) {
          final id = int.tryParse('${e.key}');
          final v = e.value;
          if (id == null || v is! Map) continue;
          final m = <int, double>{};
          for (final x in v.entries) {
            final other = int.tryParse('${x.key}');
            if (other != null && x.value is num && x.value > 0) {
              m[other] = (x.value as num).toDouble();
            }
          }
          if (m.isNotEmpty) neighbours[id] = m;
        }
      }
      return Taste(tracks, neighbours);
    } catch (_) {
      return empty;
    }
  }

  String encode() => jsonEncode({
    't': {
      for (final e in tracks.entries)
        '${e.key}': [
          double.parse(e.value.score.toStringAsFixed(3)),
          e.value.scoreAt.millisecondsSinceEpoch,
          e.value.lastPlayed?.millisecondsSinceEpoch,
          e.value.parts,
        ],
    },
    'n': {
      for (final e in neighbours.entries)
        '${e.key}': {for (final x in e.value.entries) '${x.key}': x.value},
    },
  });
}

final tasteProvider = NotifierProvider<TasteController, Taste>(
  TasteController.new,
);

/// The taste, read once from the store, then kept in memory and written
/// after each change.
class TasteController extends Notifier<Taste> {
  Future<void>? _loading;

  @override
  Taste build() {
    _loading = _load();
    return Taste.empty;
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(playbackStoreProvider).read(tasteKey);
      final stored = Taste.parse(raw);
      // Signals noted before the store answered are kept on top.
      if (identical(state, Taste.empty)) state = stored;
    } catch (_) {}
  }

  /// Waits for the stored taste (tests, and a first use right at launch).
  Future<void> ready() => _loading ?? Future.value();

  Future<void> _update(Taste Function(Taste) change) async {
    await ready();
    state = change(state);
    try {
      await ref.read(playbackStoreProvider).write({tasteKey: state.encode()});
    } catch (_) {}
  }

  Future<void> finished(int id, {int? after}) =>
      _update((t) => t.finished(id, DateTime.now(), after: after));

  Future<void> skipped(int id) => _update((t) => t.skipped(id, DateTime.now()));

  Future<void> started(int id) => _update((t) => t.started(id, DateTime.now()));
}

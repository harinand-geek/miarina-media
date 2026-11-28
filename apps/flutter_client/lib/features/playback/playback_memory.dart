import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/media_engine.dart';
import '../../src/rust/api/settings.dart';
import '../library/library_data.dart';
import 'listen_journal.dart';
import 'listen_months.dart';
import 'playback.dart';
import 'taste.dart';

/// Resume positions and play history, stored exactly like the 0.1.x app
/// (apps/client usePlayback.ts, recentPlays.ts) so both read the same data:
/// `mm:position:<id>` = whole seconds, `mm:playHistory:v1` = newest-first
/// JSON list of at most 200 plays, `mm:resume` = "0" when resuming is off.
abstract interface class PlaybackStore {
  Future<String?> read(String key);
  Future<void> write(Map<String, String?> changes);
}

class RustPlaybackStore implements PlaybackStore {
  RustPlaybackStore(this._ref);

  final Ref _ref;

  @override
  Future<String?> read(String key) async =>
      playbackGet(dbPath: await _ref.read(dbPathProvider.future), key: key);

  @override
  Future<void> write(Map<String, String?> changes) async => playbackSet(
    dbPath: await _ref.read(dbPathProvider.future),
    changes: [for (final e in changes.entries) (e.key, e.value)],
  );
}

final playbackStoreProvider = Provider<PlaybackStore>(RustPlaybackStore.new);

const historyKey = 'mm:playHistory:v1';
const resumeKey = 'mm:resume';
String positionKey(int id) => 'mm:position:$id';

/// Closer than this to the start or the end, no resume point is kept.
const resumeMargin = Duration(seconds: 5);
const historyMax = 200;

/// A new play of the latest entry within this delay is the same play.
const samePlay = Duration(hours: 6);

@immutable
class PlayEntry {
  const PlayEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.at,
    this.position = 0,
    this.duration = 0,
  });

  final int id;
  final String title;

  /// "audio" or "video", as in the 0.1.x records.
  final String kind;
  final DateTime at;

  /// Seconds.
  final int position;
  final double duration;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'at': at.millisecondsSinceEpoch,
    'position': position,
    'duration': duration,
  };

  static PlayEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final at = raw['at'];
    if (id is! int || title is! String || at is! num) return null;
    return PlayEntry(
      id: id,
      title: title,
      kind: raw['kind'] == 'video' ? 'video' : 'audio',
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      position: (raw['position'] is num) ? (raw['position'] as num).floor() : 0,
      duration: (raw['duration'] is num)
          ? (raw['duration'] as num).toDouble()
          : 0,
    );
  }

  PlayEntry withPosition(int seconds) => PlayEntry(
    id: id,
    title: title,
    kind: kind,
    at: at,
    position: seconds,
    duration: duration,
  );
}

List<PlayEntry> parseHistory(String? text) {
  if (text == null || text.isEmpty) return const [];
  try {
    final raw = jsonDecode(text);
    if (raw is! List) return const [];
    return [for (final e in raw) ?PlayEntry.fromJson(e)];
  } on FormatException {
    return const [];
  }
}

/// History after starting [entry] at [now] (the 0.1.x notePlayed rules).
List<PlayEntry> notePlayed(List<PlayEntry> history, PlayEntry entry) {
  final latest = history.firstOrNull;
  if (latest != null &&
      latest.id == entry.id &&
      entry.at.difference(latest.at) < samePlay) {
    return history;
  }
  return [entry, ...history].take(historyMax).toList();
}

/// History after the latest play of [id] stopped at [seconds].
List<PlayEntry> noteStopped(List<PlayEntry> history, int id, int seconds) {
  final i = history.indexWhere((e) => e.id == id);
  if (i < 0) return history;
  return [...history]..[i] = history[i].withPosition(seconds < 0 ? 0 : seconds);
}

/// The value to store for a resume point, or null to forget it.
String? resumeValue(Duration position, Duration duration) {
  if (position < resumeMargin || duration - position < resumeMargin) {
    return null;
  }
  return '${position.inSeconds}';
}

final playbackMemoryProvider = Provider<PlaybackMemory>((ref) {
  final memory = PlaybackMemory(ref);
  ref.onDispose(memory.dispose);
  return memory;
});

/// Follows the engine: records plays, saves resume points every 5 s of
/// playback and on pause / end / track change, and gives the start position
/// when a track is opened again.
class PlaybackMemory {
  PlaybackMemory(this._ref) {
    final engine = _ref.read(mediaEngineProvider);
    _sub = engine?.snapshots.listen(_onSnapshot);
  }

  final Ref _ref;
  StreamSubscription<PlaybackSnapshot>? _sub;
  int? _currentId;
  Uri? _currentUri;
  Duration _savedAt = Duration.zero;
  PlaybackSnapshot? _last;

  /// Listening journal: whether the current file is music that counts, its
  /// artist, and the time heard not yet written. Measured on the clock while
  /// the engine says it plays: Media3 does not send positions as they move,
  /// only states, so positions cannot measure it (2026-11-25 fix).
  bool _counts = false;
  String? _artist;
  final _clock = Stopwatch();
  int _carryMs = 0;
  Timer? _journalTick;

  /// Taste (taste.dart): whether the current file is library music, its
  /// length, the time really heard of it, and whether it was judged already
  /// (heard to the end, or passed quickly).
  bool _music = false;
  Duration? _currentDuration;
  int _trackHeardMs = 0;
  bool _judged = false;

  /// The last track heard to the end, which the next one heard to the end
  /// in the same session becomes the neighbour of.
  int? _lastFinishedId;
  DateTime? _lastFinishedAt;

  /// Two tracks heard to the end this close are of the same session.
  static const _session = Duration(minutes: 20);

  /// Time really heard: the clock runs while the music plays.
  void _syncClock(PlaybackSnapshot s) {
    final hearing =
        _counts &&
        s.isPlaying &&
        !s.buffering &&
        s.status != PlaybackStatus.ended;
    if (hearing && !_clock.isRunning) {
      _clock.start();
      _journalTick?.cancel();
      _journalTick = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_writeJournal()),
      );
    } else if (!hearing && _clock.isRunning) {
      _clock.stop();
      _journalTick?.cancel();
      unawaited(_writeJournal());
    }
  }

  /// Seconds heard since the last call; the rest is kept for the next one.
  int _takeHeard() {
    _trackHeardMs += _clock.elapsedMilliseconds;
    final ms = _clock.elapsedMilliseconds + _carryMs;
    _clock.reset();
    final secs = ms ~/ 1000;
    _carryMs = ms - secs * 1000;
    return secs;
  }

  /// Writes what was heard to the journal (every 30 s while playing, so a
  /// killed app loses at most that).
  Future<void> _writeJournal() async {
    final heard = _takeHeard();
    if (heard <= 0) return;
    final now = DateTime.now();
    final journal = (await listenJournal())
        .add(now, heard, artist: _artist)
        .encode();
    await _write({
      listenJournalKey: journal,
      listenMonthsKey: await _monthsWith(now, heard),
    });
  }

  // The store refuses nothing that matters here; a failed write only loses
  // a resume point.
  Future<void> _write(Map<String, String?> changes) async {
    try {
      await _ref.read(playbackStoreProvider).write(changes);
    } catch (_) {}
  }

  Future<List<PlayEntry>> history() async {
    try {
      return parseHistory(
        await _ref.read(playbackStoreProvider).read(historyKey),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<bool> resumeEnabled() async {
    try {
      return await _ref.read(playbackStoreProvider).read(resumeKey) != '0';
    } catch (_) {
      return true;
    }
  }

  Future<Duration?> savedPosition(int id) async {
    try {
      final v = int.tryParse(
        await _ref.read(playbackStoreProvider).read(positionKey(id)) ?? '',
      );
      return v == null || v <= 0 ? null : Duration(seconds: v);
    } catch (_) {
      return null;
    }
  }

  /// Where to start [entry]: its resume point, unless resuming is off.
  Future<Duration?> startFor(QueueEntry entry) async {
    final id = entry.libraryId;
    if (id == null || !await resumeEnabled()) return null;
    return savedPosition(id);
  }

  /// Heard to the end (80 % of it, or the engine said it ended), or passed
  /// by the listener ([skipped]: « suivant ») in its first 30 s or first
  /// half: the taste learns it. Anything else says nothing.
  void _judge({required bool skipped}) {
    final id = _currentId;
    if (id == null || !_music || _judged) return;
    final heard = _trackHeardMs + _clock.elapsedMilliseconds;
    final length =
        (_currentDuration ?? _last?.duration ?? Duration.zero).inMilliseconds;
    if (length > 0 && heard >= length * 0.8) {
      _finished(id);
    } else if (skipped &&
        heard < (length > 0 ? math.min(30000, length * 0.5) : 30000)) {
      _judged = true;
      unawaited(_ref.read(tasteProvider.notifier).skipped(id));
    }
  }

  void _finished(int id) {
    _judged = true;
    final now = DateTime.now();
    final last = _lastFinishedAt;
    final after = last != null && now.difference(last) < _session
        ? _lastFinishedId
        : null;
    _lastFinishedId = id;
    _lastFinishedAt = now;
    unawaited(_ref.read(tasteProvider.notifier).finished(id, after: after));
  }

  /// Called by the queue when [entry] starts; [skipped]: the listener
  /// passed the previous one (« suivant », a track of the queue chosen).
  Future<void> started(QueueEntry entry, {bool skipped = false}) async {
    await _flush();
    _judge(skipped: skipped);
    _music =
        entry.libraryId != null && !entry.isVideo && entry.focusKey == null;
    _currentDuration = entry.duration;
    _trackHeardMs = 0;
    _judged = false;
    if (_music) {
      unawaited(_ref.read(tasteProvider.notifier).started(entry.libraryId!));
    }
    _currentId = entry.libraryId;
    _currentUri = entry.source.uri;
    _savedAt = Duration.zero;
    _clock
      ..stop()
      ..reset();
    _carryMs = 0;
    _journalTick?.cancel();
    _counts = false;
    _artist = null;
    final id = entry.libraryId;
    if (id == null) {
      // Online listening (decision 0011): music heard counts in the journal
      // (« 7 derniers jours », « Artiste de la semaine »), its artist being
      // the channel. No history or resume point: it is not in the library.
      if (entry.onlineId != null && !entry.isVideo) {
        _counts = true;
        _artist = entry.subtitle;
        final now = _ref.read(mediaEngineProvider)?.current;
        if (now != null && now.source?.uri == _currentUri) _syncClock(now);
      }
      return;
    }
    if (!entry.isVideo && entry.focusKey == null) {
      _counts = true;
      try {
        _artist = (await _ref.read(libraryApiProvider).item(id))?.artist;
      } catch (_) {}
      // The engine may already have said it plays (states come once).
      final now = _ref.read(mediaEngineProvider)?.current;
      if (now != null && now.source?.uri == _currentUri) _syncClock(now);
    }
    final kind = entry.isVideo ? 'video' : 'audio';
    final before = await history();
    final next = notePlayed(
      before,
      PlayEntry(
        id: id,
        title: entry.title,
        kind: kind,
        at: DateTime.now(),
        duration: (entry.duration?.inMilliseconds ?? 0) / 1000,
      ),
    );
    await _write({
      historyKey: jsonEncode([for (final e in next) e.toJson()]),
    });
    // A new play (not the same one resumed): counted by the library
    // ("Jamais écoutés"). A failure only loses one count.
    if (!identical(next, before)) {
      try {
        await _ref.read(libraryApiProvider).notePlayed(id);
      } catch (_) {}
    }
  }

  void _onSnapshot(PlaybackSnapshot s) {
    // The engine already plays the next file (gapless, crossfade) before
    // the queue says so: its positions are not this file's.
    final uri = s.source?.uri;
    if (uri != null && _currentUri != null && uri != _currentUri) return;
    final previous = _last;
    _last = s;
    _syncClock(s);
    if (s.status == PlaybackStatus.ended && _currentId != null && !_judged) {
      if (_music) _finished(_currentId!);
    }
    if (_currentId == null || s.duration == Duration.zero) return;
    final paused = previous?.isPlaying == true && !s.isPlaying;
    if (s.status == PlaybackStatus.ended) {
      // Like 0.1.x: history keeps the end position (watched to the end), the
      // resume point is forgotten.
      unawaited(_save(s.duration, s.duration));
    } else if (paused ||
        (s.position - _savedAt).abs() >= const Duration(seconds: 5)) {
      unawaited(_save(s.position, s.duration));
    }
  }

  Future<void> _save(Duration position, Duration duration) async {
    final id = _currentId;
    if (id == null) return;
    _savedAt = position;
    final h = noteStopped(await history(), id, position.inSeconds);
    final heard = _takeHeard();
    String? journal, months;
    if (heard > 0) {
      final now = DateTime.now();
      journal = (await listenJournal())
          .add(now, heard, artist: _artist)
          .encode();
      months = await _monthsWith(now, heard);
    }
    await _write({
      positionKey(id): resumeValue(position, duration),
      historyKey: jsonEncode([for (final e in h) e.toJson()]),
      listenJournalKey: ?journal,
      listenMonthsKey: ?months,
    });
  }

  /// The monthly recap with [heard] more seconds of the current file.
  Future<String> _monthsWith(DateTime now, int heard) async =>
      (await listenMonths())
          .add(now, heard, artist: _artist, trackId: _music ? _currentId : null)
          .encode();

  Future<ListenMonths> listenMonths() async {
    try {
      return ListenMonths.parse(
        await _ref.read(playbackStoreProvider).read(listenMonthsKey),
      );
    } catch (_) {
      return ListenMonths.empty;
    }
  }

  Future<ListenJournal> listenJournal() async {
    try {
      return ListenJournal.parse(
        await _ref.read(playbackStoreProvider).read(listenJournalKey),
      );
    } catch (_) {
      return ListenJournal.empty;
    }
  }

  /// Saves where the previous track stopped before another one starts.
  Future<void> _flush() async {
    final s = _last;
    if (_currentId != null && s != null && s.duration > Duration.zero) {
      await _save(s.position, s.duration);
    } else if (_counts) {
      // An online track (no resume point): what was heard still counts.
      _clock.stop();
      await _writeJournal();
    }
  }

  void dispose() {
    _journalTick?.cancel();
    _sub?.cancel();
  }
}

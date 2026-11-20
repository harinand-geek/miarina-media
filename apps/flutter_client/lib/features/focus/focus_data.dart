import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/focus.dart';
import '../cinema/cinema_data.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';

/// What the Focus screens need from the core; tests use an in-memory one.
abstract interface class FocusApi {
  Future<FocusLibrary> library();
  Future<List<FocusItem>> program(String name);
  Future<FocusItem?> entry(int id);
}

class RustFocusApi implements FocusApi {
  RustFocusApi(this._ref);

  final Ref _ref;

  Future<String> get _db => _ref.read(dbPathProvider.future);

  @override
  Future<FocusLibrary> library() async => focusLibrary(dbPath: await _db);

  @override
  Future<List<FocusItem>> program(String name) async =>
      focusProgram(dbPath: await _db, name: name);

  @override
  Future<FocusItem?> entry(int id) async =>
      focusEntry(dbPath: await _db, mediaId: id);
}

final focusApiProvider = Provider<FocusApi>(RustFocusApi.new);

final focusLibraryProvider = FutureProvider<FocusLibrary>(
  (ref) => ref.watch(focusApiProvider).library(),
);

final focusProgramProvider = FutureProvider.family<List<FocusItem>, String>(
  (ref, name) => ref.watch(focusApiProvider).program(name),
);

/// Started / finished audio, from the 0.1.x play history.
final listenStateProvider = playStateProvider('audio');

/// "En cours" of W-F1 / A-F: started Focus items, latest first.
final focusInProgressProvider = FutureProvider<List<FocusItem>>((ref) async {
  final state = await ref.watch(listenStateProvider.future);
  final api = ref.watch(focusApiProvider);
  final items = <FocusItem>[];
  for (final id in state.recent) {
    if (!state.resume.containsKey(id)) continue;
    final f = await api.entry(id);
    if (f != null && !f.item.missing) items.add(f);
    if (items.length == 5) break;
  }
  return items;
});

String focusKeyOf(FocusKind kind, String program) =>
    '${kind.name}:${program.toLowerCase()}';

Duration? focusDuration(FocusItem f) => f.item.durationSecs == null
    ? null
    : Duration(milliseconds: (f.item.durationSecs! * 1000).round());

QueueEntry focusQueueEntry(FocusItem f) {
  final base = queueEntryOf(f.item);
  return QueueEntry(
    source: base.source,
    title: f.item.title,
    subtitle: f.program,
    libraryId: f.item.id,
    favorite: f.item.favorite,
    album: f.program,
    duration: base.duration,
    format: base.format,
    artwork: f.item.thumbnail,
    focusKey: focusKeyOf(f.kind, f.program),
  );
}

/// Plays [items] (one program, in order) from [start].
Future<void> playFocus(
  QueueController queue,
  List<FocusItem> items, {
  int start = 0,
  bool fromStart = false,
}) => queue.playAll(
  [for (final f in items) focusQueueEntry(f)],
  start: start,
  inOrder: true,
  fromStart: fromStart,
);

/// A bookmark: a position (whole seconds) with an optional note.
@immutable
class Bookmark {
  const Bookmark({required this.at, this.note});

  final int at;
  final String? note;

  Map<String, Object?> toJson() => {'at': at, if (note != null) 'note': note};

  @override
  bool operator ==(Object other) =>
      other is Bookmark && other.at == at && other.note == note;

  @override
  int get hashCode => Object.hash(at, note);
}

/// Speeds per program and bookmarks per item, stored as one JSON value
/// (`mm:focus:v1`) next to the play history.
@immutable
class FocusMemory {
  const FocusMemory({this.rates = const {}, this.marks = const {}});

  final Map<String, double> rates;
  final Map<int, List<Bookmark>> marks;

  static const storeKey = 'mm:focus:v1';
  static const maxPrograms = 500;
  static const maxItems = 1000;
  static const maxMarks = 200;
  static const maxNote = 200;
  static const speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];

  double rateFor(String? key) => key == null ? 1 : rates[key] ?? 1;

  List<Bookmark> marksOf(int id) => marks[id] ?? const [];

  /// Reads a stored value; anything malformed is dropped, never thrown.
  static FocusMemory parse(String? text) {
    if (text == null || text.isEmpty) return const FocusMemory();
    try {
      final raw = jsonDecode(text);
      if (raw is! Map) return const FocusMemory();
      final rates = <String, double>{};
      final r = raw['rates'];
      if (r is Map) {
        for (final e in r.entries) {
          final v = e.value;
          if (e.key is String && v is num && v >= 0.25 && v <= 4) {
            rates[e.key as String] = v.toDouble();
          }
        }
      }
      final marks = <int, List<Bookmark>>{};
      final m = raw['marks'];
      if (m is Map) {
        for (final e in m.entries) {
          final id = int.tryParse('${e.key}');
          if (id == null || e.value is! List) continue;
          final list = <Bookmark>[];
          for (final b in e.value as List) {
            if (b is Map && b['at'] is num && (b['at'] as num) >= 0) {
              final note = b['note'];
              list.add(
                Bookmark(
                  at: (b['at'] as num).floor(),
                  note: note is String && note.isNotEmpty
                      ? note.substring(0, note.length.clamp(0, maxNote))
                      : null,
                ),
              );
            }
          }
          if (list.isNotEmpty) {
            marks[id] = (list..sort((a, b) => a.at.compareTo(b.at)))
                .take(maxMarks)
                .toList();
          }
        }
      }
      return FocusMemory(rates: rates, marks: marks);
    } on FormatException {
      return const FocusMemory();
    }
  }

  String toJson() => jsonEncode({
    'rates': rates,
    'marks': {
      for (final e in marks.entries)
        '${e.key}': [for (final b in e.value) b.toJson()],
    },
  });

  FocusMemory withRate(String key, double rate) {
    final next = {...rates}..remove(key);
    if ((rate - 1).abs() > 0.001) next[key] = rate;
    // Bounded: the oldest settings go first (insertion order).
    while (next.length > maxPrograms) {
      next.remove(next.keys.first);
    }
    return FocusMemory(rates: next, marks: marks);
  }

  /// Adds a bookmark at [at] seconds; one per second at most.
  FocusMemory withMark(int id, int at, {String? note}) {
    final list = [...marksOf(id)];
    if (list.any((b) => b.at == at) || list.length >= maxMarks) return this;
    list
      ..add(Bookmark(at: at, note: note))
      ..sort((a, b) => a.at.compareTo(b.at));
    final next = {...marks}..remove(id);
    next[id] = list;
    while (next.length > maxItems) {
      next.remove(next.keys.first);
    }
    return FocusMemory(rates: rates, marks: next);
  }

  /// The note of the bookmark at [at] (empty = no note), at most
  /// [maxNote] characters.
  FocusMemory withNote(int id, int at, String? note) {
    final text = note?.trim() ?? '';
    final clean = text.isEmpty
        ? null
        : text.substring(0, text.length.clamp(0, maxNote));
    final list = [
      for (final b in marksOf(id))
        b.at == at ? Bookmark(at: b.at, note: clean) : b,
    ];
    if (list.isEmpty) return this;
    return FocusMemory(rates: rates, marks: {...marks, id: list});
  }

  FocusMemory withoutMark(int id, int at) {
    final list = [...marksOf(id)]..removeWhere((b) => b.at == at);
    final next = {...marks};
    list.isEmpty ? next.remove(id) : next[id] = list;
    return FocusMemory(rates: rates, marks: next);
  }
}

final focusMemoryProvider =
    AsyncNotifierProvider<FocusMemoryController, FocusMemory>(
      FocusMemoryController.new,
    );

class FocusMemoryController extends AsyncNotifier<FocusMemory> {
  @override
  Future<FocusMemory> build() async => FocusMemory.parse(
    await ref.read(playbackStoreProvider).read(FocusMemory.storeKey),
  );

  Future<void> _save(FocusMemory next) async {
    state = AsyncData(next);
    await ref.read(playbackStoreProvider).write({
      FocusMemory.storeKey: next.toJson(),
    });
  }

  /// Changes the speed now and remembers it for the program.
  Future<void> setRate(String key, double rate) async {
    final memory = await future;
    await ref.read(mediaEngineProvider)?.setSpeed(rate);
    await _save(memory.withRate(key, rate));
  }

  Future<void> addMark(int id, Duration at) async =>
      _save((await future).withMark(id, at.inSeconds));

  Future<void> removeMark(int id, int at) async =>
      _save((await future).withoutMark(id, at));

  Future<void> setNote(int id, int at, String? note) async =>
      _save((await future).withNote(id, at, note));
}

/// Applies the remembered speed when a Focus item starts, and goes back to
/// normal speed when music or video follows. Watched by the app root.
final focusSpeedProvider = Provider<void>((ref) {
  var focusSpeed = false;
  ref.listen(queueProvider.select((q) => q.current), (_, entry) async {
    final engine = ref.read(mediaEngineProvider);
    if (engine == null || entry == null) return;
    final key = entry.focusKey;
    if (key != null) {
      final memory = await ref.read(focusMemoryProvider.future);
      focusSpeed = true;
      await engine.setSpeed(memory.rateFor(key));
    } else if (focusSpeed) {
      focusSpeed = false;
      await engine.setSpeed(1);
    }
  });
});

/// Time left at [rate], as the listener will hear it.
Duration leftAt(Duration total, Duration position, double rate) {
  final left = total - position;
  if (left.isNegative) return Duration.zero;
  return Duration(milliseconds: (left.inMilliseconds / rate).round());
}

/// Bookmarks as plain text, to keep with the course ("Exportables en texte
/// avec le cours"): the title, the file, then one line per bookmark.
String bookmarksText({
  required String title,
  required String path,
  required List<Bookmark> marks,
  required String? Function(int at) chapterOf,
  required String Function(int at) clock,
}) {
  final lines = [title, path, ''];
  for (final b in marks) {
    lines.add([clock(b.at), ?chapterOf(b.at), ?b.note].join(' · '));
  }
  return '${lines.join('\n')}\n';
}

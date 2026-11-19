import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/cinema.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';

/// What the Cinema screens need from the core; tests use an in-memory one.
abstract interface class CinemaApi {
  Future<CinemaLibrary> library();
  Future<SeriesDetail?> series(String name);
  Future<CinemaItem?> item(int id);
}

class RustCinemaApi implements CinemaApi {
  RustCinemaApi(this._ref);

  final Ref _ref;

  Future<String> get _db => _ref.read(dbPathProvider.future);

  @override
  Future<CinemaLibrary> library() async => cinemaLibrary(dbPath: await _db);

  @override
  Future<SeriesDetail?> series(String name) async =>
      cinemaSeries(dbPath: await _db, name: name);

  @override
  Future<CinemaItem?> item(int id) async =>
      cinemaItem(dbPath: await _db, mediaId: id);
}

final cinemaApiProvider = Provider<CinemaApi>(RustCinemaApi.new);

final cinemaLibraryProvider = FutureProvider<CinemaLibrary>(
  (ref) => ref.watch(cinemaApiProvider).library(),
);

final seriesProvider = FutureProvider.family<SeriesDetail?, String>(
  (ref, name) => ref.watch(cinemaApiProvider).series(name),
);

/// A video counts as watched when its latest play reached the last 5 % (or
/// the last 5 s of a short one).
bool reachedEnd(PlayEntry e) {
  if (e.duration <= 0) return false;
  final left = e.duration - e.position;
  return left <= resumeMargin.inSeconds || e.position >= e.duration * 0.95;
}

/// What the user has watched, from the 0.1.x-compatible play history and
/// resume points (nothing is stored apart).
@immutable
class WatchState {
  const WatchState({
    this.resume = const {},
    this.seen = const {},
    this.recent = const [],
  });

  /// Saved positions of videos not watched to the end.
  final Map<int, Duration> resume;
  final Set<int> seen;

  /// Ids of played videos, latest first, each once.
  final List<int> recent;

  Duration? resumeOf(int id) => resume[id];
  bool isSeen(int id) => seen.contains(id);
}

/// Watched / started state of one kind of media ('video' or 'audio').
final playStateProvider = FutureProvider.family<WatchState, String>((
  ref,
  kind,
) async {
  // Recomputed when another item starts; screens also refresh it when a
  // player closes.
  ref.watch(queueProvider.select((q) => q.current?.libraryId));
  final memory = ref.watch(playbackMemoryProvider);
  final history = await memory.history();
  final resume = <int, Duration>{};
  final seen = <int>{};
  final recent = <int>[];
  for (final e in history.where((e) => e.kind == kind)) {
    if (recent.contains(e.id)) continue;
    recent.add(e.id);
    if (reachedEnd(e)) {
      seen.add(e.id);
      continue;
    }
    final at = await memory.savedPosition(e.id);
    if (at != null) resume[e.id] = at;
  }
  return WatchState(resume: resume, seen: seen, recent: recent);
});

final watchStateProvider = playStateProvider('video');

/// "Reprendre" of W-C1 / A-C: started videos, latest first.
final cinemaResumeProvider = FutureProvider<List<CinemaItem>>((ref) async {
  final watch = await ref.watch(watchStateProvider.future);
  final api = ref.watch(cinemaApiProvider);
  final items = <CinemaItem>[];
  for (final id in watch.recent) {
    if (!watch.resume.containsKey(id)) continue;
    final item = await api.item(id);
    if (item != null && !item.item.missing) items.add(item);
    if (items.length == 8) break;
  }
  return items;
});

Duration? durationOf(CinemaItem v) => v.item.durationSecs == null
    ? null
    : Duration(milliseconds: (v.item.durationSecs! * 1000).round());

/// Share of [v] already watched, 0..1.
double progressOf(CinemaItem v, WatchState w) {
  if (w.isSeen(v.item.id)) return 1;
  final at = w.resumeOf(v.item.id);
  final total = durationOf(v);
  if (at == null || total == null || total == Duration.zero) return 0;
  return (at.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
}

/// The episode the series' main button plays: the latest one started, the
/// one after the latest watched, or the first.
({CinemaItem episode, Duration? resumeAt})? nextEpisode(
  SeriesDetail s,
  WatchState w,
) {
  final playable = [
    for (final e in s.episodes)
      if (!e.item.missing) e,
  ];
  if (playable.isEmpty) return null;
  final ids = {for (final e in playable) e.item.id};
  final latest = w.recent.where(ids.contains).firstOrNull;
  if (latest != null) {
    final i = playable.indexWhere((e) => e.item.id == latest);
    final at = w.resumeOf(latest);
    if (at != null) return (episode: playable[i], resumeAt: at);
    if (w.isSeen(latest) && i + 1 < playable.length) {
      return (episode: playable[i + 1], resumeAt: null);
    }
    if (!w.isSeen(latest)) return (episode: playable[i], resumeAt: null);
  }
  final unseen = playable.where((e) => !w.isSeen(e.item.id)).firstOrNull;
  return (episode: unseen ?? playable.first, resumeAt: null);
}

QueueEntry videoEntry(CinemaItem v, {String? episodeLabel}) {
  final base = queueEntryOf(v.item);
  return QueueEntry(
    source: base.source,
    title: v.kind == CinemaKind.episode && episodeLabel != null
        ? episodeLabel
        : v.item.title,
    subtitle: v.series ?? (v.year?.toString()),
    libraryId: v.item.id,
    favorite: v.item.favorite,
    album: v.series,
    duration: base.duration,
    format: base.format,
    artwork: v.poster ?? v.item.thumbnail,
    isVideo: true,
  );
}

/// Starts [videos] at [start] in order (a series plays on to the next
/// episode); [fromStart] ignores the resume point.
Future<void> playVideos(
  QueueController queue,
  List<CinemaItem> videos, {
  int start = 0,
  bool fromStart = false,
  String Function(CinemaItem)? label,
}) async {
  final playable = [
    for (final v in videos)
      if (!v.item.missing || identical(v, videos[start])) v,
  ];
  final first = playable.indexOf(videos[start]);
  await queue.playAll(
    [for (final v in playable) videoEntry(v, episodeLabel: label?.call(v))],
    start: first < 0 ? 0 : first,
    inOrder: true,
    fromStart: fromStart,
  );
}

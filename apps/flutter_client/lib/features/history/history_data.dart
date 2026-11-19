import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/cinema.dart';
import '../../src/rust/api/focus.dart';
import '../../src/rust/api/library.dart';
import '../cinema/cinema_data.dart';
import '../focus/focus_data.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';

enum HistorySection { music, cinema, focus }

/// One play of the history (W-03) with what it played.
@immutable
class HistoryRow {
  const HistoryRow({
    required this.play,
    required this.item,
    required this.section,
    this.video,
    this.focus,
  });

  final PlayEntry play;
  final LibraryItem item;
  final HistorySection section;
  final CinemaItem? video;
  final FocusItem? focus;

  Duration get position => Duration(seconds: play.position);

  Duration? get duration => play.duration > 0
      ? Duration(milliseconds: (play.duration * 1000).round())
      : item.durationSecs == null
      ? null
      : Duration(milliseconds: (item.durationSecs! * 1000).round());

  bool get finished => reachedEnd(play);
}

/// The 0.1.x play history, newest first, resolved against the library;
/// plays of files no longer in the library are left out.
final historyProvider = FutureProvider<List<HistoryRow>>((ref) async {
  ref.watch(queueProvider.select((q) => q.current?.libraryId));
  final memory = ref.watch(playbackMemoryProvider);
  final library = ref.watch(libraryApiProvider);
  final cinema = ref.watch(cinemaApiProvider);
  final focusApi = ref.watch(focusApiProvider);
  final history = await memory.history();

  final items = <int, LibraryItem?>{};
  final videos = <int, CinemaItem?>{};
  final focus = <int, FocusItem?>{};
  final rows = <HistoryRow>[];
  for (final play in history) {
    if (!items.containsKey(play.id)) {
      final item = await library.item(play.id);
      items[play.id] = item;
      if (item != null && item.isVideo) {
        videos[play.id] = await cinema.item(play.id);
      } else if (item != null) {
        focus[play.id] = await focusApi.entry(play.id);
      }
    }
    final item = items[play.id];
    if (item == null) continue;
    final video = videos[play.id];
    final f = focus[play.id];
    rows.add(
      HistoryRow(
        play: play,
        item: item,
        video: video,
        focus: f,
        section: item.isVideo
            ? HistorySection.cinema
            : f != null
            ? HistorySection.focus
            : HistorySection.music,
      ),
    );
  }
  return rows;
});

/// Forgets the plays. Files, favorites and resume points are kept (the
/// 0.1.x "clear history" rule).
Future<void> clearHistory(WidgetRef ref) async {
  await ref.read(playbackStoreProvider).write({historyKey: jsonEncode([])});
  ref
    ..invalidate(historyProvider)
    ..invalidate(watchStateProvider)
    ..invalidate(listenStateProvider);
}

/// Calendar day of [at], for grouping.
DateTime dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

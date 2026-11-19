import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine_factory.dart';
import '../../engine/media_engine.dart';

/// One playable entry of the queue, with what the bars display.
@immutable
class QueueEntry {
  const QueueEntry({
    required this.source,
    required this.title,
    this.subtitle,
    this.libraryId,
    this.favorite = false,
  });

  final MediaSource source;
  final String title;
  final String? subtitle;
  final int? libraryId;
  final bool favorite;

  /// Stable tint of the placeholder cover.
  int get seed => libraryId ?? title.hashCode;
}

@immutable
class QueueState {
  const QueueState({
    this.entries = const [],
    this.order = const [],
    this.position = -1,
    this.shuffle = false,
    this.repeat = RepeatSetting.off,
  });

  final List<QueueEntry> entries;

  /// Play order as indexes into [entries] (identity unless shuffled).
  final List<int> order;

  /// Index into [order] of the current entry, -1 when nothing is loaded.
  final int position;
  final bool shuffle;
  final RepeatSetting repeat;

  QueueEntry? get current => position >= 0 && position < order.length
      ? entries[order[position]]
      : null;

  bool get hasNext =>
      position + 1 < order.length ||
      (repeat == RepeatSetting.all && order.isNotEmpty);
  bool get hasPrevious =>
      position > 0 || (repeat == RepeatSetting.all && order.isNotEmpty);

  QueueState copyWith({
    List<QueueEntry>? entries,
    List<int>? order,
    int? position,
    bool? shuffle,
    RepeatSetting? repeat,
  }) => QueueState(
    entries: entries ?? this.entries,
    order: order ?? this.order,
    position: position ?? this.position,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
  );
}

final mediaEngineProvider = Provider<MediaEngine?>((ref) {
  final engine = createPlatformEngine();
  ref.onDispose(() => engine?.dispose());
  return engine;
});

/// Engine state, at most 4 updates per second for the position.
final playbackProvider = StreamProvider<PlaybackSnapshot>((ref) {
  final engine = ref.watch(mediaEngineProvider);
  if (engine == null) return Stream.value(const PlaybackSnapshot());
  return engine.snapshots;
});

PlaybackSnapshot currentSnapshot(WidgetRef ref) =>
    ref.watch(playbackProvider).value ??
    ref.read(mediaEngineProvider)?.current ??
    const PlaybackSnapshot();

final queueProvider = NotifierProvider<QueueController, QueueState>(
  QueueController.new,
);

class QueueController extends Notifier<QueueState> {
  StreamSubscription<PlaybackSnapshot>? _ended;
  final _random = math.Random();

  MediaEngine? get _engine => ref.read(mediaEngineProvider);

  @override
  QueueState build() {
    final engine = ref.watch(mediaEngineProvider);
    _ended = engine?.snapshots
        .where((s) => s.status == PlaybackStatus.ended)
        .listen((_) => _advanceAfterEnd());
    ref.onDispose(() => _ended?.cancel());
    return const QueueState();
  }

  Future<void> playAll(List<QueueEntry> entries, {int start = 0}) async {
    if (entries.isEmpty) return;
    final first = start.clamp(0, entries.length - 1);
    final order = _orderFor(
      entries.length,
      shuffle: state.shuffle,
      first: first,
    );
    state = state.copyWith(
      entries: List.unmodifiable(entries),
      order: order,
      position: order.indexOf(first),
    );
    await _load();
  }

  Future<void> togglePlay() async {
    final engine = _engine;
    if (engine == null) return;
    final s = engine.current;
    if (s.source == null) {
      if (state.current != null) await _load();
      return;
    }
    s.isPlaying ? await engine.pause() : await engine.play();
  }

  Future<void> next() async {
    if (state.order.isEmpty) return;
    if (state.position + 1 < state.order.length) {
      state = state.copyWith(position: state.position + 1);
    } else if (state.repeat == RepeatSetting.all) {
      state = state.copyWith(position: 0);
    } else {
      return;
    }
    await _load();
  }

  /// Back to the start of the track after 3 s, otherwise the previous one.
  Future<void> previous() async {
    final engine = _engine;
    if (engine == null || state.order.isEmpty) return;
    if (engine.current.position > const Duration(seconds: 3) ||
        !state.hasPrevious) {
      await engine.seek(Duration.zero);
      return;
    }
    final p = state.position > 0 ? state.position - 1 : state.order.length - 1;
    state = state.copyWith(position: p);
    await _load();
  }

  Future<void> toggleShuffle() async {
    final on = !state.shuffle;
    if (state.order.isEmpty) {
      state = state.copyWith(shuffle: on);
      return;
    }
    final currentIndex = state.order[state.position];
    final order = _orderFor(
      state.entries.length,
      shuffle: on,
      first: currentIndex,
    );
    state = state.copyWith(
      shuffle: on,
      order: order,
      position: order.indexOf(currentIndex),
    );
  }

  Future<void> cycleRepeat() async {
    // Usual player order: off → all → one → off.
    final next = switch (state.repeat) {
      RepeatSetting.off => RepeatSetting.all,
      RepeatSetting.all => RepeatSetting.one,
      RepeatSetting.one => RepeatSetting.off,
    };
    state = state.copyWith(repeat: next);
    // The engine only loops one file; queue looping is handled here.
    await _engine?.setRepeatMode(
      next == RepeatSetting.one ? RepeatSetting.one : RepeatSetting.off,
    );
  }

  List<int> _orderFor(int length, {required bool shuffle, required int first}) {
    final order = List<int>.generate(length, (i) => i);
    if (!shuffle) {
      return order;
    }
    order
      ..remove(first)
      ..shuffle(_random)
      ..insert(0, first);
    return order;
  }

  Future<void> _load() async {
    final entry = state.current;
    final engine = _engine;
    if (entry == null || engine == null) return;
    await engine.open(entry.source);
  }

  Future<void> _advanceAfterEnd() async {
    if (state.repeat == RepeatSetting.one) return;
    if (state.hasNext) await next();
  }
}

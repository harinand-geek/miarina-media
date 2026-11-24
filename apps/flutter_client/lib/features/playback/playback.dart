import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine_factory.dart';
import '../../engine/media_engine.dart';
import '../health/health_data.dart';
import '../settings/settings_data.dart';
import 'playback_memory.dart';

/// One playable entry of the queue, with what the bars display.
@immutable
class QueueEntry {
  const QueueEntry({
    required this.source,
    required this.title,
    this.subtitle,
    this.libraryId,
    this.favorite = false,
    this.album,
    this.duration,
    this.format,
    this.artwork,
    this.isVideo = false,
    this.focusKey,
  });

  final MediaSource source;
  final String title;
  final String? subtitle;
  final int? libraryId;
  final bool favorite;
  final String? album;
  final Duration? duration;

  /// Short technical label shown in Now playing ("FLAC").
  final String? format;

  /// Cover image file, when the library has one.
  final String? artwork;
  final bool isVideo;

  /// Focus program (podcast, course, book) the entry belongs to, e.g.
  /// "course:architecture"; its speed is remembered per program.
  final String? focusKey;

  QueueEntry withFavorite(bool value) => QueueEntry(
    source: source,
    title: title,
    subtitle: subtitle,
    libraryId: libraryId,
    favorite: value,
    album: album,
    duration: duration,
    format: format,
    artwork: artwork,
    isVideo: isVideo,
    focusKey: focusKey,
  );

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

  /// Entries after the current one, in play order.
  List<QueueEntry> get upcoming => [
    for (var i = position + 1; i < order.length; i++) entries[order[i]],
  ];

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

/// Sleep timer: pause after a delay, or at the end of the current track.
@immutable
class SleepTimer {
  const SleepTimer({this.until, this.endOfTrack = false});

  final DateTime? until;
  final bool endOfTrack;

  bool get active => until != null || endOfTrack;
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

/// Whether a library entry's file is still there, checked just before it
/// plays (the core marks it missing otherwise). In doubt: present.
final presenceCheckProvider = Provider<Future<bool> Function(int libraryId)>((
  ref,
) {
  final api = ref.watch(healthApiProvider);
  return (id) async {
    try {
      return await api.check(id);
    } catch (_) {
      return true;
    }
  };
});

/// A library file found missing when its turn came (W-O2, "Fichier
/// manquant" flow): the queue went on with the next one and the shell
/// shows « introuvable, titre suivant » with "Localiser".
@immutable
class SkippedMissing {
  const SkippedMissing(this.entry, {required this.next});

  final QueueEntry entry;

  /// Another entry was played instead.
  final bool next;
}

final skippedMissingProvider =
    NotifierProvider<SkippedMissingNotifier, SkippedMissing?>(
      SkippedMissingNotifier.new,
    );

class SkippedMissingNotifier extends Notifier<SkippedMissing?> {
  @override
  SkippedMissing? build() => null;

  void report(SkippedMissing skipped) => state = skipped;
}

class QueueController extends Notifier<QueueState> {
  StreamSubscription<PlaybackSnapshot>? _ended;
  final _random = math.Random();

  /// Missing files skipped in a row: never more than the queue holds.
  int _skipped = 0;

  StreamSubscription<PlaybackSnapshot>? _moved;

  /// The entry prepared in the engine to follow the current one.
  QueueEntry? _prepared;

  MediaEngine? get _engine => ref.read(mediaEngineProvider);

  @override
  QueueState build() {
    final engine = ref.watch(mediaEngineProvider);
    _ended = engine?.snapshots
        .where((s) => s.status == PlaybackStatus.ended)
        .listen((_) => _advanceAfterEnd());
    _moved = engine?.snapshots.listen(_followEngine);
    ref.onDispose(() {
      _ended?.cancel();
      _moved?.cancel();
    });
    // A changed setting changes what may follow (the sleep timer says so
    // itself: it reads the queue).
    ref.listen(playbackPrefsProvider, (_, _) => _prepareNext());
    return const QueueState();
  }

  /// Plays [entries] from [start]. [inOrder] ignores shuffle (episodes of a
  /// series); [fromStart] ignores the saved resume point of the first one.
  Future<void> playAll(
    List<QueueEntry> entries, {
    int start = 0,
    bool inOrder = false,
    bool fromStart = false,
  }) async {
    if (entries.isEmpty) return;
    final first = start.clamp(0, entries.length - 1);
    final order = _orderFor(
      entries.length,
      shuffle: state.shuffle && !inOrder,
      first: first,
    );
    state = state.copyWith(
      entries: List.unmodifiable(entries),
      order: order,
      position: order.indexOf(first),
    );
    await _load(fromStart: fromStart);
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
    unawaited(_prepareNext());
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
    await _prepareNext();
  }

  /// Plays the [i]-th upcoming entry (0 = next), skipping those before it.
  Future<void> playUpcoming(int i) async {
    final p = state.position + 1 + i;
    if (p >= state.order.length) return;
    state = state.copyWith(position: p);
    await _load();
  }

  /// Moves an upcoming entry from index [from] to [to] (0 = next).
  void moveUpcoming(int from, int to) {
    final base = state.position + 1;
    final order = List.of(state.order);
    if (from < 0 || base + from >= order.length) return;
    final item = order.removeAt(base + from);
    order.insert((base + to).clamp(base, order.length), item);
    state = state.copyWith(order: order);
    unawaited(_prepareNext());
  }

  void removeUpcoming(int i) {
    final p = state.position + 1 + i;
    if (p >= state.order.length) return;
    state = state.copyWith(order: List.of(state.order)..removeAt(p));
    unawaited(_prepareNext());
  }

  /// "Lire ensuite" ([next]: right after the current entry) or "Ajouter à
  /// la file" (at the end). With nothing loaded, [entries] start playing.
  Future<void> enqueue(List<QueueEntry> entries, {required bool next}) async {
    if (entries.isEmpty) return;
    if (state.current == null) {
      await playAll(entries, inOrder: true);
      return;
    }
    final base = state.entries.length;
    final added = [for (var i = 0; i < entries.length; i++) base + i];
    final order = List.of(state.order);
    order.insertAll(next ? state.position + 1 : order.length, added);
    state = state.copyWith(
      entries: List.unmodifiable([...state.entries, ...entries]),
      order: order,
    );
    await _prepareNext();
  }

  void markFavorite(int libraryId, {required bool favorite}) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          e.libraryId == libraryId ? e.withFavorite(favorite) : e,
      ],
    );
  }

  void clearUpcoming() {
    if (state.position < 0) return;
    state = state.copyWith(order: state.order.sublist(0, state.position + 1));
    unawaited(_prepareNext());
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

  Future<void> _load({bool fromStart = false}) async {
    final entry = state.current;
    final engine = _engine;
    if (entry == null || engine == null) return;
    final id = entry.libraryId;
    if (id != null && !await ref.read(presenceCheckProvider)(id)) {
      // Another entry was chosen meanwhile: that load goes on.
      if (!identical(state.current, entry)) return;
      final canSkip =
          _skipped < state.order.length &&
          state.position + 1 < state.order.length;
      ref
          .read(skippedMissingProvider.notifier)
          .report(SkippedMissing(entry, next: canSkip));
      if (canSkip) {
        _skipped++;
        state = state.copyWith(position: state.position + 1);
        return _load(fromStart: fromStart);
      }
      // Last one: opened anyway, the player shows "Fichier introuvable".
    }
    _skipped = 0;
    final memory = ref.read(playbackMemoryProvider);
    final start = fromStart ? null : await memory.startFor(entry);
    // Before open(): the previous track's position is saved from the last
    // snapshot, which open() replaces.
    await memory.started(entry);
    _prepared = null;
    await engine.open(entry.source, startAt: start);
    await _prepareNext();
  }

  /// Index into the order of the entry after the current one, or -1.
  int get _nextPosition {
    if (state.repeat == RepeatSetting.one) return -1;
    if (state.position + 1 < state.order.length) return state.position + 1;
    return state.repeat == RepeatSetting.all && state.order.length > 1 ? 0 : -1;
  }

  /// Prepares again what follows (the sleep timer changed).
  Future<void> refreshNext() => _prepareNext();

  /// Gives the engine the entry that follows (gapless or crossfade), or
  /// takes it back. An entry that resumes from a saved point, a missing
  /// file, a sleep timer at the end of the track: nothing is prepared, the
  /// usual end of track decides.
  Future<void> _prepareNext() async {
    final engine = _engine;
    final current = state.current;
    if (engine == null || current == null) return;
    final prefs = ref.read(playbackPrefsProvider).value;
    final caps = engine.capabilities;
    final fadeSecs = caps.crossfade ? (prefs?.crossfadeSecs ?? 0) : 0;
    final chain = (caps.gapless && (prefs?.gapless ?? false)) || fadeSecs > 0;
    final p = _nextPosition;
    QueueEntry? next =
        chain && p >= 0 && !ref.read(sleepTimerProvider).endOfTrack
        ? state.entries[state.order[p]]
        : null;
    // The same file again (a repeated queue of one): the end of track
    // handles it.
    if (next != null && next.source.uri == current.source.uri) next = null;
    if (next != null) {
      final id = next.libraryId;
      if (await ref.read(playbackMemoryProvider).startFor(next) != null ||
          (id != null && !await ref.read(presenceCheckProvider)(id))) {
        next = null;
      }
    }
    // The queue moved on meanwhile: the newer call decides.
    if (!identical(state.current, current)) return;
    _prepared = next;
    final fade = next != null && !current.isVideo && !next.isVideo
        ? Duration(seconds: fadeSecs)
        : Duration.zero;
    if (fade == Duration.zero && !(caps.gapless && (prefs?.gapless ?? false))) {
      await engine.prepareNext(null);
      return;
    }
    await engine.prepareNext(next?.source, crossfade: fade);
  }

  /// The engine went on to the prepared entry by itself: the queue follows,
  /// without opening it again.
  Future<void> _followEngine(PlaybackSnapshot s) async {
    final next = _prepared;
    final uri = s.source?.uri;
    if (next == null || uri == null || uri != next.source.uri) return;
    if (state.current?.source.uri == uri) return;
    final p = _nextPosition;
    if (p < 0 || !identical(state.entries[state.order[p]], next)) return;
    _prepared = null;
    state = state.copyWith(position: p);
    await ref.read(playbackMemoryProvider).started(next);
    await _prepareNext();
  }

  Future<void> _advanceAfterEnd() async {
    if (ref.read(sleepTimerProvider).endOfTrack) {
      ref.read(sleepTimerProvider.notifier).cancel();
      return;
    }
    if (state.repeat == RepeatSetting.one) return;
    if (state.hasNext) await next();
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerController, SleepTimer>(
  SleepTimerController.new,
);

class SleepTimerController extends Notifier<SleepTimer> {
  Timer? _timer;

  @override
  SleepTimer build() {
    ref.onDispose(() => _timer?.cancel());
    return const SleepTimer();
  }

  void after(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      ref.read(mediaEngineProvider)?.pause();
      state = const SleepTimer();
    });
    state = SleepTimer(until: DateTime.now().add(delay));
  }

  /// Pauses when the current track ends (the queue does not advance). The
  /// engine stops looping one track meanwhile, or the end would never come.
  void atEndOfTrack() {
    _timer?.cancel();
    ref.read(mediaEngineProvider)?.setRepeatMode(RepeatSetting.off);
    state = const SleepTimer(endOfTrack: true);
    // Nothing may follow by itself (gapless, crossfade).
    unawaited(ref.read(queueProvider.notifier).refreshNext());
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    if (state.endOfTrack &&
        ref.read(queueProvider).repeat == RepeatSetting.one) {
      ref.read(mediaEngineProvider)?.setRepeatMode(RepeatSetting.one);
    }
    final wasEndOfTrack = state.endOfTrack;
    state = const SleepTimer();
    if (wasEndOfTrack) {
      unawaited(ref.read(queueProvider.notifier).refreshNext());
    }
  }
}

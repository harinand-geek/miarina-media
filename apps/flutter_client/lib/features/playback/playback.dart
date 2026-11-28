import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine_factory.dart';
import '../../engine/media_engine.dart';
import '../health/health_data.dart';
import '../library/library_data.dart' show libraryApiProvider, queueEntryOf;
import '../online/online_data.dart' show OnlineFailure, OnlineFailureKind;
import '../online/online_playback.dart';
import '../../src/rust/api/library.dart' as rust_library;
import '../settings/settings_data.dart';
import 'playback_memory.dart';
import 'smart_queue.dart';
import 'taste.dart';

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
    this.onlineId,
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

  /// Online listening (decision 0011): the YouTube video, whose stream is
  /// found just before it plays. Not in the library ([libraryId] is null).
  final String? onlineId;

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
    onlineId: onlineId,
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

  StreamSubscription<PlaybackSnapshot>? _online;

  /// The online entry whose stream was found again after the engine was
  /// refused (an address expired during a long pause): once per play.
  String? _refreshedOnline;

  /// Where the current online entry was, to resume it on a fresh stream.
  Duration _onlineAt = Duration.zero;

  MediaEngine? get _engine => ref.read(mediaEngineProvider);

  @override
  QueueState build() {
    final engine = ref.watch(mediaEngineProvider);
    _ended = engine?.snapshots
        .where((s) => s.status == PlaybackStatus.ended)
        .listen((_) => _advanceAfterEnd());
    _moved = engine?.snapshots.listen(_followEngine);
    _online = engine?.snapshots.listen(_watchOnline);
    ref.onDispose(() {
      _ended?.cancel();
      _moved?.cancel();
      _online?.cancel();
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
      entries,
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
    final current = state.current;
    // An online entry whose stream was not found: play tries again (the
    // engine may still hold the previous track, paused).
    if (s.source == null ||
        (current?.onlineId != null &&
            (s.source?.uri != current!.source.uri ||
                // A finished stream: loaded again (its address may have
                // expired) rather than replayed by the engine.
                s.status == PlaybackStatus.ended))) {
      if (current != null) await _load(fromStart: true);
      return;
    }
    s.isPlaying ? await engine.pause() : await engine.play();
  }

  /// « Réessayer » of the player's error card.
  Future<void> retryCurrent() => _load();

  /// Puts [entry] in place of the current one and plays it from [at]: an
  /// online track becomes its clip, and back (decision 0011, lot 8).
  Future<void> replaceCurrent(QueueEntry entry, {Duration? at}) async {
    if (state.position < 0) {
      await playAll([entry]);
      return;
    }
    final entries = List.of(state.entries);
    entries[state.order[state.position]] = entry;
    state = state.copyWith(entries: List.unmodifiable(entries));
    await _load(startAt: at);
  }

  /// « Suivant » by the listener: the track left counts as passed when
  /// little of it was heard (taste.dart).
  Future<void> next() => _advance(skipped: true);

  Future<void> _advance({required bool skipped}) async {
    if (state.order.isEmpty) return;
    if (state.position + 1 < state.order.length) {
      state = state.copyWith(position: state.position + 1);
    } else if (state.repeat == RepeatSetting.all) {
      state = state.copyWith(position: 0);
    } else {
      return;
    }
    await _load(skipped: skipped);
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
    final order = _orderFor(state.entries, shuffle: on, first: currentIndex);
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
    await _load(skipped: true);
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

  List<int> _orderFor(
    List<QueueEntry> entries, {
    required bool shuffle,
    required int first,
  }) {
    final order = List<int>.generate(entries.length, (i) => i);
    if (!shuffle) {
      return order;
    }
    if (ref.read(playbackPrefsProvider).value?.smartShuffle ?? true) {
      return smartShuffleOrder(
        entries,
        first: first,
        taste: ref.read(tasteProvider),
        random: _random,
        now: DateTime.now(),
      );
    }
    order
      ..remove(first)
      ..shuffle(_random)
      ..insert(0, first);
    return order;
  }

  /// Radio (2026-11-28): [seed] then up to 25 close tracks of the library
  /// (smart_queue.dart). When [seed] is the one playing, it goes on and the
  /// radio follows it. Returns how many tracks were found (0: nothing
  /// changed).
  Future<int> startRadio(QueueEntry seed, {String? unknownArtist}) async {
    final id = seed.libraryId;
    if (id == null) return 0;
    final picks = await _closeTracks(
      [TrackKey.ofEntry(seed)],
      exclude: {id},
      count: 25,
    );
    if (picks.isEmpty) return 0;
    final entries = [
      for (final i in picks) queueEntryOf(i, unknownArtist: unknownArtist),
    ];
    final current = state.current;
    if (current != null && current.libraryId == id) {
      state = state.copyWith(
        entries: List.unmodifiable([current, ...entries]),
        order: List<int>.generate(entries.length + 1, (i) => i),
        position: 0,
      );
      await _prepareNext();
    } else {
      await playAll([seed, ...entries], inOrder: true);
    }
    return entries.length;
  }

  Future<List<rust_library.LibraryItem>> _closeTracks(
    List<TrackKey> seeds, {
    required Set<int> exclude,
    required int count,
  }) async {
    try {
      final library = await ref
          .read(libraryApiProvider)
          .tracks(search: '', favoritesOnly: false, offset: 0, limit: 3000);
      await ref.read(tasteProvider.notifier).ready();
      return radioPicks(
        seeds: seeds,
        library: library.items,
        taste: ref.read(tasteProvider),
        random: _random,
        now: DateTime.now(),
        exclude: exclude,
        count: count,
      );
    } catch (_) {
      return const [];
    }
  }

  static bool _isLibraryMusic(QueueEntry e) =>
      e.libraryId != null && !e.isVideo && e.focusKey == null;

  bool _continuing = false;

  /// Automatic continuation: music of the library playing, the queue at its
  /// last track or the one before, no repeat: ten close tracks of the
  /// library are added at the end, from the last three heard.
  Future<void> _continueIfEnding() async {
    if (_continuing) return;
    final prefs = ref.read(playbackPrefsProvider).value;
    if (prefs == null || !prefs.autoplay) return;
    if (state.repeat != RepeatSetting.off) return;
    final current = state.current;
    if (current == null || !_isLibraryMusic(current)) return;
    if (state.order.length - state.position - 1 > 1) return;
    _continuing = true;
    try {
      final seeds = <TrackKey>[];
      for (var p = state.position; p >= 0 && seeds.length < 3; p--) {
        final e = state.entries[state.order[p]];
        if (_isLibraryMusic(e)) seeds.add(TrackKey.ofEntry(e));
      }
      final picks = await _closeTracks(
        seeds,
        exclude: {for (final e in state.entries) ?e.libraryId},
        count: 10,
      );
      // The queue changed meanwhile: that one decides.
      if (picks.isEmpty || !identical(state.current, current)) return;
      final base = state.entries.length;
      state = state.copyWith(
        entries: List.unmodifiable([
          ...state.entries,
          for (final i in picks) queueEntryOf(i),
        ]),
        order: [
          ...state.order,
          for (var i = 0; i < picks.length; i++) base + i,
        ],
      );
    } finally {
      _continuing = false;
    }
  }

  Future<void> _load({
    bool fromStart = false,
    Duration? startAt,
    bool skipped = false,
  }) async {
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
        return _load(fromStart: fromStart, skipped: skipped);
      }
      // Last one: opened anyway, the player shows "Fichier introuvable".
    }
    _skipped = 0;
    final memory = ref.read(playbackMemoryProvider);
    final start = startAt ?? (fromStart ? null : await memory.startFor(entry));
    // Before open(): the previous track's position is saved from the last
    // snapshot, which open() replaces.
    await memory.started(entry, skipped: skipped);
    _prepared = null;
    _refreshedOnline = null;
    _onlineAt = Duration.zero;
    var source = entry.source;
    if (entry.onlineId != null) {
      // Finding the stream takes seconds: the previous track stops now,
      // and the bar shows the new one from 0:00, not the old duration.
      if (engine.current.source != null) await engine.stop();
      final resolved = await _resolveOnline(entry);
      // Another entry was chosen meanwhile: that load goes on.
      if (!identical(state.current, entry)) return;
      // The player says why, with « Réessayer ».
      if (resolved == null) return;
      source = resolved;
    } else {
      ref.read(onlinePlaybackProvider.notifier).clear();
    }
    await engine.open(source, startAt: start);
    await _continueIfEnding();
    await _prepareNext();
  }

  /// The stream of an online [entry], or null when it cannot be had
  /// ([report]: the players show the search and its failure).
  Future<MediaSource?> _resolveOnline(
    QueueEntry entry, {
    bool fresh = false,
    bool report = true,
  }) async {
    final notifier = ref.read(onlinePlaybackProvider.notifier);
    if (report) notifier.resolving(entry);
    Future<MediaSource> attempt() => ref
        .read(onlineStreamsProvider)
        .resolve(
          entry.source,
          entry.onlineId!,
          fresh: fresh,
          ahead: !report,
          clip: entry.isVideo,
        );
    try {
      MediaSource source;
      try {
        source = await attempt();
      } on OnlineFailure catch (f) {
        // A slow answer is often passing (a busy computer, a slow
        // moment at YouTube): one more try before saying so.
        if (f.kind != OnlineFailureKind.slow ||
            !report ||
            !identical(state.current, entry)) {
          rethrow;
        }
        source = await attempt();
      }
      if (report) notifier.done(entry);
      return source;
    } catch (e) {
      if (report) notifier.failed(entry, OnlineFailure.of(e));
      return null;
    }
  }

  /// An online stream refused during playback (its address expired after
  /// a long pause, a network change): found again once, resumed where it
  /// was. A second failure shows the player's error card.
  void _watchOnline(PlaybackSnapshot s) {
    final current = state.current;
    final id = current?.onlineId;
    if (id == null || s.source?.uri != current!.source.uri) return;
    if (s.status == PlaybackStatus.playing && s.position > Duration.zero) {
      _onlineAt = s.position;
    }
    if (s.status != PlaybackStatus.error || _refreshedOnline == id) return;
    // An error as the stream ends is its end, not a refused address.
    final end = s.duration > Duration.zero ? s.duration : current.duration;
    if (end != null &&
        end > Duration.zero &&
        _onlineAt >= end - const Duration(seconds: 3)) {
      return;
    }
    _refreshedOnline = id;
    unawaited(_reopenOnline(current, _onlineAt));
  }

  Future<void> _reopenOnline(QueueEntry entry, Duration at) async {
    final source = await _resolveOnline(entry, fresh: true);
    final engine = _engine;
    if (source == null || engine == null || !identical(state.current, entry)) {
      return;
    }
    await engine.open(source, startAt: at > Duration.zero ? at : null);
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
    // An online entry next: its stream is found now (it takes seconds), so
    // the change of track does not wait, gapless or not.
    final upcoming = p >= 0 ? state.entries[state.order[p]] : null;
    if (!chain && upcoming?.onlineId != null) {
      unawaited(_resolveOnline(upcoming!, report: false));
    }
    QueueEntry? next =
        chain && p >= 0 && !ref.read(sleepTimerProvider).endOfTrack
        ? upcoming
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
    var nextSource = next?.source;
    if (next != null && next.onlineId != null) {
      nextSource = await _resolveOnline(next, report: false);
      // Not found: the usual end of track tries again, and says why.
      if (nextSource == null) next = null;
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
    await engine.prepareNext(next == null ? null : nextSource, crossfade: fade);
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
    await _continueIfEnding();
    await _prepareNext();
  }

  Future<void> _advanceAfterEnd() async {
    if (ref.read(sleepTimerProvider).endOfTrack) {
      ref.read(sleepTimerProvider.notifier).cancel();
      return;
    }
    if (state.repeat == RepeatSetting.one) return;
    if (state.hasNext) await _advance(skipped: false);
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

/// Reads a music file's tempo from its tags (tests answer it).
final bpmLoaderProvider = Provider<Future<double?> Function(String path)>(
  (_) =>
      (path) => rust_library.libraryBpm(path: path),
);

/// Tempo of the file at [QueueEntry.source] when its tags give one: the
/// seek bar's wave then moves on the beat (vinyl handoff). Null otherwise,
/// or for streams and content URIs.
final trackBpmProvider = FutureProvider.autoDispose.family<double?, Uri>((
  ref,
  uri,
) async {
  if (uri.scheme != 'file') return null;
  try {
    return await ref.read(bpmLoaderProvider)(uri.toFilePath());
  } catch (_) {
    return null;
  }
});

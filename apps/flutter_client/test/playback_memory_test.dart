import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';

import 'support/fakes.dart';

PlayEntry play(int id, DateTime at) =>
    PlayEntry(id: id, title: 't$id', kind: 'audio', at: at);

void main() {
  final t0 = DateTime(2026, 11, 19, 10);

  group('rules shared with the 0.1.x app', () {
    test('a play of the latest entry within 6 h is the same play', () {
      final h = notePlayed(const [], play(1, t0));
      expect(notePlayed(h, play(1, t0.add(const Duration(hours: 5)))), same(h));
      expect(
        notePlayed(h, play(1, t0.add(const Duration(hours: 7)))),
        hasLength(2),
      );
      expect(notePlayed(h, play(2, t0)).map((e) => e.id), [2, 1]);
    });

    test('history keeps the 200 newest plays', () {
      var h = <PlayEntry>[];
      for (var i = 0; i < 230; i++) {
        h = notePlayed(h, play(i, t0.add(Duration(days: i))));
      }
      expect(h, hasLength(historyMax));
      expect(h.first.id, 229);
    });

    test('resume points are not kept near the start or the end', () {
      const d = Duration(minutes: 4);
      expect(resumeValue(const Duration(seconds: 4), d), isNull);
      expect(resumeValue(const Duration(seconds: 236), d), isNull);
      expect(
        resumeValue(const Duration(seconds: 94, milliseconds: 600), d),
        '94',
      );
    });

    test('reads a 0.1.x history and drops corrupt records', () {
      final raw = jsonEncode([
        {
          'id': 7,
          'title': 'Marée haute',
          'kind': 'audio',
          'at': 1794000000000,
          'position': 94,
          'duration': 248,
        },
        {'id': 'x'},
        42,
        {'id': 8, 'title': 'Clip', 'kind': 'video', 'at': 1793000000000},
      ]);
      final h = parseHistory(raw);
      expect(h.map((e) => e.id), [7, 8]);
      expect(h.first.position, 94);
      expect(h.last.kind, 'video');
      expect(parseHistory('not json'), isEmpty);
      expect(parseHistory(null), isEmpty);
    });

    test('round-trips through JSON in the same shape', () {
      final e = PlayEntry(
        id: 3,
        title: 'a',
        kind: 'audio',
        at: t0,
        position: 12,
        duration: 200,
      );
      final back = parseHistory(jsonEncode([e.toJson()])).single;
      expect(back.toJson(), e.toJson());
    });
  });

  group('with the queue', () {
    late FakeEngine engine;
    late FakePlaybackStore store;
    late FakeLibraryApi library;
    late ProviderContainer c;

    QueueEntry track(int id) => QueueEntry(
      source: MediaSource.file('C:/m/$id.mp3'),
      title: 't$id',
      libraryId: id,
      duration: const Duration(minutes: 4),
    );

    setUp(() {
      engine = FakeEngine();
      store = FakePlaybackStore();
      library = FakeLibraryApi([]);
      c = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          playbackStoreProvider.overrideWithValue(store),
          libraryApiProvider.overrideWithValue(library),
        ],
      );
      c.read(queueProvider);
      c.read(playbackMemoryProvider);
    });
    tearDown(() => c.dispose());

    test(
      'a track starts at its saved position and is added to history',
      () async {
        store.values[positionKey(5)] = '94';
        await c.read(queueProvider.notifier).playAll([track(5)]);
        expect(engine.starts.single, const Duration(seconds: 94));
        expect(parseHistory(store.values[historyKey]).single.id, 5);
      },
    );

    test('each new play is counted once by the library', () async {
      await c.read(queueProvider.notifier).playAll([track(5), track(6)]);
      await c.read(queueProvider.notifier).next();
      expect(library.notedPlays, [5, 6]);
      // Back to 6 right away: the same play, not counted again.
      await c.read(queueProvider.notifier).playAll([track(6)]);
      await pumpEventQueue();
      expect(library.notedPlays, [5, 6]);
    });

    test('resume can be switched off like in 0.1.x', () async {
      store.values[positionKey(5)] = '94';
      store.values[resumeKey] = '0';
      await c.read(queueProvider.notifier).playAll([track(5)]);
      expect(engine.starts.single, isNull);
    });

    test('pausing saves the position; the end forgets it', () async {
      await c.read(queueProvider.notifier).playAll([track(5)]);
      engine.emit(
        engine.current.copyWith(position: const Duration(seconds: 61)),
      );
      await c.read(queueProvider.notifier).togglePlay();
      await pumpEventQueue();
      expect(store.values[positionKey(5)], '61');
      expect(parseHistory(store.values[historyKey]).single.position, 61);
      engine.emit(engine.current.copyWith(status: PlaybackStatus.ended));
      await pumpEventQueue();
      expect(store.values.containsKey(positionKey(5)), isFalse);
      // History keeps the end, as 0.1.x does: the video counts as watched.
      expect(parseHistory(store.values[historyKey]).single.position, 240);
    });

    test('switching track saves where the previous one stopped', () async {
      await c.read(queueProvider.notifier).playAll([track(5), track(6)]);
      engine.emit(
        engine.current.copyWith(position: const Duration(seconds: 30)),
      );
      await c.read(queueProvider.notifier).next();
      expect(store.values[positionKey(5)], '30');
      expect(parseHistory(store.values[historyKey]).map((e) => e.id), [6, 5]);
    });
  });
}

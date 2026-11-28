import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/playback/taste.dart';
import 'package:miarina_media/features/settings/settings_data.dart';
import 'package:miarina_media/src/rust/api/library.dart';

import 'support/fakes.dart';

LibraryItem track(int id, {String artist = 'Stony', bool video = false}) =>
    LibraryItem(
      id: id,
      title: 'T$id',
      path: 'C:/m/t$id.mp3',
      isVideo: video,
      durationSecs: 200,
      artist: artist,
      missing: false,
      favorite: false,
      plays: 0,
    );

void main() {
  late FakeEngine engine;
  late ProviderContainer container;
  late FakePlaybackStore store;
  final library = [
    for (var i = 1; i <= 6; i++) track(i),
    for (var i = 7; i <= 15; i++) track(i, artist: 'Other $i'),
    track(16, video: true),
  ];
  QueueController queue() => container.read(queueProvider.notifier);
  QueueState state() => container.read(queueProvider);
  Taste taste() => container.read(tasteProvider);

  Future<void> start({bool autoplay = true}) async {
    engine = FakeEngine();
    store = FakePlaybackStore();
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        playbackStoreProvider.overrideWithValue(store),
        settingsStoreProvider.overrideWithValue(
          FakeSettingsStore()..values['playback'] = {'autoplay': autoplay},
        ),
        libraryApiProvider.overrideWithValue(FakeLibraryApi(library)),
        presenceCheckProvider.overrideWithValue((_) async => true),
      ],
    );
    container.read(queueProvider);
    container.read(playbackMemoryProvider);
    await container.read(playbackPrefsProvider.future);
    await container.read(tasteProvider.notifier).ready();
  }

  tearDown(() => container.dispose());

  QueueEntry entryOf(int id) => queueEntryOf(library[id - 1]);

  test('passed at once, a track loses; heard to the end, it gains and the '
      'two heard in a row become neighbours', () async {
    await start(autoplay: false);
    await queue().playAll([entryOf(1), entryOf(2), entryOf(3)]);
    await queue().next(); // 1 passed in its first seconds
    await pumpEventQueue();
    final now = DateTime.now();
    expect(taste().score(1, now), lessThan(0));

    engine.emit(engine.current.copyWith(status: PlaybackStatus.ended));
    await pumpEventQueue();
    engine.emit(engine.current.copyWith(status: PlaybackStatus.ended));
    await pumpEventQueue();
    expect(state().current!.libraryId, 3);
    expect(taste().score(2, now), greaterThan(0));
    expect(taste().score(3, now), greaterThan(0));
    expect(taste().together(2, 3), 1);
    expect(taste().lastPlayed(3), isNotNull);
    // Kept for the next launch.
    expect(Taste.parse(store.values[tasteKey]).together(3, 2), 1);
  });

  test('the queue ending, close tracks of the library follow', () async {
    await start();
    await queue().playAll([entryOf(1), entryOf(2)]);
    await pumpEventQueue();
    final ids = [for (final e in state().entries) e.libraryId];
    expect(ids.take(2), [1, 2]);
    expect(ids.length, 12, reason: 'ten added');
    expect(ids.toSet().length, ids.length, reason: 'no track twice');
    expect(ids, isNot(contains(16)), reason: 'no video');
    expect(state().order.length, 12);
    expect(engine.opened.length, 1, reason: 'playing goes on');
  });

  test('continuation off, or repeat on: the queue stays as it is', () async {
    await start(autoplay: false);
    await queue().playAll([entryOf(1), entryOf(2)]);
    await pumpEventQueue();
    expect(state().entries.length, 2);
    container.dispose();

    await start();
    await queue().cycleRepeat(); // all
    await queue().playAll([entryOf(1), entryOf(2)]);
    await pumpEventQueue();
    expect(state().entries.length, 2);
  });

  test('radio from the track playing: it goes on, the radio follows', () async {
    await start(autoplay: false);
    await queue().playAll([entryOf(1), entryOf(8)]);
    final found = await queue().startRadio(state().current!);
    expect(found, 14, reason: 'every other music track');
    expect(state().current!.libraryId, 1);
    expect(state().position, 0);
    expect(state().entries.length, 15);
    expect(engine.opened.length, 1, reason: 'not started again');
    final ids = [for (final e in state().entries) e.libraryId];
    expect(ids.toSet().length, 15);
  });

  test('radio from another track starts it', () async {
    await start(autoplay: false);
    await queue().playAll([entryOf(9)]);
    await queue().startRadio(entryOf(3));
    expect(state().current!.libraryId, 3);
    expect(engine.opened.last.uri.path, endsWith('t3.mp3'));
    expect(state().upcoming, isNotEmpty);
  });
}

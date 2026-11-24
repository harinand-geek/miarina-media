import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/settings/settings_data.dart';

import 'support/fakes.dart';

// Réglages › Lecture: gapless and crossfade, prepared by the queue.

QueueEntry entry(String name, {bool video = false, int? id}) => QueueEntry(
  source: MediaSource.file('C:/m/$name.${video ? 'mkv' : 'mp3'}'),
  title: name,
  isVideo: video,
  libraryId: id,
);

void main() {
  late FakeEngine engine;
  late ProviderContainer container;
  late FakePlaybackStore store;
  QueueController queue() => container.read(queueProvider.notifier);
  QueueState state() => container.read(queueProvider);
  String? prepared() => engine.prepared?.uri.pathSegments.last;

  Future<void> start({bool gapless = true, int crossfade = 0}) async {
    engine = FakeEngine();
    store = FakePlaybackStore();
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        playbackStoreProvider.overrideWithValue(store),
        settingsStoreProvider.overrideWithValue(
          FakeSettingsStore()
            ..values['playback'] = {
              'gapless': gapless,
              'crossfadeSecs': crossfade,
            },
        ),
        presenceCheckProvider.overrideWithValue((_) async => true),
      ],
    );
    container.read(queueProvider);
    await container.read(playbackPrefsProvider.future);
  }

  tearDown(() => container.dispose());

  final abc = [entry('a'), entry('b'), entry('c')];

  test('the next entry waits in the engine; the queue follows it', () async {
    await start();
    await queue().playAll(abc);
    expect(prepared(), 'b.mp3');
    expect(engine.preparedFade, Duration.zero, reason: 'gapless only');

    engine.followPrepared();
    await pumpEventQueue();
    expect(state().current!.title, 'b');
    expect(engine.opened, hasLength(1), reason: 'not opened again');
    expect(prepared(), 'c.mp3');

    engine.followPrepared();
    await pumpEventQueue();
    expect(state().current!.title, 'c');
    expect(prepared(), isNull, reason: 'end of the queue');
  });

  test('changes to the queue change what is prepared', () async {
    await start();
    await queue().playAll(abc);
    queue().moveUpcoming(1, 0);
    await pumpEventQueue();
    expect(prepared(), 'c.mp3');
    queue().clearUpcoming();
    await pumpEventQueue();
    expect(prepared(), isNull);
    await queue().enqueue([entry('d')], next: true);
    expect(prepared(), 'd.mp3');
    await queue().cycleRepeat(); // all
    await queue().cycleRepeat(); // one: the same file loops
    expect(prepared(), isNull);
  });

  test('crossfade between two audio files, never with a video', () async {
    await start(crossfade: 6);
    await queue().playAll([entry('a'), entry('b'), entry('v', video: true)]);
    expect(prepared(), 'b.mp3');
    expect(engine.preparedFade, const Duration(seconds: 6));
    engine.followPrepared();
    await pumpEventQueue();
    expect(prepared(), 'v.mkv');
    expect(engine.preparedFade, Duration.zero, reason: 'gapless into video');
  });

  test(
    'a sleep timer at the end of the track takes the next one back',
    () async {
      await start();
      await queue().playAll(abc);
      expect(prepared(), 'b.mp3');
      container.read(sleepTimerProvider.notifier).atEndOfTrack();
      await pumpEventQueue();
      expect(prepared(), isNull);
      container.read(sleepTimerProvider.notifier).cancel();
      await pumpEventQueue();
      expect(prepared(), 'b.mp3');
    },
  );

  test('off, or a file that resumes elsewhere: nothing is prepared', () async {
    await start(gapless: false);
    await queue().playAll(abc);
    expect(prepared(), isNull);

    await start();
    await store.write({positionKey(7): '120'});
    await queue().playAll([entry('a'), entry('book', id: 7)]);
    expect(prepared(), isNull, reason: 'it starts from its saved point');
  });
}

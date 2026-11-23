import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/system_media.dart';

import 'support/fakes.dart';

/// The system media controls: what they are told, buttons they send.
class FakeSystemMedia implements SystemMediaApi {
  final updates = <SystemMediaState>[];
  final pressed = StreamController<String>.broadcast();

  @override
  void update(SystemMediaState state) => updates.add(state);

  @override
  Stream<String> buttons() => pressed.stream;
}

QueueEntry entry(String name) => QueueEntry(
  source: MediaSource.file('C:/m/$name.mp3'),
  title: name,
  subtitle: 'Les Cartographes',
  album: 'Boussole',
  artwork: 'C:/m/cover.jpg',
);

void main() {
  late FakeEngine engine;
  late FakeSystemMedia system;
  late ProviderContainer container;
  QueueController queue() => container.read(queueProvider.notifier);

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    engine = FakeEngine();
    system = FakeSystemMedia();
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
        systemMediaApiProvider.overrideWithValue(system),
      ],
    );
    container.read(systemMediaProvider);
    container.listen(playbackProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('what plays is shown, with its cover and the next button', () async {
    await queue().playAll([entry('Boussole'), entry('Fréquences')]);
    engine.emit(
      engine.current.copyWith(
        status: PlaybackStatus.playing,
        duration: const Duration(minutes: 3),
      ),
    );
    await flush();
    final s = system.updates.last;
    expect(s.hasMedia, isTrue);
    expect(s.playing, isTrue);
    expect(s.title, 'Boussole');
    expect(s.artist, 'Les Cartographes');
    expect(s.album, 'Boussole');
    expect(s.artwork, 'C:/m/cover.jpg');
    expect(s.canNext, isTrue);
    expect(s.durationMs, BigInt.from(180000));

    // Position ticks while playing are not sent each time.
    final before = system.updates.length;
    for (var i = 1; i <= 4; i++) {
      engine.emit(
        engine.current.copyWith(position: Duration(milliseconds: 250 * i)),
      );
    }
    await flush();
    expect(system.updates.length, before);

    // A seek is.
    engine.emit(engine.current.copyWith(position: const Duration(minutes: 2)));
    await flush();
    expect(system.updates.length, before + 1);
    expect(system.updates.last.positionMs, BigInt.from(120000));
  });

  test('media keys: play, pause, next, previous', () async {
    await queue().playAll([entry('a'), entry('b')]);
    engine.emit(engine.current.copyWith(status: PlaybackStatus.playing));
    await flush();

    system.pressed.add('pause');
    await flush();
    expect(engine.current.isPlaying, isFalse);

    system.pressed.add('play');
    await flush();
    expect(engine.current.isPlaying, isTrue);

    system.pressed.add('next');
    await flush();
    expect(container.read(queueProvider).current!.title, 'b');
    expect(system.updates.last.title, 'b');

    system.pressed.add('previous');
    await flush();
    expect(container.read(queueProvider).current!.title, 'a');

    // Stop pauses and keeps the queue.
    engine.emit(engine.current.copyWith(status: PlaybackStatus.playing));
    system.pressed.add('stop');
    await flush();
    expect(engine.current.isPlaying, isFalse);
    expect(container.read(queueProvider).current, isNotNull);
  });

  test('nothing loaded: the controls stay hidden', () async {
    engine.emit(engine.current.copyWith(volume: 0.5));
    await flush();
    expect(system.updates.single.hasMedia, isFalse);
    engine.emit(engine.current.copyWith(volume: 0.4));
    await flush();
    expect(system.updates, hasLength(1), reason: 'sent once');
  });
}

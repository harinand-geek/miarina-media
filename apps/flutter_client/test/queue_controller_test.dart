import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/playback/playback.dart';

import 'support/fakes.dart';

QueueEntry entry(String name) =>
    QueueEntry(source: MediaSource.file('C:/m/$name.mp3'), title: name);

void main() {
  late FakeEngine engine;
  late ProviderContainer container;
  QueueController queue() => container.read(queueProvider.notifier);
  QueueState state() => container.read(queueProvider);
  List<String> opened() => [
    for (final m in engine.opened) m.uri.pathSegments.last,
  ];

  setUp(() {
    engine = FakeEngine();
    container = ProviderContainer(
      overrides: [mediaEngineProvider.overrideWithValue(engine)],
    );
    container.read(queueProvider);
  });
  tearDown(() => container.dispose());

  final abc = [entry('a'), entry('b'), entry('c')];

  test('plays from the chosen entry, in list order', () async {
    await queue().playAll(abc, start: 1);
    expect(state().current!.title, 'b');
    await queue().next();
    expect(opened(), ['b.mp3', 'c.mp3']);
    expect(state().hasNext, isFalse);
    await queue().next();
    expect(opened(), ['b.mp3', 'c.mp3'], reason: 'no wrap without repeat all');
  });

  test('repeat all wraps around; repeat one is left to the engine', () async {
    await queue().playAll(abc, start: 2);
    await queue().cycleRepeat();
    expect(state().repeat, RepeatSetting.all);
    expect(engine.engineRepeat, RepeatSetting.off);
    await queue().next();
    expect(state().current!.title, 'a');
    await queue().cycleRepeat();
    expect(state().repeat, RepeatSetting.one);
    expect(engine.engineRepeat, RepeatSetting.one);
  });

  test('previous restarts the track after 3 s, otherwise goes back', () async {
    await queue().playAll(abc, start: 1);
    engine.emit(engine.current.copyWith(position: const Duration(seconds: 10)));
    await queue().previous();
    expect(engine.seeks.last, Duration.zero);
    expect(state().current!.title, 'b');
    engine.emit(engine.current.copyWith(position: const Duration(seconds: 1)));
    await queue().previous();
    expect(state().current!.title, 'a');
  });

  test('shuffle keeps the current entry and visits every entry once', () async {
    final many = [for (var i = 0; i < 20; i++) entry('t$i')];
    await queue().playAll(many, start: 5);
    await queue().toggleShuffle();
    expect(state().shuffle, isTrue);
    expect(state().current!.title, 't5');
    expect(state().position, 0);
    expect(state().order.toSet(), {for (var i = 0; i < 20; i++) i});
    await queue().toggleShuffle();
    expect(state().order, [for (var i = 0; i < 20; i++) i]);
    expect(state().current!.title, 't5');
  });

  test('the end of a track starts the next one', () async {
    await queue().playAll(abc);
    engine.emit(engine.current.copyWith(status: PlaybackStatus.ended));
    await pumpEventQueue();
    expect(opened(), ['a.mp3', 'b.mp3']);
  });

  test('toggle play pauses and resumes', () async {
    await queue().playAll(abc);
    await queue().togglePlay();
    expect(engine.current.status, PlaybackStatus.paused);
    await queue().togglePlay();
    expect(engine.current.status, PlaybackStatus.playing);
  });
}

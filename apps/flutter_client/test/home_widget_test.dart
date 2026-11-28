import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/playback/home_widget.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';

import 'support/fakes.dart';

class FakeHomeWidget implements HomeWidgetApi {
  final sent = <(String?, String?, String?)>[];
  final _buttons = StreamController<String>.broadcast();

  void press(String b) => _buttons.add(b);

  @override
  Future<void> update({String? title, String? artist, String? art}) async =>
      sent.add((title, artist, art));

  @override
  Stream<String> get buttons => _buttons.stream;
}

QueueEntry entry(String name) => QueueEntry(
  source: MediaSource.file('C:/m/$name.mp3'),
  title: name,
  subtitle: 'Stony',
  artwork: 'C:/covers/$name.jpg',
);

void main() {
  late FakeEngine engine;
  late FakeHomeWidget widget;
  late ProviderContainer container;

  setUp(() {
    engine = FakeEngine();
    widget = FakeHomeWidget();
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
        homeWidgetApiProvider.overrideWithValue(widget),
      ],
    );
    container.listen(homeWidgetProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('the track playing reaches the widget, once per track', () async {
    expect(widget.sent, [(null, null, null)], reason: 'nothing yet');
    await container.read(queueProvider.notifier).playAll([
      entry('a'),
      entry('b'),
    ]);
    await pumpEventQueue();
    expect(widget.sent.last, ('a', 'Stony', 'C:/covers/a.jpg'));
    final count = widget.sent.length;
    container.read(queueProvider.notifier).markFavorite(1, favorite: true);
    await pumpEventQueue();
    expect(widget.sent.length, count, reason: 'same track, nothing sent');
  });

  test('its buttons drive the queue', () async {
    await container.read(queueProvider.notifier).playAll([
      entry('a'),
      entry('b'),
    ]);
    widget.press('next');
    await pumpEventQueue();
    expect(container.read(queueProvider).current!.title, 'b');
    expect(widget.sent.last.$1, 'b');
    engine.emit(engine.current.copyWith(status: PlaybackStatus.playing));
    widget.press('toggle');
    await pumpEventQueue();
    expect(engine.current.isPlaying, isFalse);
    widget.press('previous');
    await pumpEventQueue();
    expect(container.read(queueProvider).current!.title, 'a');
  });
}

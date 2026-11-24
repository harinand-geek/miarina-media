import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/crossfade_engine.dart';
import 'package:miarina_media/engine/media_engine.dart';

import 'support/fakes.dart';

void main() {
  final a1 = MediaSource.file('C:/m/a.mp3');
  final b1 = MediaSource.file('C:/m/b.mp3');
  const fade = Duration(milliseconds: 300);

  test('the next file fades in while the current one fades out', () async {
    final a = FakeEngine();
    final b = FakeEngine();
    final engine = CrossfadeEngine(a, b);
    final seen = <PlaybackSnapshot>[];
    engine.snapshots.listen(seen.add);
    await engine.setVolume(0.8);

    await engine.open(a1);
    await engine.prepareNext(b1, crossfade: fade);
    expect(b.opened.single, b1, reason: 'waiting in the second engine');
    expect(a.prepared, isNull, reason: 'no gapless during a crossfade');

    // The last 300 ms of a.mp3: the crossfade starts.
    a.emit(
      a.current.copyWith(
        position:
            const Duration(minutes: 4) - const Duration(milliseconds: 250),
      ),
    );
    await pumpEventQueue();
    expect(engine.current.source, b1, reason: 'the new file is current');
    expect(seen.last.source, b1);
    expect(seen.last.volume, 0.8, reason: 'the user volume, not the ramp');

    await Future<void>.delayed(fade * 2);
    expect(a.current.source, isNull, reason: 'stopped after the fade');
    expect(b.current.volume, closeTo(0.8, 0.001));
    expect(a.current.volume, closeTo(0.8, 0.001), reason: 'ready again');

    // A file opened by the queue plays in the first engine again.
    await engine.open(a1);
    expect(a.opened.last, a1);
    expect(b.current.source, isNull);
    await engine.dispose();
  });

  test('no crossfade: gapless goes to the playing engine', () async {
    final a = FakeEngine();
    final b = FakeEngine();
    final engine = CrossfadeEngine(a, b);
    await engine.open(a1);
    await engine.prepareNext(b1);
    expect(a.prepared, b1);
    expect(b.opened, isEmpty);

    // Exclusive audio cannot open two outputs.
    await engine.applyPreferences(
      const EnginePreferences(exclusiveAudio: true),
    );
    await engine.prepareNext(b1, crossfade: fade);
    expect(b.opened, isEmpty);
    expect(a.prepared, b1);
    await engine.dispose();
  });
}

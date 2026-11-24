import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media3_engine.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/screen_control.dart';

// Android player (A7): gesture maths, gapless with Media3.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('slides and double taps', () {
    expect(slideKindAt(100, 400), SlideKind.brightness);
    expect(slideKindAt(300, 400), SlideKind.volume);
    // Up a quarter of the height: +25 %; never beyond 0..1.
    expect(slideValue(0.5, -100, 400), 0.75);
    expect(slideValue(0.5, 100, 400), 0.25);
    expect(slideValue(0.9, -400, 400), 1.0);
    expect(slideValue(0.1, 400, 400), 0.0);
    expect(doubleTapSeconds(50, 900), -10);
    expect(doubleTapSeconds(450, 900), 0);
    expect(doubleTapSeconds(850, 900), 10);
  });

  test('Media3: the next file is prepared, then followed', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(
      const MethodChannel('org.miarina.media/engine'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      const EventChannel('org.miarina.media/engine/events'),
      MockStreamHandler.inline(onListen: (_, s) => sink = s),
    );
    final engine = Media3Engine();
    expect(engine.capabilities.gapless, isTrue);
    expect(engine.capabilities.crossfade, isFalse);
    await pumpEventQueue();

    final a = MediaSource(
      Uri.parse('content://media/external/audio/media/1'),
      title: 'A',
    );
    final b = MediaSource(
      Uri.parse('content://media/external/audio/media/2'),
      title: 'B',
    );
    await engine.open(a);
    await engine.prepareNext(b);
    final prepared = calls.last;
    expect(prepared.method, 'prepareNext');
    expect(prepared.arguments, {
      'uri': 'content://media/external/audio/media/2',
      'title': 'B',
    });

    final seen = <PlaybackSnapshot>[];
    final sub = engine.snapshots.listen(seen.add);
    sink.success({
      'status': 'playing',
      'item': 'content://media/external/audio/media/1',
    });
    await pumpEventQueue();
    expect(seen.last.source?.title, 'A');
    // Media3 went on to B by itself: B is the source, no "ended" between.
    sink.success({
      'status': 'playing',
      'item': 'content://media/external/audio/media/2',
    });
    await pumpEventQueue();
    expect(seen.last.source?.title, 'B');
    expect(seen.map((s) => s.status), isNot(contains(PlaybackStatus.ended)));

    // Nothing prepared: the native list is cut after the current file.
    await engine.prepareNext(null);
    expect(calls.last.arguments, {'uri': null, 'title': null});
    await sub.cancel();
    await engine.dispose();
    messenger.setMockMethodCallHandler(
      const MethodChannel('org.miarina.media/engine'),
      null,
    );
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miarina_media/engine/engine_factory.dart';
import 'package:miarina_media/engine/media_engine.dart';

// Gapless, crossfade and normalization with the real engine (libmpv on
// Windows). Two short tones in CHAIN_MEDIA (a.mp3, b.mp3, 4 s each), e.g.
//   ffmpeg -f lavfi -i sine=f=440:d=4 a.mp3
//   ffmpeg -f lavfi -i sine=f=660:d=4 b.mp3
//   flutter test integration_test/chain_test.dart -d windows
//     --dart-define=CHAIN_MEDIA=<dir>
const _dir = String.fromEnvironment('CHAIN_MEDIA');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  initializeEngines();

  final a = MediaSource.file('$_dir/a.mp3');
  final b = MediaSource.file('$_dir/b.mp3');

  late MediaEngine engine;
  late List<PlaybackSnapshot> seen;
  late StreamSubscription<PlaybackSnapshot> sub;

  setUp(() {
    expect(File('$_dir/a.mp3').existsSync(), isTrue, reason: 'CHAIN_MEDIA');
    engine = createPlatformEngine()!;
    seen = [];
    sub = engine.snapshots.listen(seen.add);
  });
  tearDown(() async {
    await sub.cancel();
    await engine.dispose();
  });

  /// Waits until the engine plays [m]; returns a's last position before.
  Future<Duration> switchTo(MediaSource m) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (engine.current.source?.uri == m.uri && engine.current.isPlaying) {
        final before = seen
            .where((s) => s.source?.uri == a.uri && s.position > Duration.zero)
            .map((s) => s.position);
        return before.isEmpty ? Duration.zero : before.last;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('never played ${m.uri}; last: ${engine.current.status}');
  }

  testWidgets('gapless: b follows a with no end in between', (tester) async {
    await tester.runAsync(() async {
      await engine.setVolume(0.1); // short tones, kept quiet
      expect(engine.capabilities.gapless, isTrue);
      await engine.open(a);
      await engine.prepareNext(b);
      final last = await switchTo(b);
      // ignore: avoid_print
      print('gapless: a last seen at $last');
      expect(
        seen.where((s) => s.status == PlaybackStatus.ended),
        isEmpty,
        reason: 'the engine went on by itself',
      );
      // b really plays on.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(engine.current.source?.uri, b.uri);
      expect(engine.current.position, greaterThan(Duration.zero));
    });
  });

  testWidgets('crossfade: b starts before a ends', (tester) async {
    await tester.runAsync(() async {
      await engine.setVolume(0.1); // short tones, kept quiet
      expect(engine.capabilities.crossfade, isTrue);
      await engine.open(a);
      await engine.prepareNext(b, crossfade: const Duration(seconds: 1));
      final last = await switchTo(b);
      // ignore: avoid_print
      print('crossfade: switched with a at $last');
      expect(last, greaterThan(const Duration(milliseconds: 2500)));
      expect(last, lessThan(const Duration(milliseconds: 3600)));
      expect(seen.where((s) => s.status == PlaybackStatus.ended), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(engine.current.source?.uri, b.uri);
      expect(engine.current.isPlaying, isTrue);
    });
  });

  testWidgets('normalization and the equalizer play together', (tester) async {
    await tester.runAsync(() async {
      await engine.setVolume(0.1); // short tones, kept quiet
      expect(engine.capabilities.normalization, isTrue);
      await engine.applyPreferences(const EnginePreferences(normalize: true));
      expect(await engine.setEqualizer([3, 0, 0, 0, 0, -3]), isTrue);
      await engine.open(a);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(engine.current.isPlaying, isTrue);
      expect(engine.current.position, greaterThan(Duration.zero));
      expect(engine.current.error, isNull);
    });
  });

  testWidgets('A–B repeats a part; delays and size are accepted', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await engine.setVolume(0.1); // short tones, kept quiet
      await engine.open(a);
      await engine.setAbLoop(
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1500),
      );
      await engine.setAudioDelay(const Duration(milliseconds: 100));
      await engine.setSubtitleDelay(const Duration(milliseconds: -300));
      await engine.setSubtitleScale(1.4);
      // a.mp3 lasts 4 s: after 3 s it still plays inside A–B.
      await Future<void>.delayed(const Duration(seconds: 3));
      final p = engine.current.position;
      // ignore: avoid_print
      print('A–B: position after 3 s = $p');
      expect(p, greaterThanOrEqualTo(const Duration(milliseconds: 400)));
      expect(p, lessThan(const Duration(milliseconds: 1700)));
      expect(engine.current.status, isNot(PlaybackStatus.ended));
      await engine.setAbLoop(null, null);
    });
  });

  testWidgets('voice boost plays; no silence skipping on libmpv', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await engine.setVolume(0.1); // short tones, kept quiet
      expect(engine.capabilities.skipSilence, isFalse);
      expect(engine.capabilities.voiceBoost, isTrue);
      await engine.setSpeechAids(skipSilence: false, voiceBoost: true);
      await engine.open(MediaSource.file('$_dir/speech.mp3'));
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(engine.current.error, isNull);
      expect(engine.current.position, greaterThan(Duration.zero));
      await engine.setSpeechAids(skipSilence: false, voiceBoost: false);
    });
  });
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/capture/capture_data.dart';
import 'package:miarina_media/features/capture/screen_tools.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/convert/convert_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/recorder/recorder_data.dart';
import 'package:miarina_media/features/recorder/recorder_screen.dart';

import 'convert_test.dart' show FakeConvertApi;
import 'support/fakes.dart';
import 'support/screen_fakes.dart';

// Outils PC › Enregistrer l'écran.

class FakeRecorderApi implements RecorderApi {
  final started = <RecordOptions>[];
  final stems = <String>[];
  var pauses = 0, resumes = 0;
  final muted = <bool>[];
  Object? failStart;
  final _status = StreamController<RecorderStatus>.broadcast();

  void emit(String phase, int ms) => _status.add(
    RecorderStatus(phase: phase, elapsedMs: BigInt.from(ms), micMuted: false),
  );

  @override
  Future<void> start(RecordOptions options) async {
    if (failStart != null) throw failStart!;
    started.add(options);
  }

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<Recording> stop(String stem) async {
    stems.add(stem);
    return Recording(
      path: '${defaultDir()}\\$stem.mp4',
      durationSecs: 252,
      size: BigInt.from(86 * 1024 * 1024),
      format: 'mp4',
    );
  }

  @override
  void setMicMuted(bool m) => muted.add(m);

  @override
  Stream<RecorderStatus> events() => _status.stream;

  @override
  String defaultDir() => r'C:\Users\Hery\Videos\Miarina';
}

void main() {
  group('settings and places', () {
    test('defaults (the mockup’s), saved and read back', () {
      const s = RecorderSettings();
      expect(
        (s.source, s.format, s.fps, s.quality, s.systemAudio, s.mic),
        ('screen', 'mp4', 30, 'high', true, false),
      );
      expect((s.cursor, s.countdown, s.hasSound), (true, true, true));
      final changed = s.copyWith(
        source: 'region',
        region: const Rect.fromLTWH(10, 20, 640, 360),
        format: 'gif',
        fps: 60,
        mic: true,
        folder: r'D:\Rec',
      );
      final back = RecorderSettings.fromJson(changed.toJson());
      expect(back.region, const Rect.fromLTWH(10, 20, 640, 360));
      expect(
        (back.format, back.fps, back.mic, back.folder),
        ('gif', 60, true, r'D:\Rec'),
      );
      expect(back.hasSound, isFalse, reason: 'a GIF has no sound');
      final odd = RecorderSettings.fromJson({'fps': 25, 'source': 'tab'});
      expect((odd.fps, odd.source), (30, 'screen'));
    });

    test('the bar sits at the top centre of the filmed screen', () {
      const screens = [
        (rect: Rect.fromLTWH(0, 0, 1920, 1080), primary: true),
        (rect: Rect.fromLTWH(1920, 0, 2560, 1440), primary: false),
      ];
      final screen = screenOf(
        screens,
        const Rect.fromLTWH(2000, 100, 400, 300),
      );
      expect(screen, screens[1].rect);
      expect(barRect(screen, 1.5), const Rect.fromLTWH(2900, 21, 600, 72));
      expect(
        recordingStem('Enregistrement', DateTime(2026, 11, 17, 14, 32)),
        'Enregistrement 2026-11-17 14-32',
      );
    });
  });

  group('controller', () {
    late FakeScreenTools tools;
    late FakeRecorderApi api;
    late FakeSettingsStore store;
    late ProviderContainer container;

    setUp(() {
      tools = FakeScreenTools()
        ..monitorList = [
          (rect: const Rect.fromLTWH(0, 0, 1920, 1080), primary: true),
          (rect: const Rect.fromLTWH(1920, 0, 2560, 1440), primary: false),
        ];
      api = FakeRecorderApi();
      store = FakeSettingsStore();
      container = ProviderContainer(
        overrides: [
          screenToolsProvider.overrideWithValue(tools),
          recorderApiProvider.overrideWithValue(api),
          settingsStoreProvider.overrideWithValue(store),
        ],
      );
      container.listen(recorderProvider, (_, _) {});
    });
    tearDown(() => container.dispose());

    RecorderController rec() => container.read(recorderProvider.notifier);

    test('a screen: bar out of the video, record, stop, recent', () async {
      store.values['recorder'] = const RecorderSettings(
        monitor: 1,
        countdown: false,
        mic: true,
      ).toJson();
      final events = <RecorderEvent>[];
      rec().events.listen(events.add);
      await rec().start();
      final o = api.started.single;
      expect(
        (o.source, o.x, o.y, o.width, o.height),
        ('screen', 1920, 0, 2560, 1440),
      );
      expect(
        (o.format, o.fps, o.quality, o.systemAudio, o.mic, o.cursor),
        ('mp4', 30, 'high', true, true, true),
      );
      expect(o.outDir, r'C:\Users\Hery\Videos\Miarina');
      expect(tools.excluded, [true]);
      expect(tools.overlayActivates, [false], reason: 'the focus stays');
      expect(tools.overlays.single.top, greaterThanOrEqualTo(0));
      expect(container.read(recorderProvider).phase, RecPhase.recording);
      expect(container.read(recorderProvider).barShown, isTrue);

      api.emit('recording', 5000);
      await pumpEventQueue();
      expect(container.read(recorderProvider).elapsedMs, 5000);
      await rec().pause();
      expect(
        (api.pauses, container.read(recorderProvider).phase),
        (1, RecPhase.paused),
      );
      await rec().resume();
      rec().toggleMic();
      expect(api.muted.last, isTrue);

      await rec().stop();
      expect(api.stems.single, startsWith('Enregistrement 20'));
      expect(tools.exits, 1);
      expect(tools.excluded, [true, false]);
      expect(container.read(recorderProvider).busy, isFalse);
      final recents = await container.read(recentRecordingsProvider.future);
      expect(recents.single.path, endsWith('.mp4'));
      expect(recents.single.size, 86 * 1024 * 1024);
      await pumpEventQueue();
      expect(events.single, isA<RecordingSaved>());
    });

    test('the countdown can be cancelled; nothing starts', () async {
      final start = rec().start();
      await pumpEventQueue();
      expect(container.read(recorderProvider).phase, RecPhase.countdown);
      expect(container.read(recorderProvider).countdown, 3);
      await rec().toggle();
      await start;
      expect(api.started, isEmpty);
      expect(container.read(recorderProvider).busy, isFalse);
      expect(tools.exits, 1);
    });

    test('a window that closed, a failing start', () async {
      store.values['recorder'] = const RecorderSettings(
        source: 'window',
        window: 'Bloc-notes',
        countdown: false,
      ).toJson();
      final events = <RecorderEvent>[];
      rec().events.listen(events.add);
      await rec().start();
      await pumpEventQueue();
      expect((events.single as RecordingFailed).reason, 'window_gone');
      expect(tools.overlays, isEmpty);

      tools.windowList = [
        (title: 'Bloc-notes', rect: const Rect.fromLTWH(100, 100, 800, 600)),
      ];
      api.failStart = Exception('record_failed: no window');
      await rec().start();
      await pumpEventQueue();
      expect((events.last as RecordingFailed).reason, 'record_failed');
      expect(tools.exits, 1, reason: 'the bar went away');
      api.failStart = null;
      await rec().start();
      expect(api.started.single.windowTitle, 'Bloc-notes');
    });

    test('Alt R and « Filmer » come from the capture tools', () async {
      store.values['recorder'] = const RecorderSettings(countdown: false)
          .toJson();
      final capture = container.read(captureProvider.notifier);
      capture.onFilm!(const Rect.fromLTWH(2000, 50, 640, 360));
      await pumpEventQueue();
      expect(api.started.single.source, 'region');
      expect(api.started.single.x, 2000);
      final saved = await container.read(recorderSettingsProvider.future);
      expect(saved.region, const Rect.fromLTWH(2000, 50, 640, 360));
      expect(capture.blocked!(), isTrue, reason: 'no zone overlay now');
      capture.onRecordKey!();
      await pumpEventQueue();
      expect(api.stems, hasLength(1), reason: 'Alt R stops');
    });
  });

  group('screens', () {
    late FakeScreenTools tools;
    late FakeRecorderApi api;
    late FakeSettingsStore store;
    late FakeConvertApi convert;

    Future<void> pumpApp(WidgetTester tester, String route) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(FakeEngine()),
            libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            indexerApiProvider.overrideWithValue(FakeIndexerApi()),
            healthApiProvider.overrideWithValue(FakeHealthApi()),
            getApiProvider.overrideWithValue(FakeGetApi()),
            screenToolsProvider.overrideWithValue(tools),
            recorderApiProvider.overrideWithValue(api),
            convertApiProvider.overrideWithValue(convert),
            droppedFilesProvider.overrideWith((_) => const Stream.empty()),
            recorderFolderPickerProvider.overrideWithValue((_) async => null),
            recordingExistsProvider.overrideWithValue((_) => true),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(store),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(route),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
    }

    setUp(() {
      tools = FakeScreenTools();
      api = FakeRecorderApi();
      convert = FakeConvertApi();
      store = FakeSettingsStore()
        ..values['onboardingDone'] = true
        ..values['recorder'] = const RecorderSettings(countdown: false)
            .toJson();
    });

    testWidgets('choices, start, the bar, stop, the recent recording', (
      tester,
    ) async {
      await pumpApp(tester, Routes.recorder);
      expect(find.text('Enregistrer l’écran'), findsWidgets);
      expect(
        find.text(
          'Écran 1 · 1920 × 1080. Choisissez l’écran si vous en avez plusieurs.',
        ),
        findsOneWidget,
      );
      expect(find.text('MP4 · 30 i/s · son du PC'), findsOneWidget);
      expect(find.text('Alt R'), findsOneWidget);
      expect(find.text('Aucun enregistrement pour l’instant.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Micro'));
      await settle(tester);
      expect(find.text('MP4 · 30 i/s · son du PC + micro'), findsOneWidget);
      await tester.tap(find.text('60'));
      await tester.tap(find.text('Originale'));
      await settle(tester);

      await tester.tap(find.text('Démarrer l’enregistrement'));
      await settle(tester);
      expect(
        (api.started.single.fps, api.started.single.quality),
        (60, 'original'),
      );
      // The window is the bar now.
      expect(find.text('REC'), findsOneWidget);
      expect(find.bySemanticsLabel('Couper le micro'), findsOneWidget);
      api.emit('recording', 83000);
      await settle(tester);
      expect(find.text('00:01:23'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Pause'));
      await settle(tester);
      expect(find.text('PAUSE'), findsOneWidget);
      await tester.tap(find.text('Arrêter'));
      await settle(tester);
      expect(find.text('REC'), findsNothing);
      expect(
        find.text('Vidéo enregistrée dans la bibliothèque'),
        findsOneWidget,
      );
      expect(find.textContaining('Enregistrement 20'), findsOneWidget);
      expect(find.text('00:04:12 · 86 Mo'), findsOneWidget);
    });

    testWidgets('Convertir’s tile; a recording sent to Convertir', (
      tester,
    ) async {
      store.values['recordings'] = [
        {
          'path': r'C:\Users\Hery\Videos\Miarina\Clip.mp4',
          'seconds': 12.0,
          'size': 1048576,
          'format': 'mp4',
        },
      ];
      await pumpApp(tester, Routes.convert);
      expect(find.text('Enregistrer l’écran'), findsWidgets);
      // The Video tile opens the recorder.
      await tester.tap(find.text('Enregistrer l’écran').last);
      await settle(tester);
      expect(find.text('Démarrer l’enregistrement'), findsOneWidget);
      expect(find.text('Clip.mp4'), findsOneWidget);

      await tester.tap(find.text('Démarrer l’enregistrement'));
      await settle(tester);
      api.emit('recording', 65000);
      await settle(tester);
      // The bar covers the window; the screens under it are paused.
      expect(find.text('00:01:05'), findsOneWidget);
      await tester.tap(find.text('Arrêter'));
      await settle(tester);

      // A recent recording (Clip) to Convertir: waits in the next dialog.
      await tester.tap(find.bySemanticsLabel('Convertir').at(1));
      await settle(tester);
      expect(
        find.text('Choisissez un format ou un outil : le fichier sera ajouté.'),
        findsOneWidget,
      );
      await tester.tap(find.text('→ MP4'));
      await settle(tester);
      expect(find.text('Clip.mp4'), findsOneWidget);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

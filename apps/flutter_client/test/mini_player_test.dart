import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/design/widgets/cover_art.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/mini/mini_player.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/l10n/app_localizations_fr.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class FakeAppWindow implements AppWindow {
  final calls = <String>[];

  @override
  Future<void> enterCompact({required bool onTop}) async =>
      calls.add('compact onTop=$onTop');

  @override
  Future<void> leaveCompact() async => calls.add('restore');

  @override
  Future<void> setOnTop(bool value) async => calls.add('onTop=$value');
}

void main() {
  test('the taskbar buttons follow the queue', () {
    final t = L10nFr();
    expect(
      taskbarState(queue: const QueueState(), playing: false, t: t)['enabled'],
      false,
    );
    final entries = [
      for (final i in [track(1, 'Seuil'), track(2, 'Fin')]) queueEntryOf(i),
    ];
    final state = QueueState(
      entries: entries,
      order: const [0, 1],
      position: 0,
    );
    expect(taskbarState(queue: state, playing: true, t: t), {
      'enabled': true,
      'playing': true,
      'hasPrevious': true,
      'hasNext': true,
      'tips': ['Précédent', 'Lecture', 'Pause', 'Suivant'],
    });
  });

  group('in the app', () {
    late FakeAppWindow window;
    late FakeEngine engine;

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final items = [track(1, 'Marée haute', artist: 'Nafy Rakoto')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(engine),
            libraryApiProvider.overrideWithValue(FakeLibraryApi(items)),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            indexerApiProvider.overrideWithValue(FakeIndexerApi()),
            healthApiProvider.overrideWithValue(FakeHealthApi()),
            appWindowProvider.overrideWithValue(window),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(
              FakeSettingsStore()..values['onboardingDone'] = true,
            ),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(Routes.tracks),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      await container.read(queueProvider.notifier).playAll([
        queueEntryOf(items.first),
      ]);
      await settle(tester);
      return container;
    }

    setUp(() {
      window = FakeAppWindow();
      engine = FakeEngine();
    });

    testWidgets('W-M4: compact window, pinned, then back to the full one', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('Mini-lecteur (Ctrl M)'));
      await settle(tester);
      expect(window.calls, ['compact onTop=true']);
      // The window shrinks to 340 × 120.
      tester.view.physicalSize = miniSize;
      await settle(tester);
      expect(find.text('Albums'), findsNothing, reason: 'no sidebar');
      expect(find.text('Marée haute'), findsWidgets);
      expect(find.text('Nafy Rakoto'), findsWidgets);
      final cover = tester.getSize(find.byType(CoverArt).last);
      expect(cover.height, closeTo(118, 1));

      // The coral fill shows how far the track is.
      engine.emit(
        const PlaybackSnapshot(
          status: PlaybackStatus.paused,
          position: Duration(seconds: 49),
          duration: Duration(seconds: 245),
        ),
      );
      await settle(tester);
      final fill = tester.getSize(
        find.byWidgetPredicate(
          (w) => w is FractionallySizedBox && w.widthFactor == 0.2,
        ),
      );
      expect(fill.height, 3);
      expect(fill.width, greaterThan(30));

      // Play / pause from the mini player.
      await tester.tap(find.bySemanticsLabel(RegExp('^(Pause|Lecture)\$')));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('Ne plus garder au premier plan'));
      await settle(tester);
      expect(window.calls.last, 'onTop=false');
      expect(find.bySemanticsLabel('Garder au premier plan'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Agrandir la fenêtre'));
      tester.view.physicalSize = const Size(1440, 900);
      await settle(tester);
      expect(window.calls.last, 'restore');
      expect(find.text('Albums'), findsOneWidget, reason: 'full window again');
    });

    testWidgets('taller, the cover goes above the controls', (tester) async {
      await pumpApp(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(window.calls, ['compact onTop=true']);
      tester.view.physicalSize = miniMaxSize;
      await settle(tester);
      final cover = tester.getRect(find.byType(CoverArt).last);
      expect(cover.width, closeTo(338, 1));
      expect(cover.top, closeTo(1, 1));
      expect(
        tester.getTopLeft(find.bySemanticsLabel('Agrandir la fenêtre')).dy,
        greaterThan(cover.bottom),
      );

      // Ctrl M again: back to the full window.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      tester.view.physicalSize = const Size(1440, 900);
      await settle(tester);
      expect(window.calls.last, 'restore');
    });
  });
}

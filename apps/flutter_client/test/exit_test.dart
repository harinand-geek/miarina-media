import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/exit_guard.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

void main() {
  late int shutdowns;
  late Completer<void> core;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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
          appShutdownProvider.overrideWithValue(() {
            shutdowns++;
            return core.future;
          }),
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
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUp(() {
    shutdowns = 0;
  });

  testWidgets('closing waits for the core, once, then exits', (tester) async {
    // Made in the test's zone, so its completion is seen by pump().
    core = Completer<void>();
    await pumpApp(tester);
    AppExitResponse? first, second;
    unawaited(tester.binding.handleRequestAppExit().then((r) => first = r));
    unawaited(tester.binding.handleRequestAppExit().then((r) => second = r));
    await tester.pump(const Duration(seconds: 1));
    expect(shutdowns, 1, reason: 'asked twice, shut down once');
    expect(first, isNull, reason: 'downloads still flushing');

    core.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect((first, second), (AppExitResponse.exit, AppExitResponse.exit));
  });

  testWidgets('a stuck core never keeps the window open', (tester) async {
    core = Completer<void>();
    await pumpApp(tester);
    AppExitResponse? response;
    unawaited(tester.binding.handleRequestAppExit().then((r) => response = r));
    await tester.pump(shutdownLimit - const Duration(seconds: 1));
    expect(response, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(response, AppExitResponse.exit);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miarina_media/app/app.dart';
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
import 'package:miarina_media/features/tour/tour.dart';

import 'support/fakes.dart';

// First use on Windows: the guided tour.

void main() {
  late FakeSettingsStore store;

  Future<void> pumpApp(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1440, 900);
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

  setUp(() => store = FakeSettingsStore()..values['onboardingDone'] = true);

  testWidgets('from Settings: steps, the lit place, Esc ends it', (
    tester,
  ) async {
    await pumpApp(tester, '/settings/general');
    await tester.tap(find.text('Lancer'));
    await settle(tester);
    expect(find.text('Bienvenue dans Miarina Media'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await settle(tester);
    expect(find.text('Deux espaces'), findsOneWidget);
    expect(TourTarget.rectOf(TourSpot.space), isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text('Coller un lien'), findsOneWidget);
    expect(TourTarget.rectOf(TourSpot.getLink), isNotNull);
    await tester.tap(find.text('Précédent'));
    await settle(tester);
    expect(find.text('Deux espaces'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Deux espaces'), findsNothing);
    expect(store.values[TourController.doneKey], isTrue);
  });

  testWidgets('every step to the end lights its place', (tester) async {
    await pumpApp(tester, Routes.listenHome);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MiarinaApp)),
    );
    container.read(tourProvider.notifier).start();
    await settle(tester);
    for (var i = 1; i < tourSteps.length; i++) {
      await tester.tap(find.text('Suivant'));
      await settle(tester);
      final spot = tourSteps[i].spot!;
      expect(TourTarget.rectOf(spot), isNotNull, reason: spot.name);
    }
    await tester.tap(find.text('Terminer'));
    await settle(tester);
    expect(container.read(tourProvider), isNull);
    expect(store.values[TourController.doneKey], isTrue);
  });

  test('after the first-launch screens: once, on Windows only', () async {
    final s = FakeSettingsStore();
    var c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(s),
        desktopShellProvider.overrideWithValue(true),
        routerProvider.overrideWithValue(GoRouterStub.router),
      ],
    );
    await c.read(tourProvider.notifier).startIfNew();
    expect(c.read(tourProvider), 0);
    await c.read(tourProvider.notifier).finish();
    await c.read(tourProvider.notifier).startIfNew();
    expect(c.read(tourProvider), isNull, reason: 'seen once');
    c.dispose();
    c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
        desktopShellProvider.overrideWithValue(false),
      ],
    );
    await c.read(tourProvider.notifier).startIfNew();
    expect(c.read(tourProvider), isNull, reason: 'not on the phone');
    c.dispose();
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// A router that goes nowhere, for the controller alone.
abstract final class GoRouterStub {
  static final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
  );
}

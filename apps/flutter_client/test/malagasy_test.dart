import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:miarina_media/l10n/app_localizations.dart';

import 'support/fakes.dart';

// Malagasy: the app's texts in mg, Flutter's own (dialogs, menus) in French.

void main() {
  late FakeSettingsStore store;

  Future<void> pumpApp(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('mg')];
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

  test('Malagasy is offered', () {
    expect(L10n.supportedLocales, contains(const Locale('mg')));
  });

  testWidgets('screens, the tour and a dialog in Malagasy', (tester) async {
    await pumpApp(tester, '/settings/general');
    expect(find.text('Fikirana'), findsWidgets);
    expect(find.text('Fiteny'), findsOneWidget);
    expect(find.text('Fitetezana voatarika'), findsOneWidget);

    await tester.tap(find.text('Atombohy'));
    await settle(tester);
    expect(find.text("Tongasoa eto amin'ny Miarina Media"), findsOneWidget);
    await tester.tap(find.text('Dinganina ny fitetezana'));
    await settle(tester);

    // A dialog: its barrier and buttons use Flutter's own texts.
    await pumpApp(tester, Routes.playlists);
    await tester.tap(find.text('Vaovao'));
    await settle(tester);
    expect(find.text('Lisitra vaovao'), findsOneWidget);
    await tester.tap(find.text('Foanana'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

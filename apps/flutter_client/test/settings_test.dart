import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/design/tokens.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/now_playing/sound_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Finder switchFor(String label) =>
    find.byWidgetPredicate((w) => w is MmSwitch && w.label == label);

void main() {
  late FakeEngine engine;
  late FakePlaybackStore store;
  late FakeSettingsStore settings;

  Future<void> pumpApp(
    WidgetTester tester, {
    required String start,
    bool desktop = true,
    Size size = const Size(1280, 860),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          libraryApiProvider.overrideWithValue(
            FakeLibraryApi([track(1, 'Basse marée')]),
          ),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          desktopShellProvider.overrideWithValue(desktop),
          settingsStoreProvider.overrideWithValue(settings),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(store),
          initialRouteProvider.overrideWithValue(start),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    engine = FakeEngine();
    store = FakePlaybackStore();
    settings = FakeSettingsStore();
  });

  Future<void> choose(WidgetTester tester, String menu, String value) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^$menu : ')));
    await settle(tester);
    await tester.tap(find.text(value).last);
    await settle(tester);
  }

  testWidgets('W-S1: theme, text size and motion apply live and are kept', (
    tester,
  ) async {
    await pumpApp(tester, start: '${Routes.settings}/appearance');
    expect(find.text('Apparence'), findsWidgets);
    // Own navigation instead of the sidebar.
    expect(find.text('Albums'), findsNothing);
    expect(find.text('Raccourcis'), findsOneWidget);

    BuildContext ctx() => tester.element(find.text('Thème'));
    expect(MmColors.of(ctx()).brightness, Brightness.dark);
    await tester.tap(find.text('Clair'));
    await settle(tester);
    expect(MmColors.of(ctx()).brightness, Brightness.light);
    expect(store.values['mm:theme'], 'light');

    await choose(tester, 'Taille du texte', '120 %');
    expect(MediaQuery.textScalerOf(ctx()).scale(10), closeTo(12, 0.01));
    expect((settings.values['appearance'] as Map)['textScale'], 1.2);

    await tester.tap(switchFor('Réduire les animations'));
    await settle(tester);
    expect(MediaQuery.disableAnimationsOf(ctx()), isTrue);

    // P1: shown, not changeable.
    expect(find.text('Couleur de lecture'), findsOneWidget);
    expect(find.text('P1'), findsWidgets);
  });

  testWidgets('saved appearance is read back at start (0.1.x theme key)', (
    tester,
  ) async {
    store.values['mm:theme'] = 'light';
    settings.values['appearance'] = {'textScale': 1.1, 'density': 'compact'};
    await pumpApp(tester, start: Routes.tracks);
    final ctx = tester.element(find.text('Basse marée'));
    expect(MmColors.of(ctx).brightness, Brightness.light);
    expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(11, 0.01));
    // Compact density: 40 px rows in the tracks table.
    final list = tester.widget<ListView>(
      find.ancestor(
        of: find.text('Basse marée'),
        matching: find.byType(ListView),
      ),
    );
    expect(list.itemExtent, 40);
  });

  testWidgets('language follows the setting', (tester) async {
    await pumpApp(tester, start: Routes.settings);
    expect(find.text('Langue'), findsOneWidget);
    await choose(tester, 'Langue', 'English');
    expect(find.text('Language'), findsOneWidget);
    expect(store.values['mm:lang'], 'en');
  });

  testWidgets('W-S2: real settings reach the engine; P1 stay disabled', (
    tester,
  ) async {
    await pumpApp(tester, start: '${Routes.settings}/playback');
    expect(engine.preferences?.subtitleLanguage, 'fr');

    await tester.tap(switchFor("Reprendre où j'en étais"));
    await settle(tester);
    expect(store.values[resumeKey], '0');

    await choose(tester, 'Sous-titres par défaut', 'English');
    expect(engine.preferences?.subtitleLanguage, 'en');

    await choose(tester, 'Sortie audio', 'DAC USB');
    expect(engine.preferences?.audioOutput, 'wasapi/dac');

    await tester.tap(switchFor('Mode exclusif WASAPI'));
    await settle(tester);
    expect(engine.preferences?.exclusiveAudio, isTrue);

    await tester.ensureVisible(
      switchFor('Charger les sous-titres à côté du fichier'),
    );
    await settle(tester);
    await tester.tap(switchFor('Charger les sous-titres à côté du fichier'));
    await settle(tester);
    expect(engine.preferences?.sidecarSubtitles, isFalse);
    expect((settings.values['playback'] as Map)['subtitleLanguage'], 'en');

    // Gapless is not possible with the current queue: P1, not simulated.
    await tester.ensureVisible(switchFor('Lecture sans blanc (gapless)'));
    await settle(tester);
    await tester.tap(
      switchFor('Lecture sans blanc (gapless)'),
      warnIfMissed: false,
    );
    await settle(tester);
    expect(
      tester.widget<MmSwitch>(switchFor('Lecture sans blanc (gapless)')).value,
      isFalse,
    );
  });

  testWidgets('Android (A-08): list of sections, then a page', (tester) async {
    await pumpApp(
      tester,
      start: Routes.settings,
      desktop: false,
      size: const Size(400, 860),
    );
    expect(find.text('Apparence'), findsOneWidget);
    await tester.tap(find.text('Lecture'));
    await settle(tester);
    expect(find.text("Reprendre où j'en étais"), findsOneWidget);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

/// Lets transitions finish. pumpAndSettle cannot be used: the progress bar
/// animates for as long as something plays.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late FakeEngine engine;
  late FakeLibraryApi library;

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    bool desktop = true,
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
          libraryApiProvider.overrideWithValue(library),
          desktopShellProvider.overrideWithValue(desktop),
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    engine = FakeEngine();
    library = FakeLibraryApi([
      track(1, 'Basse marée', artist: 'Nafy Rakoto'),
      track(2, 'Échos', artist: 'Collectif Rova', favorite: true),
      track(3, 'Seuil', artist: 'Nafy Rakoto', missing: true),
    ]);
  });

  testWidgets('opens on Titres with the Listen sidebar and the library rows', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final label in [
      'Accueil',
      'Albums',
      'Artistes',
      'Titres',
      'Playlists',
      'Favoris',
      'Films & séries',
      'Vidéos perso',
      'Podcasts & cours',
      'Livres audio',
      'Réglages',
      'Obtenir',
      'Écouter',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('3 titres'), findsOneWidget);
    expect(find.text('Basse marée'), findsOneWidget);
    expect(find.text('Fichier introuvable'), findsOneWidget);
    expect(find.text('Rien en lecture'), findsOneWidget);
  });

  testWidgets('double-click plays the row; the bar shows it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Échos'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Échos'));
    await settle(tester);
    expect(
      engine.opened.single.uri.toFilePath(windows: true),
      r'C:\Musique\Échos.flac',
    );
    expect(find.text('Collectif Rova'), findsWidgets);
    expect(find.text('Rien en lecture'), findsNothing);
  });

  testWidgets('the heart writes the favorite through the library', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Ajouter aux favoris').first);
    await settle(tester);
    expect(library.favoriteCalls, [(1, true)]);
  });

  testWidgets('a section that is not built yet says so', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Albums'));
    await settle(tester);
    expect(find.text('Cet écran arrive bientôt'), findsOneWidget);
    expect(find.text('W-M1a'), findsOneWidget);
  });

  testWidgets('below 1280 px the sidebar keeps only icons', (tester) async {
    await pumpApp(tester, size: const Size(1100, 760));
    expect(find.text('Albums'), findsNothing);
    expect(find.byTooltip('Albums'), findsOneWidget);
  });

  testWidgets('Android: tabs, 60 dp rows, a tap plays, mini player appears', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(392, 850), desktop: false);
    for (final label in [
      'Musique',
      'Cinéma',
      'Focus',
      'Obtenir',
      'Tout lire',
      'Aléatoire',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Rien en lecture'), findsNothing);
    await tester.tap(find.text('Basse marée'));
    await settle(tester);
    expect(engine.opened.single.uri.pathSegments.last, 'Basse marée.flac');
    expect(
      find.text('Basse marée'),
      findsNWidgets(2),
      reason: 'row and mini player',
    );
    await tester.tap(find.text('Focus'));
    await settle(tester);
    expect(find.text('W-F1'), findsOneWidget);
  });

  Future<void> playFirstRow(WidgetTester tester) async {
    await tester.tap(find.text('Basse marée'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Basse marée'));
    await settle(tester);
  }

  testWidgets('the bar opens Now playing; tabs show queue and sound', (
    tester,
  ) async {
    await pumpApp(tester);
    await playFirstRow(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Ouvrir En lecture')));
    await settle(tester);
    expect(find.text('Pas de paroles pour ce titre'), findsOneWidget);
    expect(find.text('FLAC'), findsWidgets);
    await tester.tap(find.text('File'));
    await settle(tester);
    expect(find.text('Échos'), findsOneWidget, reason: 'next in the queue');
    expect(find.text('P1'), findsWidgets);
    await tester.tap(find.text('Son'));
    await settle(tester);
    await tester.tap(find.text('Voix'));
    await settle(tester);
    expect(engine.equalizer, [-2.5, -0.5, 4.0, 5.0, 2.0, -1.0]);
    expect(find.text('Voix'), findsNWidgets(2), reason: 'preset and chip');
  });

  testWidgets('Android: mini player opens the full player; chevron closes', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(392, 850), desktop: false);
    await tester.tap(find.text('Basse marée'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Ouvrir En lecture')));
    await settle(tester);
    expect(find.bySemanticsLabel('Réduire le lecteur'), findsOneWidget);
    expect(find.text('Album 1'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Afficher les paroles'));
    await settle(tester);
    expect(find.text('Pas de paroles pour ce titre'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Réduire le lecteur'));
    await settle(tester);
    expect(find.bySemanticsLabel('Réduire le lecteur'), findsNothing);
    expect(find.text('Tout lire'), findsOneWidget);
  });
}

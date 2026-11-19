import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/playback.dart';

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
}

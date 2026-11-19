import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/design/widgets/pressable.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/library.dart';

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
    String start = Routes.tracks,
    FakePlaybackStore? store,
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
          playbackStoreProvider.overrideWithValue(store ?? FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(start),
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
    await tester.tap(find.text('Podcasts & cours'));
    await settle(tester);
    expect(find.text('Cet écran arrive bientôt'), findsOneWidget);
    expect(find.text('W-F1'), findsOneWidget);
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

  group('albums and artists', () {
    setUp(() {
      library = FakeLibraryApi([
        track(
          1,
          'Vent de sable',
          artist: 'Nafy Rakoto',
          album: 'Saisons de sel',
          trackNo: 3,
        ),
        track(
          2,
          'Lumière basse',
          artist: 'Nafy Rakoto',
          album: 'Saisons de sel',
          trackNo: 1,
        ),
        track(
          3,
          'Marée haute',
          artist: 'Nafy Rakoto',
          album: 'Saisons de sel',
          trackNo: 2,
        ),
        track(
          4,
          'Basse marée',
          artist: 'Nafy Rakoto',
          album: 'Basse marée',
          trackNo: 1,
        ),
        track(5, 'Kabary', artist: 'Toky', album: 'Ny lanitra', trackNo: 1),
      ]);
    });

    testWidgets('album grid, album page in track order, play from it', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Albums'));
      await settle(tester);
      expect(find.text('3 albums · 5 titres'), findsOneWidget);
      await tester.tap(find.text('Saisons de sel'));
      await settle(tester);
      expect(find.text('ALBUM'), findsOneWidget);
      bool lit(String label) => tester
          .widget<Pressable>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(Pressable),
                )
                .first,
          )
          .selected;
      expect(lit('Albums'), isTrue, reason: 'album page keeps Albums lit');
      expect(lit('Accueil'), isFalse);
      final rows = [
        'Lumière basse',
        'Marée haute',
        'Vent de sable',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(rows, orderedEquals([...rows]..sort()), reason: 'disc order');
      await tester.tap(find.text('Lire'));
      await settle(tester);
      expect(engine.opened.first.uri.pathSegments.last, 'Lumière basse.flac');
      await tester.tap(find.text('Nafy Rakoto').first);
      await settle(tester);
      expect(find.text('Titres'), findsWidgets);
      expect(
        find.text('Basse marée'),
        findsWidgets,
        reason: 'their other album',
      );
    });

    testWidgets('artists are circles with their album count', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Artistes'));
      await settle(tester);
      expect(find.textContaining('2 artistes · regroupés'), findsOneWidget);
      expect(find.text('2 albums'), findsOneWidget);
      expect(find.text('1 album'), findsOneWidget);
    });

    testWidgets('Android: chips reach albums; back returns to the grid', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(392, 850), desktop: false);
      await tester.tap(find.text('Albums').first);
      await settle(tester);
      await tester.tap(find.text('Ny lanitra'));
      await settle(tester);
      expect(find.text('Kabary'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Retour'));
      await settle(tester);
      expect(find.text('3 albums · 5 titres'), findsOneWidget);
    });
  });

  testWidgets('files without tags give an honest empty album list', (
    tester,
  ) async {
    library = FakeLibraryApi([
      LibraryItem(
        id: 1,
        title: 'Sans tags',
        path: 'C:/m/a.mp3',
        isVideo: false,
        missing: false,
        favorite: false,
      ),
    ]);
    await pumpApp(tester);
    await tester.tap(find.text('Albums'));
    await settle(tester);
    expect(find.text("Pas encore d'album"), findsOneWidget);
  });

  group('Listen home', () {
    FakePlaybackStore storeWithHistory() {
      final store = FakePlaybackStore();
      store.values[historyKey] = jsonEncode([
        {
          'id': 2,
          'title': 'Échos',
          'kind': 'audio',
          'at': 1794000000000,
          'position': 94,
          'duration': 245,
        },
        {'id': 1, 'title': 'Basse marée', 'kind': 'audio', 'at': 1793000000000},
        {'id': 2, 'title': 'Échos', 'kind': 'audio', 'at': 1792000000000},
      ]);
      store.values[positionKey(2)] = '94';
      return store;
    }

    testWidgets('resume card, automatic lists, resume at the saved time', (
      tester,
    ) async {
      await pumpApp(
        tester,
        start: Routes.listenHome,
        store: storeWithHistory(),
      );
      expect(find.text('Reprendre · Musique'), findsOneWidget);
      expect(find.text('Reprendre à 1:34'), findsOneWidget);
      expect(find.text('Écoutés souvent'), findsOneWidget);
      expect(find.text('Ajoutés récemment'), findsOneWidget);
      expect(find.text('Vos titres favoris'), findsOneWidget);
      expect(find.text('Rien en lecture'), findsWidgets);
      await tester.tap(find.text('Reprendre à 1:34'));
      await settle(tester);
      expect(engine.starts.single, const Duration(seconds: 94));
    });

    testWidgets('an empty library and history gives the welcome state', (
      tester,
    ) async {
      library = FakeLibraryApi([]);
      await pumpApp(tester, start: Routes.listenHome);
      expect(find.text("Votre espace d'écoute est prêt"), findsOneWidget);
      expect(find.text('Obtenir de la musique'), findsOneWidget);
      expect(find.text('Voir les titres'), findsOneWidget);
    });

    testWidgets('Android: Music home with resume and recent albums', (
      tester,
    ) async {
      library = FakeLibraryApi([
        track(1, 'Basse marée', artist: 'Nafy Rakoto', album: 'Basse marée'),
        track(
          2,
          'Échos',
          artist: 'Collectif Rova',
          album: 'Échos',
          favorite: true,
        ),
      ]);
      await pumpApp(
        tester,
        size: const Size(392, 850),
        desktop: false,
        start: Routes.listenHome,
        store: storeWithHistory(),
      );
      expect(find.text('Musique'), findsWidgets);
      expect(find.text('Albums récents'), findsOneWidget);
      expect(find.text('Reprendre'), findsWidgets);
      expect(find.text('Échos'), findsWidgets);
    });
  });
}

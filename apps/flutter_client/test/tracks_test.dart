import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/get/get_screens.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/playlists/playlists_data.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

final songs = [
  track(1, 'Basse marée', artist: 'Nafy Rakoto'),
  track(2, 'Kabary', artist: 'Toky'),
  track(3, 'Lumière basse', artist: 'Iony'),
  track(4, 'Marée haute', artist: 'Mira Sol'),
];

void main() {
  late FakeLibraryApi library;
  late FakeHealthApi health;
  late FakePlaylistApi playlists;
  late FakeEngine engine;
  final revealed = <String>[];

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          libraryApiProvider.overrideWithValue(library),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(health),
          playlistApiProvider.overrideWithValue(playlists),
          getApiProvider.overrideWithValue(FakeGetApi()),
          revealProvider.overrideWithValue((path, {select = false}) async {
            revealed.add(path);
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
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(MiarinaApp)));
  }

  setUp(() {
    library = FakeLibraryApi([...songs]);
    health = FakeHealthApi();
    playlists = FakePlaylistApi(songs);
    engine = FakeEngine();
    revealed.clear();
  });

  Future<void> ctrlTap(WidgetTester tester, Finder f) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(f);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  List<String> rowTitles(WidgetTester tester) =>
      [
        for (final s in songs)
          if (find.text(s.title).evaluate().isNotEmpty) s.title,
      ]..sort(
        (a, b) => tester
            .getTopLeft(find.text(a))
            .dy
            .compareTo(tester.getTopLeft(find.text(b)).dy),
      );

  testWidgets('a column header sorts, a second click reverses', (tester) async {
    await pumpApp(tester);
    expect(rowTitles(tester).first, 'Basse marée');

    await tester.tap(find.text('ARTISTE'));
    await settle(tester);
    expect(library.sorts.last, (TrackSort.artist, false));
    expect(rowTitles(tester), [
      'Lumière basse',
      'Marée haute',
      'Basse marée',
      'Kabary',
    ]);
    expect(
      find.bySemanticsLabel(RegExp('Trier par Artiste, tri croissant')),
      findsOneWidget,
    );

    await tester.tap(find.text('ARTISTE'));
    await settle(tester);
    expect(library.sorts.last, (TrackSort.artist, true));
    expect(rowTitles(tester).first, 'Kabary');
  });

  testWidgets('several rows: play next, add to the queue', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.text('Basse marée'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Basse marée'));
    await settle(tester);
    expect(container.read(queueProvider).current?.title, 'Basse marée');

    await tester.tap(find.text('Lumière basse'));
    await ctrlTap(tester, find.text('Marée haute'));
    expect(find.text('2 sélectionnés'), findsOneWidget);

    await tester.tap(find.text('Lire ensuite'));
    await settle(tester);
    expect(container.read(queueProvider).upcoming.take(2).map((e) => e.title), [
      'Lumière basse',
      'Marée haute',
    ]);
    expect(find.text('Les 2 titres seront lus ensuite'), findsOneWidget);

    // Ctrl+A, then Échap.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.text('4 sélectionnés'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.textContaining('sélectionnés'), findsNothing);
  });

  testWidgets('right click: playlist, explorer, remove', (tester) async {
    final matin = playlists.seed('Matin', [1]);
    await pumpApp(tester);

    await tester.tap(find.text('Kabary'), buttons: kSecondaryButton);
    await settle(tester);
    expect(find.text('Lire ensuite'), findsOneWidget);
    await tester.tap(find.text('Ajouter à une playlist…'));
    await settle(tester);
    await tester.tap(find.text('Matin'));
    await settle(tester);
    expect(playlists.entries[matin], [1, 2]);
    expect(find.text('1 titre ajouté à « Matin »'), findsOneWidget);

    await tester.tap(find.text('Kabary'), buttons: kSecondaryButton);
    await settle(tester);
    await tester.tap(find.text('Afficher dans l’Explorateur'));
    await settle(tester);
    expect(revealed, ['C:/Musique/Kabary.flac']);

    await tester.tap(find.text('Kabary'), buttons: kSecondaryButton);
    await settle(tester);
    await tester.tap(find.text('Retirer…'));
    await settle(tester);
    expect(
      find.text('Retirer ce fichier de la bibliothèque ?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retirer').last);
    await settle(tester);
    expect(health.removed, [2]);
  });

  testWidgets('Suppr asks before removing the selection', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Kabary'));
    await ctrlTap(tester, find.text('Marée haute'));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(
      find.text('Retirer ces 2 fichiers de la bibliothèque ?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(health.removed, isEmpty);
  });

  testWidgets('chips: never played, hi-res, missing files, added this month', (
    tester,
  ) async {
    health = FakeHealthApi(
      missing: [
        MissingGroupInfo(
          cause: MissingCause.notFound,
          key: 'lost',
          folder: '',
          files: [
            MissingFileInfo(
              id: 9,
              path: r'C:\Musique\Seuil.flac',
              title: 'Seuil.flac',
              isVideo: false,
            ),
          ],
        ),
      ],
    );
    library
      ..addedRecently = {3}
      ..played = {1, 2}
      ..hiResIds = {4};
    await pumpApp(tester);

    await tester.tap(find.text('Jamais écoutés'));
    await settle(tester);
    expect(rowTitles(tester), ['Lumière basse', 'Marée haute']);
    // One quick filter at a time.
    await tester.tap(find.text('Hi-res'));
    await settle(tester);
    expect(rowTitles(tester), ['Marée haute']);
    await tester.tap(find.text('Hi-res'));
    await settle(tester);
    expect(rowTitles(tester).length, 4, reason: 'a second tap clears it');

    await tester.tap(find.text('Ajoutés ce mois'));
    await settle(tester);
    expect(rowTitles(tester), ['Lumière basse']);
    await tester.tap(find.text('Tous'));
    await settle(tester);
    expect(rowTitles(tester).length, 4);

    await tester.tap(find.text('Introuvables · 1'));
    await settle(tester);
    expect(find.text('Fichiers introuvables'), findsWidgets);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
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

void main() {
  final a = track(1, 'Marée haute', artist: 'Nafy Rakoto');
  final b = track(2, 'Ville lente', artist: 'Iony');
  final c = track(3, 'Seuil', artist: 'Nafy Rakoto', missing: true);
  final d = track(4, 'Échos', artist: 'Collectif Rova');

  late FakeEngine engine;
  late FakePlaylistApi playlists;
  late int calm;

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
          libraryApiProvider.overrideWithValue(FakeLibraryApi([a, b, c, d])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          playlistApiProvider.overrideWithValue(playlists),
          desktopShellProvider.overrideWithValue(desktop),
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(start),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    engine = FakeEngine();
    playlists = FakePlaylistApi([a, b, c, d]);
    calm = playlists.seed('Soirées calmes', [1, 2, 3]);
    playlists.seed('Route du Sud', [4]);
  });

  testWidgets('W-M5: list and the open playlist side by side', (tester) async {
    await pumpApp(tester, start: Routes.playlists);
    expect(find.text('Soirées calmes'), findsNWidgets(2));
    expect(find.text('Route du Sud'), findsOneWidget);
    expect(find.textContaining('3 titres'), findsWidgets);
    expect(find.textContaining('1 titre introuvable'), findsOneWidget);
    expect(find.text('Ville lente'), findsOneWidget);
    expect(find.text('Fichier introuvable'), findsOneWidget);
    // Sidebar counter.
    expect(find.text('2'), findsWidgets);

    // Play: in order, the missing file left out.
    await tester.tap(find.text('Lire'));
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Ville lente')),
    );
    expect(
      [for (final e in container.read(queueProvider).entries) e.libraryId],
      [1, 2],
    );

    await tester.tap(find.text('Route du Sud'));
    await settle(tester);
    expect(find.text('Échos'), findsOneWidget);
    expect(find.text('Ville lente'), findsNothing);
  });

  testWidgets('Alt+↓ moves a row, Del removes it (the file stays)', (
    tester,
  ) async {
    await pumpApp(tester, start: '${Routes.playlists}?id=$calm');
    await tester.tap(find.text('Marée haute'));
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(playlists.entries[calm], [2, 1, 3]);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(playlists.entries[calm], [2, 3]);
    expect(find.text('Marée haute'), findsNothing);
  });

  testWidgets('new playlist from the queue, then add, rename, delete', (
    tester,
  ) async {
    await pumpApp(tester, start: Routes.playlists);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Route du Sud')),
    );
    await container.read(queueProvider.notifier).playAll([
      queueEntryOf(a),
      queueEntryOf(d),
    ]);
    await settle(tester);

    await tester.tap(find.text('Nouvelle'));
    await settle(tester);
    expect(find.text('Nouvelle playlist'), findsOneWidget);
    expect(
      find.text("Ajouter les 2 titres de la file d'attente"),
      findsOneWidget,
    );
    expect(find.text('Playlist intelligente (règles)'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'Matins');
    await tester.tap(find.text('Créer'));
    await settle(tester);
    final matins = playlists.names.entries
        .firstWhere((e) => e.value == 'Matins')
        .key;
    expect(playlists.entries[matins], [1, 4]);
    expect(find.text('Matins'), findsNWidgets(2), reason: 'opened');

    await tester.tap(find.text('Ajouter des titres'));
    await settle(tester);
    await tester.tap(
      find.bySemanticsLabel(RegExp('^Ajouter des titres Ville lente')),
    );
    await settle(tester);
    expect(playlists.entries[matins], [1, 4, 2]);
    expect(find.text('Ajouté'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await settle(tester);

    await tester.tap(find.bySemanticsLabel(RegExp("^Plus d'options")));
    await settle(tester);
    await tester.tap(find.text('Renommer'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText).last, 'Matins doux');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(playlists.names[matins], 'Matins doux');

    await tester.tap(find.bySemanticsLabel(RegExp("^Plus d'options")));
    await settle(tester);
    await tester.tap(find.text('Supprimer la playlist'));
    await settle(tester);
    expect(find.text('Supprimer « Matins doux » ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await settle(tester);
    expect(playlists.names.containsKey(matins), isFalse);
  });

  testWidgets('Android: Playlists chip, then a playlist page (A-02c)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      start: Routes.playlists,
      desktop: false,
      size: const Size(400, 860),
    );
    expect(find.text('Soirées calmes'), findsOneWidget);
    await tester.tap(find.text('Soirées calmes'));
    await settle(tester);
    expect(find.text('Ville lente'), findsOneWidget);
    await tester.tap(find.text('Ville lente'));
    await settle(tester);
    expect(engine.opened.last.uri, Uri.file(b.path));
  });
}

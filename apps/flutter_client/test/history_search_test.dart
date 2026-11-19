import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/focus/focus_player.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/search/search_data.dart';
import 'package:miarina_media/features/shell/title_bar.dart';
import 'package:miarina_media/src/rust/api/cinema.dart';
import 'package:miarina_media/src/rust/api/focus.dart';
import 'package:miarina_media/src/rust/api/search.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('matching', () {
    test('accents and case do not matter; words match from their start', () {
      expect(fold('Marée Haute'), 'maree haute');
      expect(matchesWords('Marée haute', 'maree'), isTrue);
      expect(matchesWords('Marée haute', 'haut mar'), isTrue);
      expect(matchesWords('Marée haute', 'aree'), isFalse);
      expect(titleScore('Marée haute', 'marée haute'), 3);
      expect(titleScore('Marée haute', 'maree'), 2);
      expect(titleScore('Grande marée', 'maree'), 1);
    });
  });

  final song = track(
    1,
    'Marée haute',
    artist: 'Nafy Rakoto',
    album: 'Saisons de sel',
  );
  final ferry = video(20, 'Le Dernier Ferry', minutes: 102);
  final course = lesson(107, 'Cours 7 · Ordonnancement', number: 7, of: 7);
  final clip = video(30, 'Grande marée', kind: CinemaKind.personal, minutes: 3);
  final pod = lesson(
    201,
    'Les marées expliquées',
    kind: FocusKind.podcast,
    program: 'Ondes courtes',
    minutes: 32,
  );

  late FakeEngine engine;
  late FakePlaybackStore store;

  Future<void> pumpApp(
    WidgetTester tester, {
    required String start,
    bool desktop = true,
    Size size = const Size(1280, 800),
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
            FakeLibraryApi([
              song,
              ferry.item,
              course.item,
              clip.item,
              pod.item,
            ]),
          ),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi([ferry, clip])),
          focusApiProvider.overrideWithValue(FakeFocusApi([course, pod])),
          searchApiProvider.overrideWithValue(
            FakeSearchApi([
              SearchHit(item: song, section: SearchSection.music),
              SearchHit(
                item: clip.item,
                section: SearchSection.cinema,
                video: clip,
              ),
              SearchHit(
                item: pod.item,
                section: SearchSection.focus,
                focusKind: FocusKind.podcast,
                program: 'Ondes courtes',
              ),
            ]),
          ),
          desktopShellProvider.overrideWithValue(desktop),
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          transcriptLoaderProvider.overrideWithValue((_) async => null),
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
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    Map<String, Object> played(
      int id,
      String kind,
      DateTime at,
      int position,
      double duration,
    ) => {
      'id': id,
      'title': 't$id',
      'kind': kind,
      'at': at.millisecondsSinceEpoch,
      'position': position,
      'duration': duration,
    };
    store = FakePlaybackStore()
      ..values[historyKey] = jsonEncode([
        played(1, 'audio', now, 30, 245),
        played(
          107,
          'audio',
          now.subtract(const Duration(minutes: 1)),
          1120,
          5040,
        ),
        played(20, 'video', yesterday, 6120, 6120),
        // A file no longer in the library is left out.
        played(999, 'audio', yesterday, 10, 100),
      ])
      ..values[positionKey(1)] = '30'
      ..values[positionKey(107)] = '1120';
  });

  group('history (W-03)', () {
    testWidgets('plays grouped by day with where they stopped', (tester) async {
      await pumpApp(tester, start: Routes.history);
      expect(find.text('Historique'), findsWidgets);
      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('Marée haute'), findsOneWidget);
      expect(find.text('0:30 sur 4:05'), findsOneWidget);
      expect(find.text('Musique · Nafy Rakoto'), findsOneWidget);
      expect(
        find.text('Focus · Cours · Architecture des systèmes'),
        findsOneWidget,
      );
      expect(find.text('Le Dernier Ferry'), findsOneWidget);
      expect(find.text('Cinéma · Film'), findsOneWidget);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.text('Revoir'), findsOneWidget);
      expect(find.text('Reprendre'), findsNWidgets(2));

      await tester.tap(find.text('Cinéma').last);
      await settle(tester);
      expect(find.text('Marée haute'), findsNothing);
      expect(find.text('Le Dernier Ferry'), findsOneWidget);
    });

    testWidgets('Reprendre resumes; a course reopens in the Focus player', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.history);
      await tester.tap(find.text('Reprendre').first);
      await settle(tester);
      expect(engine.opened.last.uri, Uri.file(song.path));
      expect(engine.starts.last, const Duration(seconds: 30));

      await tester.tap(find.text('Historique').first);
      await settle(tester);
      await tester.tap(find.text('Reprendre').last);
      await settle(tester);
      expect(find.byType(FocusPlayerScreen), findsOneWidget);
      expect(engine.starts.last, const Duration(seconds: 1120));
    });

    testWidgets('clearing forgets the plays, not the resume points', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.history);
      await tester.tap(find.text("Effacer l'historique…"));
      await settle(tester);
      expect(find.text("Effacer l'historique ?"), findsOneWidget);
      await tester.tap(find.text('Effacer'));
      await settle(tester);
      expect(parseHistory(store.values[historyKey]), isEmpty);
      expect(store.values[positionKey(1)], '30');
      expect(find.text("Aucune lecture pour l'instant"), findsOneWidget);
    });
  });

  group('search (W-02)', () {
    testWidgets('results by section with counters and a best result', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.search}?q=maree');
      expect(find.text('« maree »'), findsOneWidget);
      expect(
        find.text('3 résultats dans la bibliothèque locale'),
        findsOneWidget,
      );
      expect(find.text('Meilleur résultat'), findsOneWidget);
      expect(find.text('Marée haute'), findsNWidgets(2));
      expect(find.text('Les marées expliquées'), findsOneWidget);
      expect(find.text('Grande marée'), findsOneWidget);
      expect(find.text('Recherche dans les transcriptions'), findsOneWidget);

      await tester.tap(find.text('Lire'));
      await settle(tester);
      expect(engine.opened.last.uri, Uri.file(song.path));

      await tester.tap(find.bySemanticsLabel(RegExp('^Focus 1')));
      await settle(tester);
      expect(find.text('Grande marée'), findsNothing);
      expect(find.text('Les marées expliquées'), findsOneWidget);
    });

    testWidgets('typing in the title bar shows results; Esc goes back', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.history);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchField)),
      );
      expect(container.read(searchFocusProvider).hasFocus, isTrue);

      await tester.enterText(find.byType(EditableText), 'ondes');
      await settle(tester);
      expect(find.text('Aucun résultat pour « ondes »'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'grande');
      await settle(tester);
      expect(find.text('« grande »'), findsOneWidget);
      expect(find.text('Grande marée'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Hier'), findsOneWidget, reason: 'back on History');
    });

    testWidgets('no result says so', (tester) async {
      await pumpApp(tester, start: '${Routes.search}?q=zzz');
      expect(find.text('Aucun résultat pour « zzz »'), findsOneWidget);
    });

    testWidgets('Android search page (A-01b)', (tester) async {
      await pumpApp(
        tester,
        start: Routes.cinema,
        desktop: false,
        size: const Size(400, 860),
      );
      await tester.tap(
        find.bySemanticsLabel('Rechercher titres, films, podcasts…'),
      );
      await settle(tester);
      await tester.enterText(find.byType(EditableText), 'maree');
      await settle(tester);
      expect(find.text('Marée haute'), findsWidgets);
      expect(find.text('Grande marée'), findsOneWidget);
    });
  });
}

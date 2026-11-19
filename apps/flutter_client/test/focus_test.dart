import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/focus/focus_player.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/focus.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  final l5 = lesson(105, 'Cours 5 · Mémoire virtuelle', number: 5, of: 7);
  final l6 = lesson(106, 'Cours 6 · Processus et threads', number: 6, of: 7);
  final l7 = lesson(107, 'Cours 7 · Ordonnancement', number: 7, of: 7);
  final pod = lesson(
    201,
    'Épisode 12',
    kind: FocusKind.podcast,
    program: 'Radio Miarina',
    minutes: 40,
  );
  final book = lesson(
    301,
    'Le Petit Prince',
    kind: FocusKind.audiobook,
    program: 'Le Petit Prince',
    minutes: 120,
  );

  group('memory', () {
    test('speeds per program and bookmarks per item round-trip', () {
      var m = const FocusMemory()
          .withRate('course:archi', 1.25)
          .withMark(7, 492)
          .withMark(7, 120)
          .withMark(7, 492);
      expect(m.rateFor('course:archi'), 1.25);
      expect(m.rateFor('podcast:x'), 1);
      expect(m.marksOf(7).map((b) => b.at), [120, 492]);
      m = FocusMemory.parse(m.toJson());
      expect(m.rateFor('course:archi'), 1.25);
      expect(m.marksOf(7).map((b) => b.at), [120, 492]);
      // Back to normal speed: nothing stored.
      expect(m.withRate('course:archi', 1).rates, isEmpty);
      expect(m.withoutMark(7, 120).marksOf(7).map((b) => b.at), [492]);
    });

    test('a damaged value is ignored, never thrown', () {
      expect(FocusMemory.parse('nope').rates, isEmpty);
      final m = FocusMemory.parse(
        jsonEncode({
          'rates': {'a': 9, 'b': 1.5, 'c': 'x'},
          'marks': {
            'x': [],
            '4': [
              {'at': -1},
              {'at': 30, 'note': 'ok'},
              'bad',
            ],
          },
        }),
      );
      expect(m.rates, {'b': 1.5});
      expect(m.marksOf(4), [const Bookmark(at: 30, note: 'ok')]);
    });

    test('time left and end use the chosen speed', () {
      expect(
        leftAt(const Duration(minutes: 84), const Duration(minutes: 19), 1.25),
        const Duration(minutes: 52),
      );
    });

    test('WebVTT shows its words only', () {
      expect(
        vttText(
          'WEBVTT\n\n1\n00:00:01.000 --> 00:00:04.000\n<v Pr>Bonjour</v>\n\n'
          '2\n00:00:05.000 --> 00:00:06.000\nà tous\n',
        ),
        'Bonjour\nà tous',
      );
    });
  });

  group('screens', () {
    late FakeEngine engine;
    late FakePlaybackStore store;

    Future<void> pumpApp(
      WidgetTester tester, {
      required String start,
      bool desktop = true,
      Size size = const Size(1280, 900),
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
            libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(
              FakeFocusApi([l5, l6, l7, pod, book]),
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
      final now = DateTime(2026, 11, 19, 20).millisecondsSinceEpoch;
      Map<String, Object> played(int id, int position, double duration) => {
        'id': id,
        'title': 't',
        'kind': 'audio',
        'at': now - id,
        'position': position,
        'duration': duration,
      };
      // Cours 5 heard, cours 6 heard, cours 7 stopped at 18:40 (1120 s).
      store = FakePlaybackStore()
        ..values[historyKey] = jsonEncode([
          played(107, 1120, 5040),
          played(106, 5040, 5040),
          played(105, 5040, 5040),
        ])
        ..values[positionKey(107)] = '1120'
        ..values[FocusMemory.storeKey] = jsonEncode({
          'rates': {'course:architecture des systèmes': 1.25},
        });
    });

    testWidgets('W-F1: counters, in progress, library and lessons', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.focus);
      expect(find.text('Podcasts & cours'), findsWidgets);
      expect(
        find.text('1 podcast · 1 cours · 1 livre audio · 7 h'),
        findsOneWidget,
      );
      expect(find.text('En cours'), findsOneWidget);
      // Time left at the remembered 1,25×: (84 − 18:40) / 1.25.
      expect(find.text('reste 52 min à 1,25×'), findsOneWidget);
      expect(find.text('Cours · Architecture des systèmes'), findsWidgets);
      for (final l in [l5, l6, l7]) {
        expect(find.text(l.item.title), findsWidgets);
      }

      await tester.tap(find.text('Podcasts').first);
      await settle(tester);
      expect(find.text('Radio Miarina'), findsWidgets);
      expect(find.text('Le Petit Prince'), findsNothing);
    });

    testWidgets('Livres audio opens on the audiobooks', (tester) async {
      await pumpApp(tester, start: Routes.audiobooks);
      expect(find.text('Le Petit Prince'), findsWidgets);
      expect(find.text('Radio Miarina'), findsNothing);
    });

    testWidgets('a lesson plays its course in order, at its speed', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.focus);
      await tester.tap(find.text('Cours 6 · Processus et threads').last);
      await settle(tester);
      expect(find.byType(FocusPlayerScreen), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FocusPlayerScreen)),
      );
      final q = container.read(queueProvider);
      expect([for (final e in q.entries) e.libraryId], [105, 106, 107]);
      expect(q.current?.libraryId, 106);
      expect(engine.current.speed, 1.25);
      expect(find.text('COURS 6 SUR 7 · PR. ANDRY'), findsOneWidget);
      expect(find.textContaining('Fin estimée'), findsOneWidget);
    });

    testWidgets('W-F2: speed is remembered, B adds a bookmark, chapters', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.focus);
      await tester.tap(find.text('Cours 7 · Ordonnancement').last);
      await settle(tester);
      expect(engine.starts.last, const Duration(seconds: 1120));

      await tester.tap(find.text('1,5×'));
      await settle(tester);
      expect(engine.current.speed, 1.5);
      expect(
        FocusMemory.parse(store.values[FocusMemory.storeKey])
            .rateFor('course:architecture des systèmes'),
        1.5,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await settle(tester);
      expect(
        FocusMemory.parse(store.values[FocusMemory.storeKey])
            .marksOf(107)
            .map((b) => b.at),
        [1120],
      );
      expect(find.text('18:40'), findsWidgets);
      expect(find.text('Signet sans note'), findsOneWidget);

      engine.emit(
        engine.current.copyWith(
          duration: const Duration(minutes: 84),
          chapters: const [
            ChapterInfo(start: Duration.zero, title: 'Rappels'),
            ChapterInfo(
              start: Duration(minutes: 17, seconds: 10),
              title: 'Algorithmes classiques',
            ),
            ChapterInfo(start: Duration(minutes: 41), title: 'Exercices'),
          ],
        ),
      );
      await tester.tap(find.text('Chapitres'));
      await settle(tester);
      expect(find.text('Algorithmes classiques'), findsOneWidget);
      await tester.tap(find.text('Exercices'));
      await settle(tester);
      expect(engine.seeks.last, const Duration(minutes: 41));
      expect(find.text('Minuteur : fin du chapitre'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(engine.seeks.last, const Duration(minutes: 41, seconds: 30));
    });

    testWidgets('music after Focus goes back to normal speed', (tester) async {
      await pumpApp(tester, start: Routes.focus);
      await tester.tap(find.text('Cours 6 · Processus et threads').last);
      await settle(tester);
      expect(engine.current.speed, 1.25);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FocusPlayerScreen)),
      );
      await container.read(queueProvider.notifier).playAll([
        QueueEntry(source: MediaSource.file('C:/m/a.mp3'), title: 'a'),
      ]);
      await settle(tester);
      expect(engine.current.speed, 1);
    });

    testWidgets('Android Focus tab (A-F) opens a program page', (tester) async {
      await pumpApp(
        tester,
        start: Routes.focus,
        desktop: false,
        size: const Size(400, 860),
      );
      expect(find.text('Focus'), findsWidgets);
      for (final chip in ['Tout', 'Podcasts', 'Cours', 'Livres audio']) {
        expect(find.text(chip), findsWidgets);
      }
      expect(find.text('reste 52 min à 1,25×'), findsOneWidget);
      await tester.tap(find.text('Architecture des systèmes'));
      await settle(tester);
      expect(find.text('Cours 5 · Mémoire virtuelle'), findsOneWidget);
    });
  });
}

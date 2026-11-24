import 'package:flutter/gestures.dart';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/cinema/watch_screen.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/src/rust/api/library.dart';
import 'package:miarina_media/features/library/tag_editor.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/cinema.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

final _now = DateTime(2026, 11, 19, 20);

Map<String, Object> played(
  int id, {
  int position = 0,
  double duration = 3000,
}) => {
  'id': id,
  'title': 'v$id',
  'kind': 'video',
  'at': _now.millisecondsSinceEpoch - id * 1000,
  'position': position,
  'duration': duration,
};

void main() {
  final e1 = video(
    11,
    'Les.Hautes.Terres.S01E01',
    kind: CinemaKind.episode,
    series: 'Les Hautes Terres',
    season: 1,
    episode: 1,
    episodeTitle: 'Départ',
  );
  final e2 = video(
    12,
    'Les.Hautes.Terres.S01E02',
    kind: CinemaKind.episode,
    series: 'Les Hautes Terres',
    season: 1,
    episode: 2,
    episodeTitle: 'Les bergers',
  );
  final e3 = video(
    13,
    'Les.Hautes.Terres.S01E03',
    kind: CinemaKind.episode,
    series: 'Les Hautes Terres',
    season: 1,
    episode: 3,
    subtitles: ['FR'],
  );
  final film = video(20, 'Le Dernier Ferry', minutes: 102);
  final clip = video(30, 'VID_2024', kind: CinemaKind.personal, minutes: 2);

  group('watch rules', () {
    test('a video counts as watched in its last 5 %', () {
      PlayEntry e(int position) => PlayEntry(
        id: 1,
        title: 't',
        kind: 'video',
        at: _now,
        position: position,
        duration: 3000,
      );
      expect(reachedEnd(e(2849)), isFalse);
      expect(reachedEnd(e(2850)), isTrue);
      expect(reachedEnd(e(0)), isFalse);
    });

    SeriesDetail detail(List<CinemaItem> eps) => SeriesDetail(
      name: 'Les Hautes Terres',
      episodes: eps,
      subtitleLanguages: const [],
      subtitleFormats: const [],
    );

    test('the series button resumes, moves on, or starts at the first', () {
      final s = detail([e1, e2, e3]);
      expect(nextEpisode(s, const WatchState())!.episode, e1);

      final resumed = nextEpisode(
        s,
        const WatchState(
          resume: {12: Duration(seconds: 30)},
          seen: {11},
          recent: [12, 11],
        ),
      )!;
      expect(resumed.episode, e2);
      expect(resumed.resumeAt, const Duration(seconds: 30));

      final after = nextEpisode(
        s,
        const WatchState(seen: {11, 12}, recent: [12, 11]),
      )!;
      expect(after.episode, e3);
      expect(after.resumeAt, isNull);
    });

    test('missing episodes are skipped', () {
      final gone = video(
        14,
        'gone',
        kind: CinemaKind.episode,
        series: 'Les Hautes Terres',
        season: 1,
        episode: 1,
        missing: true,
      );
      final s = detail([gone, e2]);
      expect(nextEpisode(s, const WatchState())!.episode, e2);
    });

    test('reads the 0.1.x history and resume points', () async {
      final store = FakePlaybackStore()
        ..values[historyKey] = jsonEncode([
          played(12, position: 30),
          played(11, position: 3000),
          played(12, position: 10),
          {...played(5), 'kind': 'audio'},
        ])
        ..values[positionKey(12)] = '30';
      final c = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          playbackStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
        ],
      );
      addTearDown(c.dispose);
      final w = await c.read(watchStateProvider.future);
      expect(w.recent, [12, 11]);
      expect(w.seen, {11});
      expect(w.resume, {12: const Duration(seconds: 30)});
    });

    test('marks: the latest of a mark and a play decides', () async {
      final at = DateTime.now().millisecondsSinceEpoch;
      final store = FakePlaybackStore()
        ..values[historyKey] = jsonEncode([
          {...played(12, position: 30), 'at': at - 1000},
          {...played(11, position: 3000), 'at': at + 60000},
        ])
        ..values[positionKey(12)] = '30';
      final settings = FakeSettingsStore()
        ..values['videoSeenMarks'] = {
          '12': [true, at], // after its play: seen, no resume point
          '11': [false, at], // played to the end later: seen again
          '13': [true, at], // never played: seen
        };
      final c = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          playbackStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(settings),
        ],
      );
      addTearDown(c.dispose);
      final w = await c.read(watchStateProvider.future);
      expect(w.seen, {11, 12, 13});
      expect(w.resume, isEmpty);
      expect(w.recent, [12, 11], reason: 'nothing added to the history');
    });
  });

  group('screens', () {
    late FakeEngine engine;
    late FakePlaybackStore store;
    late _FakeTags tags;

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
            libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
            cinemaApiProvider.overrideWithValue(
              FakeCinemaApi([e1, e2, e3, film, clip]),
            ),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            desktopShellProvider.overrideWithValue(desktop),
            settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(store),
            tagsApiProvider.overrideWithValue(tags),
            initialRouteProvider.overrideWithValue(start),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
    }

    setUp(() {
      engine = FakeEngine();
      tags = _FakeTags();
      // E1 watched, E2 stopped at 0:30.
      store = FakePlaybackStore()
        ..values[historyKey] = jsonEncode([
          played(12, position: 30),
          played(11, position: 3000),
        ])
        ..values[positionKey(12)] = '30';
    });

    testWidgets('Films & séries: resume row, series and films', (tester) async {
      await pumpApp(tester, start: Routes.cinema, size: const Size(1280, 1400));
      expect(find.text('Films & séries'), findsWidgets);
      expect(find.text('1 film · 1 série'), findsOneWidget);
      expect(find.text('Reprendre'), findsOneWidget);
      expect(find.text('Les Hautes Terres · S1 É2'), findsOneWidget);
      expect(find.text('Les bergers · reprendre à 0:30'), findsOneWidget);
      expect(find.text('Les Hautes Terres'), findsOneWidget);
      expect(find.text('Le Dernier Ferry'), findsOneWidget);
      // Personal videos stay in their own screen.
      expect(find.text('VID_2024'), findsNothing);

      await tester.tap(find.text('Films').first);
      await settle(tester);
      expect(find.text('Les Hautes Terres'), findsNothing);
      expect(find.text('Le Dernier Ferry'), findsOneWidget);
    });

    testWidgets('a film opens the player in the shell, without the bar', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.cinema, size: const Size(1280, 1400));
      await tester.tap(find.text('Le Dernier Ferry'));
      await settle(tester);
      expect(
        engine.opened.single.uri,
        Uri.file('D:/Vidéos/Le Dernier Ferry.mkv'),
      );
      expect(find.byType(WatchScreen), findsOneWidget);
      // Windowed player (W-C3): sidebar kept, playback bar replaced.
      expect(find.text('Vidéos perso'), findsOneWidget);
      expect(find.text('Chapitres'), findsOneWidget);
      expect(find.text('Le Dernier Ferry'), findsOneWidget);
      // Chapters read by the engine are listed; a click seeks there.
      engine.emit(
        engine.current.copyWith(
          chapters: const [
            ChapterInfo(start: Duration.zero, title: 'Ouverture'),
            ChapterInfo(
              start: Duration(minutes: 6, seconds: 40),
              title: 'Le marché',
            ),
          ],
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Le marché'));
      await settle(tester);
      expect(engine.seeks.last, const Duration(minutes: 6, seconds: 40));
    });

    testWidgets('series page: explicit resume, from the start, episodes', (
      tester,
    ) async {
      await pumpApp(
        tester,
        start: '${Routes.series}?name=Les%20Hautes%20Terres',
      );
      expect(find.text('Reprendre S1 · É2 à 0:30'), findsOneWidget);
      expect(find.text('Depuis le début'), findsOneWidget);
      expect(find.text('Saison 1'), findsOneWidget);
      expect(find.text('1 vus sur 3 · '), findsOneWidget);
      expect(find.text('É1 · Départ'), findsOneWidget);
      expect(find.text('Vu'), findsOneWidget);
      expect(find.text('É3 · Épisode 3'), findsOneWidget);
      expect(find.text('Sous-titres FR'), findsOneWidget);
      expect(find.textContaining('FR · EN (SRT)'), findsOneWidget);

      await tester.tap(find.text('Reprendre S1 · É2 à 0:30'));
      await settle(tester);
      expect(engine.starts.last, const Duration(seconds: 30));
      expect(engine.opened.last.uri, Uri.file(e2.item.path));
      expect(find.byType(WatchScreen), findsOneWidget);
    });

    testWidgets('season, series and episode marked watched or not', (
      tester,
    ) async {
      await pumpApp(
        tester,
        start: '${Routes.series}?name=Les%20Hautes%20Terres',
      );
      await tester.tap(find.text('Marquer la saison comme vue'));
      await settle(tester);
      expect(find.text('3 vus sur 3 · '), findsOneWidget);
      expect(find.text('Vu'), findsNWidgets(3));
      expect(find.text('Marquer la saison comme non vue'), findsOneWidget);

      // Right click: É1 back to not watched.
      await tester.tap(find.text('É1 · Départ'), buttons: kSecondaryButton);
      await settle(tester);
      await tester.tap(find.text('Marquer comme non vu'));
      await settle(tester);
      expect(find.text('2 vus sur 3 · '), findsOneWidget);

      // "⋯": the whole series.
      await tester.tap(find.bySemanticsLabel("Plus d'options"));
      await settle(tester);
      await tester.tap(find.text('Marquer la série comme vue'));
      await settle(tester);
      expect(find.text('3 vus sur 3 · '), findsOneWidget);
      await tester.tap(find.bySemanticsLabel("Plus d'options"));
      await settle(tester);
      await tester.tap(find.text('Marquer la série comme non vue'));
      await settle(tester);
      expect(find.text('0 vus sur 3 · '), findsOneWidget);
      // The resume point was only hidden while marked watched.
      expect(find.text('Reprendre S1 · É2 à 0:30'), findsOneWidget);
    });

    testWidgets('a film: right click, watched, its tags and a frame', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.cinema, size: const Size(1280, 1400));
      await tester.tap(
        find.text('Le Dernier Ferry'),
        buttons: kSecondaryButton,
      );
      await settle(tester);
      await tester.tap(find.text('Modifier les tags'));
      await settle(tester);
      // Video fields of the Tauri editor, no lyrics.
      expect(find.text('Réalisateur / auteur'), findsOneWidget);
      expect(find.text('Série / collection'), findsOneWidget);
      expect(find.text('Licence / commentaire'), findsOneWidget);
      expect(find.text('Paroles (facultatif)'), findsNothing);
      expect(
        find.text(
          'Ce format garde ses tags dans la bibliothèque Miarina Media seulement.',
        ),
        findsOneWidget,
      );
      // Never played: a tenth of the way in (102 min).
      await tester.tap(find.text('Capturer l’image à 10:12'));
      await settle(tester);
      expect(tags.covers.single, ('frame', 612.0));
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);
      expect(tags.saved.single.$1, 'Le Dernier Ferry');
      expect(tags.saved.single.$2, isFalse, reason: 'library only');
    });

    testWidgets('from the start ignores the resume point, in episode order', (
      tester,
    ) async {
      await pumpApp(
        tester,
        start: '${Routes.series}?name=Les%20Hautes%20Terres',
      );
      await tester.tap(find.text('Depuis le début'));
      await settle(tester);
      expect(engine.starts.last, isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WatchScreen)),
      );
      final q = container.read(queueProvider);
      expect([for (final e in q.entries) e.libraryId], [11, 12, 13]);
      expect(q.current?.libraryId, 12);
      expect(q.current?.title, 'É2 · Les bergers');
      // The next episode is announced in the side panel.
      expect(find.text('É3 · Épisode 3'), findsOneWidget);
    });

    testWidgets('player menus list what the engine reports', (tester) async {
      await pumpApp(tester, start: Routes.cinema, size: const Size(1280, 1400));
      await tester.tap(find.text('Le Dernier Ferry'));
      await settle(tester);
      engine.emit(
        engine.current.copyWith(
          subtitleTracks: const [
            TrackInfo(id: '1', language: 'fr', codec: 'ass'),
            TrackInfo(id: '2', title: 'English', language: 'en'),
          ],
          audioTracks: const [
            TrackInfo(id: '1', language: 'fr', codec: 'ac3'),
            TrackInfo(id: '2', language: 'en', codec: 'aac'),
          ],
          selectedAudio: '1',
        ),
      );
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await settle(tester);
      expect(find.text('SOUS-TITRES'), findsOneWidget);
      expect(find.text('Désactivés'), findsOneWidget);
      await tester.tap(find.text('English · en'));
      await settle(tester);
      expect(engine.subtitleSelections, ['2']);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await settle(tester);
      expect(find.text('PISTE AUDIO'), findsOneWidget);
      await tester.tap(find.text('en'));
      await settle(tester);
      expect(engine.audioSelections, ['2']);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(engine.current.status, PlaybackStatus.paused);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(engine.seeks.last, const Duration(seconds: 10));
    });

    testWidgets(
      'Vidéo menu: ratio, crop, audio sync, decoder, A–B; subtitles',
      (tester) async {
        await pumpApp(
          tester,
          start: Routes.cinema,
          size: const Size(1280, 1400),
        );
        await tester.tap(find.text('Le Dernier Ferry'));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('Vidéo'));
        await settle(tester);
        expect(find.text('VIDÉO'), findsOneWidget);
        expect(find.text('Auto (D3D11VA)'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(RegExp('^Format d’image')));
        await settle(tester);
        expect(find.text('16:9'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel(RegExp('^Recadrage')));
        await settle(tester);
        expect(find.text('Remplir l’écran'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Plus tard').first);
        await tester.tap(find.bySemanticsLabel('Plus tard').first);
        await settle(tester);
        expect(engine.audioDelay, const Duration(milliseconds: 100));
        expect(find.text('+100 ms'), findsOneWidget);

        // A at 0:30, B at 1:15: the part repeats.
        engine.emit(
          engine.current.copyWith(position: const Duration(seconds: 30)),
        );
        await settle(tester);
        await tester.tap(find.bySemanticsLabel(RegExp('^Boucle A–B')));
        await settle(tester);
        expect(find.text('A à 0:30'), findsOneWidget);
        engine.emit(
          engine.current.copyWith(position: const Duration(seconds: 75)),
        );
        await settle(tester);
        await tester.tap(find.bySemanticsLabel(RegExp('^Boucle A–B')));
        await settle(tester);
        expect(engine.abLoop, (
          const Duration(seconds: 30),
          const Duration(seconds: 75),
        ));
        await tester.tap(find.bySemanticsLabel(RegExp('^Boucle A–B')));
        await settle(tester);
        expect(engine.abLoop, (null, null));

        // Subtitles: 0.1 s steps and the size.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('Plus tôt').first);
        await settle(tester);
        expect(engine.subtitleDelay, const Duration(milliseconds: -100));
        expect(find.text('-0,1 s'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Plus grand'));
        await settle(tester);
        expect(engine.subtitleScale, 1.2);

        // Another file starts with none of them.
        engine.emit(
          engine.current.copyWith(source: MediaSource.file('C:/v/other.mkv')),
        );
        await settle(tester);
        expect(engine.audioDelay, Duration.zero);
        expect(engine.subtitleDelay, Duration.zero);
        expect(engine.subtitleScale, 1);
      },
    );

    testWidgets('F switches to the full-screen player alone', (tester) async {
      await pumpApp(tester, start: Routes.cinema, size: const Size(1280, 1400));
      await tester.tap(find.text('Le Dernier Ferry'));
      await settle(tester);
      final before = tester.state(find.byType(WatchScreen));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await settle(tester);
      expect(find.text('Vidéos perso'), findsNothing);
      expect(find.text('Chapitres'), findsNothing);
      // Same player, still in full screen: nothing was rebuilt from scratch.
      expect(tester.state(find.byType(WatchScreen)), same(before));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WatchScreen)),
      );
      expect(container.read(videoFullscreenProvider), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Vidéos perso'), findsOneWidget);
    });

    testWidgets('personal videos have their own screen', (tester) async {
      await pumpApp(tester, start: Routes.personalVideos);
      expect(find.text('1 vidéo'), findsOneWidget);
      expect(find.text('VID_2024'), findsOneWidget);
      expect(find.text('Le Dernier Ferry'), findsNothing);
    });

    testWidgets('Android Cinema tab (A-C)', (tester) async {
      await pumpApp(
        tester,
        start: Routes.cinema,
        desktop: false,
        size: const Size(400, 860),
      );
      expect(find.text('Cinéma'), findsWidgets);
      for (final chip in ['Tout', 'Films', 'Séries']) {
        expect(find.text(chip), findsWidgets);
      }
      expect(find.text('Les Hautes Terres · S1 É2'), findsOneWidget);
      await tester.tap(find.text('Les Hautes Terres · S1 É2'));
      await settle(tester);
      expect(find.byType(WatchScreen), findsOneWidget);
      expect(engine.starts.last, const Duration(seconds: 30));
      // The episode keeps its label and the series goes on after it.
      final q = ProviderScope.containerOf(
        tester.element(find.byType(WatchScreen)),
      ).read(queueProvider);
      expect(q.current?.title, 'É2 · Les bergers');
      expect([for (final e in q.entries) e.libraryId], [11, 12, 13]);
    });
  });
}

/// The core's tag editor for videos: library only, every call recorded.
class _FakeTags implements TagsApi {
  final covers = <(String, double?)>[];
  final saved = <(String?, bool)>[];

  @override
  Future<TagSheet> get(int id) async => const TagSheet(
    fields: TagFields(title: 'Le Dernier Ferry', year: 2021),
    writable: false,
    hasSourceCover: false,
  );

  LibraryItem _item(int id) => LibraryItem(
    id: id,
    title: 'Le Dernier Ferry',
    path: 'D:/Vidéos/Le Dernier Ferry.mkv',
    isVideo: true,
    missing: false,
    favorite: false,
    plays: 0,
    thumbnail: 'C:/covers/$id.jpg',
  );

  @override
  Future<LibraryItem> save(
    int id,
    TagFields fields, {
    required bool writeToFile,
    String? renameTo,
  }) async {
    saved.add((fields.title, writeToFile));
    return _item(id);
  }

  @override
  Future<LibraryItem> cover(
    int id,
    String from, {
    String? image,
    double? atSecs,
  }) async {
    covers.add((from, atSecs));
    return _item(id);
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show AlertDialog, FilledButton;
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/focus/focus_player.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/online/online_data.dart';
import 'package:miarina_media/features/online/online_obtain.dart';
import 'package:miarina_media/features/online/online_playback.dart';
import 'package:miarina_media/features/online/online_screen.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/search/search_data.dart';
import 'package:miarina_media/src/rust/api/library.dart';
import 'package:miarina_media/src/rust/api/search.dart';

import 'support/fakes.dart';

/// Online listening (decision 0011), lot 2: the En ligne page and the
/// « En ligne » section of the search.

class FakeOnlineApi implements OnlineApi {
  FakeOnlineApi(this.tracks);

  final List<OnlineTrack> tracks;
  final queries = <String>[];
  OnlineFailure? failure;

  @override
  bool available() => true;

  @override
  Future<String?> thumbnail(String url) async => null;

  /// Results already in the library, by video id.
  var obtained = <String, LibraryItem>{};

  @override
  String? watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  @override
  List<OnlineOffer> offers() => [
    for (final (key, label, ext) in [
      ('original', 'M4A', 'm4a'),
      ('mp3-320', 'MP3 · 320 kbps', 'mp3'),
      ('mp3-128', 'MP3 · 128 kbps', 'mp3'),
    ])
      OnlineOffer(
        key: key,
        formatId: 'fmt-$key',
        label: label,
        extension_: ext,
      ),
  ];

  @override
  Future<Map<String, LibraryItem>> local(List<String> videoIds) async => {
    for (final id in videoIds) id: ?obtained[id],
  };

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    queries.add(query);
    if (failure != null) throw failure!;
    return [
      for (final t in tracks)
        if (matchesWords('${t.title} ${t.channel ?? ''}', query)) t,
    ].take(limit).toList();
  }
}

/// Streams found instantly, or held by [gate], or refused with [failure].
class FakeOnlineStreams implements OnlineStreams {
  final calls = <(String, bool)>[];
  OnlineFailure? failure;
  Completer<void>? gate;
  var _n = 0;

  @override
  Future<MediaSource> resolve(
    MediaSource source,
    String videoId, {
    bool fresh = false,
  }) async {
    calls.add((videoId, fresh));
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    _n++;
    return source.withStream(
      Uri.parse('https://stream.example/$videoId?n=$_n'),
      headers: const {'User-Agent': 'UA'},
    );
  }
}

OnlineTrack onlineTrack(String id, String title, {String? channel}) =>
    OnlineTrack(videoId: id, title: title, channel: channel, durationSecs: 238);

/// Long enough for the typing pause and the fake search.
Future<void> settleOnline(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Scrolls the page's list until [target] is built and on screen, without
/// waiting for animations to settle (the phone home's carousel never does).
Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  bool last = true,
}) async {
  final lists = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  for (var i = 0; i < 30 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(last ? lists.last : lists.first, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('failures', () {
    test('the core code becomes the kind; the detail is kept', () {
      final f = OnlineFailure.of(
        AnyhowException('blocked: the source refused the request'),
      );
      expect(f.kind, OnlineFailureKind.blocked);
      expect(f.detail, 'the source refused the request');
      expect(
        OnlineFailure.of(AnyhowException('network: x\nbacktrace…')).detail,
        'x',
      );
      expect(OnlineFailure.of('boom').kind, OnlineFailureKind.other);
      expect(
        OnlineFailure.of(AnyhowException('canceled: ')).kind,
        OnlineFailureKind.canceled,
      );
    });
  });

  final song = track(1, 'Zanak Antesaka', artist: 'Sakaté Boy');
  final hits = [
    onlineTrack(
      'AAAAAAAAAAA',
      'SAKATÉ BOY - Zanak Antesaka',
      channel: 'Lalix Music Média',
    ),
    onlineTrack('BBBBBBBBBBB', 'Zanak Antesaka (Lyrics)', channel: 'OKAY'),
    onlineTrack('CCCCCCCCCCC', 'Zanak Antesaka live', channel: 'Kenny'),
    onlineTrack('DDDDDDDDDDD', 'Zanak Antesaka cover', channel: 'Beyond'),
    onlineTrack('EEEEEEEEEEE', 'Zanak Antesaka version', channel: 'Bapampa'),
  ];
  late FakeOnlineApi online;
  late FakeSettingsStore settings;
  late FakeOnlineStreams streams;
  late FakeEngine engine;
  late FakeGetApi get;

  setUp(() {
    online = FakeOnlineApi(hits);
    settings = FakeSettingsStore();
    streams = FakeOnlineStreams();
    engine = FakeEngine();
    get = FakeGetApi();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required String start,
    OnlineStatus status = OnlineStatus.ready,
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
          onlineStreamsProvider.overrideWithValue(streams),
          getApiProvider.overrideWithValue(get),
          libraryApiProvider.overrideWithValue(FakeLibraryApi([song])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi(const [])),
          searchApiProvider.overrideWithValue(
            FakeSearchApi([
              SearchHit(item: song, section: SearchSection.music),
            ]),
          ),
          onlineApiProvider.overrideWithValue(online),
          onlineStatusProvider.overrideWithValue(status),
          desktopShellProvider.overrideWithValue(desktop),
          settingsStoreProvider.overrideWithValue(settings),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          transcriptLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(start),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settleOnline(tester);
  }

  group('En ligne page', () {
    testWidgets('the sidebar opens it; it explains itself before a search', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.tracks);
      await tester.tap(find.bySemanticsLabel(RegExp('^En ligne')).first);
      await settleOnline(tester);
      expect(find.text('Cherchez un titre ou un artiste'), findsOneWidget);
      expect(online.queries, isEmpty);
    });

    testWidgets('typing searches once the user stops; results are listed', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.online);
      await tester.enterText(find.byKey(onlineFieldKey), 'zan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(onlineFieldKey), 'zanak');
      await settleOnline(tester);
      expect(online.queries, ['zanak'], reason: 'one search, after typing');
      expect(find.text('SAKATÉ BOY - Zanak Antesaka'), findsOneWidget);
      expect(find.text('Lalix Music Média'), findsOneWidget);
      expect(find.text('3:58'), findsWidgets);
    });

    testWidgets('Entrée searches now and remembers the search', (tester) async {
      await pumpApp(tester, start: Routes.online);
      await tester.enterText(find.byKey(onlineFieldKey), 'sakaté');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleOnline(tester);
      expect(find.text('SAKATÉ BOY - Zanak Antesaka'), findsOneWidget);
      expect(settings.values[recentOnlineKey], ['sakaté']);
    });

    testWidgets('recent searches: pick one, remove one, clear', (tester) async {
      settings.values[recentOnlineKey] = ['okay', 'kenny', 'bapampa'];
      await pumpApp(tester, start: Routes.online);
      expect(find.text('Recherches récentes'), findsOneWidget);
      expect(find.text('kenny'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Retirer « bapampa »'));
      await settleOnline(tester);
      expect(find.text('bapampa'), findsNothing);
      expect(settings.values[recentOnlineKey], ['okay', 'kenny']);

      await tester.tap(find.text('kenny'));
      await settleOnline(tester);
      expect(online.queries, ['kenny']);
      expect(find.text('Zanak Antesaka live'), findsOneWidget);
      expect(settings.values[recentOnlineKey], ['kenny', 'okay']);
    });

    testWidgets('no result says so', (tester) async {
      await pumpApp(tester, start: '${Routes.online}?q=zzz');
      expect(find.text('Aucun résultat en ligne pour « zzz »'), findsOneWidget);
    });

    testWidgets('more results asks for the longer list', (tester) async {
      online = FakeOnlineApi([
        for (var i = 0; i < 25; i++)
          onlineTrack('A${'$i'.padLeft(10, '0')}', 'Hira $i'),
      ]);
      await pumpApp(tester, start: '${Routes.online}?q=hira');
      expect(find.text('Hira 19'), findsNothing);
      await reveal(tester, find.text('Plus de résultats'));
      await tester.tap(find.text('Plus de résultats'));
      await settleOnline(tester);
      await reveal(tester, find.text('Hira 24'));
      expect(find.text('Hira 24'), findsOneWidget);
      expect(find.text('Plus de résultats'), findsNothing);
    });

    testWidgets('without a connection, the tracks got stay one tap away', (
      tester,
    ) async {
      online.failure = const OnlineFailure(OnlineFailureKind.network);
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      expect(find.text('Pas de connexion'), findsOneWidget);
      await tester.tap(find.text('Voir mes titres'));
      await settleOnline(tester);
      expect(find.text('Zanak Antesaka'), findsWidgets, reason: 'Titres');
    });

    testWidgets('YouTube limiting requests is explained', (tester) async {
      online.failure = const OnlineFailure(OnlineFailureKind.blocked);
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      expect(find.text('YouTube limite les requêtes'), findsOneWidget);
      online.failure = null;
      await tester.tap(find.text('Réessayer'));
      await settleOnline(tester);
      expect(find.text('SAKATÉ BOY - Zanak Antesaka'), findsOneWidget);
    });

    testWidgets('a missing extractor offers to install it', (tester) async {
      await pumpApp(tester, start: Routes.online, status: OnlineStatus.noTools);
      expect(find.text("L'extracteur n'est pas installé"), findsOneWidget);
      expect(find.text('Installer les outils'), findsOneWidget);
    });

    testWidgets('Android: a home tile opens it', (tester) async {
      await pumpApp(
        tester,
        start: Routes.listenHome,
        desktop: false,
        size: const Size(400, 860),
      );
      final tile = find.text('En ligne');
      await reveal(tester, tile, last: false);
      await tester.tap(tile.first);
      await settleOnline(tester);
      expect(
        find.text('Rechercher un titre ou un artiste en ligne'),
        findsOneWidget,
      );
    });
  });

  group('search section', () {
    testWidgets('the library first, then YouTube once typing stopped', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.search}?q=zanak');
      expect(find.text('Zanak Antesaka'), findsWidgets);
      expect(find.text('SAKATÉ BOY - Zanak Antesaka'), findsOneWidget);
      // « Tout » shows four online results and a link to the others.
      expect(find.text('Zanak Antesaka version'), findsNothing);
      expect(find.text('Tout voir (5)'), findsOneWidget);
      expect(online.queries, ['zanak']);

      await tester.tap(find.bySemanticsLabel(RegExp('^En ligne 5')));
      await settleOnline(tester);
      expect(find.text('Zanak Antesaka version'), findsOneWidget);
      expect(find.text('Marée haute'), findsNothing);

      await tester.tap(find.text('Plus de résultats'));
      await settleOnline(tester);
      expect(
        find.text('Rechercher un titre ou un artiste en ligne'),
        findsOneWidget,
        reason: 'the En ligne page, same search',
      );
      expect(find.text('Zanak Antesaka version'), findsOneWidget);
    });

    testWidgets('nothing local: the online results still show', (tester) async {
      await pumpApp(tester, start: '${Routes.search}?q=okay');
      expect(find.text('Zanak Antesaka (Lyrics)'), findsOneWidget);
      expect(find.text('Aucun résultat pour « okay »'), findsNothing);
    });

    testWidgets('a failure stays in its section', (tester) async {
      online.failure = const OnlineFailure(OnlineFailureKind.network);
      await pumpApp(tester, start: '${Routes.search}?q=zanak');
      expect(find.text('Zanak Antesaka'), findsWidgets);
      expect(find.text('Pas de connexion'), findsOneWidget);
    });

    testWidgets('without the extractor the search is the library only', (
      tester,
    ) async {
      await pumpApp(
        tester,
        start: '${Routes.search}?q=zzz',
        status: OnlineStatus.noTools,
      );
      expect(find.text('Aucun résultat pour « zzz »'), findsOneWidget);
      expect(online.queries, isEmpty);
    });
  });

  group('playing (lot 3)', () {
    const first = 'AAAAAAAAAAA';
    const second = 'BBBBBBBBBBB';

    Future<void> playFirst(WidgetTester tester) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
    }

    testWidgets('a result plays in the player; the others follow', (
      tester,
    ) async {
      await playFirst(tester);
      final opened = engine.opened.single;
      expect(opened.uri, onlineSourceUri(first), reason: 'stable identity');
      expect(opened.playable.toString(), startsWith('https://stream.example/'));
      expect(opened.httpHeaders, {'User-Agent': 'UA'});
      expect(opened.title, 'SAKATÉ BOY - Zanak Antesaka');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      final queue = container.read(queueProvider);
      expect(queue.current?.onlineId, first);
      expect(queue.current?.subtitle, 'Lalix Music Média');
      expect(queue.upcoming.map((e) => e.onlineId), [
        second,
        'CCCCCCCCCCC',
        'DDDDDDDDDDD',
        'EEEEEEEEEEE',
      ]);
      // The next one's stream is found ahead, so the change does not wait.
      expect(streams.calls, contains((second, false)));
      expect(settings.values[recentOnlineKey], ['zanak']);
    });

    testWidgets('while the stream is found, the play button spins', (
      tester,
    ) async {
      streams.gate = Completer();
      await playFirst(tester);
      expect(find.byKey(const ValueKey('resolving')), findsWidgets);
      expect(engine.opened, isEmpty);
      streams.gate!.complete();
      await settleOnline(tester);
      expect(engine.opened, hasLength(1));
      expect(find.byKey(const ValueKey('resolving')), findsNothing);
    });

    testWidgets('a stream not found says why; play tries again', (
      tester,
    ) async {
      streams.failure = const OnlineFailure(OnlineFailureKind.network);
      await playFirst(tester);
      expect(engine.opened, isEmpty);
      expect(find.text('Pas de connexion'), findsOneWidget, reason: 'bar');

      streams.failure = null;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      await container.read(queueProvider.notifier).togglePlay();
      await settleOnline(tester);
      expect(engine.opened.single.uri, onlineSourceUri(first));
      expect(find.text('Pas de connexion'), findsNothing);
    });

    testWidgets('a refused stream is found again once, where it was', (
      tester,
    ) async {
      await playFirst(tester);
      final opened = engine.opened.single;
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.playing,
          source: opened,
          position: const Duration(seconds: 90),
          duration: const Duration(minutes: 4),
        ),
      );
      await tester.pump();
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.error,
          source: opened,
          error: const PlaybackError('HTTP error 403 Forbidden'),
        ),
      );
      await settleOnline(tester);
      expect(streams.calls, contains((first, true)));
      expect(engine.opened, hasLength(2));
      expect(engine.starts.last, const Duration(seconds: 90));
      expect(engine.opened.last.playable, isNot(opened.playable));

      // A second refusal: the error card, no loop.
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.error,
          source: engine.opened.last,
          error: const PlaybackError('HTTP error 403 Forbidden'),
        ),
      );
      await settleOnline(tester);
      expect(engine.opened, hasLength(2));
    });

    testWidgets('the playing result is marked in the list', (tester) async {
      await playFirst(tester);
      final title = tester.widget<Text>(
        find.text('SAKATÉ BOY - Zanak Antesaka').first,
      );
      final other = tester.widget<Text>(find.text('Zanak Antesaka live'));
      expect(title.style?.color, isNot(other.style?.color));
    });
  });

  group('Obtenir (lot 4)', () {
    const first = 'AAAAAAAAAAA';
    const title = 'SAKATÉ BOY - Zanak Antesaka';

    testWidgets('the format is asked, then remembered when always used', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.bySemanticsLabel('Obtenir $title'));
      await settleOnline(tester);
      expect(find.text('Obtenir « $title »'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('MP3 128 kbps'), findsOneWidget);

      await tester.tap(find.text('MP3 320 kbps'));
      await tester.tap(
        find.bySemanticsLabel('Toujours utiliser ce format').last,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Obtenir'));
      await settleOnline(tester);
      final request = get.started.single;
      expect(request.url, 'https://www.youtube.com/watch?v=$first');
      expect(request.isAudio, isTrue);
      expect(request.formatId, 'fmt-mp3-320');
      expect(request.extension_, 'mp3');
      expect(request.startNow, isTrue);
      expect(find.text('Obtention lancée : $title'), findsOneWidget);
      expect((settings.values[onlineSettingsKey] as Map)['format'], 'mp3-320');

      // Next time: no question.
      await tester.tap(find.bySemanticsLabel('Obtenir Zanak Antesaka live'));
      await settleOnline(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(get.started.last.formatId, 'fmt-mp3-320');
    });

    testWidgets('an obtained result says so and plays from its file', (
      tester,
    ) async {
      online.obtained = {first: song};
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      expect(find.byTooltip('Hors connexion'), findsOneWidget);
      expect(find.bySemanticsLabel('Obtenir $title'), findsNothing);

      await tester.tap(find.text(title));
      await settleOnline(tester);
      expect(engine.opened.single.uri, Uri.file(song.path));
      expect(streams.calls.map((c) => c.$1), isNot(contains(first)));
    });

    testWidgets('Now playing offers Obtenir for an online track', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text(title));
      await settleOnline(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      container.read(routerProvider).go(Routes.now);
      await settleOnline(tester);
      await tester.tap(find.text('Obtenir').last);
      await settleOnline(tester);
      expect(find.text('Obtenir « $title »'), findsOneWidget);
    });

    testWidgets('tracks heard to the end are obtained once, when asked', (
      tester,
    ) async {
      settings.values[onlineSettingsKey] = {
        'autoObtain': true,
        'format': 'ask',
        'lastFormat': 'mp3-128',
      };
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text(title));
      await settleOnline(tester);
      final opened = engine.opened.single;
      PlaybackSnapshot at(int secs) => PlaybackSnapshot(
        status: PlaybackStatus.playing,
        source: opened,
        position: Duration(seconds: secs),
        duration: const Duration(minutes: 4),
      );
      engine.emit(at(60));
      await settleOnline(tester);
      expect(get.started, isEmpty, reason: 'not heard yet');
      engine.emit(at(220));
      await settleOnline(tester);
      expect(get.started.single.formatId, 'fmt-mp3-128');
      expect(find.text('Ajouté hors connexion : $title'), findsOneWidget);
      engine.emit(at(230));
      await settleOnline(tester);
      expect(get.started, hasLength(1), reason: 'once');
    });

    testWidgets('off by default: nothing is obtained by itself', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text(title));
      await settleOnline(tester);
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.ended,
          source: engine.opened.single,
          duration: const Duration(minutes: 4),
        ),
      );
      await settleOnline(tester);
      expect(get.started, isEmpty);
    });

    testWidgets('Réglages › Lecture: automatic obtaining and the format', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.settings}/playback');
      final label = find.text('Écoute en ligne'.toUpperCase());
      await reveal(tester, label);
      expect(label, findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel('Obtenir les titres écoutés en entier'),
      );
      await settleOnline(tester);
      expect((settings.values[onlineSettingsKey] as Map)['autoObtain'], isTrue);
    });
  });
}

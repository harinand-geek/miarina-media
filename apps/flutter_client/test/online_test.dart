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
import 'package:miarina_media/features/cinema/watch_screen.dart'
    show WatchScreen;
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/now_playing/online_lyrics.dart';
import 'package:miarina_media/features/focus/focus_player.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/online/online_data.dart';
import 'package:miarina_media/features/online/online_obtain.dart';
import 'package:miarina_media/features/online/online_playback.dart';
import 'package:miarina_media/features/online/online_screen.dart';
import 'package:miarina_media/features/online/online_widgets.dart'
    show OnlineCard;
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/listen_journal.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/search/search_data.dart';
import 'package:miarina_media/design/widgets/cover_art.dart';
import 'package:miarina_media/features/shell/mobile_shell.dart'
    show miniCoverKey, miniHidden, miniTitleKey;
import 'package:miarina_media/features/now_playing/mobile_player.dart'
    show MobilePlayer;
import 'package:miarina_media/src/rust/api/library.dart';
import 'package:miarina_media/src/rust/api/search.dart';

import 'support/fakes.dart';

/// Online listening (decision 0011), lot 2: the En ligne page and the
/// « En ligne » section of the search.

class FakeOnlineApi implements OnlineApi {
  FakeOnlineApi(this.tracks);

  final List<OnlineTrack> tracks;
  final queries = <String>[];
  final backgroundQueries = <String>[];
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
  Future<List<OnlineTrack>> search(
    String query, {
    int limit = 20,
    bool background = false,
  }) async {
    // The page's grids: every result, whatever the query.
    if (background) {
      backgroundQueries.add(query);
      return tracks.take(limit).toList();
    }
    queries.add(query);
    if (failure != null) throw failure!;
    return [
      for (final t in tracks)
        if (matchesWords('${t.title} ${t.channel ?? ''}', query)) t,
    ].take(limit).toList();
  }
}

class FakeLyricsApi implements OnlineLyricsApi {
  final asked = <LyricsLookup>[];
  FoundOnline? answer;
  var options = <LyricsOption>[];
  final searched = <(String, String?)>[];
  final pages = <String, String>{};

  @override
  Future<FoundOnline?> find(LyricsLookup query) async {
    asked.add(query);
    return answer;
  }

  @override
  Future<List<LyricsOption>> search(
    String title,
    String? artist,
    Duration? duration,
  ) async {
    searched.add((title, artist));
    return options;
  }

  @override
  Future<String?> fetch(String url) async => pages[url];
}

class MemoryLyricsCache implements LyricsCache {
  final files = <String, String>{};

  @override
  Future<String?> read(String key) async => files[key];

  @override
  Future<void> write(String key, String lrc) async => files[key] = lrc;
}

/// Streams found instantly, or held by [gate], or refused with [failure].
class FakeOnlineStreams implements OnlineStreams {
  final calls = <(String, bool)>[];
  final aheadCalls = <String>[];
  OnlineFailure? failure;

  /// Thrown by the next stream waited for only.
  OnlineFailure? failOnce;
  Completer<void>? gate;
  var _n = 0;

  @override
  Future<MediaSource> resolve(
    MediaSource source,
    String videoId, {
    bool fresh = false,
    bool ahead = false,
    bool clip = false,
  }) async {
    calls.add((videoId, fresh));
    if (ahead) aheadCalls.add(videoId);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    if (failOnce case final f? when !ahead) {
      failOnce = null;
      throw f;
    }
    _n++;
    if (clip) {
      return source.withStream(
        Uri.parse('https://hls.example/$videoId.m3u8'),
        mimeType: 'application/x-mpegURL',
      );
    }
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
        OnlineFailure.of(
          AnyhowException('slow: the source took too long to answer'),
        ).kind,
        OnlineFailureKind.slow,
      );
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
  late FakePlaybackStore playback;
  late FakeLyricsApi lyricsApi;
  late MemoryLyricsCache lyricsCache;
  var onWifi = true;

  setUp(() {
    online = FakeOnlineApi(hits);
    settings = FakeSettingsStore();
    streams = FakeOnlineStreams();
    engine = FakeEngine();
    get = FakeGetApi();
    playback = FakePlaybackStore();
    lyricsApi = FakeLyricsApi();
    lyricsCache = MemoryLyricsCache();
    onWifi = true;
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
          onWifiProvider.overrideWithValue(() async => onWifi),
          onlineLyricsApiProvider.overrideWithValue(lyricsApi),
          lyricsCacheProvider.overrideWithValue(lyricsCache),
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
          playbackStoreProvider.overrideWithValue(playback),
          initialRouteProvider.overrideWithValue(start),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settleOnline(tester);
  }

  group('En ligne page', () {
    testWidgets('the sidebar opens it on a grid of new clips', (tester) async {
      await pumpApp(tester, start: Routes.tracks);
      await tester.tap(find.bySemanticsLabel(RegExp('^En ligne')).first);
      await settleOnline(tester);
      expect(find.text('Nouveautés'), findsOneWidget);
      final year = DateTime.now().year;
      expect(online.backgroundQueries, ['nouveauté gasy $year clip officiel']);
      expect(online.queries, isEmpty, reason: 'nothing typed');
      expect(find.byType(OnlineCard), findsNWidgets(4), reason: '1 row');
      expect(find.text('Zanak Antesaka (Lyrics)'), findsOneWidget);
    });

    testWidgets('a card plays its clip, the grid following', (tester) async {
      await pumpApp(tester, start: Routes.online);
      await tester.tap(find.text('Zanak Antesaka live'));
      await settleOnline(tester);
      expect(engine.opened.single.uri, onlineSourceUri('CCCCCCCCCCC'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      expect(container.read(queueProvider).upcoming, hasLength(2));
    });

    testWidgets('« Tout voir » runs the grid\'s search', (tester) async {
      await pumpApp(tester, start: Routes.online);
      await tester.tap(find.text('Tout voir').first);
      await settleOnline(tester);
      final year = DateTime.now().year;
      expect(online.queries, ['nouveauté gasy $year clip officiel']);
    });

    testWidgets('phone: a grid of four, two by two', (tester) async {
      await pumpApp(
        tester,
        start: Routes.online,
        desktop: false,
        size: const Size(400, 860),
      );
      expect(find.byType(OnlineCard), findsNWidgets(4));
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
      // A second grid from the last search, above the recent searches.
      expect(find.text('D\'après « okay »'), findsOneWidget);
      expect(online.backgroundQueries, contains('okay'));
      await reveal(tester, find.text('bapampa'));
      expect(find.text('Recherches récentes'), findsOneWidget);
      expect(find.text('kenny'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Retirer « bapampa »'));
      await settleOnline(tester);
      expect(find.text('bapampa'), findsNothing);
      expect(settings.values[recentOnlineKey], ['okay', 'kenny']);

      await reveal(tester, find.text('kenny'));
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

    testWidgets('the first result is prepared; the next one too', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      expect(streams.aheadCalls, [first], reason: 'likeliest click');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      expect(streams.aheadCalls, contains(second), reason: 'next track');
    });

    testWidgets('another track: the old one stops, the bar starts at 0', (
      tester,
    ) async {
      await playFirst(tester);
      expect(engine.current.source, isNotNull);
      streams.gate = Completer();
      await tester.tap(find.text('Zanak Antesaka live'));
      await settleOnline(tester);
      expect(engine.current.source, isNull, reason: 'not the old duration');
      expect(find.byKey(const ValueKey('resolving')), findsWidgets);
      streams.gate!.complete();
      await settleOnline(tester);
      expect(engine.opened.last.uri, onlineSourceUri('CCCCCCCCCCC'));
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

    testWidgets('an error as the stream ends is its end', (tester) async {
      await playFirst(tester);
      final opened = engine.opened.single;
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.playing,
          source: opened,
          position: const Duration(seconds: 238),
          duration: const Duration(seconds: 239),
        ),
      );
      await tester.pump();
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.error,
          source: opened,
          duration: const Duration(seconds: 239),
          error: const PlaybackError('stream ended'),
        ),
      );
      await settleOnline(tester);
      expect(streams.calls, isNot(contains((first, true))));
      expect(engine.opened, hasLength(1));
    });

    testWidgets('a finished online track plays again from its start', (
      tester,
    ) async {
      await playFirst(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      // The last of the queue ends; play starts it again.
      container.read(queueProvider.notifier).clearUpcoming();
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.ended,
          source: engine.opened.single,
          position: const Duration(minutes: 4),
          duration: const Duration(minutes: 4),
        ),
      );
      await settleOnline(tester);
      await container.read(queueProvider.notifier).togglePlay();
      await settleOnline(tester);
      expect(engine.opened, hasLength(2));
      expect(engine.opened.last.uri, onlineSourceUri(first));
      expect(engine.starts.last, isNull);
    });

    testWidgets('a slow answer is not called a lost connection', (
      tester,
    ) async {
      streams.failure = const OnlineFailure(OnlineFailureKind.slow);
      await playFirst(tester);
      expect(find.text('YouTube ne répond pas'), findsOneWidget);
      expect(find.text('Pas de connexion'), findsNothing);
      // Tried twice before saying so (besides the one prepared ahead).
      final waited =
          streams.calls.where((c) => c.$1 == first).length -
          streams.aheadCalls.where((id) => id == first).length;
      expect(waited, 2);
    });

    testWidgets('a slow answer once is tried again, silently', (tester) async {
      streams.failOnce = const OnlineFailure(OnlineFailureKind.slow);
      await playFirst(tester);
      expect(engine.opened.single.uri, onlineSourceUri(first));
      expect(find.text('YouTube ne répond pas'), findsNothing);
    });

    testWidgets('time heard online counts in the listening journal', (
      tester,
    ) async {
      await playFirst(tester);
      final opened = engine.opened.single;
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.playing,
          source: opened,
          duration: const Duration(minutes: 4),
        ),
      );
      await tester.pump();
      // The journal measures real time while the music plays.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2100)),
      );
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.paused,
          source: opened,
          duration: const Duration(minutes: 4),
        ),
      );
      await settleOnline(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      final journal = ListenJournal.parse(playback.values[listenJournalKey]);
      final today = journal.days[ListenJournal.dayKey(DateTime.now())];
      expect(today, isNotNull);
      expect(today!.seconds, greaterThanOrEqualTo(2));
      expect(today.artists['Lalix Music Média'], greaterThanOrEqualTo(2));
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

  group('clips (lot 8)', () {
    testWidgets('a clip opens in the video player', (tester) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(
        find.bySemanticsLabel('Voir le clip SAKATÉ BOY - Zanak Antesaka'),
      );
      await settleOnline(tester);
      final opened = engine.opened.last;
      expect(opened.uri, onlineClipUri('AAAAAAAAAAA'));
      expect(
        opened.playable.toString(),
        'https://hls.example/AAAAAAAAAAA.m3u8',
      );
      expect(opened.mimeType, 'application/x-mpegURL');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      expect(container.read(queueProvider).current?.isVideo, isTrue);
      expect(find.byType(WatchScreen), findsOneWidget);
    });

    testWidgets('Now playing: the clip takes over where the sound was', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      engine.emit(
        PlaybackSnapshot(
          status: PlaybackStatus.playing,
          source: engine.opened.single,
          position: const Duration(seconds: 75),
          duration: const Duration(minutes: 4),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      container.read(routerProvider).go(Routes.now);
      await settleOnline(tester);
      await tester.tap(find.text('Voir le clip').last);
      await settleOnline(tester);
      expect(engine.opened.last.uri, onlineClipUri('AAAAAAAAAAA'));
      expect(engine.starts.last, const Duration(seconds: 75));
      // The rest of the queue stays.
      expect(container.read(queueProvider).upcoming, hasLength(4));
    });
  });

  group('lyrics (lot 7)', () {
    test('a title key ignores case, spaces and punctuation', () {
      expect(
        lyricsTitleKey('SAKATÉ BOY - Zanak Antesaka (Clip)'),
        lyricsTitleKey('sakaté boy zanak antesaka clip'),
      );
      expect(
        lyricsTitleKey('Zanak Antesaka'),
        isNot(lyricsTitleKey('Zanak Antesaka 2')),
      );
    });

    Future<Lyrics?> current(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      final l = await tester.runAsync(
        () => container.read(currentLyricsProvider.future),
      );
      return l;
    }

    testWidgets('found online once the stream is ready, then kept', (
      tester,
    ) async {
      lyricsApi.answer = (
        lrc: '[00:01.00]Tiako ianao\n[00:04.00]Mila anao\n',
        source: 'youtube',
        synced: true,
      );
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      final l = await current(tester);
      expect(l?.lines.map((x) => x.text), ['Tiako ianao', 'Mila anao']);
      expect(l?.source, 'YouTube');
      final q = lyricsApi.asked.single;
      expect(q.videoId, 'AAAAAAAAAAA');
      expect(q.artist, 'Lalix Music Média');
      expect(q.duration, const Duration(seconds: 238));
      // Kept under the video and the title: offline, and once obtained.
      expect(lyricsCache.files.keys, [
        'v-AAAAAAAAAAA',
        lyricsTitleKey('SAKATÉ BOY - Zanak Antesaka'),
      ]);
      expect(lyricsCache.files.values.first, startsWith('[re:YouTube]'));
    });

    testWidgets('an online clip has its lyrics too', (tester) async {
      lyricsApi.answer = (
        lrc: '[00:03.00]Hira',
        source: 'lrclib',
        synced: true,
      );
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(
        find.bySemanticsLabel('Voir le clip SAKATÉ BOY - Zanak Antesaka'),
      );
      await settleOnline(tester);
      final l = await current(tester);
      expect(l?.lines.single.text, 'Hira');
    });

    test('plain lyrics keep one blank line between verses', () {
      final l = parsePlainLyrics('\n\nA\nB\n\n\n\nC\n\n')!;
      expect(l.lines.map((x) => x.text), ['A', 'B', '', 'C']);
      expect(l.synced, isFalse);
      expect(parsePlainLyrics('one line'), isNull);
    });

    testWidgets('Malagasy plain lyrics show as text and are kept', (
      tester,
    ) async {
      lyricsApi.answer = (
        lrc: 'Gne carisme\nSakaté boy\n\nZanak\'antesaka',
        source: 'tononkira',
        synced: false,
      );
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      final l = await current(tester);
      expect(l?.synced, isFalse);
      expect(l?.source, 'Tononkira');
      expect(l?.lines.first.text, 'Gne carisme');
      expect(
        lyricsCache.files['v-AAAAAAAAAAA'],
        startsWith('[re:Tononkira]\n[plain]\n'),
      );
    });

    testWidgets('kept lyrics can be deleted and stay gone', (tester) async {
      lyricsApi.answer = (
        lrc: 'Gne carisme\nSakaté boy\n\nZanak\'antesaka',
        source: 'tononkira',
        synced: false,
      );
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      container.read(routerProvider).go(Routes.now);
      await settleOnline(tester);
      expect(find.text('Gne carisme'), findsOneWidget);
      expect(find.byTooltip('Chercher d\'autres paroles'), findsOneWidget);
      final asked = lyricsApi.asked.length;
      await tester.tap(find.byTooltip('Supprimer ces paroles'));
      await settleOnline(tester);
      expect(find.text('Gne carisme'), findsNothing);
      expect(find.text('Pas de paroles pour ce titre'), findsOneWidget);
      expect(lyricsCache.files['v-AAAAAAAAAAA'], '[none]');
      expect(await current(tester), isNull);
      expect(lyricsApi.asked.length, asked);
    });

    testWidgets('no lyrics: search by hand and choose', (tester) async {
      lyricsApi.options = [
        (
          track: 'Zanak\'antesaka',
          artist: 'Sakaté Boy',
          album: null,
          duration: null,
          source: 'tononkira',
          lrc: null,
          url: 'https://tononkira.serasera.org/hira/s/z',
        ),
      ];
      lyricsApi.pages['https://tononkira.serasera.org/hira/s/z'] =
          'Andalana voalohany\nAndalana faharoa';
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      container.read(routerProvider).go(Routes.now);
      await settleOnline(tester);
      expect(find.text('Pas de paroles pour ce titre'), findsOneWidget);
      await tester.tap(find.text('Chercher les paroles'));
      await settleOnline(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Chercher'));
      await settleOnline(tester);
      expect(lyricsApi.searched.single.$1, 'SAKATÉ BOY - Zanak Antesaka');
      expect(lyricsApi.searched.single.$2, 'Lalix Music Média');
      await tester.tap(find.text('Zanak\'antesaka'));
      await settleOnline(tester);
      expect(find.text('Andalana voalohany'), findsOneWidget);
      expect(
        lyricsCache.files['v-AAAAAAAAAAA'],
        startsWith('[re:Tononkira]\n[plain]\n'),
      );
    });

    testWidgets('kept lyrics need no lookup', (tester) async {
      lyricsCache.files['v-AAAAAAAAAAA'] = '[re:LRCLIB]\n[00:02.00]Efa hita\n';
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('SAKATÉ BOY - Zanak Antesaka'));
      await settleOnline(tester);
      final l = await current(tester);
      expect(l?.lines.single.text, 'Efa hita');
      expect(l?.source, 'LRCLIB');
      expect(lyricsApi.asked, isEmpty);
    });

    testWidgets('setting off: nothing is looked up', (tester) async {
      settings.values[onlineSettingsKey] = {'lyrics': false};
      lyricsApi.answer = (lrc: '[00:01.00]x', source: 'lrclib', synced: true);
      await pumpApp(tester, start: '${Routes.online}?q=zanak');
      await tester.tap(find.text('Zanak Antesaka live'));
      await settleOnline(tester);
      expect(await current(tester), isNull);
      expect(lyricsApi.asked, isEmpty);
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

    testWidgets('phone: not over mobile data unless allowed', (tester) async {
      settings.values[onlineSettingsKey] = {
        'autoObtain': true,
        'format': 'original',
      };
      onWifi = false;
      await pumpApp(
        tester,
        start: '${Routes.online}?q=zanak',
        desktop: false,
        size: const Size(400, 860),
      );
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
      expect(get.started, isEmpty, reason: 'mobile data');
    });

    testWidgets('phone on Wi-Fi: obtained', (tester) async {
      settings.values[onlineSettingsKey] = {
        'autoObtain': true,
        'format': 'original',
      };
      await pumpApp(
        tester,
        start: '${Routes.online}?q=zanak',
        desktop: false,
        size: const Size(400, 860),
      );
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
      expect(get.started.single.formatId, 'fmt-original');
    });

    testWidgets('phone: dragged down, the cover flies to the mini player', (
      tester,
    ) async {
      await pumpApp(
        tester,
        start: '${Routes.online}?q=zanak',
        desktop: false,
        size: const Size(400, 860),
      );
      await tester.tap(find.text(title));
      await settleOnline(tester);
      await tester.tap(find.byKey(miniCoverKey));
      await settleOnline(tester);
      final player = find.byType(MobilePlayer);
      expect(player, findsOneWidget);
      final rest = tester.getRect(
        find.descendant(of: player, matching: find.byType(CoverArt)).first,
      );
      final mini = tester.getRect(find.byKey(miniCoverKey));

      final drag = await tester.startGesture(const Offset(200, 120));
      await drag.moveBy(const Offset(0, 20));
      await drag.moveBy(const Offset(0, 200));
      await tester.pump();
      final flying = find.descendant(
        of: find.descendant(of: player, matching: find.byType(Positioned)),
        matching: find.byType(CoverArt),
      );
      expect(flying, findsOneWidget);
      final r = tester.getRect(flying);
      // Down and to the left, smaller: toward the mini player's cover.
      expect(r.top, greaterThan(rest.top));
      expect(r.center.dx, lessThan(rest.center.dx - 40));
      expect(r.width, lessThan(rest.width));
      expect(
        (r.center - mini.center).distance,
        lessThan((rest.center - mini.center).distance),
      );

      // The title flies too, toward the mini player's; the mini player
      // hides its own until they land.
      await tester.pump();
      final flyingTitle = find.descendant(
        of: find.descendant(of: player, matching: find.byType(Positioned)),
        matching: find.text(title),
      );
      expect(flyingTitle, findsOneWidget);
      final miniTitle = tester.getRect(find.byKey(miniTitleKey));
      expect(tester.getRect(flyingTitle).top, lessThan(miniTitle.top));
      expect(miniHidden.value, isTrue);

      // Back up: back toward its place.
      await drag.moveBy(const Offset(0, -150));
      await tester.pump();
      final back = tester.getRect(flying);
      expect(back.width, greaterThan(r.width));

      // Released low enough: the player closes.
      await drag.moveBy(const Offset(0, 400));
      await drag.up();
      await settleOnline(tester);
      expect(player, findsNothing);
      expect(miniHidden.value, isFalse, reason: 'shown again');
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

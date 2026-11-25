import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException;
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/focus/focus_player.dart';
import 'package:miarina_media/features/online/online_data.dart';
import 'package:miarina_media/features/online/online_screen.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/search/search_data.dart';
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
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    queries.add(query);
    if (failure != null) throw failure!;
    return [
      for (final t in tracks)
        if (matchesWords('${t.title} ${t.channel ?? ''}', query)) t,
    ].take(limit).toList();
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

  setUp(() {
    online = FakeOnlineApi(hits);
    settings = FakeSettingsStore();
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
          mediaEngineProvider.overrideWithValue(FakeEngine()),
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
}

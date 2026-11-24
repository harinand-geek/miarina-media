import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/browser/browser_data.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

// Obtenir › Navigateur on a phone (design_handoff_android_v2, screen 02).

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

const mb = 1024 * 1024;

void main() {
  late FakeBrowserApi browser;
  late FakeBrowserPages pages;
  late FakeGetApi get;

  Future<void> pumpApp(
    WidgetTester tester, {
    String start = Routes.getBrowser,
  }) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          libraryApiProvider.overrideWithValue(FakeLibraryApi([])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
          getApiProvider.overrideWithValue(get),
          browserApiProvider.overrideWithValue(browser),
          browserPagesProvider.overrideWithValue(pages),
          desktopShellProvider.overrideWithValue(false),
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore()..values['onboardingDone'] = true,
          ),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(start),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  BrowserSnapshot sintel() => FakeBrowserApi.snap(
    kind: 'web',
    url: 'https://commons.wikimedia.org/wiki/File:Sintel.webm',
    title: 'File:Sintel.webm',
    media: [
      detected('https://upload.wikimedia.org/Sintel.webm', size: 120 * mb),
      detected('https://upload.wikimedia.org/Sintel.ogg', kind: 'audio'),
    ],
  );

  setUp(() {
    browser = FakeBrowserApi();
    pages = FakeBrowserPages();
    get = FakeGetApi(
      analysis: Analysis(
        playlist: null,
        status: AnalysisStatus.ready,
        info: MediaInfo(
          subtitles: const [],
          url: 'https://upload.wikimedia.org/Sintel.webm',
          host: 'upload.wikimedia.org',
          engine: 'http',
          title: 'Sintel',
          publisher: 'upload.wikimedia.org',
          supportsResume: true,
          needsFfmpeg: false,
          video: [
            FormatOffer(
              id: 'original',
              quality: 'WEBM',
              detail: 'video/webm',
              sizeBytes: BigInt.from(120 * mb),
              extension_: 'webm',
            ),
          ],
          audio: const [],
        ),
        code: '',
        detail: '',
        tools: const [],
      ),
    );
  });

  testWidgets('Obtenir offers the browser; it has the screen to itself', (
    tester,
  ) async {
    await pumpApp(tester, start: Routes.get);
    await tester.tap(find.text('Navigateur'));
    await settle(tester);
    // Its own bars: no app tabs, the start page, one tab.
    expect(find.bySemanticsLabel(RegExp('^Musique')), findsNothing);
    expect(find.text('Rechercher ou ouvrir une page web'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^1 onglet ouvert')), findsOneWidget);
    expect(find.text('Télécharger · 2'), findsNothing);

    // Back to the app.
    await tester.tap(find.bySemanticsLabel('Retour à Miarina Media'));
    await settle(tester);
    expect(find.bySemanticsLabel(RegExp('^Musique')), findsOneWidget);
  });

  testWidgets('a site, media found, the floating button and its sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Wikimedia Commons'));
    await settle(tester);
    expect(browser.navigated, ['https://commons.wikimedia.org']);
    // The page is shown (the platform view holds it).
    expect(browser.shows, isNotEmpty);

    browser.push(sintel());
    await settle(tester);
    expect(
      find.textContaining('commons.wikimedia.org', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Télécharger · 2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^2 médias')), findsOneWidget);

    await tester.tap(find.text('Télécharger · 2'));
    await settle(tester);
    // Screen 03: the media as chips, the main one analyzed, its formats.
    expect(
      find.bySemanticsLabel(RegExp('^Vidéo · Sintel.webm')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Audio · Sintel.ogg')),
      findsOneWidget,
    );
    expect(get.analyzed, ['https://upload.wikimedia.org/Sintel.webm']);
    expect(find.text('Sintel'), findsOneWidget);
    expect(find.text('WEBM · fichier d’origine'), findsOneWidget);
    expect(find.text('Ajouter à la file'), findsOneWidget);
    await tester.tap(find.textContaining('Télécharger · 120'));
    await settle(tester);
    expect(get.started.single.url, 'https://upload.wikimedia.org/Sintel.webm');
    expect(get.started.single.startNow, isTrue);
    // The sheet closes; the page stays.
    expect(find.text('Ajouter à la file'), findsNothing);
    expect(find.text('Télécharger · 2'), findsOneWidget);

    // Another chip: that media is analyzed.
    await tester.tap(find.text('Télécharger · 2'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Audio · Sintel.ogg')));
    await settle(tester);
    expect(get.analyzed.last, 'https://upload.wikimedia.org/Sintel.ogg');
  });

  testWidgets('holding the button downloads the main media at once', (
    tester,
  ) async {
    await pumpApp(tester);
    browser.push(sintel());
    await settle(tester);
    await tester.longPress(find.text('Télécharger · 2'));
    await settle(tester);
    expect(get.analyzed, ['https://upload.wikimedia.org/Sintel.webm']);
    expect(get.started.single.formatId, isNull, reason: 'original file');
    expect(get.started.single.startNow, isTrue);
  });

  testWidgets('Back goes to the previous page, then leaves the browser', (
    tester,
  ) async {
    await pumpApp(tester, start: Routes.get);
    await tester.tap(find.text('Navigateur'));
    await settle(tester);
    browser.push(sintel());
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(browser.actions, ['back']);

    browser.push(FakeBrowserApi.snap());
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.bySemanticsLabel(RegExp('^Musique')), findsOneWidget);
  });

  testWidgets('tabs: list, select, close, new', (tester) async {
    browser.current = FakeBrowserApi.snap(
      kind: 'web',
      url: 'https://archive.org/details/sintel',
      title: 'Sintel',
      tabs: 2,
    );
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^2 onglets ouverts')));
    await settle(tester);
    expect(find.text('Onglets'), findsOneWidget);
    expect(find.text('Sintel'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fermer l’onglet Sintel'));
    await settle(tester);
    expect(browser.actions.last, 'close 2');
    await tester.tap(find.text('Nouvel onglet').first);
    await settle(tester);
    expect(browser.newTabs, [null]);
  });

  testWidgets('orders reach the native pages; their reports the core', (
    tester,
  ) async {
    await pumpApp(tester);
    browser.events_.add(
      BrowserEvent(
        page: BrowserPageCommand(
          tab: 3,
          action: 'load',
          url: 'https://archive.org',
        ),
      ),
    );
    await settle(tester);
    expect(pages.commands, ['load 3 https://archive.org']);

    pages.onReport!('title', {'tab': 3, 'type': 'title', 'title': 'Archive'});
    expect(browser.reports.single.$1, 'title');
    expect(browser.reports.single.$2['title'], 'Archive');
  });
}

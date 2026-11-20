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

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

const mb = 1024 * 1024;

void main() {
  test('media offered by a page, as in the Tauri app', () {
    final s = FakeBrowserApi.snap(
      kind: 'web',
      url: 'https://commons.wikimedia.org/wiki/File:Sintel.webm',
      title: 'File:Sintel.webm',
      streamPlayer: true,
      media: [
        detected('https://upload.wikimedia.org/Sintel.webm.2160p.vp9.webm'),
        detected('https://upload.wikimedia.org/Sintel.webm.720p.vp9.webm'),
      ],
    );
    final list = candidatesOf(s);
    expect(list.first.kind, 'page', reason: 'the page player first');
    expect(mainCandidate(list)!.kind, 'page');
    // Without the page player: the best variant up to 1080p.
    expect(mainCandidate(list.skip(1).toList())!.title, contains('720p'));

    final a = splitAddress('https://commons.wikimedia.org/wiki/File:X?y=1');
    expect(a.host, 'commons.wikimedia.org');
    expect(a.rest, '/wiki/File:X?y=1');
    expect(a.secure, isTrue);
  });

  group('in the app', () {
    late FakeBrowserApi browser;
    late FakeGetApi get;

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
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
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(
              FakeSettingsStore()..values['onboardingDone'] = true,
            ),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(Routes.getBrowser),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
    }

    setUp(() {
      browser = FakeBrowserApi();
      get = FakeGetApi(
        analysis: Analysis(
          status: AnalysisStatus.ready,
          info: MediaInfo(
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

    testWidgets('start page, a site, its media, then a download', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Rechercher ou ouvrir une page web'), findsOneWidget);
      expect(find.text('Wikimedia Commons'), findsOneWidget);
      expect(
        find.text(
          'Téléchargez seulement les médias qui vous appartiennent ou que vous avez le droit d’enregistrer.',
        ),
        findsOneWidget,
      );
      // No page above the start page.
      expect(browser.shows, isEmpty);

      await tester.tap(find.text('Wikimedia Commons'));
      await settle(tester);
      expect(browser.navigated, ['https://commons.wikimedia.org']);
      // The page is placed where the screen leaves room for it: below the
      // title bar, tab strip and toolbar, right of the sidebar.
      final (x, y, w, h) = browser.shows.last;
      expect(x, greaterThanOrEqualTo(64));
      expect(y, greaterThan(100));
      expect(w, greaterThan(800));
      expect(h, greaterThan(400));
      expect(
        find.text('commons.wikimedia.org', findRichText: true),
        findsOneWidget,
      );

      // The core finds two files on the page.
      browser.push(
        FakeBrowserApi.snap(
          kind: 'web',
          url: 'https://commons.wikimedia.org/wiki/File:Sintel.webm',
          title: 'File:Sintel.webm',
          media: [
            detected(
              'https://upload.wikimedia.org/Sintel.webm',
              size: 120 * mb,
            ),
            detected('https://upload.wikimedia.org/Sintel.ogg', kind: 'audio'),
          ],
        ),
      );
      await settle(tester);
      expect(find.text('2 médias'), findsOneWidget);
      expect(find.text('2 médias trouvés'), findsOneWidget);
      final before = browser.shows.last;

      await tester.tap(find.text('Choisir le média et le format'));
      await settle(tester);
      expect(find.text('Télécharger depuis cette page'), findsOneWidget);
      // The page shrinks to leave room for the panel.
      expect(browser.shows.last.$3, lessThan(before.$3));
      expect(find.text('WEBM · fichier d’origine'), findsOneWidget);
      expect(get.analyzed, ['https://upload.wikimedia.org/Sintel.webm']);

      await tester.tap(find.text('Ajouter à la file'));
      await settle(tester);
      expect(
        get.started.single.url,
        'https://upload.wikimedia.org/Sintel.webm',
      );
      expect(get.started.single.startNow, isFalse);
    });

    testWidgets('popups become tabs; offered files go to the analysis', (
      tester,
    ) async {
      await pumpApp(tester);
      browser.events_.add(BrowserEvent(openTab: 'https://archive.org/x'));
      await settle(tester);
      expect(browser.newTabs, ['https://archive.org/x']);

      // Ctrl+W pressed while the page had the keyboard.
      browser.events_.add(BrowserEvent(shortcut: 'Ctrl+W'));
      await settle(tester);
      expect(browser.actions.last, startsWith('close'));

      // A page is shown, then offers a file.
      browser.push(
        FakeBrowserApi.snap(kind: 'web', url: 'https://archive.org/x'),
      );
      await settle(tester);
      expect(browser.shows, isNotEmpty);
      final hidesBefore = browser.hides;
      browser.events_.add(
        BrowserEvent(download: 'https://archive.org/download/x/x.mp4'),
      );
      await settle(tester);
      expect(get.analyzed, ['https://archive.org/download/x/x.mp4']);
      expect(browser.hides, greaterThan(hidesBefore), reason: 'page hidden');
    });

    testWidgets('a refused address says why', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('browser-address')),
        'file:///C:/secret',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(
        find.text(
          'Seules les pages web (http, https) s’ouvrent dans le navigateur.',
        ),
        findsOneWidget,
      );
    });
  });
}

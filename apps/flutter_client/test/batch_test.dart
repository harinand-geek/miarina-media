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

import 'support/fakes.dart';

// Obtenir › Plusieurs liens.

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

FormatOffer own(String quality, String ext) => FormatOffer(
  id: 'original',
  quality: quality,
  detail: '',
  sizeBytes: null,
  extension_: ext,
  tag: null,
);

Analysis ready(String url, String title, {String engine = 'ytdlp'}) =>
    Analysis(
      status: AnalysisStatus.ready,
      info: MediaInfo(
        url: url,
        host: Uri.parse(url).host,
        engine: engine,
        title: title,
        publisher: Uri.parse(url).host,
        source: null,
        durationSecs: null,
        license: null,
        supportsResume: engine == 'http',
        needsFfmpeg: false,
        video: engine == 'http' ? [own('MP4', 'mp4')] : const [],
        audio: const [],
      ),
      code: '',
      detail: '',
      tools: const [],
      playlist: null,
    );

Analysis status(AnalysisStatus s, {String code = ''}) => Analysis(
  status: s,
  info: null,
  code: code,
  detail: '',
  tools: const [],
  playlist: null,
);

void main() {
  late FakeGetApi get;

  test('a pasted text gives its links once each, 50 at most', () {
    expect(splitLinks(' a\n\nb  a\r\nc\t'), ['a', 'b', 'c']);
    final many = [for (var i = 0; i < 60; i++) 'https://e.org/$i'].join('\n');
    expect(splitLinks(many), hasLength(maxBatchLinks));
  });

  Future<void> pumpApp(
    WidgetTester tester,
    String start, {
    Size size = const Size(1440, 900),
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
          libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
          getApiProvider.overrideWithValue(get),
          downloadFolderPickerProvider.overrideWithValue(() async => null),
          revealProvider.overrideWithValue((_, {select = false}) async {}),
          desktopShellProvider.overrideWithValue(size.width >= 600),
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

  setUp(() {
    get = FakeGetApi()
      ..analysisOf = (url) => switch (url) {
        'https://www.youtube.com/watch?v=a' => ready(url, 'Sintel'),
        'https://cdn.example.org/film.mp4' => ready(
          url,
          'film.mp4',
          engine: 'http',
        ),
        'https://www.youtube.com/playlist?list=PL' => status(
          AnalysisStatus.playlist,
        ),
        _ => status(AnalysisStatus.noMedia, code: 'network'),
      };
  });

  testWidgets('the home tile opens it', (tester) async {
    await pumpApp(tester, Routes.get);
    expect(find.text('PRÉVU'), findsNothing, reason: 'every tile works');
    await tester.tap(find.text('Plusieurs liens'));
    await settle(tester);
    expect(find.text('Les liens collés apparaîtront ici.'), findsOneWidget);
  });

  testWidgets('each link is analysed and added, or says why not', (
    tester,
  ) async {
    await pumpApp(tester, Routes.getBatch);
    await tester.enterText(
      find.byKey(const ValueKey('batch-links')),
      [
        'https://www.youtube.com/watch?v=a',
        'https://cdn.example.org/film.mp4',
        'https://www.youtube.com/playlist?list=PL',
        'https://down.example.org/page',
        'ftp://example.org/x',
        'https://www.youtube.com/watch?v=a',
      ].join('\n'),
    );
    await settle(tester);
    expect(find.textContaining('4 valides sur 5'), findsOneWidget);
    expect(
      find.text('Ce lien utilise un protocole non pris en charge.'),
      findsNothing,
      reason: 'checked by the fake as unsupported_scheme',
    );

    await tester.tap(find.text('Télécharger 4 liens'));
    await settle(tester);

    final started = {for (final r in get.started) r.url: r};
    expect(started.keys, {
      'https://www.youtube.com/watch?v=a',
      'https://cdn.example.org/film.mp4',
    });
    final page = started['https://www.youtube.com/watch?v=a']!;
    expect(page.formatId, 'p1080');
    expect(page.title, 'Sintel (1080p)');
    expect(page.startNow, isFalse);
    final file = started['https://cdn.example.org/film.mp4']!;
    expect(file.engine, 'http');
    expect(file.formatId, isNull);
    expect(find.text('Sintel'), findsOneWidget, reason: 'title once added');
    expect(
      find.text('C’est une playlist : utilisez la tuile Playlist'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsNWidgets(2));
    expect(find.text('2 ajoutés à la file · 2 non ajoutés'), findsOneWidget);

    // A retry only runs the failed links again.
    get.started.clear();
    await tester.tap(find.text('Réessayer').first);
    await settle(tester);
    expect(get.started, isEmpty);
  });

  testWidgets('audio only uses the audio quality', (tester) async {
    await pumpApp(tester, Routes.getBatch);
    await tester.enterText(
      find.byKey(const ValueKey('batch-links')),
      'https://www.youtube.com/watch?v=a',
    );
    await settle(tester);
    await tester.tap(find.text('Audio seul'));
    await settle(tester);
    await tester.tap(find.text('Télécharger 1 lien'));
    await settle(tester);
    final r = get.started.single;
    expect(r.isAudio, isTrue);
    expect(r.formatId, 'p320');
    expect(r.extension_, 'mp3');
  });

  testWidgets('on a phone', (tester) async {
    await pumpApp(tester, Routes.getBatch, size: const Size(412, 892));
    await tester.enterText(
      find.byKey(const ValueKey('batch-links')),
      'https://www.youtube.com/watch?v=a',
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Télécharger 1 lien'));
    await settle(tester);
    expect(get.started, hasLength(1));
  });
}

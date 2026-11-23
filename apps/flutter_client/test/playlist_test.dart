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

// Obtenir › Playlist (CDC DL-07).

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

FormatOffer preset(String id, String quality, String ext, {String? tag}) =>
    FormatOffer(
      id: id,
      quality: quality,
      detail: ext.toUpperCase(),
      sizeBytes: null,
      extension_: ext,
      tag: tag,
    );

WebPlaylistEntry entry(int i, String title, {bool ok = true, double? secs}) =>
    WebPlaylistEntry(
      index: i,
      url: ok ? 'https://www.youtube.com/watch?v=v$i' : null,
      title: title,
      durationSecs: secs,
      thumbnailUrl: ok ? 'https://i.ytimg.com/vi/v$i/hq.jpg' : null,
    );

Analysis playlist({bool truncated = false, int? count}) => Analysis(
  status: AnalysisStatus.playlist,
  info: null,
  code: '',
  detail: '',
  tools: const [],
  playlist: WebPlaylist(
    url: 'https://www.youtube.com/playlist?list=PL1',
    host: 'youtube.com',
    title: 'Open Movies',
    publisher: 'Blender Studio',
    source: 'YoutubeTab',
    thumbnail: null,
    count: count == null ? null : BigInt.from(count),
    truncated: truncated,
    needsFfmpeg: false,
    entries: [
      entry(1, 'Sintel', secs: 888),
      entry(2, '[Private video]', ok: false),
      entry(3, 'Tears of Steel', secs: 734),
      entry(4, ''),
    ],
    video: [
      preset('v1080', '1080p', 'mp4', tag: 'Recommended'),
      preset('v720', '720p', 'mp4'),
    ],
    audio: [
      preset('a320', 'MP3 · 320 kbps', 'mp3', tag: 'Recommended'),
      preset('a192', 'MP3 · 192 kbps', 'mp3'),
    ],
  ),
);

void main() {
  late FakeGetApi get;

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

  String analysisOf(String url) => Uri(
    path: Routes.getAnalysis,
    queryParameters: {'url': url, 'tab': 'playlist'},
  ).toString();

  setUp(() => get = FakeGetApi(analysis: playlist()));

  testWidgets('the Playlist tile analyses the whole playlist of a link', (
    tester,
  ) async {
    await pumpApp(tester, Routes.get);
    await tester.enterText(
      find.byKey(const ValueKey('get-link')),
      'https://www.youtube.com/watch?v=v3&list=PL1',
    );
    await tester.tap(find.text('Playlist'));
    await settle(tester);
    expect(get.analyzed, [
      'playlist https://www.youtube.com/watch?v=v3&list=PL1',
    ]);
    expect(find.text('Open Movies'), findsOneWidget);
  });

  testWidgets('entries are chosen, then queued in order with one quality', (
    tester,
  ) async {
    await pumpApp(
      tester,
      analysisOf('https://www.youtube.com/playlist?list=PL1'),
    );
    expect(find.text('Open Movies'), findsOneWidget);
    expect(find.text('youtube.com · Blender Studio'), findsOneWidget);
    expect(find.text('4 éléments'), findsOneWidget);
    expect(find.text('14:48'), findsOneWidget);
    // The private one cannot be chosen; the untitled one is named.
    expect(find.text('Indisponible'), findsOneWidget);
    expect(find.text('Élément 4'), findsOneWidget);
    expect(find.textContaining('3 sur 3 sélectionnés'), findsOneWidget);
    expect(find.text('Télécharger 3 éléments'), findsOneWidget);

    await tester.tap(find.text('Tout désélectionner'));
    await settle(tester);
    expect(find.textContaining('0 sur 3 sélectionnés'), findsOneWidget);
    await tester.tap(find.text('Télécharger'));
    await settle(tester);
    expect(get.playlists, isEmpty, reason: 'nothing chosen');

    await tester.tap(find.text('Tears of Steel'));
    await tester.tap(find.text('Sintel'));
    await tester.tap(find.text('[Private video]'));
    await settle(tester);
    expect(find.textContaining('2 sur 3 sélectionnés'), findsOneWidget);

    await tester.tap(find.text('Audio seul'));
    await settle(tester);
    await tester.tap(find.text('MP3 · 192 kbps'));
    await tester.tap(find.text('Dans un dossier « Open Movies »'));
    await settle(tester);
    await tester.tap(find.text('Télécharger 2 éléments'));
    await settle(tester);

    final request = get.playlists.single;
    expect(request.playlistTitle, 'Open Movies');
    expect(request.isAudio, isTrue);
    expect(request.formatId, 'a192');
    expect(request.extension_, 'mp3');
    expect(request.ownFolder, isFalse);
    // The playlist's order, not the order of the clicks.
    expect(request.items.map((i) => i.index), [1, 3]);
    expect(request.items.first.url, 'https://www.youtube.com/watch?v=v1');
    expect(
      request.items.first.thumbnailUrl,
      'https://i.ytimg.com/vi/v1/hq.jpg',
    );
    expect(find.text('2 téléchargements ajoutés à la file'), findsOneWidget);
    expect(find.textContaining('En cours · '), findsOneWidget);
  });

  testWidgets('a long playlist says it is cut; a full queue says so', (
    tester,
  ) async {
    get = FakeGetApi(analysis: playlist(truncated: true, count: 532))
      ..playlistError = Exception('queue_full');
    await pumpApp(
      tester,
      analysisOf('https://www.youtube.com/playlist?list=PL1'),
    );
    expect(find.text('Les 4 premiers sur 532'), findsOneWidget);
    await tester.tap(find.text('Télécharger 3 éléments'));
    await settle(tester);
    expect(
      find.text(
        'La file est pleine. Terminez ou retirez des téléchargements, puis '
        'réessayez.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open Movies'), findsOneWidget, reason: 'stays');
  });

  testWidgets('on a phone', (tester) async {
    await pumpApp(
      tester,
      analysisOf('https://www.youtube.com/playlist?list=PL1'),
      size: const Size(412, 892),
    );
    expect(find.text('Open Movies'), findsOneWidget);
    expect(find.text('Télécharger 3 éléments'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Télécharger 3 éléments'));
    await settle(tester);
    expect(get.playlists.single.items, hasLength(3));
    expect(get.playlists.single.ownFolder, isTrue);
  });
}

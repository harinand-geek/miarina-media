import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/albums_screen.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/library.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

LibraryGroup group(
  String name, {
  String? detail,
  int? year,
  int added = 0,
  int plays = 0,
  int count = 1,
}) => LibraryGroup(
  name: name,
  detail: detail,
  count: BigInt.from(count),
  durationSecs: 60,
  year: year,
  addedAt: added,
  plays: BigInt.from(plays),
  sizeBytes: BigInt.zero,
  lossless: false,
  downloaded: false,
  compilation: false,
);

// Ids grow with the time of addition in these fixtures.
final songs = [
  track(1, 'Basse marée', artist: 'Nafy Rakoto', album: 'Saisons de sel'),
  track(2, 'Kabary', artist: 'Nafy Rakoto', album: 'Saisons de sel', plays: 9),
  track(3, 'Ville lente', artist: 'Iony', album: 'Ville lente', format: 'MP3'),
  track(4, 'Été', artist: 'Toky', album: 'Été 2024', format: 'MP3', plays: 2),
  track(
    5,
    'Marée haute',
    artist: 'Nafy Rakoto',
    album: 'Anciens',
    format: 'MP3',
    plays: 4,
  ),
];

void main() {
  late FakeLibraryApi library;
  late FakeSettingsStore settings;

  Future<void> pumpApp(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          libraryApiProvider.overrideWithValue(library),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
          getApiProvider.overrideWithValue(FakeGetApi()),
          desktopShellProvider.overrideWithValue(true),
          settingsStoreProvider.overrideWithValue(settings),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    library = FakeLibraryApi([...songs]);
    settings = FakeSettingsStore()..values['onboardingDone'] = true;
  });

  List<String> inOrder(WidgetTester tester, List<String> names) =>
      [
        for (final n in names)
          if (find.text(n).evaluate().isNotEmpty) n,
      ]..sort((a, b) {
        final pa = tester.getTopLeft(find.text(a).first);
        final pb = tester.getTopLeft(find.text(b).first);
        return pa.dy != pb.dy ? pa.dy.compareTo(pb.dy) : pa.dx.compareTo(pb.dx);
      });

  const albums = ['Saisons de sel', 'Ville lente', 'Été 2024', 'Anciens'];

  test('sorts: undated and untagged last, ties by name', () {
    final list = [
      group('b', year: 2020, detail: 'Zed'),
      group('a', detail: null),
      group('c', year: 2024, detail: 'Anna'),
    ];
    String names(GroupSort s) => sortGroups(list, s).map((g) => g.name).join();
    expect(names(GroupSort.year), 'cba');
    expect(names(GroupSort.artist), 'cba');
    expect(names(GroupSort.name), 'abc');
  });

  testWidgets('albums: newest first, the order chosen is remembered', (
    tester,
  ) async {
    await pumpApp(tester, Routes.albums);
    expect(find.text('Ajoutés récemment'), findsOneWidget);
    expect(inOrder(tester, albums), [
      'Anciens',
      'Été 2024',
      'Ville lente',
      'Saisons de sel',
    ]);

    await tester.tap(find.text('Ajoutés récemment'));
    await settle(tester);
    await tester.tap(find.text('A → Z'));
    await settle(tester);
    expect(inOrder(tester, albums).first, 'Anciens');
    expect(inOrder(tester, albums)[1], 'Saisons de sel');
    expect(
      settings.values['groupViews'],
      containsPair('album', {'sort': 'name', 'list': false}),
    );

    await tester.tap(find.bySemanticsLabel('Liste'));
    await settle(tester);
    expect(find.text('2 titres'), findsOneWidget, reason: 'list row');
    expect((settings.values['groupViews'] as Map)['album'], {
      'sort': 'name',
      'list': true,
    });
  });

  testWidgets('albums: quick filters, one at a time', (tester) async {
    library.compilations = {'été 2024'};
    library.downloadedGroups = {'ville lente'};
    await pumpApp(tester, Routes.albums);
    expect(find.text('Sans pochette · 4'), findsOneWidget);

    await tester.tap(find.text('FLAC / hi-res'));
    await settle(tester);
    expect(inOrder(tester, albums), ['Saisons de sel']);
    await tester.tap(find.text('Compilations'));
    await settle(tester);
    expect(inOrder(tester, albums), ['Été 2024']);
    await tester.tap(find.text('Téléchargés avec Miarina'));
    await settle(tester);
    expect(inOrder(tester, albums), ['Ville lente']);
    await tester.tap(find.text('Tous'));
    await settle(tester);
    expect(inOrder(tester, albums).length, 4);
  });

  testWidgets('artists: most played order; their page', (tester) async {
    await pumpApp(tester, Routes.artists);
    expect(find.text('A → Z'), findsOneWidget);
    await tester.tap(find.text('A → Z'));
    await settle(tester);
    await tester.tap(find.text('Les plus écoutés'));
    await settle(tester);
    expect(inOrder(tester, ['Iony', 'Nafy Rakoto', 'Toky']), [
      'Nafy Rakoto',
      'Toky',
      'Iony',
    ]);

    await tester.tap(find.text('Nafy Rakoto'));
    await settle(tester);
    expect(find.textContaining('écouté 13 fois'), findsOneWidget);
    expect(find.text('Les plus écoutés'), findsOneWidget);
    expect(find.text('9 écoutes'), findsOneWidget);
    expect(find.text('4 écoutes'), findsOneWidget);
    expect(
      find.text('Basse marée'),
      findsOneWidget,
      reason: 'never played: only in the full list',
    );
  });
}

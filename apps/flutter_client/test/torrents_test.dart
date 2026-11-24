import 'package:flutter/services.dart';
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
import 'package:miarina_media/features/torrents/torrents_data.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

const mb = 1024 * 1024;

TorrentRow row(
  String hash,
  String name, {
  String phase = 'downloading',
  int done = 0,
  int total = 0,
  int uploaded = 0,
  double down = 0,
  double up = 0,
  int peers = 0,
}) => TorrentRow(
  hash: hash,
  name: name,
  folder: 'C:\\Downloads\\Miarina\\Torrents\\$hash-0',
  phase: phase,
  done: BigInt.from(done),
  total: BigInt.from(total),
  uploaded: BigInt.from(uploaded),
  downSpeed: down,
  upSpeed: up,
  peers: peers,
);

/// The torrent session in memory, every call recorded.
class FakeTorrentsApi implements TorrentsApi {
  var enabled = false;
  var rows = <TorrentRow>[];
  var downLimit = 0;
  var upLimit = 0;
  final calls = <String>[];
  Object? previewError;
  final started = <(String, List<int>, bool)>[];
  final limitCalls = <(int, int)>[];

  @override
  Future<void> enable() async {
    calls.add('enable');
    enabled = true;
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    enabled = false;
  }

  @override
  Future<TorrentSnapshot> list() async => TorrentSnapshot(
    enabled: enabled,
    rows: rows,
    downloadLimit: BigInt.from(downLimit),
    uploadLimit: BigInt.from(upLimit),
    targetRatio: ratio,
    seedHours: hours,
  );

  double ratio = 0;
  int hours = 0;

  @override
  Future<void> sharing(double ratio, int hours) async {
    this.ratio = ratio;
    this.hours = hours;
  }

  @override
  Future<TorrentPreview> preview({String? magnet, String? file}) async {
    calls.add('preview ${magnet ?? file}');
    if (previewError != null) throw previewError!;
    return TorrentPreview(
      hash: 'abc',
      name: 'Blender Open Movies — collection',
      files: [
        TorrentFile(
          index: 0,
          path: 'Sintel/sintel.mkv',
          size: BigInt.from(600 * mb),
        ),
        TorrentFile(
          index: 2,
          path: 'Spring/spring.mkv',
          size: BigInt.from(400 * mb),
        ),
      ],
    );
  }

  @override
  Future<void> start(
    String hash,
    List<int> files, {
    required bool sequential,
  }) async => started.add((hash, files, sequential));

  @override
  Future<void> action(String hash, String action) async =>
      calls.add('$action $hash');

  @override
  Future<void> limits(int download, int upload) async {
    limitCalls.add((download, upload));
    downLimit = download;
    upLimit = upload;
  }
}

void main() {
  late FakeTorrentsApi torrents;
  String? picked;

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
          getApiProvider.overrideWithValue(FakeGetApi()),
          torrentsApiProvider.overrideWithValue(torrents),
          torrentFilePickerProvider.overrideWithValue((_) async => picked),
          revealProvider.overrideWithValue((_, {select = false}) async {}),
          desktopShellProvider.overrideWithValue(true),
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore()..values['onboardingDone'] = true,
          ),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(Routes.getTorrents),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    torrents = FakeTorrentsApi();
    picked = null;
  });

  testWidgets('nothing runs until the session is enabled', (tester) async {
    await pumpApp(tester);
    expect(find.text('Session arrêtée'), findsOneWidget);
    expect(find.byKey(const ValueKey('magnet')), findsNothing);
    expect(torrents.calls, isEmpty, reason: 'no session at all');

    await tester.tap(find.text('Activer la session'));
    await settle(tester);
    expect(torrents.calls, ['enable']);
    expect(find.text('Session active'), findsOneWidget);
    expect(find.text('Vos torrents apparaîtront ici.'), findsOneWidget);
    expect(find.text('PRÉVU'), findsNothing, reason: 'ratio, seeding time');

    // Finished torrents stop sharing at 1,5 or after 24 h.
    await tester.enterText(find.byKey(const ValueKey('share-ratio')), '1,5');
    await tester.enterText(find.byKey(const ValueKey('share-hours')), '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect((torrents.ratio, torrents.hours), (1.5, 24));

    await tester.tap(find.text('Arrêter tout et le partage'));
    await settle(tester);
    expect(torrents.calls.last, 'disable');
    expect(find.text('Session arrêtée'), findsOneWidget);
  });

  testWidgets('a magnet link: files chosen, then started', (tester) async {
    torrents.enabled = true;
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const ValueKey('magnet')),
      'magnet:?xt=urn:btih:abc',
    );
    await settle(tester);
    await tester.tap(find.text('Analyser le lien'));
    await settle(tester);
    expect(torrents.calls.last, 'preview magnet:?xt=urn:btih:abc');
    expect(find.text('Blender Open Movies — collection'), findsOneWidget);
    expect(find.text('600 Mo'), findsOneWidget);

    // Spring left out, pieces in order.
    await tester.tap(find.text('Spring/spring.mkv'));
    await tester.tap(find.text('Télécharger les morceaux dans l’ordre'));
    await settle(tester);
    await tester.tap(find.text('Démarrer le téléchargement'));
    await settle(tester);
    final (hash, files, sequential) = torrents.started.single;
    expect((hash, sequential), ('abc', true));
    expect(files, [0]);
    expect(find.text('Blender Open Movies — collection'), findsNothing);

    // A .torrent file chosen in the dialog.
    picked = r'C:\Users\Hery\Downloads\x.torrent';
    await tester.tap(find.text('Ouvrir un .torrent'));
    await settle(tester);
    expect(torrents.calls.last, r'preview C:\Users\Hery\Downloads\x.torrent');
  });

  testWidgets('a bad link says why, in words', (tester) async {
    torrents.enabled = true;
    torrents.previewError = Exception('torrent_link');
    await pumpApp(tester);
    await tester.enterText(find.byKey(const ValueKey('magnet')), 'magnet:?x');
    await settle(tester);
    await tester.tap(find.text('Analyser le lien'));
    await settle(tester);
    expect(find.text('Ce lien magnet n’est pas valide.'), findsOneWidget);
  });

  testWidgets('transfers and sharing are shown and stoppable', (tester) async {
    torrents
      ..enabled = true
      ..rows = [
        row(
          'a',
          'Blender Open Movies',
          done: 1500 * mb,
          total: 3175 * mb,
          down: 4.2 * mb,
          up: 310 * 1024,
          peers: 18,
        ),
        row(
          'b',
          'Sintel 4K — source files',
          phase: 'finished',
          done: 5837 * mb,
          total: 5837 * mb,
          uploaded: 4670 * mb,
          up: 1.2 * mb,
          peers: 6,
        ),
      ];
    await pumpApp(tester);
    expect(find.text('Session active · partage en cours'), findsOneWidget);
    expect(find.text('4,2 Mo/s'), findsOneWidget);
    expect(find.text('310 Ko/s'), findsOneWidget);
    expect(find.text('Terminé · 5,70 Go · partage en cours'), findsOneWidget);
    expect(find.text('0.8'), findsOneWidget, reason: 'ratio');

    await tester.tap(find.text('Arrêter le partage'));
    await settle(tester);
    expect(torrents.calls.last, 'pause b');

    await tester.tap(find.bySemanticsLabel('Retirer Blender Open Movies'));
    await settle(tester);
    expect(find.text('Retirer ce torrent ?'), findsOneWidget);
    await tester.tap(find.text('Retirer').last);
    await settle(tester);
    expect(torrents.calls.last, 'remove a');

    // Upload capped at 512 KB/s.
    await tester.enterText(find.byKey(const ValueKey('limit-up')), '512');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(torrents.limitCalls.single, (0, 512 * 1024));
    expect(find.text('Limites appliquées'), findsOneWidget);
  });
}

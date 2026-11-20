import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/health/health_screens.dart';
import 'package:miarina_media/features/import/import_data.dart';
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

MissingFileInfo file(int id, String path, {String? found}) => MissingFileInfo(
  id: id,
  path: path,
  title: path.split(RegExp(r'[\\/]')).last,
  isVideo: path.endsWith('.mkv') || path.endsWith('.mp4'),
  found: found,
);

List<MissingGroupInfo> threeCauses() => [
  MissingGroupInfo(
    cause: MissingCause.volumeAbsent,
    key: r'volume:E:\',
    folder: r'E:\',
    files: [
      file(1, r'E:\Films\Le Dernier Ferry (2022).mkv'),
      file(2, r'E:\Films\Rova (2021)\Rova.mp4'),
    ],
  ),
  MissingGroupInfo(
    cause: MissingCause.moved,
    key: r'moved:D:\Musique\Nafy>D:\Musique\Nafy (2024)',
    folder: r'D:\Musique\Nafy',
    target: r'D:\Musique\Nafy (2024)',
    files: [
      file(
        3,
        r'D:\Musique\Nafy\05 Seuil.flac',
        found: r'D:\Musique\Nafy (2024)\05 Seuil.flac',
      ),
    ],
  ),
  MissingGroupInfo(
    cause: MissingCause.notFound,
    key: 'lost',
    folder: '',
    files: [file(4, r'C:\Users\Hery\Music\Vieux\Mena (demo).mp3')],
  ),
];

void main() {
  test('volumes, folders, sizes and quality labels', () {
    expect(volumeLabel(r'E:\'), 'E:');
    expect(volumeLabel('/storage/1A2B-3C4D'), '/storage/1A2B-3C4D');
    expect(
      commonFolder([r'E:\Films\a.mkv', r'E:\Films\Rova (2021)\Rova.mp4']),
      r'E:\Films',
    );
    expect(commonFolder([r'E:\a.mkv', r'E:\b\c.mp4']), r'E:\');
    expect(
      qualityLabel(
        version(1, 'a.flac', size: 1, codec: 'flac', lossless: true),
      ),
      'FLAC',
    );
    expect(
      qualityLabel(version(2, 'a.mp3', size: 1, kbps: 192)),
      'MP3 192 kb/s',
    );

    final set = DuplicateSet(
      isVideo: false,
      title: 'Marée haute',
      versions: [
        version(5, 'best.flac', size: 58 << 20, lossless: true),
        version(9, 'copy.mp3', size: 6 << 20),
      ],
    );
    expect(keptOf(set, const {}), 5);
    expect(keptOf(set, {duplicateKey(set): 9}), 9);
    // A choice that no longer exists falls back to the best version.
    expect(keptOf(set, {duplicateKey(set): 42}), 5);
    expect(recoverableBytes([set], const {}), 6 << 20);
    expect(recoverableBytes([set], {duplicateKey(set): 9}), 58 << 20);
  });

  group('in the app', () {
    late FakeSettingsStore settings;
    late FakeHealthApi health;
    late FakeEngine engine;
    late FakeIndexerApi indexer;
    String? pickedFile;
    String? pickedFolder;

    Future<void> pumpApp(
      WidgetTester tester, {
      required String start,
      List<LibraryItem> items = const [],
    }) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(engine),
            libraryApiProvider.overrideWithValue(FakeLibraryApi(items)),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            indexerApiProvider.overrideWithValue(indexer),
            healthApiProvider.overrideWithValue(health),
            locateFilePickerProvider.overrideWithValue((_) async => pickedFile),
            searchFolderPickerProvider.overrideWithValue(
              () async => pickedFolder,
            ),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(settings),
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
      settings = FakeSettingsStore()..values['onboardingDone'] = true;
      engine = FakeEngine();
      indexer = FakeIndexerApi();
      pickedFile = null;
      pickedFolder = null;
    });

    testWidgets('W-O2a: grouped by cause, nothing deleted by itself', (
      tester,
    ) async {
      health = FakeHealthApi(missing: threeCauses());
      await pumpApp(tester, start: Routes.missing);

      expect(find.text('Fichiers introuvables'), findsOneWidget);
      expect(
        find.text(
          "4 éléments n'ont pas été trouvés au dernier passage. "
          "Rien n'a été supprimé.",
        ),
        findsOneWidget,
      );
      expect(find.text('Disque E: déconnecté'), findsOneWidget);
      expect(
        find.text(
          r'2 éléments de E:\Films. Ils réapparaîtront au branchement.',
        ),
        findsOneWidget,
      );
      expect(find.text('Dossier probablement renommé'), findsOneWidget);
      expect(find.text('1 fichier introuvable'), findsOneWidget);
      // The sidebar points here, with an amber count.
      expect(find.text('Introuvables'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // The renamed folder: paths updated in one click.
      await tester.tap(find.text('Mettre à jour les chemins'));
      await settle(tester);
      expect(health.relocated, [(3, r'D:\Musique\Nafy (2024)\05 Seuil.flac')]);
      expect(find.text('Dossier probablement renommé'), findsNothing);
      expect(find.text('1 chemin mis à jour'), findsOneWidget);

      // The unplugged drive: searched in another folder.
      pickedFolder = r'F:\Sauvegarde';
      await tester.tap(find.text('Relocaliser…'));
      await settle(tester);
      expect(health.searched.single.$2, r'F:\Sauvegarde');
      expect(health.searched.single.$1, [1, 2]);
      expect(
        find.text('1 fichier retrouvé · 1 toujours introuvable'),
        findsOneWidget,
      );

      // Hidden, then shown again.
      await tester.tap(find.text('Masquer'));
      await settle(tester);
      expect(find.textContaining('Disque E:'), findsNothing);
      expect(settings.values[MissingDismissedController.key], [r'volume:E:\']);
      await tester.tap(find.text('Tout afficher'));
      await settle(tester);
      expect(find.text('Disque E: déconnecté'), findsOneWidget);

      // The lone file: removed from the library after a confirmation.
      await tester.tap(find.text('Retirer de la bibliothèque'));
      await settle(tester);
      expect(
        find.text('Retirer ce fichier de la bibliothèque ?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retirer'));
      await settle(tester);
      expect(health.removed, [4]);
    });

    testWidgets('a lone file is located by hand', (tester) async {
      health = FakeHealthApi(missing: [threeCauses().last]);
      await pumpApp(tester, start: Routes.missing);
      // Cancelled dialog: nothing happens.
      await tester.tap(find.text('Localiser…'));
      await settle(tester);
      expect(health.relocated, isEmpty);

      pickedFile = r'D:\Archives\Mena (demo).mp3';
      await tester.tap(find.text('Localiser…'));
      await settle(tester);
      expect(health.relocated, [(4, r'D:\Archives\Mena (demo).mp3')]);
      expect(find.text('Tous vos fichiers sont là'), findsOneWidget);
    });

    testWidgets('W-O2b: keep the best, hide the others on request', (
      tester,
    ) async {
      health = FakeHealthApi(
        duplicates: [
          DuplicateSet(
            isVideo: false,
            title: 'Marée haute',
            artist: 'Nafy Rakoto',
            album: 'Saisons de sel',
            versions: [
              version(
                5,
                r'D:\Musique\Nafy Rakoto\02 Marée haute.flac',
                size: 58 << 20,
                codec: 'flac',
                lossless: true,
              ),
              version(
                9,
                r'C:\Users\Hery\Downloads\Miarina\Marée haute.mp3',
                size: 6 << 20,
                kbps: 192,
              ),
            ],
          ),
          DuplicateSet(
            isVideo: false,
            title: 'Kabary',
            versions: [
              version(11, r'D:\Musique\Toky\Kabary.m4a', size: 7 << 20),
              version(12, r'C:\Music\kabary.mp3', size: 4 << 20),
              version(13, r'C:\Music\kabary (1).mp3', size: 3 << 20),
            ],
          ),
        ],
      );
      await pumpApp(tester, start: Routes.duplicates);
      expect(find.text('Doublons'), findsWidgets);
      expect(
        find.text(
          '2 groupes · 13 Mo récupérables · même titre, même artiste, '
          'même durée',
        ),
        findsOneWidget,
      );
      expect(find.text('FLAC'), findsOneWidget);
      expect(find.text('MP3 192 kb/s'), findsOneWidget);
      expect(find.text('Garder'), findsNWidgets(2));

      // The user prefers the MP3 of the first title.
      // The file name stays whole; the folder part is the one cut.
      expect(find.text(r'C:\Users\Hery\Downloads\Miarina\'), findsOneWidget);
      await tester.tap(find.text('Marée haute.mp3'));
      await settle(tester);
      expect(find.textContaining('65 Mo récupérables'), findsOneWidget);

      await tester.tap(find.text('Masquer les 3 doublons'));
      await settle(tester);
      expect(health.setAsides, [
        (9, 5, false),
        (11, 12, false),
        (11, 13, false),
      ]);
      expect(find.text('Aucun doublon'), findsOneWidget);
    });

    testWidgets('a duplicate goes to the Recycle Bin only when asked', (
      tester,
    ) async {
      health = FakeHealthApi(
        duplicates: [
          DuplicateSet(
            isVideo: false,
            title: 'Kabary',
            versions: [
              version(11, r'D:\Musique\Toky\Kabary.m4a', size: 7 << 20),
              version(12, r'C:\Music\kabary.mp3', size: 4 << 20),
            ],
          ),
        ],
      );
      await pumpApp(tester, start: Routes.duplicates);
      await tester.tap(find.bySemanticsLabel('Mettre à la Corbeille…'));
      await settle(tester);
      expect(find.text('Mettre ce fichier à la Corbeille ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(health.setAsides, isEmpty);

      await tester.tap(find.bySemanticsLabel('Mettre à la Corbeille…'));
      await settle(tester);
      await tester.tap(find.text('Mettre à la Corbeille'));
      await settle(tester);
      expect(health.setAsides, [(11, 12, true)]);
    });

    testWidgets('screens refresh after the launch scan, even a quick one', (
      tester,
    ) async {
      health = FakeHealthApi();
      indexer = FakeIndexerApi(files: {r'D:\Musique': 4});
      settings.values[LibraryFoldersController.key] = [
        const WatchedFolder(r'D:\Musique', FolderKind.music).toJson(),
      ];
      await pumpApp(tester, start: Routes.tracks);
      final before = health.countReads;
      // The scan was done before the first poll: it is still noticed.
      await tester.pump(const Duration(milliseconds: 2100));
      await settle(tester);
      expect(indexer.scanned, isNotEmpty);
      expect(health.countReads, greaterThan(before));
    });

    testWidgets('a missing file is skipped with « introuvable, suivant »', (
      tester,
    ) async {
      health = FakeHealthApi(absent: {1});
      await pumpApp(
        tester,
        start: Routes.tracks,
        items: [track(1, 'Seuil'), track(2, 'Fin')],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      await container.read(queueProvider.notifier).playAll([
        for (final i in [track(1, 'Seuil'), track(2, 'Fin')]) queueEntryOf(i),
      ]);
      await settle(tester);
      expect(health.checked, [1, 2]);
      expect(engine.opened.single.uri.path, endsWith('Fin.flac'));
      expect(
        find.text('« Seuil » est introuvable, titre suivant'),
        findsOneWidget,
      );
      expect(find.text('Localiser'), findsOneWidget);

      pickedFile = r'D:\Musique\Seuil.flac';
      await tester.tap(find.text('Localiser'));
      await settle(tester);
      expect(health.relocated, [(1, r'D:\Musique\Seuil.flac')]);
    });
  });
}

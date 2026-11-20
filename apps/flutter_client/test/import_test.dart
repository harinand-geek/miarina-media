import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/import/welcome_screen.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/indexer.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  const music = r'D:\Musique';
  const lessons = r'E:\Cours\Licence 3';

  test('folders keep their type through the settings', () {
    const f = WatchedFolder(lessons, FolderKind.focus);
    expect(WatchedFolder.fromJson(f.toJson()), f);
    expect(WatchedFolder.fromJson({'path': 3}), isNull);
  });

  test('progress counts what the worker can do', () {
    IndexStatus s({required bool ffmpeg}) => IndexStatus(
      total: BigInt.from(100),
      toTag: BigInt.from(10),
      toProbe: BigInt.from(40),
      unreadable: BigInt.zero,
      audio: BigInt.from(90),
      video: BigInt.from(10),
      albums: BigInt.from(5),
      hasFfmpeg: ffmpeg,
    );
    // Without FFmpeg, only tags are read: done once tags are.
    expect(scanCounts(s(ffmpeg: false)), (90, 100));
    expect(scanCounts(s(ffmpeg: true)), (60, 100));
  });

  group('in the app', () {
    late FakeSettingsStore settings;
    late FakeIndexerApi indexer;

    Future<void> pumpApp(WidgetTester tester, {required String start}) async {
      tester.view.physicalSize = const Size(1280, 860);
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
            indexerApiProvider.overrideWithValue(indexer),
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
      settings = FakeSettingsStore();
      indexer = FakeIndexerApi(files: {music: 12, lessons: 3});
    });

    testWidgets('W-O1: language, typed folders, scan, then listen', (
      tester,
    ) async {
      settings.values[LibraryFoldersController.key] = [
        const WatchedFolder(music, FolderKind.music).toJson(),
        const WatchedFolder(lessons, FolderKind.music).toJson(),
      ];
      await pumpApp(tester, start: Routes.welcome);
      // No sidebar, no search on the first launch.
      expect(find.text('Albums'), findsNothing);
      expect(
        find.text('Votre musique, vos films et vos cours, au même endroit.'),
        findsOneWidget,
      );

      await tester.tap(find.text('English'));
      await settle(tester);
      expect(find.text('Language and appearance'), findsWidgets);
      await tester.tap(find.text('Français'));
      await settle(tester);

      await tester.tap(find.text('Continuer'));
      await settle(tester);
      expect(find.text('Où sont vos fichiers ?'), findsOneWidget);
      expect(find.text(music), findsOneWidget);
      expect(find.text('12 fichiers audio ou vidéo'), findsOneWidget);
      expect(find.text('2 dossiers · environ 15 fichiers'), findsOneWidget);

      // The course recordings are typed Focus.
      await tester.tap(find.text('Focus').last);
      await settle(tester);
      expect(indexer.focusFolders, [lessons]);

      await tester.tap(find.text('Analyser'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(indexer.scanned.last, [music, lessons]);
      expect(find.text('Analyse de votre bibliothèque'), findsOneWidget);
      expect(find.text('15 fichiers sur environ 15'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget);

      await tester.tap(find.text('Commencer à écouter'));
      await settle(tester);
      expect(settings.values[OnboardingController.key], isTrue);
      expect(find.text('Albums'), findsOneWidget, reason: 'back in the app');
    });

    testWidgets('every step can be skipped', (tester) async {
      await pumpApp(tester, start: Routes.welcome);
      await tester.tap(find.text('Passer'));
      await settle(tester);
      expect(settings.values[OnboardingController.key], isTrue);
    });

    testWidgets('followed folders are scanned again at launch', (tester) async {
      settings.values['onboardingDone'] = true;
      settings.values[LibraryFoldersController.key] = [
        const WatchedFolder(lessons, FolderKind.focus).toJson(),
      ];
      await pumpApp(tester, start: Routes.tracks);
      expect(indexer.scanned, [
        [lessons],
      ]);
      expect(indexer.focusFolders, [lessons]);
    });

    testWidgets('Settings › Bibliothèque: folders, scan now, progress', (
      tester,
    ) async {
      settings.values['onboardingDone'] = true;
      settings.values[LibraryFoldersController.key] = [
        const WatchedFolder(music, FolderKind.music).toJson(),
      ];
      await pumpApp(tester, start: '${Routes.settings}/library');
      expect(find.text('DOSSIERS SUIVIS'), findsOneWidget);
      expect(find.text(music), findsOneWidget);
      final before = indexer.scanned.length;
      await tester.tap(find.text('Analyser maintenant'));
      await settle(tester);
      expect(indexer.scanned.length, before + 1);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.textContaining('fichiers sur environ'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Retirer ce dossier')));
      await settle(tester);
      expect(settings.values[LibraryFoldersController.key], isEmpty);
    });
  });
}

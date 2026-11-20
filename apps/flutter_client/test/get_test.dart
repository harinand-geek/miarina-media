import 'dart:async';

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

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

FormatOffer offer(
  String id,
  String quality, {
  String detail = 'MP4 · H.264 · 24 fps',
  int? size,
  String ext = 'mp4',
  String? tag,
}) => FormatOffer(
  id: id,
  quality: quality,
  detail: detail,
  sizeBytes: size == null ? null : BigInt.from(size),
  extension_: ext,
  tag: tag,
);

const mb = 1024 * 1024;

Analysis ready() => Analysis(
  status: AnalysisStatus.ready,
  info: MediaInfo(
    url: 'https://www.youtube.com/watch?v=R6MlUcmOul8',
    host: 'youtube.com',
    engine: 'ytdlp',
    title: 'Tears of Steel',
    publisher: 'Blender Foundation',
    source: 'Youtube',
    durationSecs: 734,
    license: 'CC BY 3.0',
    supportsResume: false,
    needsFfmpeg: false,
    video: [
      offer(
        'v:2160',
        '2160p · 4K',
        detail: 'WebM · VP9 · 24 fps',
        size: 1146 * mb,
        ext: 'webm',
        tag: 'Best quality',
      ),
      offer('v:1080', '1080p', size: 372 * mb, tag: 'Recommended'),
      offer('v:720', '720p', size: 198 * mb),
    ],
    audio: [
      offer(
        'a:320',
        'MP3 320 kbps',
        detail: 'MP3 · 320 kbps',
        size: 28 * mb,
        ext: 'mp3',
      ),
    ],
  ),
  code: '',
  detail: '',
  tools: const [],
);

void main() {
  test('sizes, speeds and the default format as in the Tauri app', () {
    expect(formatBytes(765 * mb, lang: 'fr'), '765 Mo');
    expect(formatBytes((1.12 * 1024 * mb).round(), lang: 'fr'), '1,12 Go');
    expect(formatBytes(1146 * mb, lang: 'en'), '1.12 GB');
    expect(formatSpeed(10.3 * mb, lang: 'fr'), '10,3 Mo/s');
    expect(etaLabel(38), '0:38');
    expect(etaLabel(3725), '1:02:05');
    final info = ready().info!;
    expect(defaultFormat(info.video)!.id, 'v:1080');
    expect(defaultFormat([offer('a', '1440p'), offer('b', '720p')])!.id, 'b');
    expect(downloadTitle(info, info.video[1]), 'Tears of Steel (1080p)');
  });

  group('in the app', () {
    late FakeGetApi get;
    late FakeSettingsStore settings;
    String? picked;

    Future<ProviderContainer> pumpApp(WidgetTester tester, String start) async {
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
            downloadFolderPickerProvider.overrideWithValue(() async => picked),
            revealProvider.overrideWithValue((_, {select = false}) async {}),
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
      return ProviderScope.containerOf(tester.element(find.byType(MiarinaApp)));
    }

    setUp(() {
      get = FakeGetApi(analysis: ready());
      settings = FakeSettingsStore()..values['onboardingDone'] = true;
      picked = null;
    });

    testWidgets('home: the link is checked, fixed, then analyzed', (
      tester,
    ) async {
      await pumpApp(tester, Routes.get);
      expect(find.text('Du lien à votre bibliothèque'), findsOneWidget);
      // The Obtenir sidebar, as in the Tauri app.
      for (final entry in [
        'Accueil',
        'Téléchargements',
        'Navigateur',
        'Torrents',
        'Historique',
      ]) {
        expect(find.text(entry), findsWidgets);
      }
      expect(find.text('Aucun téléchargement'), findsOneWidget);
      expect(find.text('PRÉVU'), findsNWidgets(2));

      await tester.tap(find.text('Analyser'));
      await settle(tester);
      expect(find.text('Collez un lien à analyser.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('get-link')),
        'youtube.com/watch?v=R6MlUcmOul8',
      );
      await tester.tap(find.text('Analyser'));
      await settle(tester);
      expect(find.text('Il manque « https:// » à ce lien.'), findsOneWidget);
      await tester.tap(find.text('Ajouter https://'));
      await settle(tester);
      expect(get.analyzed, ['https://youtube.com/watch?v=R6MlUcmOul8']);
      expect(find.text('Tears of Steel'), findsOneWidget);
    });

    testWidgets('analysis: formats, queue, then download now', (tester) async {
      await pumpApp(
        tester,
        Uri(
          path: Routes.getAnalysis,
          queryParameters: {
            'url': 'https://www.youtube.com/watch?v=R6MlUcmOul8',
          },
        ).toString(),
      );
      expect(find.text('Tears of Steel'), findsOneWidget);
      expect(
        find.text('youtube.com · Blender Foundation · CC BY 3.0'),
        findsOneWidget,
      );
      expect(find.text('Jusqu’à 4K'), findsOneWidget);
      expect(find.text('Recommandé'), findsOneWidget);
      expect(find.text('Meilleure qualité'), findsOneWidget);
      expect(find.text('12:14'), findsOneWidget);
      expect(find.text(r'C:\Users\Hery\Downloads\Miarina'), findsOneWidget);
      // 1080p is preselected: the button says its size.
      expect(find.text('Télécharger · 372 Mo'), findsOneWidget);

      await tester.tap(find.text('720p'));
      await settle(tester);
      await tester.tap(find.text('Ajouter à la file'));
      await settle(tester);
      expect(get.started.single.startNow, isFalse);
      expect(get.started.single.formatId, 'v:720');
      expect(get.started.single.title, 'Tears of Steel (720p)');
      expect(find.text('Ajouté à la file · 720p'), findsOneWidget);

      // Another folder for the next downloads.
      picked = r'D:\Médias';
      await tester.tap(find.text('Changer'));
      await settle(tester);
      expect(get.dir, r'D:\Médias');
      expect(find.text(r'D:\Médias'), findsOneWidget);

      // Audio only: MP3, then downloaded right away.
      await tester.tap(find.text('Audio seul'));
      await settle(tester);
      await tester.tap(find.text('Télécharger · 28 Mo'));
      await settle(tester);
      expect(get.started.last.startNow, isTrue);
      expect(get.started.last.isAudio, isTrue);
      expect(get.started.last.extension_, 'mp3');
      expect(
        find.textContaining('En cours ·'),
        findsOneWidget,
        reason: 'on Downloads',
      );
    });

    testWidgets('analysis: no media and the media tools', (tester) async {
      get.analysis = Analysis(
        status: AnalysisStatus.noMedia,
        code: 'network',
        detail: '',
        tools: const [],
      );
      await pumpApp(
        tester,
        Uri(
          path: Routes.getAnalysis,
          queryParameters: {'url': 'https://example.org/page'},
        ).toString(),
      );
      expect(find.text('Aucun média téléchargeable trouvé'), findsOneWidget);
      expect(
        find.text(
          'Raison : le site n’a pas pu être joint ; vérifiez le lien et votre connexion',
        ),
        findsOneWidget,
      );

      get.analysis = Analysis(
        status: AnalysisStatus.needsTools,
        code: '',
        detail: '',
        tools: [
          ToolStatus(
            name: 'yt-dlp',
            version: '2026.10.01',
            license: 'Unlicense',
            downloadBytes: BigInt.from(18 * mb),
            installed: false,
          ),
        ],
      );
      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.text('Cette page a besoin des outils média'), findsOneWidget);
      get.analysis = ready();
      await tester.tap(find.text('Télécharger les outils · 18 Mo'));
      await settle(tester);
      expect(get.installs, 1);
      expect(
        find.text('Tears of Steel'),
        findsOneWidget,
        reason: 'analyzed again',
      );
    });

    testWidgets('an analysis opened at launch waits for the manager', (
      tester,
    ) async {
      get.startGate = Completer<void>();
      final url = Uri(
        path: Routes.getAnalysis,
        queryParameters: {'url': 'https://example.org/v.mp4'},
      ).toString();
      await pumpApp(tester, url);
      expect(get.analyzed, isEmpty);
      expect(find.text('Préparation de votre fichier'), findsOneWidget);
      get.startGate!.complete();
      await settle(tester);
      expect(get.analyzed, ['https://example.org/v.mp4']);
      expect(find.text('Tears of Steel'), findsOneWidget);
    });

    testWidgets('an unexpected failure shows no technical text', (
      tester,
    ) async {
      get.analysisError = Exception('AnyhowException(boom) Stack backtrace');
      await pumpApp(
        tester,
        Uri(
          path: Routes.getAnalysis,
          queryParameters: {'url': 'https://example.org/v.mp4'},
        ).toString(),
      );
      expect(find.text('Aucun média téléchargeable trouvé'), findsOneWidget);
      expect(find.textContaining('Anyhow'), findsNothing);
      expect(find.textContaining('backtrace'), findsNothing);
    });

    testWidgets('downloads: live progress, actions, lists', (tester) async {
      get.tasks_ = [
        taskInfo('a', 'Tears of Steel', total: 1146 * mb, downloaded: 0),
        taskInfo(
          'b',
          'Clair de Lune',
          state: 'queued',
          position: 1,
          audio: true,
          format: 'FLAC',
        ),
      ];
      get.history_ = [
        HistoryInfo(
          id: 1,
          taskId: 'old',
          url: 'https://example.org/old',
          title: 'Big Buck Bunny',
          sourceHost: 'example.org',
          formatLabel: 'MP4 · 1080p',
          doneBytes: BigInt.from(356 * mb),
          completed: true,
          finishedAt: 0,
        ),
      ];
      await pumpApp(tester, Routes.getDownloads);
      get.events_.add(
        GetEvent(
          kind: GetEventKind.progress,
          id: 'a',
          downloaded: BigInt.from(765 * mb),
          total: BigInt.from(1146 * mb),
          bytesPerSec: 10.3 * mb,
          etaSecs: BigInt.from(38),
          supportsResume: true,
          retryInSecs: BigInt.zero,
          offline: false,
        ),
      );
      await settle(tester);
      expect(
        find.text(
          '1 en cours · 10,3 Mo/s · reprise automatique si la source l’accepte',
        ),
        findsOneWidget,
      );
      expect(find.text('Téléchargement'), findsOneWidget);
      expect(find.text('765 Mo / 1,12 Go · 10,3 Mo/s · 0:38'), findsOneWidget);
      expect(find.text('66%'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      // Sidebar: open downloads and the card.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1 en cours'), findsOneWidget);
      expect(find.text('1 en attente'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Mettre en pause Tears of Steel'));
      await tester.tap(
        find.bySemanticsLabel('Démarrer Clair de Lune maintenant'),
      );
      await settle(tester);
      expect(get.actions, [('a', 'pause'), ('b', 'start_now')]);

      // Cancelling asks first.
      await tester.tap(find.bySemanticsLabel('Annuler Clair de Lune'));
      await settle(tester);
      expect(find.text('Annuler le téléchargement ?'), findsOneWidget);
      await tester.tap(find.text('Annuler le téléchargement'));
      await settle(tester);
      expect(get.actions.last, ('b', 'cancel'));
      get.events_.add(getEvent(GetEventKind.removed, id: 'b'));
      await settle(tester);
      expect(find.text('Clair de Lune'), findsNothing);

      await tester.tap(find.text('Tout mettre en pause'));
      await settle(tester);
      expect(get.pauses, [true]);

      await tester.tap(find.text('Terminés · 1'));
      await settle(tester);
      expect(find.text('Big Buck Bunny'), findsOneWidget);
      expect(find.text('Terminé'), findsOneWidget);
    });
  });
}

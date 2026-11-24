import 'dart:async';

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
  playlist: null,
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
      // Every quick action works (Playlist, Plusieurs liens).
      expect(find.text('PRÉVU'), findsNothing);

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
        playlist: null,
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
        playlist: null,
        status: AnalysisStatus.needsTools,
        code: '',
        detail: '',
        tools: [
          ToolStatus(
            id: 'yt_dlp',
            bundled: false,
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

    testWidgets('the queue is reordered with Alt + arrows or by dragging', (
      tester,
    ) async {
      get.tasks_ = [
        taskInfo('a', 'Tears of Steel', total: 100 * mb),
        taskInfo('c', 'Charge', state: 'queued', position: 1),
        taskInfo('d', 'Spring', state: 'queued', position: 2),
        taskInfo('e', 'Clair de Lune', state: 'queued', position: 3),
      ];
      await pumpApp(tester, Routes.getDownloads);
      // Only waiting rows have a handle.
      expect(find.byTooltip(RegExp('^Réordonner Tears')), findsNothing);

      // Charge one place down: to Spring's place among open tasks.
      // The handle is the thumbnail (its tooltip names it).
      Finder handle(String title) => find.byTooltip(
        'Réordonner $title (Alt + flèches haut et bas, ou glisser)',
      );
      await tester.tap(handle('Charge'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(get.moves, [('c', 2)]);

      // The first waiting row cannot go above the queue.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(get.moves, [('c', 2)], reason: 'already first: no move');

      // Clair de Lune dragged onto Charge.
      final from = tester.getCenter(handle('Clair de Lune'));
      final to = tester.getCenter(find.text('Charge'));
      await tester.dragFrom(from, to - from);
      await settle(tester);
      expect(get.moves.last, ('e', 1));
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
          canceled: false,
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
    HistoryInfo entry(
      int id,
      String title, {
      required DateTime at,
      bool completed = true,
      bool canceled = false,
      String? reason,
      String format = 'MP4 · 1080p',
    }) => HistoryInfo(
      id: id,
      taskId: 't$id',
      url: 'https://example.org/$id',
      title: title,
      sourceHost: 'example.org',
      formatLabel: format,
      totalBytes: BigInt.from(356 * mb),
      doneBytes: BigInt.from(356 * mb),
      completed: completed,
      canceled: canceled,
      reason: reason,
      finishedAt: at.millisecondsSinceEpoch,
    );

    testWidgets('history: by day, menu, clearing keeps the files', (
      tester,
    ) async {
      final now = DateTime.now();
      get.history_ = [
        entry(1, 'Big Buck Bunny', at: now),
        entry(
          2,
          'Live stream',
          at: now,
          completed: false,
          reason: 'the disk is full',
        ),
        entry(
          3,
          'Elephants Dream',
          at: now.subtract(const Duration(days: 1)),
          completed: false,
          canceled: true,
        ),
      ];
      await pumpApp(tester, Routes.getHistory);
      expect(find.text('AUJOURD’HUI'), findsOneWidget);
      expect(find.text('HIER'), findsOneWidget);
      expect(find.text('MP4 · 1080p · 356 Mo · example.org'), findsOneWidget);
      expect(find.text('Échec · Disque plein'), findsOneWidget);
      expect(find.text('Annulé · example.org'), findsOneWidget);
      expect(
        find.text('Effacer l’historique ne supprime aucun fichier.'),
        findsOneWidget,
      );

      // The cancelled one is analyzed again from its link.
      await tester.tap(find.byTooltip('Actions pour Elephants Dream'));
      await settle(tester);
      await tester.tap(find.text('Réessayer').last);
      await settle(tester);
      expect(get.analyzed, ['https://example.org/3']);

      await tester.tap(find.text('Historique').first);
      await settle(tester);
      await tester.tap(find.text('Effacer l’historique'));
      await settle(tester);
      expect(
        find.text('Effacer l’historique des téléchargements ?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Effacer l’historique').last);
      await settle(tester);
      expect(get.cleared, 1);
      expect(
        find.text(
          'Les téléchargements terminés, échoués ou annulés apparaissent ici.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('settings: folder, simultaneous, resource mode, tools', (
      tester,
    ) async {
      get.tools_ = [
        ToolStatus(
          id: 'yt_dlp',
          name: 'yt-dlp',
          version: '2026.08.19',
          license: 'Unlicense',
          downloadBytes: BigInt.from(17 * mb),
          installed: true,
          bundled: true,
        ),
        ToolStatus(
          id: 'ffmpeg',
          name: 'FFmpeg',
          version: '8.0',
          license: 'GPL-3.0',
          downloadBytes: BigInt.from(90 * mb),
          installed: false,
          bundled: false,
        ),
      ];
      await pumpApp(tester, '${Routes.settings}/downloads');
      expect(find.text(r'C:\Users\Hery\Downloads\Miarina'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel('Téléchargements simultanés · Plus'),
      );
      await settle(tester);
      expect(get.concurrency, 4);
      expect(find.text('4'), findsOneWidget);

      // Eco changes the real limits, and says so.
      await tester.tap(find.text('Éco'));
      await settle(tester);
      expect(get.mode, 'eco');
      expect(
        find.text(
          '1 téléchargement(s) simultané(s), 1 conversion(s) à la fois.',
        ),
        findsOneWidget,
      );

      expect(find.text('Inclus · vérifié'), findsOneWidget);
      expect(find.text('8.0 · GPL-3.0 · 90 Mo à télécharger'), findsOneWidget);
      await tester.tap(find.text('Rechercher une mise à jour'));
      await settle(tester);
      expect(get.updates, 1);
      expect(find.text('yt-dlp est à jour (2026.08.19)'), findsOneWidget);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/design/theme.dart';
import 'package:miarina_media/design/tokens.dart';
import 'package:miarina_media/design/widgets/states.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/common/state_views.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
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

/// A library whose database does not open.
class BrokenLibraryApi extends FakeLibraryApi {
  BrokenLibraryApi(this.message) : super(const []);

  final String message;
  int calls = 0;

  @override
  Future<LibraryPage> tracks({
    required String search,
    required bool favoritesOnly,
    required int offset,
    required int limit,
    String? album,
    String? artist,
    bool recent = false,
  }) async {
    calls++;
    throw Exception(message);
  }
}

void main() {
  group('rules', () {
    test('engine messages are sorted into the W-E3 cases', () {
      expect(
        classifyPlayback('Failed to recognize file format.'),
        PlaybackProblem.format,
      );
      expect(
        classifyPlayback('No decoder for codec ac3'),
        PlaybackProblem.format,
      );
      expect(
        classifyPlayback('demux error: invalid data found'),
        PlaybackProblem.damaged,
      );
      expect(classifyPlayback('Access is denied'), PlaybackProblem.access);
      expect(
        classifyPlayback('No such file or directory'),
        PlaybackProblem.missing,
      );
      expect(classifyPlayback('???'), PlaybackProblem.other);
    });
  });

  group('skeletons (W-E2)', () {
    Widget host(Widget child, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: MaterialApp(
        theme: buildMmTheme(MmColors.dark),
        home: Scaffold(body: child),
      ),
    );

    testWidgets('nothing before 300 ms, the shapes after', (tester) async {
      await tester.pumpWidget(host(const SkeletonList(rows: 3)));
      expect(find.byType(SkeletonBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SkeletonBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(tester.hasRunningAnimations, isTrue, reason: 'pulse');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: no pulse', (tester) async {
      await tester.pumpWidget(host(const SkeletonList(rows: 3), reduced: true));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('in the app', () {
    late FakeEngine engine;

    Future<void> pumpApp(
      WidgetTester tester, {
      required String start,
      required LibraryApi library,
    }) async {
      tester.view.physicalSize = const Size(1280, 860);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(engine),
            libraryApiProvider.overrideWithValue(library),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(FakeSettingsStore()),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(start),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
    }

    setUp(() => engine = FakeEngine());

    testWidgets('W-E1: an empty library says what to do and what is read', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.tracks, library: FakeLibraryApi([]));
      expect(find.text('Ouvrir des fichiers…'), findsOneWidget);
      expect(find.textContaining('MP3, M4A, FLAC'), findsOneWidget);
      expect(
        find.text(
          'Vous téléchargez avec Miarina ? Les fichiers obtenus arrivent ici '
          'automatiquement.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('W-E3: a library that does not open, then a broken one', (
      tester,
    ) async {
      final broken = BrokenLibraryApi('database is locked');
      await pumpApp(tester, start: Routes.tracks, library: broken);
      expect(find.text("La bibliothèque ne s'ouvre pas"), findsOneWidget);
      expect(find.textContaining('database is locked'), findsOneWidget);
      expect(find.text('Copier les détails'), findsOneWidget);
      final before = broken.calls;
      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(broken.calls, greaterThan(before));
    });

    testWidgets('a malformed index is a library to repair', (tester) async {
      await pumpApp(
        tester,
        start: Routes.tracks,
        library: BrokenLibraryApi('database disk image is malformed'),
      );
      expect(find.text('Bibliothèque à réparer'), findsOneWidget);
    });

    testWidgets('W-E3 in the players: what happened, skip to the next', (
      tester,
    ) async {
      final a = track(1, 'Ancien rip');
      final b = track(2, 'Suivant');
      await pumpApp(tester, start: Routes.now, library: FakeLibraryApi([a, b]));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiarinaApp)),
      );
      await container.read(queueProvider.notifier).playAll([
        queueEntryOf(a),
        queueEntryOf(b),
      ]);
      engine.emit(
        engine.current.copyWith(
          status: PlaybackStatus.error,
          error: const PlaybackError(
            'Failed to recognize file format.',
            recoverable: false,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Format non pris en charge'), findsOneWidget);
      expect(
        find.textContaining("Le fichier n'est pas modifié"),
        findsOneWidget,
      );
      await tester.tap(find.text('Passer au suivant'));
      await settle(tester);
      expect(engine.opened.last.uri, Uri.file(b.path));
      expect(find.text('Format non pris en charge'), findsNothing);
    });
  });
}

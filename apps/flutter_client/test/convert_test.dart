import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/convert/convert_data.dart';
import 'package:miarina_media/features/convert/convert_screen.dart';
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

// Outils PC › Convertir.

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class FakeConvertApi implements ConvertApi {
  final added = <(String, String, List<String>, ConvertOptions)>[];
  final _events = StreamController<ConvertJob>.broadcast();
  var jobs_ = <ConvertJob>[];
  bool? startedMulti;
  var stops = 0;
  final removed = <String>[];

  ConvertJob job(String id, String name, String state, {double pct = 0}) =>
      ConvertJob(
        id: id,
        inputs: ['C:\\in\\$name'],
        name: name,
        category: 'video',
        target: 'mp4',
        source: SourceInfo(
          size: BigInt.from(96783155),
          width: 1280,
          height: 720,
          kbps: 417,
          durationSecs: 1811,
          totalSecs: 1811,
        ),
        state: state,
        percent: pct,
        outPath: state == 'done' ? 'C:\\out\\$name.mp4' : null,
        outSize: state == 'done' ? BigInt.from(52 * 1024 * 1024) : null,
        error: null,
      );

  void emit(ConvertJob j) {
    jobs_ = [for (final x in jobs_) x.id == j.id ? j : x];
    _events.add(j);
  }

  @override
  Future<List<ConvertJob>> add(
    String category,
    String target,
    List<String> inputs,
    ConvertOptions options,
  ) async {
    added.add((category, target, inputs, options));
    final made = [
      for (final i in inputs)
        job(
          'j${jobs_.length}-${i.split('\\').last}',
          i.split('\\').last,
          'waiting',
        ),
    ];
    jobs_ = [...jobs_, ...made];
    return made;
  }

  @override
  Future<List<ConvertJob>> jobs() async => jobs_;

  @override
  Future<void> start({required bool multi}) async => startedMulti = multi;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Future<void> clear() async => jobs_ = [];

  @override
  Stream<ConvertJob> events() => _events.stream;

  @override
  String defaultDir() => r'C:\Users\Hery\Videos\Miarina\Converti';
}

void main() {
  late FakeConvertApi api;
  late StreamController<List<String>> drops;

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
          libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
          getApiProvider.overrideWithValue(FakeGetApi()),
          convertApiProvider.overrideWithValue(api),
          convertFilePickerProvider.overrideWithValue(
            (_, _) async => [r'C:\in\Film.mkv', r'C:\in\Clip.mp4'],
          ),
          droppedFilesProvider.overrideWith((_) => drops.stream),
          desktopShellProvider.overrideWithValue(true),
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore()..values['onboardingDone'] = true,
          ),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(Routes.convert),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    api = FakeConvertApi();
    drops = StreamController<List<String>>.broadcast();
  });
  tearDown(() => drops.close());

  testWidgets('a format: files, options, queue, start, done', (tester) async {
    await pumpApp(tester);
    expect(find.text('Outils PC'.toUpperCase()), findsOneWidget);
    expect(find.text('La liste est vide'), findsOneWidget);
    expect(find.text(r'C:\Users\Hery\Videos\Miarina\Converti'), findsOneWidget);

    await tester.tap(find.text('→ MP4'));
    await settle(tester);
    expect(find.text('Convertir en MP4'), findsOneWidget);
    await tester.tap(find.text('Ajouter des fichiers'));
    await settle(tester);
    expect(find.text('Film.mkv'), findsOneWidget);
    await tester.tap(find.text('Moyenne'));
    await tester.tap(find.text('720p'));
    await settle(tester);
    await tester.tap(find.text('Ajouter à la liste (2)'));
    await settle(tester);

    final (cat, target, inputs, o) = api.added.single;
    expect((cat, target), ('video', 'mp4'));
    expect(inputs, [r'C:\in\Film.mkv', r'C:\in\Clip.mp4']);
    expect((o.quality, o.height), ('medium', 720));
    expect(o.outDir, r'C:\Users\Hery\Videos\Miarina\Converti');
    expect(
      find.textContaining('1280 × 720 · 417 kbit/s · 00:30:11'),
      findsNWidgets(2),
    );
    expect(find.text('En attente'), findsNWidgets(2));

    await tester.tap(find.text('Démarrer'));
    await settle(tester);
    expect(api.startedMulti, isTrue);
    expect(find.text('Arrêter'), findsOneWidget);
    final first = api.jobs_.first;
    api.emit(api.job(first.id, first.name, 'converting', pct: 62));
    await settle(tester);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('Conversion…'), findsOneWidget);
    for (final j in List.of(api.jobs_)) {
      api.emit(api.job(j.id, j.name, 'done'));
    }
    await settle(tester);
    expect(find.text('Terminé'), findsNWidgets(2));
    expect(find.text('Conversion terminée'), findsOneWidget);
    expect(find.text('Démarrer'), findsOneWidget);

    // Remove the selected one; clear the list.
    await tester.tap(find.text('Film.mkv'));
    await settle(tester);
    await tester.tap(find.text('Retirer'));
    await settle(tester);
    expect(api.removed, [first.id]);
    await tester.tap(find.text('Vider la liste'));
    await settle(tester);
    expect(find.text('La liste est vide'), findsOneWidget);
  });

  testWidgets('Compresser: AV1 by quality, a size aimed at, H.264; 3GP', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('→ 3GP'), findsOneWidget);

    await tester.tap(find.text('Compresser').first);
    await settle(tester);
    expect(find.text('AV1'), findsOneWidget);
    await tester.tap(find.text('Ajouter des fichiers'));
    await settle(tester);
    await tester.tap(find.text('Ajouter à la liste (2)'));
    await settle(tester);
    var (_, target, _, o) = api.added.last;
    expect(
      (target, o.codec, o.quality, o.targetMb),
      ('compress', 'av1', 'medium', 0),
    );

    await tester.tap(find.text('Compresser').first);
    await settle(tester);
    await tester.tap(find.text('Ajouter des fichiers'));
    await settle(tester);
    await tester.tap(find.text('Taille maximale'));
    await tester.tap(find.text('H.264'));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('compress-size')), '200');
    await tester.tap(find.text('Ajouter à la liste (2)'));
    await settle(tester);
    (_, target, _, o) = api.added.last;
    expect((o.codec, o.targetMb), ('h264', 200));

    await tester.tap(find.text('→ 3GP'));
    await settle(tester);
    expect(find.text('144p'), findsOneWidget, reason: 'small phones');
  });

  testWidgets('a tool with its options; dropped files take the last choice', (
    tester,
  ) async {
    await pumpApp(tester);
    // Nothing chosen yet: dropped files are not taken.
    drops.add([r'C:\in\a.mp4']);
    await settle(tester);
    expect(api.added, isEmpty);
    expect(
      find.text('Choisissez d’abord un format ou un outil à gauche.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Découper').first);
    await settle(tester);
    await tester.tap(find.text('Ajouter des fichiers'));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('cut-from')), '00:00:05');
    await tester.enterText(find.byKey(const ValueKey('cut-to')), '00:00:20');
    await tester.tap(find.text('Ajouter à la liste (2)'));
    await settle(tester);
    final (_, target, _, o) = api.added.single;
    expect(target, 'cut');
    expect((o.fromMs.toInt(), o.toMs.toInt()), (5000, 20000));

    drops.add([r'C:\in\b.mp4', r'C:\in\notes.txt']);
    await settle(tester);
    expect(api.added.last.$3, [r'C:\in\b.mp4'], reason: 'videos only');
    expect(api.added.last.$2, 'cut');
  });
}

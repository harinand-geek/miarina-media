// Social media screenshots of the Windows tools (Convertir, conversion
// running, Compresser, Enregistrer l'écran, Capture d'écran): the real
// screens with the tests' fake services and fictional file names.
//
//   $env:MM_SOCIAL = "<folder>"; flutter test test/tool/pc_tools_shots_test.dart
//
// Skipped when MM_SOCIAL is not set. The capture shot draws the zone over
// `<folder>/pc-1-accueil.png` (social_shots_test.dart) when it exists.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ScaffoldMessenger;
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/capture/capture_data.dart';
import 'package:miarina_media/features/capture/screen_tools.dart';
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
import 'package:miarina_media/features/recorder/recorder_data.dart';
import 'package:miarina_media/features/recorder/recorder_screen.dart';

import '../capture_test.dart' show FakeCaptureApi;
import '../convert_test.dart' show FakeConvertApi;
import '../recorder_test.dart' show FakeRecorderApi;
import '../support/fakes.dart';
import '../support/screen_fakes.dart';

final _out = Platform.environment['MM_SOCIAL'];
const _dpr = 1.5;
final _shotKey = GlobalKey();

const _files = [
  r'C:\Videos\Voyage à Nosy Be.mkv',
  r'C:\Videos\Concert Ambalavao.mp4',
  r'C:\Videos\Mariage de Hanta.mov',
  r'C:\Videos\Interview radio.mp4',
];

Future<void> _font(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out/$name.png').writeAsBytes(png!.buffer.asUint8List());
  });
}

/// The tests' fakes with neutral folders (no person's name on screen).
class _Convert extends FakeConvertApi {
  @override
  String defaultDir() => r'C:\Users\Miarina\Videos\Converti';
}

class _Recorder extends FakeRecorderApi {
  @override
  String defaultDir() => r'C:\Users\Miarina\Videos\Enregistrements';
}

class _ShowCapture extends CaptureController {
  void show(CaptureSession s) => state = s;

  @override
  Future<void> finish(Rect zone, {required bool save}) async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  setUpAll(() async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
    await _font('Manrope', 'assets/fonts/Manrope-Variable.ttf');
    await _font('JetBrainsMono', 'assets/fonts/JetBrainsMono-Variable.ttf');
    await _font('PhosphorRegular', 'assets/icons/Phosphor.ttf');
    await _font('PhosphorFill', 'assets/icons/Phosphor-Fill.ttf');
  });

  Future<void> pump(
    WidgetTester tester,
    String route, {
    required FakeConvertApi convert,
    FakeRecorderApi? recorder,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(1440, 900) * _dpr;
    tester.view.devicePixelRatio = _dpr;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final store = FakeSettingsStore()
      ..values['onboardingDone'] = true
      ..values['recorder'] = const RecorderSettings(countdown: false).toJson();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(FakeEngine()),
            libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            indexerApiProvider.overrideWithValue(FakeIndexerApi()),
            healthApiProvider.overrideWithValue(FakeHealthApi()),
            getApiProvider.overrideWithValue(FakeGetApi()),
            convertApiProvider.overrideWithValue(convert),
            convertFilePickerProvider.overrideWithValue((_, _) async => _files),
            droppedFilesProvider.overrideWith((_) => const Stream.empty()),
            screenToolsProvider.overrideWithValue(FakeScreenTools()),
            recorderApiProvider.overrideWithValue(
              recorder ?? FakeRecorderApi(),
            ),
            recorderFolderPickerProvider.overrideWithValue((_) async => null),
            recordingExistsProvider.overrideWithValue((_) => true),
            captureApiProvider.overrideWithValue(
              FakeCaptureApi(r'C:\Users\Miarina\Pictures\Captures'),
            ),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(store),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(route),
            ...extra,
          ],
          child: const MiarinaApp(),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('convert, running, compress', (tester) async {
    final api = _Convert();
    await pump(tester, Routes.convert, convert: api);
    await tester.tap(find.text('→ MP4'));
    await _settle(tester);
    await tester.tap(find.text('Ajouter des fichiers'));
    await _settle(tester);
    await tester.tap(find.text('Moyenne'));
    await tester.tap(find.text('720p'));
    await _settle(tester);
    await _shot(tester, 'pc-6-convertir');

    await tester.tap(find.textContaining('Ajouter à la liste'));
    await _settle(tester);
    await tester.tap(find.text('Démarrer'));
    await _settle(tester);
    final jobs = List.of(api.jobs_);
    api.emit(api.job(jobs[0].id, jobs[0].name, 'done'));
    api.emit(api.job(jobs[1].id, jobs[1].name, 'converting', pct: 62));
    await _settle(tester);
    await _shot(tester, 'pc-7-conversion-en-cours');

    await tester.tap(find.text('Compresser').first);
    await _settle(tester);
    await tester.tap(find.text('Ajouter des fichiers'));
    await _settle(tester);
    await _shot(tester, 'pc-8-compresser');
  }, skip: _out == null);

  testWidgets('recorder', (tester) async {
    final rec = _Recorder();
    await pump(tester, Routes.recorder, convert: _Convert(), recorder: rec);
    await tester.tap(find.bySemanticsLabel('Micro'));
    await tester.tap(find.text('60'));
    await _settle(tester);
    await tester.tap(find.text('Démarrer l’enregistrement'));
    await _settle(tester);
    rec.emit('recording', 252000);
    await _settle(tester);
    await tester.tap(find.text('Arrêter'));
    await _settle(tester);
    // The « saved » message (it waits for « Lire ») leaves before the shot.
    final saved = find.text('Vidéo enregistrée dans la bibliothèque');
    if (saved.evaluate().isNotEmpty) {
      ScaffoldMessenger.of(tester.element(saved)).removeCurrentSnackBar();
    }
    await _settle(tester);
    await _shot(tester, 'pc-9-enregistrer-ecran');
  }, skip: _out == null);

  testWidgets('screen capture', (tester) async {
    final controller = _ShowCapture();
    await pump(
      tester,
      Routes.listenHome,
      convert: _Convert(),
      extra: [captureProvider.overrideWith(() => controller)],
    );
    final background = File('$_out/pc-1-accueil.png');
    final image = (await tester.runAsync(() async {
      if (background.existsSync()) {
        final codec = await ui.instantiateImageCodec(
          await background.readAsBytes(),
        );
        return (await codec.getNextFrame()).image;
      }
      final r = ui.PictureRecorder();
      ui.Canvas(r).drawRect(
        const Rect.fromLTWH(0, 0, 2160, 1350),
        ui.Paint()..color = const Color(0xFF223344),
      );
      return r.endRecording().toImage(2160, 1350);
    }))!;
    controller.show(
      CaptureSession(
        image: image,
        screen: Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    // The resume card and the automatic lists.
    await tester.dragFrom(const Offset(256, 118), const Offset(818, 552));
    await _settle(tester);
    await _shot(tester, 'pc-10-capture-ecran');
  }, skip: _out == null);
}

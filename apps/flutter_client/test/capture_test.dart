import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/capture/capture_data.dart';
import 'package:miarina_media/features/capture/capture_settings.dart';
import 'package:miarina_media/features/capture/screen_tools.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/shortcuts/keymap.dart';

import 'support/fakes.dart';

// Outils PC › Capture d'écran.

class FakeScreenTools implements ScreenTools {
  final registered = <List<Hotkey>>[];
  var refuse = <int>[];
  final _keys = StreamController<int>.broadcast();
  final overlays = <Rect>[];
  var exits = 0;
  final copied = <Uint8List>[];
  var beeps = 0;
  var cursor = false;

  void press(int id) => _keys.add(id);

  @override
  Future<List<int>> registerHotkeys(List<Hotkey> keys) async {
    registered.add(keys);
    return [
      for (final k in keys)
        if (refuse.contains(k.id)) k.id,
    ];
  }

  @override
  Future<Rect?> capture(String path, {required bool cursor}) async {
    this.cursor = cursor;
    return const Rect.fromLTWH(1920, 0, 200, 100);
  }

  @override
  Future<void> enterOverlay(Rect screen) async => overlays.add(screen);

  @override
  Future<bool> exitOverlay() async {
    exits++;
    return true;
  }

  @override
  Future<bool> copyImage(String path) async {
    copied.add(await File(path).readAsBytes());
    return true;
  }

  @override
  Future<void> beep() async => beeps++;

  @override
  Future<bool> excludeFromCapture(bool on) async => true;

  @override
  Stream<int> get hotkeys => _keys.stream;
}

class FakeCaptureApi implements CaptureApi {
  FakeCaptureApi(this.dir);

  final String dir;
  var fail = false;
  final encoded = <(String, String)>[];

  @override
  String defaultDir() => dir;

  @override
  Future<void> encode(String png, String output, String format) async {
    if (fail) throw Exception('encode_failed');
    encoded.add((output, format));
    await File(png).copy(output);
  }
}

/// A 200 × 100 screen: red left half, blue right half.
Uint8List screenBmp() {
  const w = 200, h = 100;
  final rgba = ByteData(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      rgba
        ..setUint8(i, x < 100 ? 255 : 0)
        ..setUint8(i + 2, x < 100 ? 0 : 255)
        ..setUint8(i + 3, 255);
    }
  }
  return bmpFromRgba(w, h, rgba);
}

Future<ui.Image> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  return image;
}

void main() {
  group('settings and keys', () {
    test('defaults, saved and read back', () {
      const s = CaptureSettings();
      expect(
        s.keyOf(CaptureShortcut.region),
        const KeySpec(LogicalKeyboardKey.keyC, alt: true),
      );
      expect(
        (s.format, s.delay, s.copy, s.preview, s.sound, s.cursor),
        ('png', 0, true, true, false, false),
      );
      final changed = s
          .copyWith(format: 'webp', delay: 5, folder: r'D:\Pics', sound: true)
          .withKey(CaptureShortcut.record, null);
      final back = CaptureSettings.fromJson(changed.toJson());
      expect(
        (back.format, back.delay, back.folder, back.sound),
        ('webp', 5, r'D:\Pics', true),
      );
      expect(back.keyOf(CaptureShortcut.record), isNull);
      expect(back.keyOf(CaptureShortcut.full), s.keyOf(CaptureShortcut.full));
      // Unknown values fall back.
      final odd = CaptureSettings.fromJson({'format': 'bmp', 'delay': 7});
      expect((odd.format, odd.delay), ('png', 0));
    });

    test('Windows shortcuts: modifiers and virtual keys', () {
      expect(hotkeyOf(0, const KeySpec(LogicalKeyboardKey.keyC, alt: true)), (
        id: 0,
        mods: 1,
        vk: 0x43,
      ));
      expect(
        hotkeyOf(
          1,
          const KeySpec(LogicalKeyboardKey.keyC, alt: true, shift: true),
        ),
        (id: 1, mods: 5, vk: 0x43),
      );
      expect(hotkeyOf(2, const KeySpec(LogicalKeyboardKey.f9, ctrl: true)), (
        id: 2,
        mods: 2,
        vk: 0x78,
      ));
      expect(
        hotkeyOf(0, const KeySpec(LogicalKeyboardKey.digit5, ctrl: true)),
        (id: 0, mods: 2, vk: 0x35),
      );
      // No modifier, or a key Windows shortcuts do not take here.
      expect(hotkeyOf(0, const KeySpec(LogicalKeyboardKey.keyC)), isNull);
      expect(
        hotkeyOf(0, const KeySpec(LogicalKeyboardKey.arrowLeft, alt: true)),
        isNull,
      );
    });

    test('file names and the clipboard picture', () {
      final t = DateTime(2026, 11, 17, 14, 32, 9);
      expect(captureFileName(t, 'png'), 'Capture 2026-11-17 14-32.png');
      expect(captureFileName(t, 'jpg', 2), 'Capture 2026-11-17 14-32 (2).jpg');
      final rgba = ByteData(2 * 2 * 4);
      // Top-left red, bottom-left green.
      rgba
        ..setUint8(0, 255)
        ..setUint8(8 + 1, 255);
      final bmp = ByteData.sublistView(bmpFromRgba(2, 2, rgba));
      expect((bmp.getUint8(0), bmp.getUint8(1)), (0x42, 0x4D));
      expect(bmp.getUint32(2, Endian.little), 54 + 16);
      expect(bmp.getInt32(18, Endian.little), 2);
      expect(bmp.getUint16(28, Endian.little), 32);
      // Bottom-up, BGRA: the first row stored is the bottom one (green).
      expect([for (var i = 54; i < 58; i++) bmp.getUint8(i)], [0, 255, 0, 255]);
      expect([for (var i = 62; i < 66; i++) bmp.getUint8(i)], [0, 0, 255, 255]);
    });
  });

  group('captures', () {
    late Directory dir;
    late FakeScreenTools tools;
    late FakeCaptureApi api;
    late FakeSettingsStore store;
    late ProviderContainer container;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mm-capture-test-');
      tools = FakeScreenTools();
      api = FakeCaptureApi(dir.path);
      store = FakeSettingsStore();
      container = ProviderContainer(
        overrides: [
          screenToolsProvider.overrideWithValue(tools),
          captureApiProvider.overrideWithValue(api),
          settingsStoreProvider.overrideWithValue(store),
          captureBytesProvider.overrideWithValue((_) async => screenBmp()),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await dir.delete(recursive: true);
    });

    Future<CaptureEvent> next() =>
        container.read(captureProvider.notifier).events.first;

    test('full screen: saved, copied, sound', () async {
      store.values['capture'] = const CaptureSettings(
        sound: true,
        cursor: true,
      ).toJson();
      final event = next();
      await container.read(captureProvider.notifier).full();
      final done = await event as CaptureDone;
      final path = done.result.path!;
      expect(path, startsWith(dir.path));
      expect(path, endsWith('.png'));
      final saved = await decode(await File(path).readAsBytes());
      expect((saved.width, saved.height), (200, 100));
      expect(done.result.copied, isTrue);
      expect(tools.copied.single.length, 54 + 200 * 100 * 4);
      expect((tools.beeps, tools.cursor), (1, true));
      expect(tools.overlays, isEmpty, reason: 'no overlay for full screen');
    });

    test('a zone: overlay, crop, JPG through FFmpeg or PNG', () async {
      store.values['capture'] = const CaptureSettings(
        format: 'jpg',
        copy: false,
      ).toJson();
      final capture = container.read(captureProvider.notifier);
      await capture.region();
      expect(tools.overlays.single, const Rect.fromLTWH(1920, 0, 200, 100));
      expect(container.read(captureProvider), isNotNull);

      var event = next();
      await capture.finish(const Rect.fromLTWH(90, 10, 20, 30), save: true);
      expect(tools.exits, 1);
      expect(container.read(captureProvider), isNull);
      var result = (await event as CaptureDone).result;
      expect(result.path, endsWith('.jpg'));
      expect(api.encoded.single.$2, 'jpg');
      expect(tools.copied, isEmpty, reason: 'copy is off');
      // The crop: 20 × 30, half red, half blue.
      final crop = await decode(result.png);
      expect((crop.width, crop.height), (20, 30));
      final px = (await crop.toByteData())!;
      expect(px.getUint8(0), 255); // red at the left
      expect(px.getUint8((19) * 4 + 2), 255); // blue at the right

      // FFmpeg fails: PNG instead, said in the toast.
      api.fail = true;
      await capture.region();
      event = next();
      await capture.finish(const Rect.fromLTWH(0, 0, 50, 50), save: true);
      result = (await event as CaptureDone).result;
      expect(result.path, endsWith('.png'));
      expect(result.fellBackToPng, isTrue);
      expect(Directory(dir.path).listSync().whereType<File>().length, 2);
    });

    test('Copier copies only; Échap cancels', () async {
      final capture = container.read(captureProvider.notifier);
      await capture.region();
      final event = next();
      await capture.finish(const Rect.fromLTWH(0, 0, 10, 10), save: false);
      final result = (await event as CaptureDone).result;
      expect((result.path, result.copied), (null, true));
      expect(tools.copied.single.length, 54 + 10 * 10 * 4);
      expect(dir.listSync(), isEmpty);

      await capture.region();
      await capture.cancel();
      expect(container.read(captureProvider), isNull);
      expect(tools.exits, 2);
    });

    test('Filmer hands the zone to the recorder, desktop pixels', () async {
      final capture = container.read(captureProvider.notifier);
      Rect? filmed;
      capture.onFilm = (r) => filmed = r;
      await capture.region();
      await capture.film(const Rect.fromLTWH(10, 20, 30, 40));
      expect(filmed, const Rect.fromLTWH(1930, 20, 30, 40));
    });

    test('shortcuts registered, refused ones reported, let go while '
        'editing', () async {
      tools.refuse = [1];
      container.listen(captureHotkeysProvider, (_, _) {});
      await container.read(captureSettingsProvider.future);
      await pumpEventQueue();
      expect(tools.registered.last, [
        (id: 0, mods: 1, vk: 0x43),
        (id: 1, mods: 5, vk: 0x43),
        (id: 2, mods: 1, vk: 0x52),
      ]);
      expect(container.read(captureKeyFailuresProvider), {
        CaptureShortcut.full,
      });

      container.read(captureKeyEditingProvider.notifier).set(true);
      await pumpEventQueue();
      expect(tools.registered.last, isEmpty);
      expect(container.read(captureKeyFailuresProvider), {
        CaptureShortcut.full,
      });
      container.read(captureKeyEditingProvider.notifier).set(false);
      await pumpEventQueue();
      expect(tools.registered.last.length, 3);

      // Alt Shift C pressed anywhere: the picture is taken.
      final event = next();
      tools.press(1);
      expect(await event, isA<CaptureDone>());
    });
  });

  group('screens', () {
    late FakeScreenTools tools;
    late FakeSettingsStore store;

    Future<void> pumpApp(
      WidgetTester tester, {
      List<Override> extra = const [],
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
            getApiProvider.overrideWithValue(FakeGetApi()),
            screenToolsProvider.overrideWithValue(tools),
            captureApiProvider.overrideWithValue(
              FakeCaptureApi(r'C:\Users\Hery\Pictures\Miarina\Captures'),
            ),
            captureFolderPickerProvider.overrideWithValue(
              (_) async => r'D:\Captures',
            ),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(store),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue('/settings/capture'),
            ...extra,
          ],
          child: const MiarinaApp(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    setUp(() {
      tools = FakeScreenTools();
      store = FakeSettingsStore()..values['onboardingDone'] = true;
    });

    Future<void> press(
      WidgetTester tester,
      List<LogicalKeyboardKey> keys,
    ) async {
      for (final k in keys) {
        await tester.sendKeyDownEvent(k);
      }
      for (final k in keys.reversed) {
        await tester.sendKeyUpEvent(k);
      }
      await tester.pump(const Duration(milliseconds: 150));
    }

    testWidgets('Réglages › Capture d’écran: keys, choices, folder', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1440, 1500));
      expect(find.text('Capture d’écran'), findsWidgets);
      expect(
        find.text('Capture depuis n’importe quelle application'),
        findsOneWidget,
      );
      expect(find.text('Essayer'), findsOneWidget);
      expect(
        find.text(r'C:\Users\Hery\Pictures\Miarina\Captures'),
        findsOneWidget,
      );
      // Alt C, Alt Maj C, Alt R.
      expect(find.text('Maj'), findsOneWidget);
      expect(find.text('Alt'), findsNWidgets(3));

      // A new key for the zone: Windows lets go of them while listening.
      await tester.tap(find.text('Modifier').first);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Appuyez sur la combinaison…'), findsOneWidget);
      expect(tools.registered.last, isEmpty);
      // No modifier: refused.
      await press(tester, [LogicalKeyboardKey.keyX]);
      expect(
        find.text('Il faut Ctrl, Alt ou Maj avec une autre touche.'),
        findsOneWidget,
      );
      // Ctrl K is the app's search.
      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyK,
      ]);
      expect(find.textContaining('sert déjà à'), findsOneWidget);
      // Alt R is the recording's.
      await press(tester, [
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.keyR,
      ]);
      expect(
        find.text(
          'Alt R sert déjà à « Démarrer / arrêter l’enregistrement vidéo ».',
        ),
        findsOneWidget,
      );
      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.keyS,
      ]);
      expect(find.text('Appuyez sur la combinaison…'), findsNothing);
      final saved = CaptureSettings.fromJson(store.values['capture']);
      expect(
        saved.keyOf(CaptureShortcut.region),
        const KeySpec(LogicalKeyboardKey.keyS, ctrl: true, shift: true),
      );
      expect(tools.registered.last.first, (id: 0, mods: 6, vk: 0x53));

      // Format, timer, folder, a toggle.
      await tester.tap(find.text('WebP'));
      await tester.tap(find.text('5 s'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Modifier').last);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.bySemanticsLabel('Son d’obturateur'));
      await tester.pump(const Duration(milliseconds: 150));
      final s = CaptureSettings.fromJson(store.values['capture']);
      expect(
        (s.format, s.delay, s.folder, s.sound),
        ('webp', 5, r'D:\Captures', true),
      );
      expect(find.text(r'D:\Captures'), findsOneWidget);
    });

    testWidgets('a key taken by another application is shown', (tester) async {
      tools.refuse = [2];
      await pumpApp(tester);
      expect(
        find.text(
          'Utilise les derniers réglages de l’enregistreur. · Pris par une autre application',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the overlay: drag a zone, its size, the buttons, Échap', (
      tester,
    ) async {
      final calls = <String>[];
      final controller = _RecordingCapture(calls);
      await pumpApp(
        tester,
        extra: [captureProvider.overrideWith(() => controller)],
      );
      // A 2880 × 1800 screen in a 1440 × 900 window: 2 pixels a point.
      final image = (await tester.runAsync(() async {
        final r = ui.PictureRecorder();
        ui.Canvas(r).drawRect(
          const Rect.fromLTWH(0, 0, 2880, 1800),
          ui.Paint()..color = const Color(0xFF223344),
        );
        return r.endRecording().toImage(2880, 1800);
      }))!;
      controller.show(
        CaptureSession(
          image: image,
          screen: const Rect.fromLTWH(0, 0, 2880, 1800),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Glissez pour choisir une zone'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing, reason: 'no zone yet');

      await tester.dragFrom(const Offset(300, 200), const Offset(420, 240));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('840 × 480'), findsOneWidget);
      expect(find.text('Tout l’écran'), findsOneWidget);
      expect(find.text('Filmer'), findsNothing, reason: 'no recorder yet');

      await tester.tap(find.text('Copier'));
      await tester.pump();
      expect(calls.last, 'finish 600,400 840x480 save=false');

      // A corner moves, the other stays.
      await tester.dragFrom(const Offset(720, 440), const Offset(80, 60));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('1000 × 600'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls.last, 'finish 600,400 1000x600 save=true');
      await tester.tap(find.text('Tout l’écran'));
      await tester.pump();
      expect(calls.last, 'finish 0,0 2880x1800 save=true');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(calls.last, 'cancel');
      image.dispose();
    });
  });
}

/// Keeps the overlay open and writes down what its buttons ask.
class _RecordingCapture extends CaptureController {
  _RecordingCapture(this.calls);

  final List<String> calls;

  void show(CaptureSession s) => state = s;

  @override
  Future<void> finish(Rect zone, {required bool save}) async => calls.add(
    'finish ${zone.left.round()},${zone.top.round()} '
    '${zone.width.round()}x${zone.height.round()} save=$save',
  );

  @override
  Future<void> cancel() async => calls.add('cancel');
}

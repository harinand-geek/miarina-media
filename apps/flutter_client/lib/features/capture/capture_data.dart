import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/capture.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;
import '../playback/settings_store.dart';
import '../shortcuts/keymap.dart' show KeySpec;
import 'screen_tools.dart';

/// The three global shortcuts of Settings › Capture d'écran; the index is
/// the id Windows gives back.
enum CaptureShortcut { region, full, record }

const captureFormats = ['png', 'jpg', 'webp'];
const captureDelays = [0, 3, 5, 10];

/// Settings › Capture d'écran (handoff `useCaptureSettings`), saved under
/// the `capture` key.
@immutable
class CaptureSettings {
  const CaptureSettings({
    this.keys = defaultKeys,
    this.format = 'png',
    this.delay = 0,
    this.folder,
    this.copy = true,
    this.preview = true,
    this.sound = false,
    this.cursor = false,
  });

  static const defaultKeys = {
    CaptureShortcut.region: KeySpec(LogicalKeyboardKey.keyC, alt: true),
    CaptureShortcut.full: KeySpec(
      LogicalKeyboardKey.keyC,
      alt: true,
      shift: true,
    ),
    CaptureShortcut.record: KeySpec(LogicalKeyboardKey.keyR, alt: true),
  };

  final Map<CaptureShortcut, KeySpec?> keys;

  /// png, jpg or webp.
  final String format;

  /// Seconds before the picture is taken.
  final int delay;

  /// Null: Pictures\Miarina\Captures.
  final String? folder;
  final bool copy;
  final bool preview;
  final bool sound;
  final bool cursor;

  KeySpec? keyOf(CaptureShortcut s) => keys[s];

  CaptureSettings copyWith({
    Map<CaptureShortcut, KeySpec?>? keys,
    String? format,
    int? delay,
    String? folder,
    bool? copy,
    bool? preview,
    bool? sound,
    bool? cursor,
  }) => CaptureSettings(
    keys: keys ?? this.keys,
    format: format ?? this.format,
    delay: delay ?? this.delay,
    folder: folder ?? this.folder,
    copy: copy ?? this.copy,
    preview: preview ?? this.preview,
    sound: sound ?? this.sound,
    cursor: cursor ?? this.cursor,
  );

  CaptureSettings withKey(CaptureShortcut s, KeySpec? key) =>
      copyWith(keys: {...keys, s: key});

  Map<String, Object?> toJson() => {
    'keys': {for (final e in keys.entries) e.key.name: e.value?.encode()},
    'format': format,
    'delay': delay,
    'folder': folder,
    'copy': copy,
    'preview': preview,
    'sound': sound,
    'cursor': cursor,
  };

  static CaptureSettings fromJson(Object? raw) {
    if (raw is! Map) return const CaptureSettings();
    final keys = <CaptureShortcut, KeySpec?>{...defaultKeys};
    final saved = raw['keys'];
    if (saved is Map) {
      for (final s in CaptureShortcut.values) {
        if (!saved.containsKey(s.name)) continue;
        final v = saved[s.name];
        keys[s] = v is String ? KeySpec.decode(v) : null;
      }
    }
    final format = raw['format'];
    final delay = raw['delay'];
    final folder = raw['folder'];
    bool flag(String k, bool fallback) =>
        raw[k] is bool ? raw[k] as bool : fallback;
    return CaptureSettings(
      keys: keys,
      format: captureFormats.contains(format) ? format as String : 'png',
      delay: captureDelays.contains(delay) ? delay as int : 0,
      folder: folder is String && folder.isNotEmpty ? folder : null,
      copy: flag('copy', true),
      preview: flag('preview', true),
      sound: flag('sound', false),
      cursor: flag('cursor', false),
    );
  }
}

final captureSettingsProvider =
    AsyncNotifierProvider<CaptureSettingsController, CaptureSettings>(
      CaptureSettingsController.new,
    );

class CaptureSettingsController extends AsyncNotifier<CaptureSettings> {
  static const storeKey = 'capture';

  @override
  Future<CaptureSettings> build() async => CaptureSettings.fromJson(
    await ref.read(settingsStoreProvider).read(storeKey),
  );

  Future<void> change(CaptureSettings Function(CaptureSettings) edit) async {
    final next = edit(state.value ?? const CaptureSettings());
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).write(storeKey, next.toJson());
  }
}

/// The Rust side: the default folder, JPG / WebP through FFmpeg.
abstract class CaptureApi {
  String defaultDir();
  Future<void> encode(String png, String output, String format);
}

class RustCaptureApi implements CaptureApi {
  @override
  String defaultDir() => rust.captureDefaultDir();

  @override
  Future<void> encode(String png, String output, String format) =>
      rust.captureEncode(input: png, output: output, format: format);
}

final captureApiProvider = Provider<CaptureApi?>(
  (_) => Platform.isWindows && RustLib.instance.initialized
      ? RustCaptureApi()
      : null,
);

/// Where pictures go: the chosen folder or Pictures\Miarina\Captures.
String captureFolder(CaptureSettings s, CaptureApi? api) =>
    s.folder ?? api?.defaultDir() ?? '';

/// Shortcuts Windows refused at the last registration.
final captureKeyFailuresProvider =
    NotifierProvider<_Failures, Set<CaptureShortcut>>(_Failures.new);

class _Failures extends Notifier<Set<CaptureShortcut>> {
  @override
  Set<CaptureShortcut> build() => const {};

  void set(Set<CaptureShortcut> v) => state = v;
}

/// True while Settings listens for a new shortcut: Windows lets go of them
/// all meanwhile, so the keys pressed reach the screen.
final captureKeyEditingProvider = NotifierProvider<_Editing, bool>(
  _Editing.new,
);

class _Editing extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

/// Registers the global shortcuts with Windows and follows them (watched by
/// the app root). Changing them in Settings registers them again.
final captureHotkeysProvider = Provider<void>((ref) {
  final tools = ref.watch(screenToolsProvider);
  if (tools == null) return;
  final settings = ref.watch(captureSettingsProvider).value;
  if (settings == null) return;
  final sub = tools.hotkeys.listen(
    (id) => ref.read(captureProvider.notifier).onHotkey(id),
  );
  ref.onDispose(sub.cancel);
  final editing = ref.watch(captureKeyEditingProvider);
  final keys = [
    if (!editing)
      for (final s in CaptureShortcut.values)
        if (settings.keyOf(s) case final k?) ?hotkeyOf(s.index, k),
  ];
  unawaited(
    tools.registerHotkeys(keys).then((failed) {
      if (editing) return;
      ref.read(captureKeyFailuresProvider.notifier).set({
        for (final id in failed) CaptureShortcut.values[id],
      });
    }, onError: (Object _) {}),
  );
});

// ------------------------------------------------------------- pictures

/// A frozen picture of one screen, while the zone is chosen.
@immutable
class CaptureSession {
  const CaptureSession({required this.image, required this.screen});

  final ui.Image image;

  /// The screen on the desktop, physical pixels.
  final Rect screen;
}

/// What a capture made, for the toast.
@immutable
class CaptureResult {
  const CaptureResult({
    required this.png,
    this.path,
    this.copied = false,
    this.fellBackToPng = false,
  });

  final Uint8List png;

  /// The saved file, or null when only copied.
  final String? path;
  final bool copied;

  /// JPG / WebP could not be made: saved as PNG.
  final bool fellBackToPng;
}

/// Pictures taken; the screen shows a toast for each (or an error).
sealed class CaptureEvent {
  const CaptureEvent();
}

class CaptureDone extends CaptureEvent {
  const CaptureDone(this.result);

  final CaptureResult result;
}

class CaptureFailed extends CaptureEvent {
  const CaptureFailed();
}

/// Reads a file (overridden in widget tests, where real I/O waits).
final captureBytesProvider = Provider<Future<Uint8List> Function(String)>(
  (_) =>
      (path) => File(path).readAsBytes(),
);

final captureProvider = NotifierProvider<CaptureController, CaptureSession?>(
  CaptureController.new,
);

class CaptureController extends Notifier<CaptureSession?> {
  final _events = StreamController<CaptureEvent>.broadcast();
  bool _busy = false;

  /// Called by the recorder (Outils PC › Enregistrer l'écran) for Alt R
  /// and the overlay's « Filmer ».
  void Function()? onRecordKey;
  void Function(Rect zone)? onFilm;

  /// True while the window is the recording bar: no zone overlay then.
  bool Function()? blocked;

  Stream<CaptureEvent> get events => _events.stream;

  ScreenTools? get _tools => ref.read(screenToolsProvider);

  @override
  CaptureSession? build() => null;

  Future<CaptureSettings> _settings() async =>
      ref.read(captureSettingsProvider).value ??
      await ref.read(captureSettingsProvider.future);

  void onHotkey(int id) {
    if (id < 0 || id >= CaptureShortcut.values.length) return;
    switch (CaptureShortcut.values[id]) {
      case CaptureShortcut.region:
        unawaited(region());
      case CaptureShortcut.full:
        unawaited(full());
      case CaptureShortcut.record:
        onRecordKey?.call();
    }
  }

  /// The timer, then a picture of the screen under the mouse.
  Future<CaptureSession?> _shoot(CaptureSettings s) async {
    final tools = _tools;
    if (tools == null) return null;
    if (s.delay > 0) await Future<void>.delayed(Duration(seconds: s.delay));
    final dir = await Directory.systemTemp.createTemp('mm-capture-');
    try {
      final bmp = '${dir.path}${Platform.pathSeparator}screen.bmp';
      final screen = await tools.capture(bmp, cursor: s.cursor);
      if (screen == null) return null;
      final bytes = await ref.read(captureBytesProvider)(bmp);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return CaptureSession(image: frame.image, screen: screen);
    } catch (_) {
      return null;
    } finally {
      unawaited(dir.delete(recursive: true).catchError((_) => dir));
    }
  }

  /// Alt C: the overlay to draw the zone on.
  Future<void> region() async {
    if (_busy || state != null || (blocked?.call() ?? false)) return;
    _busy = true;
    try {
      final s = await _settings();
      final shot = await _shoot(s);
      if (shot == null) {
        _events.add(const CaptureFailed());
        return;
      }
      await _tools?.enterOverlay(shot.screen);
      state = shot;
    } finally {
      _busy = false;
    }
  }

  /// Alt Shift C: the whole screen, saved at once.
  Future<void> full() async {
    if (_busy || state != null) return;
    _busy = true;
    try {
      final s = await _settings();
      final shot = await _shoot(s);
      if (shot == null) {
        _events.add(const CaptureFailed());
        return;
      }
      final image = shot.image;
      await _deliver(
        s,
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        save: true,
        copy: s.copy,
      );
      image.dispose();
    } finally {
      _busy = false;
    }
  }

  /// The overlay's buttons: [zone] in the picture's pixels. Save keeps the
  /// file (and copies it when the setting says so); copy only copies.
  Future<void> finish(Rect zone, {required bool save}) async {
    final session = state;
    if (session == null) return;
    state = null;
    await _tools?.exitOverlay();
    final s = await _settings();
    await _deliver(s, session.image, zone, save: save, copy: !save || s.copy);
    session.image.dispose();
  }

  /// « Filmer »: the recorder takes the zone (desktop pixels).
  Future<void> film(Rect zone) async {
    final session = state;
    if (session == null) return;
    state = null;
    await _tools?.exitOverlay();
    session.image.dispose();
    onFilm?.call(zone.shift(session.screen.topLeft));
  }

  Future<void> cancel() async {
    final session = state;
    if (session == null) return;
    state = null;
    await _tools?.exitOverlay();
    session.image.dispose();
  }

  Future<void> _deliver(
    CaptureSettings s,
    ui.Image image,
    Rect zone, {
    required bool save,
    required bool copy,
  }) async {
    try {
      final picture = await cropImage(image, zone);
      final png = (await picture.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      var copied = false;
      if (copy) {
        final rgba = (await picture.toByteData())!;
        copied = await _copy(bmpFromRgba(picture.width, picture.height, rgba));
      }
      picture.dispose();
      CaptureResult result = CaptureResult(png: png, copied: copied);
      if (save) result = await saveCapture(s, png, copied: copied);
      if (s.sound) unawaited(_tools?.beep());
      _events.add(CaptureDone(result));
    } catch (_) {
      _events.add(const CaptureFailed());
    }
  }

  Future<bool> _copy(Uint8List bmp) async {
    final tools = _tools;
    if (tools == null) return false;
    final dir = await Directory.systemTemp.createTemp('mm-clip-');
    try {
      final path = '${dir.path}${Platform.pathSeparator}clip.bmp';
      await File(path).writeAsBytes(bmp);
      return await tools.copyImage(path);
    } finally {
      unawaited(dir.delete(recursive: true).catchError((_) => dir));
    }
  }

  /// [png] into the folder, in the chosen format (PNG when FFmpeg cannot).
  Future<CaptureResult> saveCapture(
    CaptureSettings s,
    Uint8List png, {
    bool copied = false,
  }) async {
    final api = ref.read(captureApiProvider);
    final dir = Directory(captureFolder(s, api));
    await dir.create(recursive: true);
    final now = DateTime.now();
    if (s.format != 'png' && api != null) {
      final out = freeCapturePath(dir.path, now, s.format);
      final temp = '$out.source.png';
      await File(temp).writeAsBytes(png);
      try {
        await api.encode(temp, out, s.format);
        return CaptureResult(png: png, path: out, copied: copied);
      } catch (_) {
        // Falls back to PNG below.
      } finally {
        unawaited(File(temp).delete().catchError((_) => File(temp)));
      }
    }
    final out = freeCapturePath(dir.path, now, 'png');
    await File(out).writeAsBytes(png, flush: true);
    return CaptureResult(
      png: png,
      path: out,
      copied: copied,
      fellBackToPng: s.format != 'png',
    );
  }
}

/// "Capture 2026-11-17 14-32.png", then " (2)"… when taken.
String captureFileName(DateTime t, String ext, [int n = 1]) {
  String two(int v) => v.toString().padLeft(2, '0');
  final stem =
      'Capture ${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}-${two(t.minute)}';
  return n == 1 ? '$stem.$ext' : '$stem ($n).$ext';
}

String freeCapturePath(String dir, DateTime t, String ext) {
  for (var n = 1; ; n++) {
    final path = '$dir${Platform.pathSeparator}${captureFileName(t, ext, n)}';
    if (!File(path).existsSync()) return path;
  }
}

/// [zone] of [image] (its pixels), clamped to it.
Future<ui.Image> cropImage(ui.Image image, Rect zone) async {
  final bounds = Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  final r = zone.intersect(bounds);
  final w = r.width.round().clamp(1, image.width);
  final h = r.height.round().clamp(1, image.height);
  final src = Rect.fromLTWH(
    r.left.roundToDouble(),
    r.top.roundToDouble(),
    w.toDouble(),
    h.toDouble(),
  );
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    src,
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.none,
  );
  final picture = recorder.endRecording();
  final out = await picture.toImage(w, h);
  picture.dispose();
  return out;
}

/// A 32-bit bottom-up BMP of [rgba] (straight RGBA rows), for the
/// clipboard.
Uint8List bmpFromRgba(int width, int height, ByteData rgba) {
  const header = 14 + 40;
  final size = width * height * 4;
  final out = ByteData(header + size);
  out
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4D)
    ..setUint32(2, header + size, Endian.little)
    ..setUint32(10, header, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 32, Endian.little)
    ..setUint32(34, size, Endian.little);
  for (var y = 0; y < height; y++) {
    final from = y * width * 4;
    final to = header + (height - 1 - y) * width * 4;
    for (var x = 0; x < width * 4; x += 4) {
      out
        ..setUint8(to + x, rgba.getUint8(from + x + 2))
        ..setUint8(to + x + 1, rgba.getUint8(from + x + 1))
        ..setUint8(to + x + 2, rgba.getUint8(from + x))
        ..setUint8(to + x + 3, 255);
    }
  }
  return out.buffer.asUint8List();
}

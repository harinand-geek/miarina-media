import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shortcuts/keymap.dart' show KeySpec;

/// A global shortcut for Windows: [id] comes back in [ScreenTools.hotkeys].
typedef Hotkey = ({int id, int mods, int vk});

/// What the Windows runner does for the Outils PC (windows/runner/
/// screen_tools.cpp): global shortcuts, a picture of the screen under the
/// mouse, the window as a full-screen overlay, the clipboard.
abstract class ScreenTools {
  /// Replaces the shortcuts; returns the ids Windows refused (taken by
  /// another application).
  Future<List<int>> registerHotkeys(List<Hotkey> keys);

  /// A BMP picture of the screen under the mouse ([all]: of every screen)
  /// in [path]; its place on the desktop, in physical pixels. Null when it
  /// failed.
  Future<Rect?> capture(String path, {required bool cursor, bool all = false});

  /// The screen under the mouse, physical pixels.
  Future<Rect?> cursorScreen();

  /// The window covers [screen] (physical pixels), borderless, on top;
  /// [radius] rounds its corners, [activate] false leaves the focus where
  /// it is (the recording bar).
  Future<void> enterOverlay(
    Rect screen, {
    int radius = 0,
    bool activate = true,
  });

  /// Every screen, physical pixels (the primary one flagged).
  Future<List<({Rect rect, bool primary})>> monitors();

  /// The windows that can be filmed: title and place.
  Future<List<({String title, Rect rect})>> windows();

  /// The window as before; false when it was minimized.
  Future<bool> exitOverlay();

  /// The BMP file [path] to the clipboard.
  Future<bool> copyImage(String path);

  Future<void> beep();

  /// The window left out of screen recordings (or back in).
  Future<bool> excludeFromCapture(bool on);

  /// Ids of the shortcuts pressed.
  Stream<int> get hotkeys;
}

class ChannelScreenTools implements ScreenTools {
  ChannelScreenTools() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hotkey' && call.arguments is int) {
        _hotkeys.add(call.arguments as int);
      }
    });
  }

  static const _channel = MethodChannel('org.miarina.media/screen_tools');
  final _hotkeys = StreamController<int>.broadcast();

  static Rect? _rect(Object? raw) {
    if (raw is! Map) return null;
    int v(String k) => (raw[k] as num?)?.toInt() ?? 0;
    return Rect.fromLTWH(
      v('x').toDouble(),
      v('y').toDouble(),
      v('width').toDouble(),
      v('height').toDouble(),
    );
  }

  @override
  Future<List<int>> registerHotkeys(List<Hotkey> keys) async {
    final failed = await _channel.invokeMethod<List<Object?>>(
      'registerHotkeys',
      {
        'keys': [
          for (final k in keys) {'id': k.id, 'mods': k.mods, 'key': k.vk},
        ],
      },
    );
    return [for (final id in failed ?? const []) id as int];
  }

  @override
  Future<Rect?> capture(
    String path, {
    required bool cursor,
    bool all = false,
  }) async {
    try {
      return _rect(
        await _channel.invokeMethod('capture', {
          'path': path,
          'cursor': cursor,
          'all': all,
        }),
      );
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<Rect?> cursorScreen() async =>
      _rect(await _channel.invokeMethod('monitor'));

  @override
  Future<void> enterOverlay(
    Rect screen, {
    int radius = 0,
    bool activate = true,
  }) => _channel.invokeMethod('enterOverlay', {
    'x': screen.left.round(),
    'y': screen.top.round(),
    'width': screen.width.round(),
    'height': screen.height.round(),
    'radius': radius,
    'activate': activate,
  });

  @override
  Future<List<({Rect rect, bool primary})>> monitors() async {
    final raw = await _channel.invokeMethod<List<Object?>>('monitors');
    return [
      for (final m in raw ?? const [])
        if (_rect(m) case final r?)
          (rect: r, primary: (m as Map)['primary'] == true),
    ];
  }

  @override
  Future<List<({String title, Rect rect})>> windows() async {
    final raw = await _channel.invokeMethod<List<Object?>>('windows');
    return [
      for (final w in raw ?? const [])
        if (_rect(w) case final r?)
          if ((w as Map)['title'] case final String title)
            (title: title, rect: r),
    ];
  }

  @override
  Future<bool> exitOverlay() async =>
      await _channel.invokeMethod<bool>('exitOverlay') ?? true;

  @override
  Future<bool> copyImage(String path) async =>
      await _channel.invokeMethod<bool>('copyImage', {'path': path}) ?? false;

  @override
  Future<void> beep() => _channel.invokeMethod('beep');

  @override
  Future<bool> excludeFromCapture(bool on) async =>
      await _channel.invokeMethod<bool>('excludeFromCapture', {'on': on}) ??
      false;

  @override
  Stream<int> get hotkeys => _hotkeys.stream;
}

/// Null off Windows. Overridden in tests.
final screenToolsProvider = Provider<ScreenTools?>(
  (ref) => Platform.isWindows ? ChannelScreenTools() : null,
);

// Windows modifier flags of RegisterHotKey.
const _modAlt = 0x1, _modCtrl = 0x2, _modShift = 0x4;

const _fKeys = [
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
];

/// The Windows virtual key of [key], or null for one a global shortcut
/// cannot use here.
int? windowsVk(LogicalKeyboardKey key) {
  final id = key.keyId;
  if (id >= 0x61 && id <= 0x7a) return id - 0x20; // a–z → VK_A…VK_Z
  if (id >= 0x30 && id <= 0x39) return id; // 0–9
  final f = _fKeys.indexOf(key);
  if (f >= 0) return 0x70 + f;
  return switch (key) {
    LogicalKeyboardKey.space => 0x20,
    LogicalKeyboardKey.printScreen => 0x2C,
    LogicalKeyboardKey.insert => 0x2D,
    LogicalKeyboardKey.delete => 0x2E,
    LogicalKeyboardKey.home => 0x24,
    LogicalKeyboardKey.end => 0x23,
    LogicalKeyboardKey.pageUp => 0x21,
    LogicalKeyboardKey.pageDown => 0x22,
    _ => null,
  };
}

/// [spec] as a Windows shortcut, or null when it cannot be one.
Hotkey? hotkeyOf(int id, KeySpec spec) {
  final vk = windowsVk(spec.key);
  if (vk == null || !(spec.ctrl || spec.alt || spec.shift)) return null;
  return (
    id: id,
    mods:
        (spec.alt ? _modAlt : 0) |
        (spec.ctrl ? _modCtrl : 0) |
        (spec.shift ? _modShift : 0),
    vk: vk,
  );
}

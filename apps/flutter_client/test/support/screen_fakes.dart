import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:miarina_media/features/capture/screen_tools.dart';

/// The Windows runner's screen tools, recorded.
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

  bool? allScreens;
  Rect? cursorRect;

  @override
  Future<Rect?> cursorScreen() async => cursorRect;

  @override
  Future<List<int>> registerHotkeys(List<Hotkey> keys) async {
    registered.add(keys);
    return [
      for (final k in keys)
        if (refuse.contains(k.id)) k.id,
    ];
  }

  @override
  Future<Rect?> capture(
    String path, {
    required bool cursor,
    bool all = false,
  }) async {
    this.cursor = cursor;
    allScreens = all;
    return const Rect.fromLTWH(1920, 0, 200, 100);
  }

  @override
  Future<void> enterOverlay(
    Rect screen, {
    int radius = 0,
    bool activate = true,
  }) async {
    overlays.add(screen);
    overlayActivates.add(activate);
  }

  final overlayActivates = <bool>[];
  var excluded = <bool>[];
  var monitorList = [
    (rect: const Rect.fromLTWH(0, 0, 1920, 1080), primary: true),
  ];
  var windowList = <({String title, Rect rect})>[];

  @override
  Future<List<({Rect rect, bool primary})>> monitors() async => monitorList;

  @override
  Future<List<({String title, Rect rect})>> windows() async => windowList;

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
  Future<bool> excludeFromCapture(bool on) async {
    excluded.add(on);
    return true;
  }

  @override
  Stream<int> get hotkeys => _keys.stream;
}

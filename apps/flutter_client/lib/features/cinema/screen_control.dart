import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android video page (A-04 / A-04b): brightness of the window (never the
/// system setting), media volume, picture in picture, orientation
/// (`ScreenControlChannel.kt`).
abstract class ScreenControl {
  /// 0..1.
  Future<double> brightness();

  /// 0..1; -1 gives the screen back to the system setting.
  Future<void> setBrightness(double value);

  /// Media volume, 0..1.
  Future<double> volume();
  Future<void> setVolume(double value);

  Future<bool> pipSupported();

  /// The picture's shape, whether it plays, whether leaving the app opens
  /// the small window.
  Future<void> setVideo({
    required int width,
    required int height,
    required bool playing,
    required bool autoPip,
  });

  Future<bool> enterPip();

  /// landscape, portrait or auto.
  Future<void> setOrientation(String mode);

  /// True while the app shows only in the small window.
  Stream<bool> get pip;

  /// The media volume (0..1) whenever it changes, buttons included.
  Stream<double> get volumeChanges;
}

class ChannelScreenControl implements ScreenControl {
  ChannelScreenControl() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pip' && call.arguments is bool) {
        _pip.add(call.arguments as bool);
      }
      if (call.method == 'volume' && call.arguments is num) {
        _volume.add((call.arguments as num).toDouble());
      }
    });
  }

  static const _channel = MethodChannel('org.miarina.media/screen_control');
  final _pip = StreamController<bool>.broadcast();
  final _volume = StreamController<double>.broadcast();

  @override
  Stream<double> get volumeChanges => _volume.stream;

  @override
  Future<double> brightness() async =>
      (await _channel.invokeMethod<num>('brightness'))?.toDouble() ?? 0.5;

  @override
  Future<void> setBrightness(double value) =>
      _channel.invokeMethod('setBrightness', {'value': value});

  @override
  Future<double> volume() async =>
      (await _channel.invokeMethod<num>('volume'))?.toDouble() ?? 0.5;

  @override
  Future<void> setVolume(double value) =>
      _channel.invokeMethod('setVolume', {'value': value});

  @override
  Future<bool> pipSupported() async =>
      await _channel.invokeMethod<bool>('pipSupported') ?? false;

  @override
  Future<void> setVideo({
    required int width,
    required int height,
    required bool playing,
    required bool autoPip,
  }) => _channel.invokeMethod('setVideo', {
    'width': width,
    'height': height,
    'playing': playing,
    'autoPip': autoPip,
  });

  @override
  Future<bool> enterPip() async =>
      await _channel.invokeMethod<bool>('enterPip') ?? false;

  @override
  Future<void> setOrientation(String mode) =>
      _channel.invokeMethod('setOrientation', {'mode': mode});

  @override
  Stream<bool> get pip => _pip.stream;
}

/// Null off Android. Overridden in tests.
final screenControlProvider = Provider<ScreenControl?>(
  (_) => Platform.isAndroid ? ChannelScreenControl() : null,
);

final pipSupportedProvider = FutureProvider<bool>((ref) async {
  final control = ref.watch(screenControlProvider);
  return control == null ? false : control.pipSupported();
});

/// The app shows only in the picture-in-picture window.
final pipModeProvider = NotifierProvider<PipMode, bool>(PipMode.new);

class PipMode extends Notifier<bool> {
  @override
  bool build() {
    final control = ref.watch(screenControlProvider);
    final sub = control?.pip.listen((v) => state = v);
    ref.onDispose(() => sub?.cancel());
    return false;
  }
}

/// Which gesture a one-finger vertical drag makes: the left half of the
/// picture sets the brightness, the right half the volume.
enum SlideKind { brightness, volume }

SlideKind slideKindAt(double x, double width) =>
    x < width / 2 ? SlideKind.brightness : SlideKind.volume;

/// A drag of [dy] points over a picture [height] high moves the value by
/// the same share (up = more), kept within 0..1.
double slideValue(double start, double dy, double height) =>
    height <= 0 ? start : (start - dy / height).clamp(0.0, 1.0);

/// Double tap on the sides: −10 s on the left third, +10 s on the right
/// third, play / pause in the middle (0).
int doubleTapSeconds(double x, double width) {
  if (x < width / 3) return -10;
  if (x > width * 2 / 3) return 10;
  return 0;
}

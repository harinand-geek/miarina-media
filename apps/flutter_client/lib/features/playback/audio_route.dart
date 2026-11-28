import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_data.dart';

/// Where the sound goes (decision 0013, proposal 9): the equalizer keeps
/// one setting per output.
enum AudioRouteKind { speaker, wired, bluetooth, output }

@immutable
class AudioRoute {
  const AudioRoute(this.kind, [this.name = '']);

  final AudioRouteKind kind;

  /// Device name (a Bluetooth headset, a Windows output); may be empty.
  final String name;

  /// What the equalizer settings are kept under: each Bluetooth device and
  /// each Windows output apart; wired headsets together, the speaker.
  String get key => switch (kind) {
    AudioRouteKind.bluetooth => 'bluetooth:${name.trim().toLowerCase()}',
    AudioRouteKind.output => 'output:${name.trim().toLowerCase()}',
    AudioRouteKind.wired => 'wired',
    AudioRouteKind.speaker => 'speaker',
  };

  @override
  bool operator ==(Object other) =>
      other is AudioRoute && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);
}

/// The phone's output, from the native side (AudioRouteChannel.kt).
abstract interface class AudioRouteSource {
  Future<AudioRoute?> current();
  Stream<AudioRoute> get changes;
}

class AndroidAudioRouteSource implements AudioRouteSource {
  AndroidAudioRouteSource() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        final r = _parse(call.arguments);
        if (r != null) _changes.add(r);
      }
    });
  }

  static const _channel = MethodChannel('org.miarina.media/audio_route');
  final _changes = StreamController<AudioRoute>.broadcast();

  static AudioRoute? _parse(Object? raw) {
    if (raw is! Map) return null;
    final kind = AudioRouteKind.values.asNameMap()[raw['kind']];
    if (kind == null) return null;
    return AudioRoute(kind, raw['name'] is String ? raw['name'] as String : '');
  }

  @override
  Future<AudioRoute?> current() async {
    try {
      return _parse(await _channel.invokeMethod<Object?>('current'));
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AudioRoute> get changes => _changes.stream;
}

final audioRouteSourceProvider = Provider<AudioRouteSource?>(
  (_) => Platform.isAndroid ? AndroidAudioRouteSource() : null,
);

/// The output now: on Android from the device, elsewhere the output chosen
/// in the settings (« auto » = the system's). Null when unknown.
final audioRouteProvider = StreamProvider<AudioRoute?>((ref) async* {
  final source = ref.watch(audioRouteSourceProvider);
  if (source != null) {
    yield await source.current();
    yield* source.changes;
    return;
  }
  final prefs = await ref.watch(playbackPrefsProvider.future);
  yield AudioRoute(AudioRouteKind.output, prefs.engine.audioOutput);
});

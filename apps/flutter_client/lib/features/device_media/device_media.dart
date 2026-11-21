import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/import_data.dart';
import '../playback/settings_store.dart';

/// Read access to the phone's music and videos (A-06), granted or not.
@immutable
class DeviceAccess {
  const DeviceAccess({required this.audio, required this.video});

  static const none = DeviceAccess(audio: false, video: false);

  final bool audio;
  final bool video;

  bool get any => audio || video;

  static DeviceAccess fromMap(Object? raw) {
    if (raw is! Map) return none;
    return DeviceAccess(
      audio: raw['audio'] == 'granted',
      video: raw['video'] == 'granted',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceAccess && other.audio == audio && other.video == video;

  @override
  int get hashCode => Object.hash(audio, video);
}

/// The Android side (`DeviceMediaChannel.kt`); tests use a fake.
abstract interface class DeviceMediaApi {
  Future<DeviceAccess> access();

  /// Shows the system permission dialogs, then answers the new state.
  Future<DeviceAccess> request();

  /// App details in the system settings, where a refusal is undone.
  Future<void> openSettings();

  /// The media the granted access allows (absolute paths).
  Future<(DeviceAccess, List<String>)> list();
}

class ChannelDeviceMediaApi implements DeviceMediaApi {
  static const _channel = MethodChannel('org.miarina.media/device_media');

  @override
  Future<DeviceAccess> access() async =>
      DeviceAccess.fromMap(await _channel.invokeMethod<Object?>('access'));

  @override
  Future<DeviceAccess> request() async =>
      DeviceAccess.fromMap(await _channel.invokeMethod<Object?>('request'));

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<(DeviceAccess, List<String>)> list() async {
    final raw = await _channel.invokeMethod<Object?>('list');
    final paths = raw is Map && raw['paths'] is List
        ? [for (final p in raw['paths'] as List) ?(p is String ? p : null)]
        : const <String>[];
    return (DeviceAccess.fromMap(raw), paths);
  }
}

final deviceMediaApiProvider = Provider<DeviceMediaApi>(
  (ref) => ChannelDeviceMediaApi(),
);

/// Whether the phone's media can be asked for (Android only); tests
/// override it.
final deviceMediaSupportedProvider = Provider<bool>(
  (ref) => Platform.isAndroid,
);

@immutable
class DeviceMediaState {
  const DeviceMediaState({required this.access, required this.asked});

  final DeviceAccess access;

  /// The explanation (A-06) led to the system dialog at least once: a
  /// missing access is then a refusal (A-07).
  final bool asked;
}

final deviceMediaProvider =
    AsyncNotifierProvider<DeviceMediaController, DeviceMediaState>(
      DeviceMediaController.new,
    );

class DeviceMediaController extends AsyncNotifier<DeviceMediaState> {
  static const askedKey = 'deviceMediaAsked';

  DeviceMediaApi get _api => ref.read(deviceMediaApiProvider);

  @override
  Future<DeviceMediaState> build() async {
    if (!ref.watch(deviceMediaSupportedProvider)) {
      return const DeviceMediaState(access: DeviceAccess.none, asked: false);
    }
    final asked = await ref.read(settingsStoreProvider).read(askedKey) == true;
    return DeviceMediaState(access: await _api.access(), asked: asked);
  }

  /// A-06 « Autoriser l'accès »: the system dialog, then the phone's media
  /// join the library when something was granted.
  Future<void> request() async {
    await future;
    await ref.read(settingsStoreProvider).write(askedKey, true);
    final access = await _api.request();
    state = AsyncData(DeviceMediaState(access: access, asked: true));
    if (access.any) await sync();
  }

  /// Back from the system settings (A-07): the access may have changed.
  Future<void> recheck() async {
    if (!ref.read(deviceMediaSupportedProvider)) return;
    final before = state.value;
    final access = await _api.access();
    state = AsyncData(
      DeviceMediaState(access: access, asked: before?.asked ?? false),
    );
    if (access.any && before?.access != access) await sync();
  }

  Future<void> openSettings() => _api.openSettings();

  /// Indexes what the access allows (at launch and after a grant); nothing
  /// without access.
  Future<void> sync() async {
    if (!ref.read(deviceMediaSupportedProvider)) return;
    try {
      final (access, paths) = await _api.list();
      if (!access.any) return;
      await ref.read(indexerApiProvider).syncListed(paths);
      refreshLibraryWith(ref.invalidate);
    } catch (e) {
      debugPrint('phone media not indexed: $e');
    }
  }
}

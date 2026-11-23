import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/media_engine.dart';
import '../../src/rust/api/system_media.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;
import 'playback.dart';

export '../../src/rust/api/system_media.dart' show SystemMediaState;

/// Windows system media controls (SMTC, api/system_media.rs): the media
/// keys of the keyboard, headset buttons and the media panel of Windows act
/// on Miarina Media and show what plays. Android has its own media session
/// (PlaybackService). Tests use a fake.
abstract interface class SystemMediaApi {
  void update(rust.SystemMediaState state);

  /// play, pause, stop, next, previous.
  Stream<String> buttons();
}

class RustSystemMediaApi implements SystemMediaApi {
  @override
  void update(rust.SystemMediaState state) =>
      rust.systemMediaUpdate(state: state);

  @override
  Stream<String> buttons() => rust.systemMediaButtons();
}

final systemMediaApiProvider = Provider<SystemMediaApi?>(
  (ref) => Platform.isWindows && RustLib.instance.initialized
      ? RustSystemMediaApi()
      : null,
);

/// Keeps the system controls in step with the queue and the engine; read
/// once at launch.
final systemMediaProvider = NotifierProvider<SystemMediaSync, void>(
  SystemMediaSync.new,
);

class SystemMediaSync extends Notifier<void> {
  SystemMediaApi? _api;
  String? _key;
  DateTime _sentAt = DateTime(0);
  Duration _sentPosition = Duration.zero;
  bool _sentPlaying = false;
  bool _failed = false;

  /// While playing, the position is sent again at most this often (the
  /// system moves it on by itself in between).
  static const _refresh = Duration(seconds: 10);

  @override
  void build() {
    final api = ref.watch(systemMediaApiProvider);
    _api = api;
    if (api == null) return;
    final buttons = api.buttons().listen((b) => unawaited(_pressed(b)));
    ref.onDispose(buttons.cancel);
    ref.listen(queueProvider, (_, _) => _sync());
    ref.listen(playbackProvider, (_, _) => _sync());
  }

  Future<void> _pressed(String button) async {
    final queue = ref.read(queueProvider.notifier);
    final engine = ref.read(mediaEngineProvider);
    final playing = engine?.current.isPlaying ?? false;
    switch (button) {
      case 'play':
        if (!playing) await queue.togglePlay();
      case 'pause' || 'stop':
        // Stop keeps the queue: the next Play goes on from here.
        if (playing) await engine?.pause();
      case 'next':
        await queue.next();
      case 'previous':
        await queue.previous();
    }
  }

  Duration _expected(DateTime now) =>
      _sentPlaying ? _sentPosition + now.difference(_sentAt) : _sentPosition;

  void _sync() {
    final api = _api;
    if (api == null) return;
    final q = ref.read(queueProvider);
    final entry = q.current;
    final snap =
        ref.read(mediaEngineProvider)?.current ?? const PlaybackSnapshot();
    final playing = snap.isPlaying;
    final key = entry == null
        ? ''
        : [
            identityHashCode(entry),
            playing,
            q.hasNext,
            q.hasPrevious,
            snap.duration.inSeconds,
          ].join('|');
    final now = DateTime.now();
    final jumped =
        (snap.position - _expected(now)).abs() > const Duration(seconds: 2);
    final stale = playing && now.difference(_sentAt) >= _refresh;
    if (key == _key && (entry == null || !jumped && !stale)) return;
    _key = key;
    _sentAt = now;
    _sentPosition = snap.position;
    _sentPlaying = playing;
    try {
      api.update(
        rust.SystemMediaState(
          hasMedia: entry != null,
          playing: playing,
          isVideo: entry?.isVideo ?? false,
          title: entry?.title ?? '',
          artist: entry?.subtitle ?? '',
          album: entry?.album ?? '',
          artwork: entry?.artwork,
          canNext: q.hasNext,
          canPrevious: entry != null,
          positionMs: BigInt.from(snap.position.inMilliseconds),
          durationMs: BigInt.from(snap.duration.inMilliseconds),
        ),
      );
    } catch (e) {
      // Shown once: the app plays on without the system controls.
      if (!_failed) debugPrint('system media controls: $e');
      _failed = true;
    }
  }
}

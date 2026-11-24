import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/media_engine.dart';
import '../playback/playback.dart';

/// The Vidéo menu of the player (handoff Cinéma: ratio, crop, audio sync,
/// A–B) and the subtitle timing and size. They belong to the file being
/// watched: a new file starts with none of them.
@immutable
class VideoAdjust {
  const VideoAdjust({
    this.aspect,
    this.fill = false,
    this.audioDelayMs = 0,
    this.subDelayMs = 0,
    this.subScale = 1,
    this.abA,
    this.abB,
  });

  /// One of [aspects], or null for the file's own.
  final String? aspect;

  /// The picture fills the frame (cropped) instead of fitting in it.
  final bool fill;
  final int audioDelayMs;
  final int subDelayMs;
  final double subScale;
  final Duration? abA;
  final Duration? abB;

  static const aspects = {
    '16:9': 16 / 9,
    '4:3': 4 / 3,
    '21:9': 21 / 9,
    '1:1': 1.0,
  };

  double? get aspectRatio => aspects[aspect];

  VideoAdjust copyWith({
    Object? aspect = _keep,
    bool? fill,
    int? audioDelayMs,
    int? subDelayMs,
    double? subScale,
    Object? abA = _keep,
    Object? abB = _keep,
  }) => VideoAdjust(
    aspect: identical(aspect, _keep) ? this.aspect : aspect as String?,
    fill: fill ?? this.fill,
    audioDelayMs: audioDelayMs ?? this.audioDelayMs,
    subDelayMs: subDelayMs ?? this.subDelayMs,
    subScale: subScale ?? this.subScale,
    abA: identical(abA, _keep) ? this.abA : abA as Duration?,
    abB: identical(abB, _keep) ? this.abB : abB as Duration?,
  );
}

const _keep = Object();

/// Audio sync and subtitle steps, and their bounds.
const audioDelayStepMs = 50;
const subDelayStepMs = 100;
const maxDelayMs = 10000;
const subScales = [0.6, 0.8, 1.0, 1.2, 1.4, 1.7, 2.0];

final videoAdjustProvider =
    NotifierProvider<VideoAdjustController, VideoAdjust>(
      VideoAdjustController.new,
    );

class VideoAdjustController extends Notifier<VideoAdjust> {
  Uri? _source;

  MediaEngine? get _engine => ref.read(mediaEngineProvider);

  @override
  VideoAdjust build() {
    final engine = ref.watch(mediaEngineProvider);
    _source = engine?.current.source?.uri;
    final sub = engine?.snapshots.listen((s) {
      final uri = s.source?.uri;
      if (uri == null || uri == _source) return;
      _source = uri;
      // Another file: the engine keeps some of these; set them back.
      if (state != const VideoAdjust()) unawaited(_reset());
    });
    ref.onDispose(() => sub?.cancel());
    return const VideoAdjust();
  }

  Future<void> _reset() async {
    final had = state;
    state = const VideoAdjust();
    final engine = _engine;
    if (engine == null) return;
    if (had.abA != null) await engine.setAbLoop(null, null);
    if (had.audioDelayMs != 0) await engine.setAudioDelay(Duration.zero);
    if (had.subDelayMs != 0) await engine.setSubtitleDelay(Duration.zero);
    if (had.subScale != 1) await engine.setSubtitleScale(1);
  }

  void setAspect(String? aspect) => state = state.copyWith(aspect: aspect);

  void setFill(bool fill) => state = state.copyWith(fill: fill);

  Future<void> nudgeAudio(int steps) async {
    final ms = (state.audioDelayMs + steps * audioDelayStepMs).clamp(
      -maxDelayMs,
      maxDelayMs,
    );
    state = state.copyWith(audioDelayMs: ms);
    await _engine?.setAudioDelay(Duration(milliseconds: ms));
  }

  Future<void> nudgeSubtitles(int steps) async {
    final ms = (state.subDelayMs + steps * subDelayStepMs).clamp(
      -maxDelayMs,
      maxDelayMs,
    );
    state = state.copyWith(subDelayMs: ms);
    await _engine?.setSubtitleDelay(Duration(milliseconds: ms));
  }

  Future<void> stepSubtitleSize(int steps) async {
    final i = subScales.indexWhere((s) => (s - state.subScale).abs() < 0.01);
    final next =
        subScales[((i < 0 ? 2 : i) + steps).clamp(0, subScales.length - 1)];
    state = state.copyWith(subScale: next);
    await _engine?.setSubtitleScale(next);
  }

  /// A–B, one tap at a time: A at [position], then B, then off.
  Future<void> abStep(Duration position) async {
    final engine = _engine;
    if (state.abA == null) {
      state = state.copyWith(abA: position);
    } else if (state.abB == null) {
      final a = state.abA!;
      if (position <= a) {
        // B before A: A moves there instead.
        state = state.copyWith(abA: position);
        return;
      }
      state = state.copyWith(abB: position);
      await engine?.setAbLoop(a, position);
    } else {
      state = state.copyWith(abA: null, abB: null);
      await engine?.setAbLoop(null, null);
    }
  }
}

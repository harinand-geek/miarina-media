import 'dart:async';

import 'package:flutter/widgets.dart';

import 'media_engine.dart';

/// Two engines, so the next audio file can start while the current one
/// fades out (Réglages › Lecture › Fondu entre les titres). Everything else
/// goes to the engine that plays; gapless stays the playing engine's own.
///
/// Rules: a file opened by the queue always plays in the first engine (it
/// carries the video view), so only audio ever crosses over to the second;
/// in exclusive audio mode the two cannot share the output, so there is no
/// crossfade.
class CrossfadeEngine implements MediaEngine {
  CrossfadeEngine(this._a, this._b) {
    _subs
      ..add(_a.snapshots.listen((s) => _onSnapshot(_a, s)))
      ..add(_b.snapshots.listen((s) => _onSnapshot(_b, s)));
  }

  final MediaEngine _a;
  final MediaEngine _b;
  late MediaEngine _active = _a;
  final _subs = <StreamSubscription<PlaybackSnapshot>>[];
  final _controller = StreamController<PlaybackSnapshot>.broadcast();

  /// The user's volume; the fade moves each engine's own volume.
  double _volume = 1;
  bool _exclusive = false;

  /// The file waiting in the other engine, and how long the fade lasts.
  MediaSource? _next;
  Duration _fade = Duration.zero;
  bool _standbyLoaded = false;
  Timer? _ramp;

  MediaEngine get _standby => identical(_active, _a) ? _b : _a;

  @override
  EngineCapabilities get capabilities {
    final c = _a.capabilities;
    return EngineCapabilities(
      video: c.video,
      speed: c.speed,
      audioTrackSelection: c.audioTrackSelection,
      embeddedSubtitles: c.embeddedSubtitles,
      externalSubtitles: c.externalSubtitles,
      assSubtitles: c.assSubtitles,
      chapters: c.chapters,
      equalizer: c.equalizer,
      backgroundPlayback: c.backgroundPlayback,
      audioOutputs: c.audioOutputs,
      exclusiveAudio: c.exclusiveAudio,
      sidecarSubtitles: c.sidecarSubtitles,
      subtitleLanguage: c.subtitleLanguage,
      frameStep: c.frameStep,
      normalization: c.normalization,
      gapless: c.gapless,
      crossfade: true,
      abLoop: c.abLoop,
      audioDelay: c.audioDelay,
      subtitleTiming: c.subtitleTiming,
      videoFrame: c.videoFrame,
      hardwareDecoding: c.hardwareDecoding,
    );
  }

  @override
  PlaybackSnapshot get current => _active.current.copyWith(volume: _volume);

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  void _onSnapshot(MediaEngine from, PlaybackSnapshot s) {
    if (!identical(from, _active)) return;
    if (!_controller.isClosed) _controller.add(s.copyWith(volume: _volume));
    final fade = _fade;
    if (_next != null &&
        _standbyLoaded &&
        _ramp == null &&
        s.isPlaying &&
        s.duration > fade * 2 &&
        s.duration - s.position <= fade) {
      unawaited(_crossOver());
    }
  }

  /// The next file starts in the other engine; the current one fades out.
  Future<void> _crossOver() async {
    final from = _active;
    final to = _standby;
    final fade = _fade;
    _next = null;
    _standbyLoaded = false;
    _active = to;
    await to.setVolume(0);
    await to.play();
    if (!_controller.isClosed) {
      _controller.add(to.current.copyWith(volume: _volume));
    }
    final started = DateTime.now();
    _ramp = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final k =
          (DateTime.now().difference(started).inMilliseconds /
                  fade.inMilliseconds)
              .clamp(0.0, 1.0);
      unawaited(to.setVolume(_volume * k));
      unawaited(from.setVolume(_volume * (1 - k)));
      if (k >= 1) unawaited(_endFade(from));
    });
  }

  Future<void> _endFade(MediaEngine from) async {
    _ramp?.cancel();
    _ramp = null;
    if (identical(from, _active)) return;
    await from.stop();
    await from.setVolume(_volume);
    await _active.setVolume(_volume);
  }

  /// Stops any fade or waiting file: [_a] plays alone again.
  Future<void> _reset() async {
    _ramp?.cancel();
    _ramp = null;
    _next = null;
    _standbyLoaded = false;
    if (!identical(_active, _a)) {
      await _b.stop();
      _active = _a;
    } else if (_b.current.source != null) {
      await _b.stop();
    }
    await _a.setVolume(_volume);
    await _b.setVolume(_volume);
  }

  @override
  Future<void> prepareNext(
    MediaSource? next, {
    Duration crossfade = Duration.zero,
  }) async {
    final fade = next != null && crossfade > Duration.zero && !_exclusive;
    if (!fade) {
      if (_next != null) {
        _next = null;
        _standbyLoaded = false;
        if (_ramp == null) await _standby.stop();
      }
      // Gapless, by the playing engine itself; a video only follows in the
      // first engine (its view).
      return _active.prepareNext(identical(_active, _a) ? next : null);
    }
    await _active.prepareNext(null);
    if (_next?.uri == next.uri && _fade == crossfade) return;
    _next = next;
    _fade = crossfade;
    _standbyLoaded = false;
    final standby = _standby;
    await standby.setVolume(0);
    await standby.open(next, autoplay: false);
    if (_next?.uri == next.uri) _standbyLoaded = true;
  }

  @override
  Future<void> open(
    MediaSource media, {
    bool autoplay = true,
    Duration? startAt,
  }) async {
    await _reset();
    return _a.open(media, autoplay: autoplay, startAt: startAt);
  }

  @override
  Future<void> play() => _active.play();

  @override
  Future<void> pause() async {
    // A pause during a fade ends it: the new file stays, alone.
    if (_ramp != null) {
      final from = _standby;
      _ramp?.cancel();
      _ramp = null;
      await from.stop();
      await from.setVolume(_volume);
      await _active.setVolume(_volume);
    }
    return _active.pause();
  }

  @override
  Future<void> stop() async {
    await _reset();
    return _a.stop();
  }

  @override
  Future<void> seek(Duration position) => _active.seek(position);

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    if (_ramp == null) await _active.setVolume(_volume);
    if (!_controller.isClosed) {
      _controller.add(_active.current.copyWith(volume: _volume));
    }
  }

  @override
  Future<void> setSpeed(double value) async {
    await _standby.setSpeed(value);
    return _active.setSpeed(value);
  }

  @override
  Future<void> setRepeatMode(RepeatSetting mode) async {
    await _standby.setRepeatMode(mode);
    return _active.setRepeatMode(mode);
  }

  @override
  Future<void> selectAudioTrack(String trackId) =>
      _active.selectAudioTrack(trackId);

  @override
  Future<void> selectSubtitleTrack(String? trackId) =>
      _active.selectSubtitleTrack(trackId);

  @override
  Future<void> loadExternalSubtitle(Uri uri) =>
      _active.loadExternalSubtitle(uri);

  @override
  Future<void> setSubtitleEnabled(bool enabled) =>
      _active.setSubtitleEnabled(enabled);

  @override
  Future<bool?> setEqualizer(List<double>? gainsDb) async {
    await _b.setEqualizer(gainsDb);
    return _a.setEqualizer(gainsDb);
  }

  @override
  Future<List<AudioOutput>> audioOutputs() => _a.audioOutputs();

  @override
  Future<void> frameStep() => _active.frameStep();

  @override
  Future<void> applyPreferences(EnginePreferences preferences) async {
    _exclusive = preferences.exclusiveAudio;
    if (_exclusive) await _reset();
    await _b.applyPreferences(preferences);
    return _a.applyPreferences(preferences);
  }

  @override
  Widget buildVideoView({BoxFit fit = BoxFit.contain, double? aspectRatio}) =>
      _a.buildVideoView(fit: fit, aspectRatio: aspectRatio);

  @override
  Future<void> setAbLoop(Duration? a, Duration? b) => _active.setAbLoop(a, b);

  @override
  Future<void> setAudioDelay(Duration delay) => _active.setAudioDelay(delay);

  @override
  Future<void> setSubtitleDelay(Duration delay) =>
      _active.setSubtitleDelay(delay);

  @override
  Future<void> setSubtitleScale(double scale) =>
      _active.setSubtitleScale(scale);

  @override
  Future<String?> hardwareDecoder() => _active.hardwareDecoder();

  @override
  Future<void> dispose() async {
    _ramp?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _controller.close();
    await _a.dispose();
    await _b.dispose();
  }
}

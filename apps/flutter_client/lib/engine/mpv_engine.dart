import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'media_engine.dart';

class MpvEngine implements MediaEngine {
  MpvEngine({this.positionInterval = const Duration(milliseconds: 250)}) {
    _video = mkv.VideoController(_player);
    _bind();
  }

  static void ensureInitialized() => mk.MediaKit.ensureInitialized();

  final mk.Player _player = mk.Player();
  late final mkv.VideoController _video;
  final Duration positionInterval;
  final _controller = StreamController<PlaybackSnapshot>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  PlaybackSnapshot _state = const PlaybackSnapshot();
  DateTime _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);
  String? _subtitleBeforeDisable;

  @override
  final EngineCapabilities capabilities = const EngineCapabilities(
    video: true,
    speed: true,
    audioTrackSelection: true,
    embeddedSubtitles: true,
    externalSubtitles: true,
    assSubtitles: true,
    // media_kit does not expose the chapter list; libmpv has it, but until an
    // adapter reads it the interface must not offer chapters.
    chapters: false,
    equalizer: false,
    backgroundPlayback: true,
  );

  @override
  PlaybackSnapshot get current => _state;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  void _emit(PlaybackSnapshot next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  void _bind() {
    final s = _player.stream;
    _subscriptions
      ..add(
        s.playing.listen((playing) {
          if (_state.status == PlaybackStatus.idle ||
              _state.status == PlaybackStatus.error) {
            if (!playing) return;
          }
          _emit(
            _state.copyWith(
              status: playing ? PlaybackStatus.playing : _pausedOrEnded(),
            ),
          );
        }),
      )
      ..add(
        s.completed.listen((done) {
          if (done && _state.repeat == RepeatSetting.off) {
            _emit(_state.copyWith(status: PlaybackStatus.ended));
          }
        }),
      )
      ..add(
        s.position.listen((position) {
          final now = DateTime.now();
          if (now.difference(_lastPositionEmit) < positionInterval) {
            _state = _state.copyWith(position: position);
            return;
          }
          _lastPositionEmit = now;
          _emit(_state.copyWith(position: position));
        }),
      )
      ..add(s.duration.listen((d) => _emit(_state.copyWith(duration: d))))
      ..add(s.buffering.listen((b) => _emit(_state.copyWith(buffering: b))))
      ..add(
        s.volume.listen(
          (v) => _emit(_state.copyWith(volume: (v / 100).clamp(0.0, 1.0))),
        ),
      )
      ..add(s.rate.listen((r) => _emit(_state.copyWith(speed: r))))
      ..add(
        s.tracks.listen((t) {
          _emit(
            _state.copyWith(
              audioTracks: t.audio
                  .where(_isReal)
                  .map(_audioInfo)
                  .toList(growable: false),
              subtitleTracks: t.subtitle
                  .where(_isReal)
                  .map(_subtitleInfo)
                  .toList(growable: false),
            ),
          );
          _refreshSelection();
        }),
      )
      ..add(s.track.listen((_) => _refreshSelection()))
      ..add(s.width.listen((_) => _updateVideoSize()))
      ..add(s.height.listen((_) => _updateVideoSize()))
      ..add(
        s.error.listen((message) {
          final fatal =
              _state.status == PlaybackStatus.loading ||
              _state.duration == Duration.zero;
          _emit(
            _state.copyWith(
              status: fatal ? PlaybackStatus.error : _state.status,
              error: PlaybackError(message, recoverable: !fatal),
            ),
          );
        }),
      );
  }

  // media_kit reports 'auto' when mpv picked the track itself, and a URI for
  // external subtitles; the id mpv actually plays matches the track list.
  Future<void> _refreshSelection() async {
    final native = _player.platform;
    if (native is! mk.NativePlayer) return;
    final audio = await native.getProperty('current-tracks/audio/id');
    final sub = await native.getProperty('current-tracks/sub/id');
    final next = _state.copyWith(
      selectedAudio: audio.isEmpty ? null : audio,
      selectedSubtitle: sub.isEmpty ? null : sub,
    );
    if (next.selectedAudio != _state.selectedAudio ||
        next.selectedSubtitle != _state.selectedSubtitle) {
      _emit(next);
    }
  }

  PlaybackStatus _pausedOrEnded() => _state.status == PlaybackStatus.ended
      ? PlaybackStatus.ended
      : PlaybackStatus.paused;

  void _updateVideoSize() {
    final w = _player.state.width;
    final h = _player.state.height;
    final size = (w != null && h != null && w > 0 && h > 0)
        ? Size(w.toDouble(), h.toDouble())
        : null;
    if (size != _state.videoSize) _emit(_state.copyWith(videoSize: size));
  }

  static bool _isReal(dynamic track) => track.id != 'auto' && track.id != 'no';

  static TrackInfo _audioInfo(mk.AudioTrack t) =>
      TrackInfo(id: t.id, title: t.title, language: t.language, codec: t.codec);

  static TrackInfo _subtitleInfo(mk.SubtitleTrack t) =>
      TrackInfo(id: t.id, title: t.title, language: t.language, codec: t.codec);

  @override
  Future<void> open(
    MediaSource media, {
    bool autoplay = true,
    Duration? startAt,
  }) async {
    _emit(
      PlaybackSnapshot(
        status: PlaybackStatus.loading,
        source: media,
        volume: _state.volume,
        speed: _state.speed,
        repeat: _state.repeat,
      ),
    );
    final resource = media.uri.isScheme('file')
        ? media.uri.toFilePath()
        : media.uri.toString();
    await _player.open(mk.Media(resource, start: startAt), play: autoplay);
    if (!autoplay && _state.status == PlaybackStatus.loading) {
      _emit(_state.copyWith(status: PlaybackStatus.paused));
    }
  }

  @override
  Future<void> play() async {
    if (_state.status == PlaybackStatus.ended) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(
      PlaybackSnapshot(
        volume: _state.volume,
        speed: _state.speed,
        repeat: _state.repeat,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) {
    final max = _state.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (max > Duration.zero && position > max ? max : position);
    _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);
    return _player.seek(target);
  }

  @override
  Future<void> setVolume(double value) =>
      _player.setVolume((value.clamp(0.0, 1.0)) * 100);

  @override
  Future<void> setSpeed(double value) =>
      _player.setRate(value.clamp(0.25, 4.0));

  @override
  Future<void> setRepeatMode(RepeatSetting mode) async {
    await _player.setPlaylistMode(switch (mode) {
      RepeatSetting.off => mk.PlaylistMode.none,
      RepeatSetting.one => mk.PlaylistMode.single,
      RepeatSetting.all => mk.PlaylistMode.loop,
    });
    _emit(_state.copyWith(repeat: mode));
  }

  @override
  Future<void> selectAudioTrack(String trackId) async {
    final track = _player.state.tracks.audio
        .where((t) => t.id == trackId)
        .firstOrNull;
    if (track != null) await _player.setAudioTrack(track);
  }

  @override
  Future<void> selectSubtitleTrack(String? trackId) async {
    if (trackId == null) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
      return;
    }
    final track = _player.state.tracks.subtitle
        .where((t) => t.id == trackId)
        .firstOrNull;
    if (track != null) {
      await _player.setSubtitleTrack(track);
      if (!_state.subtitlesEnabled) {
        _emit(_state.copyWith(subtitlesEnabled: true));
      }
    }
  }

  @override
  Future<void> loadExternalSubtitle(Uri uri) async {
    final resource = uri.isScheme('file') ? uri.toFilePath() : uri.toString();
    await _player.setSubtitleTrack(mk.SubtitleTrack.uri(resource));
    _emit(_state.copyWith(subtitlesEnabled: true));
  }

  @override
  Future<void> setSubtitleEnabled(bool enabled) async {
    if (enabled == _state.subtitlesEnabled) return;
    if (!enabled) {
      _subtitleBeforeDisable = _state.selectedSubtitle;
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
    } else {
      final previous = _subtitleBeforeDisable;
      await selectSubtitleTrack(previous);
      if (previous == null) {
        await _player.setSubtitleTrack(mk.SubtitleTrack.auto());
      }
    }
    _emit(_state.copyWith(subtitlesEnabled: enabled));
  }

  @override
  Widget buildVideoView({BoxFit fit = BoxFit.contain}) => mkv.Video(
    controller: _video,
    fit: fit,
    controls: mkv.NoVideoControls,
    fill: const Color(0xFF070B0F),
  );

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _controller.close();
    await _player.dispose();
  }
}

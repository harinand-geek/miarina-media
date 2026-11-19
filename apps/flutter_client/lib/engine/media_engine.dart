import 'dart:async';

import 'package:flutter/widgets.dart';

enum RepeatSetting { off, one, all }

enum PlaybackStatus { idle, loading, playing, paused, ended, error }

class MediaSource {
  const MediaSource(this.uri, {this.title});

  final Uri uri;
  final String? title;

  factory MediaSource.file(String path, {String? title}) =>
      MediaSource(Uri.file(path), title: title);
}

class TrackInfo {
  const TrackInfo({required this.id, this.title, this.language, this.codec});

  final String id;
  final String? title;
  final String? language;
  final String? codec;

  String get label {
    final parts = [
      title,
      language,
      codec,
    ].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Piste $id' : parts.join(' · ');
  }

  @override
  bool operator ==(Object other) => other is TrackInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What an engine can really do on this platform. The interface hides or
/// disables anything set to false instead of simulating it.
class EngineCapabilities {
  const EngineCapabilities({
    required this.video,
    required this.speed,
    required this.audioTrackSelection,
    required this.embeddedSubtitles,
    required this.externalSubtitles,
    required this.assSubtitles,
    required this.chapters,
    required this.equalizer,
    required this.backgroundPlayback,
  });

  final bool video;
  final bool speed;
  final bool audioTrackSelection;
  final bool embeddedSubtitles;
  final bool externalSubtitles;
  final bool assSubtitles;
  final bool chapters;
  final bool equalizer;
  final bool backgroundPlayback;
}

class PlaybackError {
  const PlaybackError(this.message, {this.recoverable = true});

  final String message;
  final bool recoverable;
}

@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.status = PlaybackStatus.idle,
    this.source,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = false,
    this.volume = 1,
    this.speed = 1,
    this.repeat = RepeatSetting.off,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudio,
    this.selectedSubtitle,
    this.subtitlesEnabled = true,
    this.videoSize,
    this.error,
  });

  final PlaybackStatus status;
  final MediaSource? source;
  final Duration position;
  final Duration duration;
  final bool buffering;
  final double volume;
  final double speed;
  final RepeatSetting repeat;
  final List<TrackInfo> audioTracks;
  final List<TrackInfo> subtitleTracks;
  final String? selectedAudio;
  final String? selectedSubtitle;
  final bool subtitlesEnabled;
  final Size? videoSize;
  final PlaybackError? error;

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get hasVideo => videoSize != null && videoSize!.width > 0;

  static const _keep = Object();

  PlaybackSnapshot copyWith({
    PlaybackStatus? status,
    Object? source = _keep,
    Duration? position,
    Duration? duration,
    bool? buffering,
    double? volume,
    double? speed,
    RepeatSetting? repeat,
    List<TrackInfo>? audioTracks,
    List<TrackInfo>? subtitleTracks,
    Object? selectedAudio = _keep,
    Object? selectedSubtitle = _keep,
    bool? subtitlesEnabled,
    Object? videoSize = _keep,
    Object? error = _keep,
  }) {
    return PlaybackSnapshot(
      status: status ?? this.status,
      source: identical(source, _keep) ? this.source : source as MediaSource?,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffering: buffering ?? this.buffering,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      repeat: repeat ?? this.repeat,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      selectedAudio: identical(selectedAudio, _keep)
          ? this.selectedAudio
          : selectedAudio as String?,
      selectedSubtitle: identical(selectedSubtitle, _keep)
          ? this.selectedSubtitle
          : selectedSubtitle as String?,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      videoSize: identical(videoSize, _keep)
          ? this.videoSize
          : videoSize as Size?,
      error: identical(error, _keep) ? this.error : error as PlaybackError?,
    );
  }
}

/// Platform-independent playback contract. Adapters: [MpvEngine] (Windows,
/// libmpv through media_kit) and the Android Media3 adapter.
abstract interface class MediaEngine {
  EngineCapabilities get capabilities;

  PlaybackSnapshot get current;

  /// Position updates are throttled by the adapter; never one event per frame.
  Stream<PlaybackSnapshot> get snapshots;

  Future<void> open(
    MediaSource media, {
    bool autoplay = true,
    Duration? startAt,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// [value] in 0..1.
  Future<void> setVolume(double value);
  Future<void> setSpeed(double value);
  Future<void> setRepeatMode(RepeatSetting mode);
  Future<void> selectAudioTrack(String trackId);
  Future<void> selectSubtitleTrack(String? trackId);
  Future<void> loadExternalSubtitle(Uri uri);
  Future<void> setSubtitleEnabled(bool enabled);

  /// The picture for this engine, or an empty box for audio-only engines.
  Widget buildVideoView({BoxFit fit = BoxFit.contain});

  Future<void> dispose();
}

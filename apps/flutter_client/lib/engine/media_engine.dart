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

/// A chapter of the open file (start time and its title, when it has one).
@immutable
class ChapterInfo {
  const ChapterInfo({required this.start, this.title});

  final Duration start;
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is ChapterInfo && other.start == start && other.title == title;

  @override
  int get hashCode => Object.hash(start, title);
}

/// An audio output the engine can play to.
@immutable
class AudioOutput {
  const AudioOutput({required this.id, required this.label});

  /// 'auto' = the system's default output.
  final String id;
  final String label;

  @override
  bool operator ==(Object other) => other is AudioOutput && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Playback settings (W-S2) the engine applies to every file it opens.
@immutable
class EnginePreferences {
  const EnginePreferences({
    this.subtitleLanguage,
    this.sidecarSubtitles = true,
    this.exclusiveAudio = false,
    this.audioOutput = 'auto',
  });

  /// ISO 639-1 code of the preferred subtitle language, or null for none.
  final String? subtitleLanguage;

  /// Load subtitle files named after the video (.srt, .vtt, .ass).
  final bool sidecarSubtitles;

  /// Exclusive access to the output (WASAPI), for external DACs.
  final bool exclusiveAudio;
  final String audioOutput;
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
    this.audioOutputs = false,
    this.exclusiveAudio = false,
    this.sidecarSubtitles = false,
    this.subtitleLanguage = false,
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

  /// Settings of [EnginePreferences] the engine honours; the others are not
  /// offered in Settings.
  final bool audioOutputs;
  final bool exclusiveAudio;
  final bool sidecarSubtitles;
  final bool subtitleLanguage;
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
    this.chapters = const [],
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

  /// Chapters of the file, in order; empty when it has none or the engine
  /// cannot read them.
  final List<ChapterInfo> chapters;

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get hasVideo => videoSize != null && videoSize!.width > 0;

  /// Index of the chapter playing at [at] (the position by default), or -1.
  int chapterAt([Duration? at]) {
    final p = at ?? position;
    var i = -1;
    for (var k = 0; k < chapters.length; k++) {
      if (chapters[k].start <= p) i = k;
    }
    return i;
  }

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
    List<ChapterInfo>? chapters,
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
      chapters: chapters ?? this.chapters,
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

  /// Six band gains in dB at 60, 230, 910, 3.6k, 7k and 14k Hz, or null to
  /// bypass. Applied to what plays; files are never modified. Returns whether
  /// the output really applies it (null when not known yet).
  Future<bool?> setEqualizer(List<double>? gainsDb);

  /// Outputs the user can choose from ('auto' first); empty when the
  /// platform decides alone.
  Future<List<AudioOutput>> audioOutputs();

  /// Applies the playback settings to what plays and what will.
  Future<void> applyPreferences(EnginePreferences preferences);

  /// The picture for this engine, or an empty box for audio-only engines.
  Widget buildVideoView({BoxFit fit = BoxFit.contain});

  Future<void> dispose();
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'media_engine.dart';

/// Android adapter: Media3 ExoPlayer in a MediaSessionService, driven by
/// Media3EnginePlugin.kt. Media3 does not draw subtitles into the texture, so
/// the current cues are drawn over the picture here.
class Media3Engine implements MediaEngine {
  Media3Engine() {
    _events = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) => _emit(
        _state.copyWith(
          status: PlaybackStatus.error,
          error: PlaybackError('$e', recoverable: false),
        ),
      ),
    );
  }

  static const _methods = MethodChannel('org.miarina.media/engine');
  static const _eventChannel = EventChannel('org.miarina.media/engine/events');

  late final StreamSubscription<dynamic> _events;
  final _controller = StreamController<PlaybackSnapshot>.broadcast();
  final _cues = ValueNotifier<List<String>>(const []);
  PlaybackSnapshot _state = const PlaybackSnapshot();
  Future<int>? _texture;

  @override
  final EngineCapabilities capabilities = const EngineCapabilities(
    video: true,
    speed: true,
    audioTrackSelection: true,
    embeddedSubtitles: true,
    externalSubtitles: true,
    // Media3 parses SSA/ASS but drops most styling; shown as plain text.
    assSubtitles: false,
    chapters: false,
    // Depends on the device: setEqualizer reports it.
    equalizer: true,
    backgroundPlayback: true,
    // Media3 picks the text track by language; outputs, exclusive mode and
    // sidecar files are left to Android.
    subtitleLanguage: true,
  );

  /// Not chained yet on Android (capabilities say so): files play one by
  /// one.
  @override
  Future<void> prepareNext(
    MediaSource? next, {
    Duration crossfade = Duration.zero,
  }) async {}

  @override
  PlaybackSnapshot get current => _state;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  void _emit(PlaybackSnapshot next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final m = raw.cast<String, Object?>();
    final status =
        PlaybackStatus.values.asNameMap()[m['status']] ?? PlaybackStatus.idle;
    final width = (m['videoWidth'] as num?)?.toDouble() ?? 0;
    final height = (m['videoHeight'] as num?)?.toDouble() ?? 0;
    final error = m['error'] as Map?;
    _cues.value = ((m['cues'] as List?) ?? const []).cast<String>();
    _emit(
      PlaybackSnapshot(
        status: status,
        // Native "idle" also arrives between open() and the item being set;
        // only stop() forgets the source.
        source: _state.source,
        position: Duration(
          milliseconds: (m['positionMs'] as num?)?.toInt() ?? 0,
        ),
        duration: Duration(
          milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0,
        ),
        buffering: m['buffering'] == true,
        volume: (m['volume'] as num?)?.toDouble() ?? _state.volume,
        speed: (m['speed'] as num?)?.toDouble() ?? _state.speed,
        repeat: RepeatSetting.values.asNameMap()[m['repeat']] ?? _state.repeat,
        audioTracks: _tracks(m['audioTracks']),
        subtitleTracks: _tracks(m['subtitleTracks']),
        selectedAudio: m['selectedAudio'] as String?,
        selectedSubtitle: m['selectedSubtitle'] as String?,
        subtitlesEnabled: m['subtitlesEnabled'] != false,
        videoSize: width > 0 && height > 0 ? Size(width, height) : null,
        error: error == null
            ? null
            : PlaybackError(
                '${error['message']}',
                recoverable: error['recoverable'] == true,
              ),
      ),
    );
  }

  static List<TrackInfo> _tracks(Object? raw) => [
    for (final t in (raw as List?) ?? const [])
      if (t is Map)
        TrackInfo(
          id: '${t['id']}',
          title: t['title'] as String?,
          language: t['language'] as String?,
          codec: t['codec'] as String?,
        ),
  ];

  Future<void> _call(String method, [Map<String, Object?>? args]) =>
      _methods.invokeMethod<void>(method, args);

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
    final uri = media.uri.isScheme('file')
        ? media.uri.toFilePath()
        : media.uri.toString();
    await _call('open', {
      'uri': uri,
      'title': media.title,
      'autoplay': autoplay,
      'startMs': startAt?.inMilliseconds ?? 0,
    });
  }

  @override
  Future<void> play() => _call('play');

  @override
  Future<void> pause() => _call('pause');

  @override
  Future<void> stop() async {
    await _call('stop');
    _emit(
      PlaybackSnapshot(
        volume: _state.volume,
        speed: _state.speed,
        repeat: _state.repeat,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) => _call('seek', {
    'ms': position.inMilliseconds < 0 ? 0 : position.inMilliseconds,
  });

  @override
  Future<void> setVolume(double value) =>
      _call('setVolume', {'value': value.clamp(0.0, 1.0)});

  @override
  Future<void> setSpeed(double value) => _call('setSpeed', {'value': value});

  @override
  Future<void> setRepeatMode(RepeatSetting mode) =>
      _call('setRepeat', {'mode': mode.name});

  @override
  Future<void> selectAudioTrack(String trackId) =>
      _call('selectTrack', {'kind': 'audio', 'id': trackId});

  @override
  Future<void> selectSubtitleTrack(String? trackId) =>
      _call('selectTrack', {'kind': 'text', 'id': trackId});

  @override
  Future<void> loadExternalSubtitle(Uri uri) => _call('loadSubtitle', {
    'uri': uri.isScheme('file') ? uri.toFilePath() : uri.toString(),
  });

  @override
  Future<void> setSubtitleEnabled(bool enabled) =>
      _call('setSubtitlesEnabled', {'enabled': enabled});

  @override
  Future<List<AudioOutput>> audioOutputs() async => const [];

  @override
  Future<void> frameStep() async {}

  @override
  Future<void> applyPreferences(EnginePreferences p) =>
      _methods.invokeMethod<void>('setPreferredSubtitle', {
        'language': p.subtitleLanguage,
      });

  @override
  Future<bool?> setEqualizer(List<double>? gainsDb) =>
      _methods.invokeMethod<bool>('setEqualizer', {'gains': gainsDb});

  @override
  Widget buildVideoView({BoxFit fit = BoxFit.contain}) {
    _texture ??= _methods.invokeMethod<int>('texture').then((id) => id!);
    return FutureBuilder<int>(
      future: _texture,
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.expand();
        final size = _state.videoSize ?? const Size(16, 9);
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Texture(textureId: id),
              ),
            ),
            ValueListenableBuilder<List<String>>(
              valueListenable: _cues,
              builder: (context, cues, _) => cues.isEmpty
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: const Alignment(0, 0.88),
                      child: _CueText(cues.join('\n')),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    await _events.cancel();
    await _controller.close();
    _cues.dispose();
    await _call('dispose');
  }
}

class _CueText extends StatelessWidget {
  const _CueText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x99070B0F),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF5F7FA),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

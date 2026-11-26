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
    abLoop: true,
    videoFrame: true,
    skipSilence: true,
    // The next file waits in Media3's own list; no crossfade on Android.
    gapless: true,
  );

  /// The file prepared after the current one, until Media3 starts it.
  MediaSource? _prepared;

  static String _native(MediaSource m) => m.playable.isScheme('file')
      ? m.playable.toFilePath()
      : m.playable.toString();

  @override
  Future<void> prepareNext(
    MediaSource? next, {
    Duration crossfade = Duration.zero,
  }) async {
    _prepared = next;
    await _call('prepareNext', {
      'uri': next == null ? null : _native(next),
      'title': next?.title,
      if (next != null && next.httpHeaders.isNotEmpty)
        'headers': next.httpHeaders,
      'mime': ?next?.mimeType,
    });
  }

  @override
  PlaybackSnapshot get current => _state;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  void _emit(PlaybackSnapshot next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
    // A–B: Media3 has no loop of a part; back to A once B is reached
    // (position updates come 4 times a second).
    final ab = _ab;
    if (ab != null && next.isPlaying && next.position >= ab.$2) {
      unawaited(seek(ab.$1));
    }
  }

  (Duration, Duration)? _ab;

  @override
  Future<void> setAbLoop(Duration? a, Duration? b) async =>
      _ab = a != null && b != null && b > a ? (a, b) : null;

  // Not in Media3 (capabilities say so).
  @override
  Future<void> setAudioDelay(Duration delay) async {}

  @override
  Future<void> setSubtitleDelay(Duration delay) async {}

  @override
  Future<void> setSubtitleScale(double scale) async {}

  @override
  Future<String?> hardwareDecoder() async => null;

  @override
  Future<void> setVideoEnabled(bool on) => _call('setVideoEnabled', {'on': on});

  /// Media3's own silence skipping; no voice boost on Android.
  @override
  Future<void> setSpeechAids({
    required bool skipSilence,
    required bool voiceBoost,
  }) => _methods.invokeMethod<void>('setSkipSilence', {'on': skipSilence});

  MediaSource? _followed(Object? item) {
    final next = _prepared;
    if (next == null || item is! String || item != _native(next)) return null;
    _prepared = null;
    return next;
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
        // only stop() forgets the source. Media3 went on to the prepared
        // file by itself (gapless): it is the source now.
        source: _followed(m['item']) ?? _state.source,
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
    _prepared = null;
    final uri = _native(media);
    await _call('open', {
      'uri': uri,
      'title': media.title,
      'autoplay': autoplay,
      'startMs': startAt?.inMilliseconds ?? 0,
      // Online streams (decision 0011); applied by the plugin in lot 5.
      if (media.httpHeaders.isNotEmpty) 'headers': media.httpHeaders,
      'mime': ?media.mimeType,
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
  Widget buildVideoView({BoxFit fit = BoxFit.contain, double? aspectRatio}) {
    _texture ??= _methods.invokeMethod<int>('texture').then((id) => id!);
    return FutureBuilder<int>(
      future: _texture,
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.expand();
        final own = _state.videoSize ?? const Size(16, 9);
        final size = aspectRatio == null
            ? own
            : Size(own.height * aspectRatio, own.height);
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
        color: const Color(0x99080808),
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

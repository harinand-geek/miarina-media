import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/recorder.dart';
import '../../src/rust/frb_generated.dart' show RustLib;
import '../capture/capture_data.dart';
import '../capture/screen_tools.dart';
import '../playback/settings_store.dart';

export '../../src/rust/api/recorder.dart'
    show RecordOptions, RecorderStatus, Recording;

/// The Rust recorder (`rust/src/recorder.rs`).
abstract class RecorderApi {
  Future<void> start(RecordOptions options);
  Future<void> pause();
  Future<void> resume();
  Future<Recording> stop(String stem);
  void setMicMuted(bool muted);
  Stream<RecorderStatus> events();
  String defaultDir();
}

class RustRecorderApi implements RecorderApi {
  @override
  Future<void> start(RecordOptions options) => recorderStart(options: options);

  @override
  Future<void> pause() => recorderPause();

  @override
  Future<void> resume() => recorderResume();

  @override
  Future<Recording> stop(String stem) => recorderStop(stem: stem);

  @override
  void setMicMuted(bool muted) => recorderSetMicMuted(muted: muted);

  @override
  Stream<RecorderStatus> events() => recorderEvents();

  @override
  String defaultDir() => recorderDefaultDir();
}

final recorderApiProvider = Provider<RecorderApi?>(
  (_) => Platform.isWindows && RustLib.instance.initialized
      ? RustRecorderApi()
      : null,
);

const recorderSources = ['screen', 'window', 'region'];
const recorderFormats = ['mp4', 'mkv', 'webm', 'gif'];
const recorderFps = [24, 30, 60];
const recorderQualities = ['medium', 'high', 'original'];

/// The recorder screen's choices (handoff `useRecorder`), saved under the
/// `recorder` key: Alt R starts with the last ones.
@immutable
class RecorderSettings {
  const RecorderSettings({
    this.source = 'screen',
    this.monitor = 0,
    this.window,
    this.region,
    this.format = 'mp4',
    this.fps = 30,
    this.quality = 'high',
    this.systemAudio = true,
    this.mic = false,
    this.cursor = true,
    this.countdown = true,
    this.folder,
  });

  final String source;

  /// Index among the screens (source screen).
  final int monitor;

  /// The window's title (source window).
  final String? window;

  /// The last zone, desktop pixels (source region).
  final Rect? region;
  final String format;
  final int fps;
  final String quality;
  final bool systemAudio;
  final bool mic;
  final bool cursor;
  final bool countdown;

  /// Null: Videos\Miarina.
  final String? folder;

  bool get hasSound => format != 'gif' && (systemAudio || mic);

  RecorderSettings copyWith({
    String? source,
    int? monitor,
    String? window,
    Rect? region,
    String? format,
    int? fps,
    String? quality,
    bool? systemAudio,
    bool? mic,
    bool? cursor,
    bool? countdown,
    String? folder,
  }) => RecorderSettings(
    source: source ?? this.source,
    monitor: monitor ?? this.monitor,
    window: window ?? this.window,
    region: region ?? this.region,
    format: format ?? this.format,
    fps: fps ?? this.fps,
    quality: quality ?? this.quality,
    systemAudio: systemAudio ?? this.systemAudio,
    mic: mic ?? this.mic,
    cursor: cursor ?? this.cursor,
    countdown: countdown ?? this.countdown,
    folder: folder ?? this.folder,
  );

  Map<String, Object?> toJson() => {
    'source': source,
    'monitor': monitor,
    'window': window,
    if (region case final r?)
      'region': [
        r.left,
        r.top,
        r.width,
        r.height,
      ].map((v) => v.round()).toList(),
    'format': format,
    'fps': fps,
    'quality': quality,
    'systemAudio': systemAudio,
    'mic': mic,
    'cursor': cursor,
    'countdown': countdown,
    'folder': folder,
  };

  static RecorderSettings fromJson(Object? raw) {
    if (raw is! Map) return const RecorderSettings();
    T pick<T>(String k, List<T> allowed, T fallback) =>
        allowed.contains(raw[k]) ? raw[k] as T : fallback;
    bool flag(String k, bool fallback) =>
        raw[k] is bool ? raw[k] as bool : fallback;
    final r = raw['region'];
    Rect? region;
    if (r is List && r.length == 4 && r.every((v) => v is num)) {
      final v = [for (final x in r) (x as num).toDouble()];
      if (v[2] >= 16 && v[3] >= 16) {
        region = Rect.fromLTWH(v[0], v[1], v[2], v[3]);
      }
    }
    final monitor = raw['monitor'];
    final window = raw['window'];
    final folder = raw['folder'];
    return RecorderSettings(
      source: pick('source', recorderSources, 'screen'),
      monitor: monitor is int && monitor >= 0 ? monitor : 0,
      window: window is String && window.isNotEmpty ? window : null,
      region: region,
      format: pick('format', recorderFormats, 'mp4'),
      fps: pick('fps', recorderFps, 30),
      quality: pick('quality', recorderQualities, 'high'),
      systemAudio: flag('systemAudio', true),
      mic: flag('mic', false),
      cursor: flag('cursor', true),
      countdown: flag('countdown', true),
      folder: folder is String && folder.isNotEmpty ? folder : null,
    );
  }
}

final recorderSettingsProvider =
    AsyncNotifierProvider<RecorderSettingsController, RecorderSettings>(
      RecorderSettingsController.new,
    );

class RecorderSettingsController extends AsyncNotifier<RecorderSettings> {
  static const storeKey = 'recorder';

  @override
  Future<RecorderSettings> build() async => RecorderSettings.fromJson(
    await ref.read(settingsStoreProvider).read(storeKey),
  );

  Future<void> change(RecorderSettings Function(RecorderSettings) edit) async {
    final next = edit(state.value ?? const RecorderSettings());
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).write(storeKey, next.toJson());
  }
}

/// A finished recording in « Enregistrements récents ».
@immutable
class RecentRecording {
  const RecentRecording({
    required this.path,
    required this.seconds,
    required this.size,
    required this.format,
  });

  final String path;
  final double seconds;
  final int size;
  final String format;

  String get name => path.split(Platform.pathSeparator).last;

  Map<String, Object?> toJson() => {
    'path': path,
    'seconds': seconds,
    'size': size,
    'format': format,
  };

  static RecentRecording? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'], seconds = raw['seconds'], size = raw['size'];
    final format = raw['format'];
    if (path is! String ||
        seconds is! num ||
        size is! int ||
        format is! String) {
      return null;
    }
    return RecentRecording(
      path: path,
      seconds: seconds.toDouble(),
      size: size,
      format: format,
    );
  }
}

const maxRecents = 20;

final recentRecordingsProvider =
    AsyncNotifierProvider<RecentRecordingsController, List<RecentRecording>>(
      RecentRecordingsController.new,
    );

class RecentRecordingsController extends AsyncNotifier<List<RecentRecording>> {
  static const storeKey = 'recordings';

  @override
  Future<List<RecentRecording>> build() async {
    final raw = await ref.read(settingsStoreProvider).read(storeKey);
    return [
      if (raw is List)
        for (final r in raw) ?RecentRecording.fromJson(r),
    ];
  }

  Future<void> _save(List<RecentRecording> list) async {
    state = AsyncData(list);
    await ref.read(settingsStoreProvider).write(storeKey, [
      for (final r in list) r.toJson(),
    ]);
  }

  Future<void> add(RecentRecording r) async {
    final now = state.value ?? await future;
    await _save(
      [r, ...now.where((x) => x.path != r.path)].take(maxRecents).toList(),
    );
  }

  /// Off the list (the file stays).
  Future<void> remove(String path) async {
    final now = state.value ?? await future;
    await _save(now.where((x) => x.path != path).toList());
  }
}

enum RecPhase { idle, countdown, recording, paused, finalizing }

@immutable
class RecorderState {
  const RecorderState({
    this.phase = RecPhase.idle,
    this.elapsedMs = 0,
    this.micMuted = false,
    this.countdown = 0,
    this.barShown = false,
  });

  final RecPhase phase;
  final int elapsedMs;
  final bool micMuted;

  /// 3, 2, 1 during the countdown.
  final int countdown;

  /// The window is the floating bar.
  final bool barShown;

  bool get busy => phase != RecPhase.idle;

  RecorderState copyWith({
    RecPhase? phase,
    int? elapsedMs,
    bool? micMuted,
    int? countdown,
    bool? barShown,
  }) => RecorderState(
    phase: phase ?? this.phase,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    micMuted: micMuted ?? this.micMuted,
    countdown: countdown ?? this.countdown,
    barShown: barShown ?? this.barShown,
  );
}

/// Toasts of the recorder.
sealed class RecorderEvent {
  const RecorderEvent();
}

class RecordingSaved extends RecorderEvent {
  const RecordingSaved(this.recording);

  final RecentRecording recording;
}

/// [reason]: window_gone, no_screen, record_failed, finish_failed,
/// ffmpeg_missing.
class RecordingFailed extends RecorderEvent {
  const RecordingFailed(this.reason);

  final String reason;
}

String recordingReason(Object e) {
  final text = e.toString();
  for (final r in ['ffmpeg_missing', 'finish_failed', 'record_failed']) {
    if (text.contains(r)) return r;
  }
  return 'record_failed';
}

/// "Enregistrement 2026-11-17 14-32" ([word] localised).
String recordingStem(String word, DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '$word ${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}-${two(t.minute)}';
}

/// Floating bar size, logical pixels.
const recorderBarSize = Size(400, 48);

/// The screen that holds [r] most (by its centre), or the first one.
Rect screenOf(List<({Rect rect, bool primary})> screens, Rect r) {
  for (final s in screens) {
    if (s.rect.contains(r.center)) return s.rect;
  }
  return screens.isEmpty ? r : screens.first.rect;
}

/// The bar's place: top centre of [screen], 14 points down.
Rect barRect(Rect screen, double dpr) {
  final w = recorderBarSize.width * dpr, h = recorderBarSize.height * dpr;
  return Rect.fromLTWH(
    (screen.center.dx - w / 2).roundToDouble(),
    (screen.top + 14 * dpr).roundToDouble(),
    w.roundToDouble(),
    h.roundToDouble(),
  );
}

final recorderProvider = NotifierProvider<RecorderController, RecorderState>(
  RecorderController.new,
);

class RecorderController extends Notifier<RecorderState> {
  final _events = StreamController<RecorderEvent>.broadcast();
  StreamSubscription<RecorderStatus>? _status;
  Timer? _countdown;
  Completer<bool>? _countdownDone;

  /// "Enregistrement" in the app's language (set by the screen).
  String fileWord = 'Enregistrement';

  Stream<RecorderEvent> get events => _events.stream;

  RecorderApi? get _api => ref.read(recorderApiProvider);
  ScreenTools? get _tools => ref.read(screenToolsProvider);

  double get _dpr {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1 : views.first.devicePixelRatio;
  }

  @override
  RecorderState build() {
    final api = ref.watch(recorderApiProvider);
    ref.onDispose(() {
      _status?.cancel();
      _countdown?.cancel();
    });
    // Alt R and the zone overlay's « Filmer ».
    final capture = ref.read(captureProvider.notifier);
    capture.onRecordKey = () => unawaited(toggle());
    capture.onFilm = (zone) => unawaited(start(zone: zone));
    capture.blocked = () => state.busy;
    if (api != null) {
      _status = api.events().listen((s) {
        if (state.phase == RecPhase.countdown) return;
        final phase = switch (s.phase) {
          'recording' => RecPhase.recording,
          'paused' => RecPhase.paused,
          'finalizing' => RecPhase.finalizing,
          _ => null,
        };
        state = state.copyWith(
          phase: phase ?? state.phase,
          elapsedMs: s.elapsedMs.toInt(),
          micMuted: s.micMuted,
        );
      });
    }
    return const RecorderState();
  }

  Future<RecorderSettings> _settings() async =>
      ref.read(recorderSettingsProvider).value ??
      await ref.read(recorderSettingsProvider.future);

  /// Alt R: starts with the last choices, or stops.
  Future<void> toggle() async {
    switch (state.phase) {
      case RecPhase.idle:
        await start();
      case RecPhase.recording || RecPhase.paused:
        await stop();
      case RecPhase.countdown:
        await cancelCountdown();
      case RecPhase.finalizing:
        break;
    }
  }

  /// [zone] (desktop pixels): from the overlay's « Filmer ». A zone source
  /// with no zone yet asks for one first.
  Future<void> start({Rect? zone}) async {
    final api = _api, tools = _tools;
    if (api == null || tools == null || state.busy) return;
    var s = await _settings();
    if (zone != null) {
      s = s.copyWith(source: 'region', region: zone);
      await ref.read(recorderSettingsProvider.notifier).change((_) => s);
    } else if (s.source == 'region' && s.region == null) {
      await ref.read(captureProvider.notifier).region();
      return;
    }
    final screens = await tools.monitors();
    Rect target;
    var title = '';
    switch (s.source) {
      case 'window':
        final w = (await tools.windows())
            .where((w) => w.title == s.window)
            .firstOrNull;
        if (w == null) {
          _events.add(const RecordingFailed('window_gone'));
          return;
        }
        target = w.rect;
        title = w.title;
      case 'region':
        target = s.region!;
      default:
        if (screens.isEmpty) {
          _events.add(const RecordingFailed('no_screen'));
          return;
        }
        target = screens[s.monitor.clamp(0, screens.length - 1)].rect;
    }
    final options = RecordOptions(
      source: s.source,
      x: target.left.round(),
      y: target.top.round(),
      width: target.width.round(),
      height: target.height.round(),
      windowTitle: title,
      format: s.format,
      fps: s.fps,
      quality: s.quality,
      systemAudio: s.systemAudio,
      mic: s.mic,
      cursor: s.cursor,
      outDir: s.folder ?? api.defaultDir(),
    );
    // The window becomes the floating bar, left out of the video.
    final dpr = _dpr;
    await tools.excludeFromCapture(true);
    await tools.enterOverlay(
      barRect(screenOf(screens, target), dpr),
      radius: (recorderBarSize.height * dpr / 2).round(),
      activate: false,
    );
    state = RecorderState(
      phase: s.countdown ? RecPhase.countdown : RecPhase.recording,
      countdown: s.countdown ? 3 : 0,
      barShown: true,
    );
    if (s.countdown && !await _runCountdown()) return;
    try {
      api.setMicMuted(false);
      await api.start(options);
      state = state.copyWith(phase: RecPhase.recording, elapsedMs: 0);
    } catch (e) {
      await _leaveBar();
      state = const RecorderState();
      _events.add(RecordingFailed(recordingReason(e)));
    }
  }

  /// 3, 2, 1; false when stopped meanwhile.
  Future<bool> _runCountdown() {
    final done = _countdownDone = Completer<bool>();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final n = state.countdown - 1;
      if (n <= 0) {
        timer.cancel();
        if (!done.isCompleted) done.complete(true);
      } else {
        state = state.copyWith(countdown: n);
      }
    });
    return done.future;
  }

  Future<void> cancelCountdown() async {
    if (state.phase != RecPhase.countdown) return;
    _countdown?.cancel();
    final done = _countdownDone;
    if (done != null && !done.isCompleted) done.complete(false);
    await _leaveBar();
    state = const RecorderState();
  }

  Future<void> pause() async {
    if (state.phase != RecPhase.recording) return;
    await _api?.pause();
    state = state.copyWith(phase: RecPhase.paused);
  }

  Future<void> resume() async {
    if (state.phase != RecPhase.paused) return;
    await _api?.resume();
    state = state.copyWith(phase: RecPhase.recording);
  }

  void toggleMic() {
    final muted = !state.micMuted;
    _api?.setMicMuted(muted);
    state = state.copyWith(micMuted: muted);
  }

  Future<void> stop() async {
    final api = _api;
    if (api == null) return;
    if (state.phase == RecPhase.countdown) return cancelCountdown();
    if (state.phase != RecPhase.recording && state.phase != RecPhase.paused) {
      return;
    }
    state = state.copyWith(phase: RecPhase.finalizing);
    try {
      final r = await api.stop(recordingStem(fileWord, DateTime.now()));
      final recent = RecentRecording(
        path: r.path,
        seconds: r.durationSecs,
        size: r.size.toInt(),
        format: r.format,
      );
      await ref.read(recentRecordingsProvider.notifier).add(recent);
      await _leaveBar();
      state = const RecorderState();
      _events.add(RecordingSaved(recent));
    } catch (e) {
      await _leaveBar();
      state = const RecorderState();
      _events.add(RecordingFailed(recordingReason(e)));
    }
  }

  Future<void> _leaveBar() async {
    final tools = _tools;
    if (tools == null) return;
    await tools.exitOverlay();
    await tools.excludeFromCapture(false);
  }
}

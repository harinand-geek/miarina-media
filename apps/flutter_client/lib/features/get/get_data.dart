import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/get.dart';
import '../../src/rust/api/indexer.dart' show indexerStart;
import '../../src/rust/frb_generated.dart' show RustLib;
import '../import/import_data.dart' show toolsDir;
import '../library/library_data.dart' show dbPathProvider, dataDirProvider;

export '../../src/rust/api/get.dart'
    show
        Analysis,
        AnalysisStatus,
        FormatOffer,
        GetEvent,
        GetEventKind,
        GetSettings,
        HistoryInfo,
        LinkCheck,
        MediaInfo,
        PresetOffers,
        StartRequest,
        TaskInfo,
        ToolStatus,
        WebPlaylist,
        WebPlaylistEntry,
        WebPlaylistPick,
        WebPlaylistStart,
        YtDlpUpdate;

/// Obtenir in the core (download manager); tests use an in-memory one.
abstract interface class GetApi {
  Future<void> start();
  Stream<GetEvent> events();
  Future<LinkCheck> checkLink(String url);
  Future<Analysis> analyze(String url);

  /// Qualities valid for any page (Plusieurs liens).
  PresetOffers presetOffers();

  /// Obtenir › Playlist: the whole playlist the link belongs to.
  Future<Analysis> analyzePlaylist(String url);
  Future<void> installTools();
  Future<TaskInfo> startDownload(StartRequest request);

  /// Queues a playlist's chosen entries; how many were queued.
  Future<int> startPlaylist(WebPlaylistStart request);
  Future<List<TaskInfo>> tasks();
  Future<List<HistoryInfo>> history();
  Future<void> action(String id, String action);
  Future<void> move(String id, int index);
  Future<void> pauseAll(bool pause);
  Future<GetSettings> settings();
  Future<GetSettings> setDownloadDir(String path);
  Future<GetSettings> setConcurrency(int value);
  Future<GetSettings> setResourceMode(String mode);
  Future<List<ToolStatus>> tools();
  Future<YtDlpUpdate> updateYtDlp();
  Future<void> clearHistory();
}

/// Android side of Obtenir (`MediaToolsChannel.kt`): extractor, folders and
/// the phone's media index.
const androidMediaTools = MethodChannel('org.miarina.media/media_tools');

/// Where downloads go until the user picks another folder: Téléchargements
/// \Miarina, as in the Tauri app.
String defaultDownloadDir() {
  final home = Platform.environment['USERPROFILE'] ?? '';
  return '$home\\Downloads\\Miarina';
}

class RustGetApi implements GetApi {
  RustGetApi(this._ref);

  final Ref _ref;

  @override
  Future<void> start() async {
    // Widget tests run without the native core.
    if (!RustLib.instance.initialized) throw StateError('core not loaded');
    // Idempotent: the indexing may already have started the same base.
    await indexerStart(
      dbPath: await _ref.read(dbPathProvider.future),
      dataDir: await _ref.read(dataDirProvider.future),
      toolsDir: toolsDir(),
    );
    if (!Platform.isAndroid) {
      await getStart(defaultDir: defaultDownloadDir());
      return;
    }
    // Android: the APK's extractor is unpacked first; it also says where
    // downloads go (Movies/Miarina, Music/Miarina on Android 11+).
    final raw = await androidMediaTools.invokeMapMethod<String, Object?>(
      'prepare',
    );
    String at(String key) => raw![key]! as String;
    await getStart(defaultDir: at('videoDir'));
    await getSetAndroidTools(
      tools: AndroidTools(
        python: at('python'),
        script: at('script'),
        ffmpeg: at('ffmpeg'),
        quickjs: at('quickjs'),
        pythonHome: at('pythonHome'),
        libraryPath: at('libraryPath'),
        certificates: at('certificates'),
        temp: at('temp'),
        bin: at('bin'),
        audioDir: raw!['audioDir'] as String?,
        stagingDir: raw['stagingDir'] as String?,
      ),
    );
  }

  @override
  Stream<GetEvent> events() => getEvents();

  @override
  Future<LinkCheck> checkLink(String url) => getCheckLink(url: url);

  @override
  Future<Analysis> analyze(String url) => getAnalyze(url: url);

  @override
  PresetOffers presetOffers() => getPresetOffers();

  @override
  Future<Analysis> analyzePlaylist(String url) => getAnalyzePlaylist(url: url);

  @override
  Future<void> installTools() => getInstallTools();

  @override
  Future<TaskInfo> startDownload(StartRequest request) =>
      getStartDownload(request: request);

  @override
  Future<int> startPlaylist(WebPlaylistStart request) =>
      getStartPlaylist(request: request);

  @override
  Future<List<TaskInfo>> tasks() => getTasks();

  @override
  Future<List<HistoryInfo>> history() => getHistory(limit: 200);

  @override
  Future<void> action(String id, String action) =>
      getTaskAction(id: id, action: action);

  @override
  Future<void> move(String id, int index) => getMoveTask(id: id, index: index);

  @override
  Future<void> pauseAll(bool pause) => getPauseAll(pause: pause);

  @override
  Future<GetSettings> settings() => getSettings();

  @override
  Future<GetSettings> setDownloadDir(String path) =>
      getSetDownloadDir(path: path);

  @override
  Future<GetSettings> setConcurrency(int value) =>
      getSetConcurrency(value: value);

  @override
  Future<GetSettings> setResourceMode(String mode) =>
      getSetResourceMode(mode: mode);

  @override
  Future<List<ToolStatus>> tools() => getTools();

  @override
  Future<YtDlpUpdate> updateYtDlp() => getUpdateYtdlp();

  @override
  Future<void> clearHistory() async => getClearHistory();
}

final getApiProvider = Provider<GetApi>(RustGetApi.new);

/// A task as the screens see it: the record plus the live transfer figures
/// of the last progress event.
@immutable
class DownloadTask {
  const DownloadTask(
    this.info, {
    this.downloaded = 0,
    this.total,
    this.bytesPerSec = 0,
    this.etaSecs,
    this.supportsResume = false,
    this.retryInSecs,
    this.retryAt,
    this.offline = false,
  });

  final TaskInfo info;
  final int downloaded;
  final int? total;
  final double bytesPerSec;
  final int? etaSecs;
  final bool supportsResume;

  /// Automatic retry announced (connection lost).
  final int? retryInSecs;
  final DateTime? retryAt;
  final bool offline;

  String get id => info.id;
  String get state => info.state;
  bool get retrying => retryInSecs != null;

  double get percent => total != null && total! > 0
      ? (downloaded / total! * 100).clamp(0, 100)
      : 0;

  bool get running => state == 'downloading' || state == 'processing';

  /// Waiting for a slot (not a retry backoff).
  bool get queued => state == 'queued' || (state == 'waiting' && !retrying);

  bool get open => state != 'completed' && state != 'canceled';

  DownloadTask copyWith({
    TaskInfo? info,
    int? downloaded,
    int? total,
    double? bytesPerSec,
    int? etaSecs,
    bool clearEta = false,
    bool? supportsResume,
    int? retryInSecs,
    DateTime? retryAt,
    bool clearRetry = false,
    bool? offline,
  }) => DownloadTask(
    info ?? this.info,
    downloaded: downloaded ?? this.downloaded,
    total: total ?? this.total,
    bytesPerSec: bytesPerSec ?? this.bytesPerSec,
    etaSecs: clearEta ? null : (etaSecs ?? this.etaSecs),
    supportsResume: supportsResume ?? this.supportsResume,
    retryInSecs: clearRetry ? null : (retryInSecs ?? this.retryInSecs),
    retryAt: clearRetry ? null : (retryAt ?? this.retryAt),
    offline: clearRetry ? false : (offline ?? this.offline),
  );

  /// From a record; a record may lag behind the last progress event, so the
  /// larger downloaded figure is kept while the state is the same.
  static DownloadTask fromRecord(TaskInfo r, [DownloadTask? previous]) {
    final same = previous != null && previous.state == r.state;
    final downloading = r.state == 'downloading';
    return DownloadTask(
      r,
      downloaded: same
          ? (previous.downloaded > r.downloadedBytes.toInt()
                ? previous.downloaded
                : r.downloadedBytes.toInt())
          : r.downloadedBytes.toInt(),
      total: r.totalBytes?.toInt() ?? previous?.total,
      bytesPerSec: downloading ? (previous?.bytesPerSec ?? 0) : 0,
      etaSecs: downloading ? previous?.etaSecs : null,
      supportsResume: r.supportsResume,
      retryInSecs: r.state == 'waiting' ? previous?.retryInSecs : null,
      retryAt: r.state == 'waiting' ? previous?.retryAt : null,
      offline: r.state == 'waiting' && (previous?.offline ?? false),
    );
  }
}

@immutable
class DownloadsState {
  const DownloadsState({
    this.tasks = const {},
    this.history = const [],
    this.ready = false,
    this.toolProgress = const {},
  });

  final Map<String, DownloadTask> tasks;
  final List<HistoryInfo> history;
  final bool ready;

  /// Media tools being downloaded: name → (downloaded, total).
  final Map<String, (int, int)> toolProgress;

  /// In queue order.
  List<DownloadTask> get ordered =>
      tasks.values.toList()
        ..sort((a, b) => a.info.position.compareTo(b.info.position));

  DownloadsState copyWith({
    Map<String, DownloadTask>? tasks,
    List<HistoryInfo>? history,
    bool? ready,
    Map<String, (int, int)>? toolProgress,
  }) => DownloadsState(
    tasks: tasks ?? this.tasks,
    history: history ?? this.history,
    ready: ready ?? this.ready,
    toolProgress: toolProgress ?? this.toolProgress,
  );
}

/// Aggregates of the sidebar card and the Downloads header.
@immutable
class DownloadsSummary {
  const DownloadsSummary({
    required this.active,
    required this.running,
    required this.queued,
    required this.openCount,
    required this.offline,
    required this.speed,
    required this.overallPercent,
  });

  factory DownloadsSummary.of(DownloadsState s) {
    final all = s.ordered;
    final active = [
      for (final t in all)
        if (t.open && !t.queued) t,
    ];
    final running = [
      for (final t in active)
        if (t.running) t,
    ];
    return DownloadsSummary(
      active: active,
      running: running,
      queued: [
        for (final t in all)
          if (t.queued) t,
      ],
      openCount: all.where((t) => t.open).length,
      offline: all.any((t) => t.offline),
      speed: running.fold(0.0, (n, t) => n + t.bytesPerSec),
      overallPercent: active.isEmpty
          ? 0
          : active.fold(0.0, (n, t) => n + t.percent) / active.length,
    );
  }

  final List<DownloadTask> active;
  final List<DownloadTask> running;
  final List<DownloadTask> queued;
  final int openCount;
  final bool offline;
  final double speed;
  final double overallPercent;
}

/// Mirror of the Rust download manager: state changes only arrive through
/// its events; actions forward the user's intent.
final downloadsProvider = NotifierProvider<DownloadsController, DownloadsState>(
  DownloadsController.new,
);

final downloadsSummaryProvider = Provider<DownloadsSummary>(
  (ref) => DownloadsSummary.of(ref.watch(downloadsProvider)),
);

class DownloadsController extends Notifier<DownloadsState> {
  StreamSubscription<GetEvent>? _events;

  GetApi get _api => ref.read(getApiProvider);

  /// Done when the manager is up (or could not start): analyses wait for
  /// it, since the app may open straight on one.
  late Future<void> started;

  @override
  DownloadsState build() {
    ref.onDispose(() => _events?.cancel());
    started = _init();
    return const DownloadsState();
  }

  Future<void> _init() async {
    try {
      await _api.start();
      _events = _api.events().listen(apply);
      final records = await _api.tasks();
      final history = await _api.history();
      final tasks = {...state.tasks};
      // Events received since subscribing are newer than this snapshot.
      for (final r in records) {
        tasks.putIfAbsent(r.id, () => DownloadTask.fromRecord(r));
      }
      state = state.copyWith(tasks: tasks, history: history, ready: true);
    } catch (e) {
      debugPrint('downloads not started: $e');
    }
  }

  @visibleForTesting
  void apply(GetEvent e) {
    final tasks = {...state.tasks};
    switch (e.kind) {
      case GetEventKind.progress:
        final task = tasks[e.id];
        if (task == null) return;
        tasks[e.id] = task.copyWith(
          downloaded: e.downloaded.toInt(),
          total: e.total?.toInt(),
          bytesPerSec: e.bytesPerSec,
          etaSecs: e.etaSecs?.toInt(),
          clearEta: e.etaSecs == null,
          supportsResume: e.supportsResume,
          clearRetry: true,
        );
      case GetEventKind.task:
        final record = e.task!;
        if (record.state == 'canceled') {
          tasks.remove(record.id);
        } else {
          tasks[record.id] = DownloadTask.fromRecord(record, tasks[record.id]);
        }
        // Android: a finished download joins the phone's media index
        // (gallery, other players), as in the Tauri app.
        final done = record.finalPath;
        if (Platform.isAndroid && record.state == 'completed' && done != null) {
          unawaited(
            androidMediaTools
                .invokeMethod<bool>('publish', {'path': done})
                .catchError((Object _) => false),
          );
        }
      case GetEventKind.removed:
        tasks.remove(e.id);
      case GetEventKind.retrying:
        final task = tasks[e.id];
        if (task == null) return;
        tasks[e.id] = task.copyWith(
          retryInSecs: e.retryInSecs.toInt(),
          retryAt: DateTime.now(),
          offline: e.offline,
        );
      case GetEventKind.history:
        final h = e.history!;
        state = state.copyWith(
          history: [h, ...state.history.where((x) => x.id != h.id)],
        );
        return;
      case GetEventKind.toolProgress:
        state = state.copyWith(
          toolProgress: {
            ...state.toolProgress,
            e.id: (e.downloaded.toInt(), e.total?.toInt() ?? 0),
          },
        );
        return;
    }
    state = state.copyWith(tasks: tasks);
  }

  /// Starts (or queues) a download; null when refused.
  Future<TaskInfo> start(StartRequest request) async {
    final record = await _api.startDownload(request);
    // The worker may already have moved on: its events win.
    if (!state.tasks.containsKey(record.id)) {
      state = state.copyWith(
        tasks: {...state.tasks, record.id: DownloadTask.fromRecord(record)},
      );
    }
    return record;
  }

  Future<void> action(String id, String action) => _api.action(id, action);

  Future<void> move(String id, int index) => _api.move(id, index);

  Future<void> pauseAll(bool pause) => _api.pauseAll(pause);

  /// Forgets past downloads; files are not deleted.
  Future<void> clearHistory() async {
    await _api.clearHistory();
    state = state.copyWith(history: const []);
  }
}

/// Download folder and limits (settings table, shared with the Tauri app).
/// Null until the manager is up.
final getSettingsProvider = FutureProvider<GetSettings?>((ref) async {
  if (!ref.watch(downloadsProvider.select((s) => s.ready))) return null;
  return ref.read(getApiProvider).settings();
});

// -------------------------------------------------------------- formatting

/// "765 Mo", "1,12 Go" (as the Tauri app: GB with 2 decimals, MB and KB
/// rounded), in the interface language.
String formatBytes(int bytes, {required String lang}) {
  const k = 1024.0;
  final fr = lang == 'fr';
  String num(double v, int digits) {
    final text = v.toStringAsFixed(digits);
    return fr ? text.replaceAll('.', ',') : text;
  }

  if (bytes >= k * k * k) {
    return '${num(bytes / (k * k * k), 2)} ${fr ? 'Go' : 'GB'}';
  }
  if (bytes >= k * k) return '${num(bytes / (k * k), 0)} ${fr ? 'Mo' : 'MB'}';
  if (bytes >= k) return '${num(bytes / k, 0)} ${fr ? 'Ko' : 'KB'}';
  return '$bytes ${fr ? 'o' : 'B'}';
}

/// "10,3 Mo/s".
String formatSpeed(double bytesPerSec, {required String lang}) {
  final fr = lang == 'fr';
  final text = (bytesPerSec / (1024 * 1024)).toStringAsFixed(1);
  return '${fr ? text.replaceAll('.', ',') : text} ${fr ? 'Mo/s' : 'MB/s'}';
}

/// "0:38", "1:02:05".
String etaLabel(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// Seconds left before an automatic retry.
int retryIn(DownloadTask t, DateTime now) {
  if (t.retryInSecs == null || t.retryAt == null) return 0;
  final left =
      t.retryInSecs! - now.difference(t.retryAt!).inMilliseconds / 1000;
  return left <= 0 ? 0 : left.ceil();
}

/// Pre-selected format: the source's recommended one, else the best quality
/// up to 1080p (sensible size), else the first offered.
FormatOffer? defaultFormat(List<FormatOffer> formats) {
  for (final f in formats) {
    if (f.tag == 'Recommended') return f;
  }
  int height(FormatOffer f) =>
      int.tryParse(RegExp(r'^\d+').stringMatch(f.quality) ?? '') ?? 0;
  final sized = [
    for (final f in formats)
      if (height(f) > 0 && height(f) <= 1080) f,
  ]..sort((a, b) => height(b).compareTo(height(a)));
  if (sized.isNotEmpty) return sized.first;
  return formats.isEmpty ? null : formats.first;
}

/// "1080p" from "1080p · 4K…"-like labels.
String shortQuality(FormatOffer f) => f.quality.split(' ·').first;

/// File title: "Tears of Steel (1080p)", or the plain title for an original
/// file.
String downloadTitle(MediaInfo info, FormatOffer f) =>
    f.id == 'original' ? info.title : '${info.title} (${shortQuality(f)})';

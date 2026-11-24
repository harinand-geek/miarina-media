import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/converter.dart';
import '../../src/rust/frb_generated.dart' show RustLib;
import '../playback/settings_store.dart';

export '../../src/rust/api/converter.dart'
    show ConvertJob, ConvertOptions, SourceInfo;

/// Convertir in the core (FFmpeg queue); tests use an in-memory one.
abstract interface class ConvertApi {
  Future<List<ConvertJob>> add(
    String category,
    String target,
    List<String> inputs,
    ConvertOptions options,
  );
  Future<List<ConvertJob>> jobs();
  Future<void> start({required bool multi});
  Future<void> stop();
  Future<void> remove(String id);
  Future<void> clear();
  Stream<ConvertJob> events();
  String defaultDir();
}

class RustConvertApi implements ConvertApi {
  @override
  Future<List<ConvertJob>> add(
    String category,
    String target,
    List<String> inputs,
    ConvertOptions options,
  ) => converterAdd(
    category: category,
    target: target,
    inputs: inputs,
    options: options,
  );

  @override
  Future<List<ConvertJob>> jobs() => converterJobs();

  @override
  Future<void> start({required bool multi}) => converterStart(multi: multi);

  @override
  Future<void> stop() => converterStop();

  @override
  Future<void> remove(String id) => converterRemove(id: id);

  @override
  Future<void> clear() => converterClear();

  @override
  Stream<ConvertJob> events() => converterEvents();

  @override
  String defaultDir() => converterDefaultDir();
}

final convertApiProvider = Provider<ConvertApi?>(
  (_) => Platform.isWindows && RustLib.instance.initialized
      ? RustConvertApi()
      : null,
);

/// The catalogue of the handoff: per category, formats then tools.
enum ConvertCategory { video, audio, image }

@immutable
class ConvertChoice {
  const ConvertChoice(this.category, this.target, {this.tool = false});

  final ConvertCategory category;

  /// A format ("mp4") or a tool ("join").
  final String target;
  final bool tool;

  /// Several files make one output.
  bool get joins => target == 'join';

  @override
  bool operator ==(Object other) =>
      other is ConvertChoice &&
      other.category == category &&
      other.target == target;

  @override
  int get hashCode => Object.hash(category, target);
}

/// Files sent from elsewhere (a recording's « Convertir »): the next
/// format or tool dialog starts with them.
final convertPendingProvider = NotifierProvider<_Pending, List<String>>(
  _Pending.new,
);

class _Pending extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> files) => state = files;
}

const convertCatalog = {
  ConvertCategory.video: [
    ConvertChoice(ConvertCategory.video, 'mp4'),
    ConvertChoice(ConvertCategory.video, 'mkv'),
    ConvertChoice(ConvertCategory.video, 'webm'),
    ConvertChoice(ConvertCategory.video, 'avi'),
    ConvertChoice(ConvertCategory.video, 'mov'),
    ConvertChoice(ConvertCategory.video, '3gp'),
    ConvertChoice(ConvertCategory.video, 'gif'),
    ConvertChoice(ConvertCategory.video, 'join', tool: true),
    ConvertChoice(ConvertCategory.video, 'cut', tool: true),
    ConvertChoice(ConvertCategory.video, 'crop', tool: true),
    ConvertChoice(ConvertCategory.video, 'compress', tool: true),
    ConvertChoice(ConvertCategory.video, 'frames', tool: true),
    // Opens Outils PC › Enregistrer l'écran.
    ConvertChoice(ConvertCategory.video, 'record', tool: true),
  ],
  ConvertCategory.audio: [
    ConvertChoice(ConvertCategory.audio, 'mp3'),
    ConvertChoice(ConvertCategory.audio, 'm4a'),
    ConvertChoice(ConvertCategory.audio, 'flac'),
    ConvertChoice(ConvertCategory.audio, 'wav'),
    ConvertChoice(ConvertCategory.audio, 'ogg'),
    ConvertChoice(ConvertCategory.audio, 'opus'),
    ConvertChoice(ConvertCategory.audio, 'extract', tool: true),
    ConvertChoice(ConvertCategory.audio, 'cut', tool: true),
    ConvertChoice(ConvertCategory.audio, 'join', tool: true),
  ],
  ConvertCategory.image: [
    ConvertChoice(ConvertCategory.image, 'png'),
    ConvertChoice(ConvertCategory.image, 'jpg'),
    ConvertChoice(ConvertCategory.image, 'webp'),
    ConvertChoice(ConvertCategory.image, 'ico'),
    ConvertChoice(ConvertCategory.image, 'bmp'),
    ConvertChoice(ConvertCategory.image, 'resize', tool: true),
  ],
};

/// Files each category's picker offers.
const convertExtensions = {
  ConvertCategory.video: [
    'mp4',
    'mkv',
    'webm',
    'avi',
    'mov',
    'm4v',
    'wmv',
    'flv',
    'ts',
    'mts',
    'm2ts',
    'mpg',
    'mpeg',
    '3gp',
    'ogv',
    'gif',
  ],
  ConvertCategory.audio: [
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'oga',
    'opus',
    'wma',
    'aif',
    'aiff',
    'mka',
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
  ],
  ConvertCategory.image: [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'gif',
    'tif',
    'tiff',
    'ico',
    'heic',
  ],
};

/// The extension a file chosen for [category] must have.
bool convertAccepts(ConvertCategory category, String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return convertExtensions[category]!.contains(
    path.substring(dot + 1).toLowerCase(),
  );
}

@immutable
class ConvertState {
  const ConvertState({
    this.jobs = const [],
    this.selected,
    this.running = false,
    this.multi = true,
    this.shutdown = false,
    this.notify = true,
    this.elapsed = Duration.zero,
    this.outDir = '',
    this.last,
    this.lastOptions,
  });

  final List<ConvertJob> jobs;
  final String? selected;
  final bool running;
  final bool multi;
  final bool shutdown;
  final bool notify;
  final Duration elapsed;
  final String outDir;

  /// The last format or tool chosen, for files dropped on the queue.
  final ConvertChoice? last;
  final ConvertOptions? lastOptions;

  bool get hasWork =>
      jobs.any((j) => j.state == 'waiting' || j.state == 'stopped');

  ConvertState copyWith({
    List<ConvertJob>? jobs,
    Object? selected = _keep,
    bool? running,
    bool? multi,
    bool? shutdown,
    bool? notify,
    Duration? elapsed,
    String? outDir,
    ConvertChoice? last,
    ConvertOptions? lastOptions,
  }) => ConvertState(
    jobs: jobs ?? this.jobs,
    selected: identical(selected, _keep) ? this.selected : selected as String?,
    running: running ?? this.running,
    multi: multi ?? this.multi,
    shutdown: shutdown ?? this.shutdown,
    notify: notify ?? this.notify,
    elapsed: elapsed ?? this.elapsed,
    outDir: outDir ?? this.outDir,
    last: last ?? this.last,
    lastOptions: lastOptions ?? this.lastOptions,
  );
}

const _keep = Object();

/// Why the queue ended, for the screen (toast, shutdown dialog).
enum ConvertEnd { finished, none }

final convertProvider = NotifierProvider<ConvertController, ConvertState>(
  ConvertController.new,
);

class ConvertController extends Notifier<ConvertState> {
  StreamSubscription<ConvertJob>? _events;
  Timer? _clock;
  DateTime? _since;
  Duration _before = Duration.zero;

  /// The screen shows the end of a run (toast, shutdown countdown).
  final _ended = StreamController<ConvertEnd>.broadcast();
  Stream<ConvertEnd> get ended => _ended.stream;

  ConvertApi? get _api => ref.read(convertApiProvider);

  @override
  ConvertState build() {
    final api = ref.watch(convertApiProvider);
    ref.onDispose(() {
      _events?.cancel();
      _clock?.cancel();
    });
    if (api == null) return const ConvertState();
    _events = api.events().listen(_onJob);
    unawaited(_load(api));
    return ConvertState(outDir: api.defaultDir());
  }

  Future<void> _load(ConvertApi api) async {
    final saved = await ref.read(settingsStoreProvider).read('convertDir');
    final jobs = await api.jobs();
    state = state.copyWith(
      jobs: jobs,
      outDir: saved is String && saved.isNotEmpty ? saved : null,
    );
  }

  void _onJob(ConvertJob job) {
    final jobs = [for (final j in state.jobs) j.id == job.id ? job : j];
    state = state.copyWith(jobs: jobs);
    final busy = jobs.any(
      (j) => j.state == 'converting' || j.state == 'waiting',
    );
    if (state.running && !busy) _finished();
  }

  void _finished() {
    _stopClock();
    state = state.copyWith(running: false);
    final done = state.jobs.any((j) => j.state == 'done');
    _ended.add(done ? ConvertEnd.finished : ConvertEnd.none);
  }

  void _startClock() {
    _since = DateTime.now();
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: _before + DateTime.now().difference(_since!),
      );
    });
  }

  void _stopClock() {
    if (_since != null) _before += DateTime.now().difference(_since!);
    _since = null;
    _clock?.cancel();
    _clock = null;
  }

  ConvertOptions optionsFor({
    String quality = 'source',
    int height = 0,
    int audioKbps = 0,
    int fromMs = 0,
    int toMs = 0,
    String crop = '',
    int frameEvery = 0,
    int width = 0,
    String codec = 'av1',
    int targetMb = 0,
  }) => ConvertOptions(
    quality: quality,
    height: height,
    audioKbps: audioKbps,
    fromMs: BigInt.from(fromMs),
    toMs: BigInt.from(toMs),
    crop: crop,
    frameEvery: frameEvery,
    width: width,
    codec: codec,
    targetMb: targetMb,
    outDir: state.outDir,
  );

  /// Adds files with a format or tool; they wait for "Démarrer".
  Future<void> add(
    ConvertChoice choice,
    List<String> files,
    ConvertOptions options,
  ) async {
    final api = _api;
    if (api == null || files.isEmpty) return;
    final added = await api.add(
      choice.category.name,
      choice.target,
      files,
      options,
    );
    state = state.copyWith(
      jobs: [...state.jobs, ...added],
      last: choice,
      lastOptions: options,
      selected: added.isEmpty ? state.selected : added.last.id,
    );
  }

  /// Files dropped on the queue: with the last format or tool, those of
  /// its category only. False when nothing was chosen yet.
  Future<bool> addDropped(List<String> files) async {
    final choice = state.last;
    final options = state.lastOptions;
    if (choice == null || options == null) return false;
    final fit = files.where((f) => convertAccepts(choice.category, f)).toList();
    if (fit.isEmpty) return true;
    if (choice.joins && fit.length < 2) return true;
    await add(choice, fit, options);
    return true;
  }

  Future<void> start() async {
    final api = _api;
    if (api == null || !state.hasWork) return;
    await api.start(multi: state.multi);
    state = state.copyWith(running: true);
    _startClock();
  }

  Future<void> stop() async {
    await _api?.stop();
  }

  Future<void> remove(String id) async {
    await _api?.remove(id);
    state = state.copyWith(
      jobs: [
        for (final j in state.jobs)
          if (j.id != id) j,
      ],
      selected: state.selected == id ? null : state.selected,
    );
  }

  /// Stops everything, empties the list and the elapsed time.
  Future<void> clear() async {
    await _api?.clear();
    _stopClock();
    _before = Duration.zero;
    state = state.copyWith(
      jobs: const [],
      selected: null,
      running: false,
      elapsed: Duration.zero,
    );
  }

  void select(String? id) => state = state.copyWith(selected: id);

  void setMulti(bool v) => state = state.copyWith(multi: v);
  void setShutdown(bool v) => state = state.copyWith(shutdown: v);
  void setNotify(bool v) => state = state.copyWith(notify: v);

  Future<void> setOutDir(String dir) async {
    state = state.copyWith(outDir: dir);
    await ref.read(settingsStoreProvider).write('convertDir', dir);
  }
}

/// Files dropped on the window from the Explorer (Windows runner).
final droppedFilesProvider = StreamProvider<List<String>>((ref) {
  final controller = StreamController<List<String>>();
  const channel = MethodChannel('org.miarina.media/drop');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'files' && call.arguments is List) {
      controller.add([
        for (final f in call.arguments as List)
          if (f is String) f,
      ]);
    }
  });
  ref.onDispose(() {
    channel.setMethodCallHandler(null);
    controller.close();
  });
  return controller.stream;
});

/// Windows' own shutdown, with its 60 s warning; [cancelShutdown] stops it.
Future<void> shutdownPc() => Process.run('shutdown', [
  '/s',
  '/t',
  '60',
  '/c',
  'Miarina Media : conversions terminées.',
]);

Future<void> cancelShutdown() => Process.run('shutdown', ['/a']);

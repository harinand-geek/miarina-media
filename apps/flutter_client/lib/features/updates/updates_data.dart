import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../src/rust/api/updates.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;
import '../library/library_data.dart' show appId;
import '../settings/settings_screen.dart' show appVersion;

export '../../src/rust/api/updates.dart'
    show UpdatePrefsInfo, UpdateRelease, UpdateStatusInfo;

/// App updates in the core (`api/updates.rs`, the 0.1.x rules); tests use a
/// fake. Errors carry the 0.1.x codes at the start of their text.
abstract interface class UpdatesApi {
  /// Release builds only (`MM_VERSION`), Windows and Android.
  bool get enabled;
  Future<rust.UpdateStatusInfo> status();
  Future<rust.UpdateRelease?> check();
  Future<rust.UpdateRelease> download();
  void cancel();
  int progress();
  Future<void> install();
  Future<rust.UpdatePrefsInfo> prefs();
  Future<rust.UpdatePrefsInfo> setPrefs(String channel, bool autoDownload);
  Future<bool> autoAllowed();
}

class RustUpdatesApi implements UpdatesApi {
  const RustUpdatesApi();

  static const _android = MethodChannel('org.miarina.media/app_update');

  @override
  bool get enabled =>
      (Platform.isWindows || Platform.isAndroid) &&
      appVersion.isNotEmpty &&
      RustLib.instance.initialized &&
      (!Platform.isAndroid || androidUpdateApk != null);

  @override
  Future<rust.UpdateStatusInfo> status() => rust.updatesStatus();

  @override
  Future<rust.UpdateRelease?> check() => rust.updatesCheck();

  @override
  Future<rust.UpdateRelease> download() => rust.updatesDownload();

  @override
  void cancel() => rust.updatesCancel();

  @override
  int progress() => rust.updatesProgress().toInt();

  /// Windows starts the installer from the core; Android checks the APK in
  /// the core, then the system installer opens it (AppUpdateChannel.kt).
  @override
  Future<void> install() async {
    await rust.updatesInstall();
    if (!Platform.isAndroid) return;
    final answer = await _android.invokeMethod<String>('installApk', {
      'path': androidUpdateApk,
    });
    if (answer == 'permission') throw Exception('update_permission');
  }

  @override
  Future<rust.UpdatePrefsInfo> prefs() => rust.updatesPrefs();

  @override
  Future<rust.UpdatePrefsInfo> setPrefs(String channel, bool autoDownload) =>
      rust.updatesSetPrefs(channel: channel, autoDownload: autoDownload);

  @override
  Future<bool> autoAllowed() => rust.updatesAutoAllowed();
}

final updatesApiProvider = Provider<UpdatesApi>((_) => const RustUpdatesApi());

/// Once at launch, before the interface (release builds): the cache folder
/// of 0.1.x, so an update it was downloading is found and cleaned up.
Future<void> startUpdates(String dbPath) async {
  if (appVersion.isEmpty) return;
  String cacheDir;
  if (Platform.isAndroid) {
    // Android: the app cache, the only folder the update file provider
    // serves (res/xml/update_paths.xml).
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      cacheDir = dir.path;
    } catch (_) {
      return;
    }
  } else if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) return;
    cacheDir = '$local${Platform.pathSeparator}$appId';
  } else {
    return;
  }
  try {
    await rust.updatesStart(
      installed: appVersion,
      cacheDir: cacheDir,
      dbPath: dbPath,
    );
    if (Platform.isAndroid) androidUpdateApk = '$cacheDir/miarina-update.apk';
  } catch (_) {
    // Updates stay off; the app works without them.
  }
}

/// Where the core keeps the verified APK on Android (set at launch).
String? androidUpdateApk;

enum UpdatePhase { idle, checking, available, downloading, ready, installing }

@immutable
class UpdatesState {
  const UpdatesState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.error = '',
    this.checked = false,
    this.installed = appVersion,
    this.downloaded = 0,
    this.channel = 'stable',
    this.autoDownload = false,
  });

  final UpdatePhase phase;
  final rust.UpdateRelease? release;

  /// Error code (`update_network`, `update_converting`) or message; empty
  /// when none.
  final String error;
  final bool checked;
  final String installed;

  /// Bytes on disk, resumable after a cancel, a failure or a restart.
  final int downloaded;
  final String channel;
  final bool autoDownload;

  bool get ready =>
      phase == UpdatePhase.ready || phase == UpdatePhase.installing;

  UpdatesState copyWith({
    UpdatePhase? phase,
    rust.UpdateRelease? release,
    bool clearRelease = false,
    String? error,
    bool? checked,
    String? installed,
    int? downloaded,
    String? channel,
    bool? autoDownload,
  }) => UpdatesState(
    phase: phase ?? this.phase,
    release: clearRelease ? null : release ?? this.release,
    error: error ?? this.error,
    checked: checked ?? this.checked,
    installed: installed ?? this.installed,
    downloaded: downloaded ?? this.downloaded,
    channel: channel ?? this.channel,
    autoDownload: autoDownload ?? this.autoDownload,
  );
}

/// The 0.1.x code of an error, else its text.
String updateError(Object e) {
  final s = '$e';
  for (final code in const [
    'update_converting',
    'update_network',
    'update_canceled',
    'update_permission',
  ]) {
    if (s.contains(code)) return code;
  }
  final i = s.indexOf('update: ');
  return i >= 0 ? s.substring(i + 8) : s;
}

final updatesProvider = NotifierProvider<UpdatesController, UpdatesState>(
  UpdatesController.new,
);

/// The 0.1.x `useUpdates` store: restore, check, download, cancel,
/// install, preferences. Installing never happens without a click.
class UpdatesController extends Notifier<UpdatesState> {
  static const _busy = {
    UpdatePhase.checking,
    UpdatePhase.downloading,
    UpdatePhase.ready,
    UpdatePhase.installing,
  };

  UpdatesApi get _api => ref.read(updatesApiProvider);

  @override
  UpdatesState build() => const UpdatesState();

  /// After launch: a ready or partial download from an earlier session.
  Future<void> restore() async {
    if (!_api.enabled) return;
    try {
      final status = await _api.status();
      final prefs = await _api.prefs();
      state = state.copyWith(
        installed: status.installed,
        channel: prefs.channel,
        autoDownload: prefs.autoDownload,
      );
      final r = status.release;
      if (r == null || state.phase != UpdatePhase.idle) return;
      state = state.copyWith(
        release: r,
        downloaded: status.downloaded.toInt(),
        phase: status.ready
            ? UpdatePhase.ready
            : status.downloading
            ? UpdatePhase.downloading
            : UpdatePhase.available,
      );
    } catch (_) {
      // Nothing restored: the next check starts from scratch.
    }
  }

  /// Returns the release found when the user should hear about it.
  Future<rust.UpdateRelease?> check() async {
    if (!_api.enabled || _busy.contains(state.phase)) return null;
    state = state.copyWith(phase: UpdatePhase.checking, error: '');
    try {
      final release = await _api.check();
      final known = state.release;
      state = state.copyWith(
        release: release,
        clearRelease: release == null,
        phase: release != null ? UpdatePhase.available : UpdatePhase.idle,
        checked: true,
        // Bytes of another version cannot be resumed.
        downloaded: release != null && known?.version == release.version
            ? state.downloaded
            : 0,
      );
      if (release == null) return null;
      // UPD-05: only when enabled and on an unmetered network; installing
      // still waits for the user.
      if (await _api.autoAllowed().catchError((_) => false)) {
        unawaited(download());
        return null;
      }
      return release;
    } catch (e) {
      state = state.copyWith(
        phase: state.release != null ? UpdatePhase.available : UpdatePhase.idle,
        error: updateError(e),
      );
      return null;
    }
  }

  Future<void> download() async {
    if (state.phase != UpdatePhase.available) return;
    state = state.copyWith(phase: UpdatePhase.downloading, error: '');
    try {
      final release = await _api.download();
      state = state.copyWith(
        release: release,
        phase: UpdatePhase.ready,
        downloaded: release.size.toInt(),
      );
    } catch (e) {
      final code = updateError(e);
      state = state.copyWith(
        phase: UpdatePhase.available,
        downloaded: _api.progress(),
        error: code == 'update_canceled' ? '' : code,
      );
    }
  }

  void cancel() {
    if (state.phase == UpdatePhase.downloading) _api.cancel();
  }

  /// Starts the verified installer; true when the app must now close
  /// (Windows). On Android the system installer opens over the app, which
  /// keeps running until Android replaces it.
  Future<bool> install() async {
    if (state.phase != UpdatePhase.ready) return false;
    state = state.copyWith(phase: UpdatePhase.installing, error: '');
    try {
      await _api.install();
      if (Platform.isAndroid) {
        state = state.copyWith(phase: UpdatePhase.ready);
        return false;
      }
      return true;
    } catch (e) {
      // The file may have been removed if it no longer matched.
      rust.UpdateStatusInfo? status;
      try {
        status = await _api.status();
      } catch (_) {}
      state = state.copyWith(
        phase: status != null && !status.ready
            ? (status.release != null
                  ? UpdatePhase.available
                  : UpdatePhase.idle)
            : UpdatePhase.ready,
        error: updateError(e),
      );
      return false;
    }
  }

  Future<void> setPrefs({String? channel, bool? autoDownload}) async {
    state = state.copyWith(channel: channel, autoDownload: autoDownload);
    if (!_api.enabled) return;
    try {
      final saved = await _api.setPrefs(state.channel, state.autoDownload);
      state = state.copyWith(
        channel: saved.channel,
        autoDownload: saved.autoDownload,
      );
    } catch (e) {
      state = state.copyWith(error: updateError(e));
    }
  }
}

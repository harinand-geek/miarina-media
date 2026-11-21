import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_data.dart';
import 'get_data.dart';

/// Android download notifications (design_handoff_android_v2), as in the
/// Tauri app: at most once a second, the downloads in progress go to
/// `DownloadNotificationsChannel.kt` (foreground service, progress
/// notification with Pause / Cancel / Pause all) and the ones finished in
/// this session get "Download complete · tap to play". The buttons pressed
/// there come back with the reply and are applied here.
class DownloadNotifier {
  DownloadNotifier(this._ref);

  final Ref _ref;
  static const _channel = MethodChannel(
    'org.miarina.media/download_notifications',
  );

  Timer? _timer;
  final _followed = <String>{};
  final _announced = <String>{};
  bool _wasActive = false;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void dispose() => _timer?.cancel();

  Future<void> _tick() async {
    final state = _ref.read(downloadsProvider);
    if (!state.ready) return;
    final t = lookupL10n(_locale());
    final active =
        [
          for (final task in state.ordered)
            if (isActive(task.state)) task,
        ]..sort(
          (a, b) => (a.state == 'downloading' ? 0 : 1).compareTo(
            b.state == 'downloading' ? 0 : 1,
          ),
        );
    final finished = <Map<String, Object?>>[];
    for (final task in state.tasks.values) {
      if (isActive(task.state)) _followed.add(task.id);
      // Only downloads followed in this session are announced, once.
      if (task.state == 'completed' &&
          _followed.contains(task.id) &&
          _announced.add(task.id)) {
        final size = task.total ?? task.downloaded;
        finished.add({
          'id': task.id,
          'title': task.info.title,
          'text':
              '${formatBytes(size, lang: t.localeName)} · ${t.dlNotifTapToPlay}',
        });
      }
    }
    // Idle and nothing new: nothing to send.
    if (active.isEmpty && finished.isEmpty && !_wasActive) return;
    _wasActive = active.isNotEmpty;
    try {
      final actions = await _channel.invokeListMethod<Object?>('update', {
        'labels': {
          'pause': t.dlNotifPause,
          'cancel': t.dlNotifCancel,
          'pauseAll': t.dlNotifPauseAll,
          'complete': t.dlNotifComplete,
          'several': t.dlNotifSeveral,
          'channelProgress': t.dlNotifChannelProgress,
          'channelDone': t.dlNotifChannelDone,
        },
        'active': [
          for (final task in active)
            {
              'id': task.id,
              'title': task.info.title,
              'text': describe(task, t),
              'percent': percentOf(task),
            },
        ],
        'finished': finished,
      });
      await _apply(actions ?? const []);
    } catch (e) {
      debugPrint('download notification: $e');
    }
  }

  Future<void> _apply(List<Object?> actions) async {
    final api = _ref.read(getApiProvider);
    for (final raw in actions) {
      if (raw is! Map) continue;
      final id = raw['id'] is String ? raw['id'] as String : '';
      switch (raw['action']) {
        case 'pause' when id.isNotEmpty:
          await api.action(id, 'pause');
        case 'cancel' when id.isNotEmpty:
          await api.action(id, 'cancel');
        case 'pause_all':
          await api.pauseAll(true);
      }
    }
  }

  Locale _locale() {
    final chosen = _ref.read(appearanceProvider).value?.language;
    final code = chosen ?? PlatformDispatcher.instance.locale.languageCode;
    return Locale(code == 'en' ? 'en' : 'fr');
  }
}

/// Work that keeps the service (and its notification) running.
bool isActive(String state) => const {
  'queued',
  'analyzing',
  'waiting',
  'downloading',
  'processing',
}.contains(state);

/// 0–100, -1 when unknown (indeterminate bar).
int percentOf(DownloadTask task) {
  final total = task.total;
  if (task.state == 'processing' || total == null || total == 0) return -1;
  return (task.downloaded.clamp(0, total) * 100 ~/ total);
}

/// "12 Mo sur 25 Mo · 1,2 Mo/s · 1 min restantes" (design).
String describe(DownloadTask task, L10n t) {
  switch (task.state) {
    case 'queued' || 'waiting':
      return t.dlNotifWaiting;
    case 'analyzing':
      return t.dlNotifAnalyzing;
    case 'processing':
      return t.dlNotifProcessing;
  }
  final lang = t.localeName;
  final total = task.total;
  final parts = [
    total != null
        ? t.dlNotifOf(
            formatBytes(task.downloaded, lang: lang),
            formatBytes(total, lang: lang),
          )
        : formatBytes(task.downloaded, lang: lang),
  ];
  if (task.bytesPerSec > 0) {
    final speed = (task.bytesPerSec / (1024 * 1024)).toStringAsFixed(1);
    parts.add(
      t.dlNotifSpeed(lang == 'fr' ? speed.replaceAll('.', ',') : speed),
    );
  }
  final eta = task.etaSecs;
  if (eta != null) {
    parts.add(
      eta < 60
          ? t.dlNotifLeftSoon
          : eta < 3600
          ? t.dlNotifLeftMin((eta + 59) ~/ 60)
          : t.dlNotifLeftHours(eta ~/ 3600, (eta % 3600) ~/ 60),
    );
  }
  return parts.join(' · ');
}

/// Started with the app on Android (watched by the app root).
final downloadNotifierProvider = Provider<void>((ref) {
  if (!Platform.isAndroid) return;
  final notifier = DownloadNotifier(ref)..start();
  ref.onDispose(notifier.dispose);
});

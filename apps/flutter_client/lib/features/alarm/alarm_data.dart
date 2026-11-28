import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/media_engine.dart';
import '../cinema/screen_control.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';
import '../playback/settings_store.dart';
import '../playback/smart_queue.dart';
import '../playback/taste.dart';

/// Music alarm (2026-11-28, decision 0013 proposal 8): wake up to the day's
/// mix, the favourites or the whole library, the sound rising slowly.
enum AlarmSource { mix, favorites, all }

@immutable
class AlarmSettings {
  const AlarmSettings({
    this.enabled = false,
    this.hour = 7,
    this.minute = 0,
    this.days = const {},
    this.source = AlarmSource.mix,
    this.volume = 0.6,
    this.gradual = true,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// Weekdays it rings ([DateTime.monday]..[DateTime.sunday]); empty: once.
  final Set<int> days;
  final AlarmSource source;

  /// The phone's media volume at the alarm (Android), 0..1.
  final double volume;

  /// The music starts low and rises over [rampTime].
  final bool gradual;

  static const rampTime = Duration(seconds: 60);

  AlarmSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? days,
    AlarmSource? source,
    double? volume,
    bool? gradual,
  }) => AlarmSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    days: days ?? this.days,
    source: source ?? this.source,
    volume: volume ?? this.volume,
    gradual: gradual ?? this.gradual,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'days': (days.toList()..sort()),
    'source': source.name,
    'volume': volume,
    'gradual': gradual,
  };

  static AlarmSettings fromJson(Object? json) {
    if (json is! Map) return const AlarmSettings();
    int clampInt(Object? v, int min, int max, int fallback) =>
        v is int ? v.clamp(min, max) : fallback;
    final days = json['days'];
    return AlarmSettings(
      enabled: json['enabled'] == true,
      hour: clampInt(json['hour'], 0, 23, 7),
      minute: clampInt(json['minute'], 0, 59, 0),
      days: days is List
          ? {
              for (final d in days)
                if (d is int && d >= 1 && d <= 7) d,
            }
          : const {},
      source: AlarmSource.values.asNameMap()[json['source']] ?? AlarmSource.mix,
      volume: json['volume'] is num
          ? (json['volume'] as num).toDouble().clamp(0.1, 1.0)
          : 0.6,
      gradual: json['gradual'] != false,
    );
  }
}

/// When the alarm rings next after [now]; null when it is off.
DateTime? nextAlarm(AlarmSettings s, DateTime now) {
  if (!s.enabled) return null;
  for (var i = 0; i <= 7; i++) {
    final at = DateTime(now.year, now.month, now.day + i, s.hour, s.minute);
    if (!at.isAfter(now)) continue;
    if (s.days.isEmpty || s.days.contains(at.weekday)) return at;
  }
  return null;
}

/// The platform's alarm: Android's system alarm (AlarmChannel.kt), or a
/// timer while the app runs (Windows).
abstract interface class AlarmApi {
  /// Sets the alarm at [at]; false when the system refuses exact alarms.
  Future<bool> schedule(DateTime at);
  Future<void> cancel();
  Future<bool> canExact();
  Future<void> requestExact();

  /// The app was opened by the alarm (asked once at launch).
  Future<bool> takeLaunch();

  /// Rings while the app runs.
  Stream<void> get fired;

  /// The alarm was stopped (the app leaves the lock screen).
  Future<void> release();

  /// Whether the alarm also rings with the app closed.
  bool get ringsWhenClosed;
}

class AndroidAlarmApi implements AlarmApi {
  AndroidAlarmApi() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fired') _fired.add(null);
    });
  }

  static const _channel = MethodChannel('org.miarina.media/alarm');
  final _fired = StreamController<void>.broadcast();

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> schedule(DateTime at) async =>
      await _call<bool>('schedule', {'atMs': at.millisecondsSinceEpoch}) ??
      false;

  @override
  Future<void> cancel() => _call<void>('cancel');

  @override
  Future<bool> canExact() async => await _call<bool>('canExact') ?? false;

  @override
  Future<void> requestExact() => _call<void>('requestExact');

  @override
  Future<bool> takeLaunch() async => await _call<bool>('takeLaunch') ?? false;

  @override
  Stream<void> get fired => _fired.stream;

  @override
  Future<void> release() => _call<void>('release');

  @override
  bool get ringsWhenClosed => true;
}

/// Windows: a timer, so the app must be open.
class TimerAlarmApi implements AlarmApi {
  Timer? _timer;
  final _fired = StreamController<void>.broadcast();

  @override
  Future<bool> schedule(DateTime at) async {
    _timer?.cancel();
    final wait = at.difference(DateTime.now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _fired.add(null);
    });
    return true;
  }

  @override
  Future<void> cancel() async => _timer?.cancel();

  @override
  Future<bool> canExact() async => true;

  @override
  Future<void> requestExact() async {}

  @override
  Future<bool> takeLaunch() async => false;

  @override
  Stream<void> get fired => _fired.stream;

  @override
  Future<void> release() async {}

  @override
  bool get ringsWhenClosed => false;
}

final alarmApiProvider = Provider<AlarmApi>(
  (_) => Platform.isAndroid ? AndroidAlarmApi() : TimerAlarmApi(),
);

@immutable
class AlarmState {
  const AlarmState({
    this.settings = const AlarmSettings(),
    this.next,
    this.exactAllowed = true,
    this.ringing = false,
    this.snoozedUntil,
  });

  final AlarmSettings settings;

  /// When it rings next (a snooze included).
  final DateTime? next;

  /// Android 12+: the user allowed exact alarms.
  final bool exactAllowed;
  final bool ringing;
  final DateTime? snoozedUntil;

  AlarmState copyWith({
    AlarmSettings? settings,
    DateTime? Function()? next,
    bool? exactAllowed,
    bool? ringing,
    DateTime? Function()? snoozedUntil,
  }) => AlarmState(
    settings: settings ?? this.settings,
    next: next == null ? this.next : next(),
    exactAllowed: exactAllowed ?? this.exactAllowed,
    ringing: ringing ?? this.ringing,
    snoozedUntil: snoozedUntil == null ? this.snoozedUntil : snoozedUntil(),
  );
}

const _settingsKey = 'alarm';

/// Snooze length.
const alarmSnooze = Duration(minutes: 10);

final alarmProvider = NotifierProvider<AlarmController, AlarmState>(
  AlarmController.new,
);

class AlarmController extends Notifier<AlarmState> {
  Timer? _ramp;
  late Future<void> _loaded;

  @override
  AlarmState build() {
    final api = ref.watch(alarmApiProvider);
    final fired = api.fired.listen((_) => unawaited(ring()));
    ref.onDispose(() {
      fired.cancel();
      _ramp?.cancel();
    });
    _loaded = Future.microtask(_load);
    return const AlarmState();
  }

  Future<void> _load() async {
    final api = ref.read(alarmApiProvider);
    try {
      final s = AlarmSettings.fromJson(
        await ref.read(settingsStoreProvider).read(_settingsKey),
      );
      state = state.copyWith(settings: s);
    } catch (_) {}
    state = state.copyWith(exactAllowed: await api.canExact());
    // Set again at each launch (the system may have dropped it).
    await _reschedule();
    if (await api.takeLaunch()) await ring();
  }

  Future<void> ready() => _loaded;

  /// The exact-alarm permission may have just been given (back from the
  /// system's page).
  Future<void> refreshPermission() async {
    final allowed = await ref.read(alarmApiProvider).canExact();
    state = state.copyWith(exactAllowed: allowed);
    if (allowed) await _reschedule();
  }

  Future<void> requestExact() => ref.read(alarmApiProvider).requestExact();

  Future<void> save(AlarmSettings next) async {
    await _loaded;
    state = state.copyWith(settings: next, snoozedUntil: () => null);
    try {
      await ref.read(settingsStoreProvider).write(_settingsKey, next.toJson());
    } catch (_) {}
    await _reschedule();
  }

  Future<void> _reschedule() async {
    final api = ref.read(alarmApiProvider);
    final snooze = state.snoozedUntil;
    final at = snooze != null && snooze.isAfter(DateTime.now())
        ? snooze
        : nextAlarm(state.settings, DateTime.now());
    state = state.copyWith(next: () => at);
    if (at == null) {
      await api.cancel();
      return;
    }
    final ok = await api.schedule(at);
    state = state.copyWith(exactAllowed: ok || !api.ringsWhenClosed);
  }

  /// The alarm rings: the music chosen starts, low then rising, and the
  /// alarm screen shows. A one-time alarm turns itself off.
  Future<void> ring() async {
    if (state.ringing) return;
    state = state.copyWith(ringing: true, snoozedUntil: () => null);
    final s = state.settings;
    if (s.days.isEmpty && s.enabled) {
      await save(s.copyWith(enabled: false));
    } else {
      await _reschedule();
    }
    final entries = await _music(s.source);
    final engine = ref.read(mediaEngineProvider);
    if (engine == null || entries.isEmpty) return;
    await ref.read(screenControlProvider)?.setVolume(s.volume);
    await engine.setVolume(s.gradual ? 0.08 : 1);
    await ref
        .read(queueProvider.notifier)
        .playAll(entries, inOrder: true, fromStart: true);
    // Again once the track is open: an engine may reset it on opening.
    if (s.gradual) {
      await engine.setVolume(0.08);
      _rampUp(engine);
    }
  }

  void _rampUp(MediaEngine engine) {
    _ramp?.cancel();
    const step = Duration(seconds: 2);
    final steps = AlarmSettings.rampTime.inSeconds ~/ step.inSeconds;
    var i = 0;
    _ramp = Timer.periodic(step, (t) {
      i++;
      // Ears hear loudness on a curve: the square rises gently first.
      final v = math.pow(i / steps, 2).toDouble().clamp(0.08, 1.0);
      unawaited(engine.setVolume(v));
      if (i >= steps) t.cancel();
    });
  }

  /// « Arrêter »: the music stops, the volume comes back.
  Future<void> stop() async {
    _ramp?.cancel();
    final engine = ref.read(mediaEngineProvider);
    await engine?.pause();
    await engine?.setVolume(1);
    state = state.copyWith(ringing: false);
    await ref.read(alarmApiProvider).release();
  }

  /// « Encore 10 min »: silence, and the alarm rings again later.
  Future<void> snooze() async {
    await stop();
    state = state.copyWith(snoozedUntil: () => DateTime.now().add(alarmSnooze));
    await _reschedule();
  }

  Future<List<QueueEntry>> _music(AlarmSource source) async {
    final api = ref.read(libraryApiProvider);
    try {
      final page = await api.tracks(
        search: '',
        favoritesOnly: source == AlarmSource.favorites,
        offset: 0,
        limit: source == AlarmSource.favorites ? 200 : 3000,
      );
      var items = [
        for (final i in page.items)
          if (!i.isVideo && !i.missing) i,
      ];
      // No favourites yet: the whole library rather than silence.
      if (items.isEmpty && source == AlarmSource.favorites) {
        return await _music(AlarmSource.all);
      }
      final random = math.Random();
      if (source == AlarmSource.mix) {
        await ref.read(tasteProvider.notifier).ready();
        final plays = await ref.read(playbackMemoryProvider).history();
        items = dailyMixPicks(
          library: items,
          taste: ref.read(tasteProvider),
          recentIds: [for (final p in plays) p.id],
          random: random,
          now: DateTime.now(),
          part: dayPart(DateTime.now()),
        );
      } else {
        items = [...items]..shuffle(random);
        items = items.take(50).toList();
      }
      return [for (final i in items) queueEntryOf(i)];
    } catch (_) {
      return const [];
    }
  }
}

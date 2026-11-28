import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_route.dart';
import 'playback.dart';
import 'settings_store.dart';

enum EqPreset { flat, bass, voice, rock, classic, custom }

/// Bands of the design (W-M3 Son, A-03c), in Hz.
const eqBands = ['60', '230', '910', '3,6k', '7k', '14k'];
const eqMaxDb = 12.0;

/// Same presets as the shipped app (apps/client equalizer.ts): design
/// positions 0–100 with 50 = 0 dB, rounded to half decibels.
List<double> _fromDesign(List<int> levels) => [
  for (final v in levels) ((v - 50) / 50 * eqMaxDb * 2).round() / 2,
];

final eqPresets = <EqPreset, List<double>>{
  EqPreset.flat: _fromDesign([50, 50, 50, 50, 50, 50]),
  EqPreset.bass: _fromDesign([78, 68, 52, 48, 50, 54]),
  EqPreset.voice: _fromDesign([40, 48, 66, 70, 58, 46]),
  EqPreset.rock: _fromDesign([70, 58, 44, 52, 64, 70]),
  EqPreset.classic: _fromDesign([60, 54, 50, 48, 56, 64]),
};

@immutable
class EqualizerState {
  const EqualizerState({
    this.enabled = false,
    this.preset = EqPreset.flat,
    this.gains = const [0, 0, 0, 0, 0, 0],
    this.supported,
    this.perOutput = true,
    this.route,
  });

  final bool enabled;
  final EqPreset preset;
  final List<double> gains;

  /// Whether the output applies it (Android depends on the device); null
  /// until the engine answered.
  final bool? supported;

  /// One setting per output (decision 0013, proposal 9): the Bluetooth
  /// headset, the wired one and the speaker each keep theirs, taken back
  /// when the sound goes there again.
  final bool perOutput;

  /// Where the sound goes now; null when unknown.
  final AudioRoute? route;

  EqualizerState copyWith({
    bool? enabled,
    EqPreset? preset,
    List<double>? gains,
    bool? supported,
    bool? perOutput,
    AudioRoute? route,
  }) => EqualizerState(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    gains: gains ?? this.gains,
    supported: supported ?? this.supported,
    perOutput: perOutput ?? this.perOutput,
    route: route ?? this.route,
  );

  /// The same output, with [saved]'s settings.
  EqualizerState withSettingsOf(EqualizerState saved) => copyWith(
    enabled: saved.enabled,
    preset: saved.preset,
    gains: saved.gains,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'preset': preset.name,
    'gains': gains,
  };

  static EqualizerState fromJson(Object? json) {
    if (json is! Map) return const EqualizerState();
    final raw = json['gains'];
    final gains =
        raw is List &&
            raw.length == eqBands.length &&
            raw.every((g) => g is num)
        ? [for (final g in raw) (g as num).toDouble().clamp(-eqMaxDb, eqMaxDb)]
        : null;
    if (gains == null) return const EqualizerState();
    return EqualizerState(
      enabled: json['enabled'] == true,
      preset: EqPreset.values.asNameMap()[json['preset']] ?? EqPreset.custom,
      gains: gains,
    );
  }
}

const _key = 'equalizer';

/// `{"perOutput": bool, "routes": {"<AudioRoute.key>": <equalizer>}}`.
const _outputsKey = 'equalizerOutputs';

/// Outputs remembered at most (the last used kept).
const _maxOutputs = 20;

final equalizerProvider = NotifierProvider<EqualizerController, EqualizerState>(
  EqualizerController.new,
);

class EqualizerController extends Notifier<EqualizerState> {
  late Future<void> _restored;

  /// Settings per output, by [AudioRoute.key], the last used last.
  Map<String, Object?> _routes = {};

  @override
  EqualizerState build() {
    _restored = Future.microtask(_restore);
    ref.listen(audioRouteProvider, (_, next) {
      final route = next.value;
      if (route != null) unawaited(_onRoute(route));
    }, fireImmediately: true);
    return const EqualizerState();
  }

  Future<void> _restore() async {
    try {
      final saved = EqualizerState.fromJson(
        await ref.read(settingsStoreProvider).read(_key),
      );
      final outputs = await ref.read(settingsStoreProvider).read(_outputsKey);
      var perOutput = true;
      if (outputs is Map) {
        perOutput = outputs['perOutput'] != false;
        final routes = outputs['routes'];
        if (routes is Map) {
          _routes = {
            for (final e in routes.entries)
              if (e.key is String) e.key as String: e.value,
          };
        }
      }
      state = saved.copyWith(perOutput: perOutput, route: state.route);
    } catch (_) {
      // Unreadable setting: defaults stay.
    }
    await _apply();
  }

  /// The sound went elsewhere: that output's settings come back (a new
  /// output starts from the current ones).
  Future<void> _onRoute(AudioRoute route) async {
    await _restored;
    if (state.route == route) return;
    if (!state.perOutput) {
      state = state.copyWith(route: route);
      return;
    }
    final saved = _routes[route.key];
    if (saved != null) {
      state = state
          .withSettingsOf(EqualizerState.fromJson(saved))
          .copyWith(route: route);
      await _apply();
      try {
        await ref.read(settingsStoreProvider).write(_key, state.toJson());
      } catch (_) {}
    } else {
      state = state.copyWith(route: route);
    }
    await _saveOutputs();
  }

  /// « Un réglage par sortie » on or off.
  Future<void> setPerOutput(bool on) async {
    state = state.copyWith(perOutput: on);
    await _saveOutputs();
  }

  Future<void> _saveOutputs() async {
    final route = state.route;
    if (state.perOutput && route != null) {
      _routes
        ..remove(route.key)
        ..[route.key] = state.toJson();
      while (_routes.length > _maxOutputs) {
        _routes.remove(_routes.keys.first);
      }
    }
    try {
      await ref.read(settingsStoreProvider).write(_outputsKey, {
        'perOutput': state.perOutput,
        'routes': _routes,
      });
    } catch (_) {}
  }

  Future<void> setEnabled(bool on) => _commit(state.copyWith(enabled: on));

  Future<void> setPreset(EqPreset preset) {
    final gains = eqPresets[preset];
    if (gains == null) return Future.value();
    return _commit(
      state.copyWith(preset: preset, gains: List.of(gains), enabled: true),
    );
  }

  Future<void> setGain(int band, double db) {
    final gains = List.of(state.gains)..[band] = (db * 2).round() / 2;
    return _commit(
      state.copyWith(gains: gains, preset: EqPreset.custom, enabled: true),
    );
  }

  Future<void> _commit(EqualizerState next) async {
    state = next;
    await _apply();
    try {
      await ref.read(settingsStoreProvider).write(_key, next.toJson());
    } catch (_) {
      // Not saved: still applied for this session.
    }
    if (next.perOutput && next.route != null) await _saveOutputs();
  }

  Future<void> _apply() async {
    final engine = ref.read(mediaEngineProvider);
    if (engine == null || !engine.capabilities.equalizer) {
      state = state.copyWith(supported: false);
      return;
    }
    final supported = await engine.setEqualizer(
      state.enabled ? state.gains : null,
    );
    if (supported != null) state = state.copyWith(supported: supported);
  }
}

/// Keeps the equalizer alive from launch: its saved setting reaches the
/// engine, and it follows the output even when no sound panel is open.
/// Watched by the app root.
final equalizerKeeperProvider = Provider<void>((ref) {
  ref.listen(equalizerProvider, (_, _) {});
});

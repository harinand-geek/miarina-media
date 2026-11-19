import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final bool enabled;
  final EqPreset preset;
  final List<double> gains;

  /// Whether the output applies it (Android depends on the device); null
  /// until the engine answered.
  final bool? supported;

  EqualizerState copyWith({
    bool? enabled,
    EqPreset? preset,
    List<double>? gains,
    bool? supported,
  }) => EqualizerState(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    gains: gains ?? this.gains,
    supported: supported ?? this.supported,
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

final equalizerProvider = NotifierProvider<EqualizerController, EqualizerState>(
  EqualizerController.new,
);

class EqualizerController extends Notifier<EqualizerState> {
  @override
  EqualizerState build() {
    Future.microtask(_restore);
    return const EqualizerState();
  }

  Future<void> _restore() async {
    try {
      final saved = EqualizerState.fromJson(
        await ref.read(settingsStoreProvider).read(_key),
      );
      state = saved;
    } catch (_) {
      // Unreadable setting: defaults stay.
    }
    await _apply();
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

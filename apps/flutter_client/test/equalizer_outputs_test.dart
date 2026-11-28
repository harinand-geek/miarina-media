import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/playback/audio_route.dart';
import 'package:miarina_media/features/playback/equalizer.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

class FakeRoutes implements AudioRouteSource {
  FakeRoutes(this.now);

  AudioRoute now;
  final _changes = StreamController<AudioRoute>.broadcast();

  void go(AudioRoute r) {
    now = r;
    _changes.add(r);
  }

  @override
  Future<AudioRoute?> current() async => now;

  @override
  Stream<AudioRoute> get changes => _changes.stream;
}

void main() {
  const speaker = AudioRoute(AudioRouteKind.speaker);
  const buds = AudioRoute(AudioRouteKind.bluetooth, 'JBL Tune');
  late FakeEngine engine;
  late FakeSettingsStore store;
  late FakeRoutes routes;
  late ProviderContainer container;
  EqualizerController eq() => container.read(equalizerProvider.notifier);
  EqualizerState state() => container.read(equalizerProvider);

  Future<void> start() async {
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        settingsStoreProvider.overrideWithValue(store),
        audioRouteSourceProvider.overrideWithValue(routes),
      ],
    );
    // Kept alive as the app root does (equalizerKeeperProvider).
    container.listen(equalizerKeeperProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() {
    engine = FakeEngine();
    store = FakeSettingsStore();
    routes = FakeRoutes(speaker);
  });
  tearDown(() => container.dispose());

  test('each output keeps its own setting and gets it back', () async {
    await start();
    expect(state().route, speaker);
    await eq().setPreset(EqPreset.voice);

    // Bluetooth headset: starts from the current setting, then its own.
    routes.go(buds);
    await pumpEventQueue();
    expect(state().route, buds);
    expect(state().preset, EqPreset.voice);
    await eq().setPreset(EqPreset.bass);
    expect(engine.equalizer, eqPresets[EqPreset.bass]);

    routes.go(speaker);
    await pumpEventQueue();
    expect(state().preset, EqPreset.voice);
    expect(engine.equalizer, eqPresets[EqPreset.voice]);

    routes.go(buds);
    await pumpEventQueue();
    expect(state().preset, EqPreset.bass);
    expect(engine.equalizer, eqPresets[EqPreset.bass]);

    // Kept for the next launch.
    container.dispose();
    routes = FakeRoutes(speaker);
    await start();
    expect(state().preset, EqPreset.voice);
    routes.go(buds);
    await pumpEventQueue();
    expect(state().preset, EqPreset.bass);
  });

  test('turned off: one setting for every output', () async {
    await start();
    await eq().setPerOutput(false);
    await eq().setPreset(EqPreset.rock);
    routes.go(buds);
    await pumpEventQueue();
    await eq().setPreset(EqPreset.classic);
    routes.go(speaker);
    await pumpEventQueue();
    expect(state().preset, EqPreset.classic);
    expect(state().perOutput, isFalse);
  });

  test('keys: each Bluetooth device apart, wired headsets together', () {
    expect(buds.key, 'bluetooth:jbl tune');
    expect(
      const AudioRoute(AudioRouteKind.wired, 'USB-C').key,
      const AudioRoute(AudioRouteKind.wired, 'Jack').key,
    );
    expect(const AudioRoute(AudioRouteKind.output, 'auto').key, 'output:auto');
  });
}

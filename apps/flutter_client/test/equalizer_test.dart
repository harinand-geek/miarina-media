import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/playback/equalizer.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

void main() {
  late FakeEngine engine;
  late FakeSettingsStore store;
  late ProviderContainer container;
  EqualizerController eq() => container.read(equalizerProvider.notifier);
  EqualizerState state() => container.read(equalizerProvider);

  setUp(() {
    engine = FakeEngine();
    store = FakeSettingsStore();
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        settingsStoreProvider.overrideWithValue(store),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> start() async {
    container.read(equalizerProvider);
    await pumpEventQueue();
  }

  test('presets match the shipped app and reach the engine', () async {
    await start();
    await eq().setPreset(EqPreset.voice);
    expect(state().enabled, isTrue);
    expect(state().gains, [-2.5, -0.5, 4.0, 5.0, 2.0, -1.0]);
    expect(engine.equalizer, state().gains);
    await eq().setEnabled(false);
    expect(engine.equalizer, isNull);
  });

  test('moving a band makes the setting custom and is saved', () async {
    await start();
    await eq().setPreset(EqPreset.bass);
    await eq().setGain(2, 3.3);
    expect(state().preset, EqPreset.custom);
    expect(state().gains[2], 3.5);
    final saved = store.values['equalizer']! as Map;
    expect(saved['preset'], 'custom');
    expect((saved['gains'] as List)[2], 3.5);
  });

  test('the saved setting is applied again at start', () async {
    store.values['equalizer'] = {
      'enabled': true,
      'preset': 'rock',
      'gains': [7, 3, -2.5, 0.5, 5.5, 7],
    };
    await start();
    expect(state().preset, EqPreset.rock);
    expect(engine.equalizer, [7, 3, -2.5, 0.5, 5.5, 7]);
  });

  test('an output without equalizer is reported, not simulated', () async {
    engine.equalizerSupported = false;
    await start();
    await eq().setPreset(EqPreset.rock);
    expect(state().supported, isFalse);
  });

  test('corrupt saved values fall back to defaults', () async {
    store.values['equalizer'] = {
      'enabled': true,
      'gains': [1, 2],
    };
    await start();
    expect(state().enabled, isFalse);
    expect(state().gains, everyElement(0));
  });
}

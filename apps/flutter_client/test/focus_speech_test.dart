import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'support/fakes.dart';

QueueEntry entry(String name, {String? focus}) => QueueEntry(
  source: MediaSource.file('C:/m/$name.mp3'),
  title: name,
  focusKey: focus,
);

void main() {
  test('skip silences and voice boost: Focus programs only', () async {
    final engine = FakeEngine();
    final settings = FakeSettingsStore()
      ..values['focusSpeech'] = {'skipSilence': true, 'voiceBoost': false};
    final container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
        settingsStoreProvider.overrideWithValue(settings),
        presenceCheckProvider.overrideWithValue((_) async => true),
      ],
    );
    addTearDown(container.dispose);
    container.read(focusSpeechProvider);
    await container.read(speechAidsProvider.future);
    final queue = container.read(queueProvider.notifier);

    await queue.playAll([entry('episode', focus: 'podcast:radio')]);
    await pumpEventQueue();
    expect(engine.speechAids, (true, false));

    await container
        .read(speechAidsProvider.notifier)
        .save(const SpeechAids(skipSilence: true, voiceBoost: true));
    await pumpEventQueue();
    expect(engine.speechAids, (true, true));
    expect(settings.values['focusSpeech'], {
      'skipSilence': true,
      'voiceBoost': true,
    });

    await queue.playAll([entry('song')]);
    await pumpEventQueue();
    expect(engine.speechAids, (false, false), reason: 'never for music');
  });
}

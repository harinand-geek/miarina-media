import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/series_audio.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';

import 'support/fakes.dart';

QueueEntry episode(int n, {String series = 'Le Dernier Ferry'}) => QueueEntry(
  source: MediaSource.file('C:/v/s01e0$n.mkv'),
  title: 'Épisode $n',
  album: series,
  isVideo: true,
);

const tracks = [
  TrackInfo(id: '1', language: 'fr', codec: 'ac3'),
  TrackInfo(id: '2', language: 'en', codec: 'aac'),
];

void main() {
  test('the language picked for an episode is kept for the series', () async {
    final engine = FakeEngine();
    final store = FakePlaybackStore();
    final container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        playbackStoreProvider.overrideWithValue(store),
        presenceCheckProvider.overrideWithValue((_) async => true),
      ],
    );
    addTearDown(container.dispose);
    container.read(seriesAudioProvider);
    final queue = container.read(queueProvider.notifier);

    await queue.playAll([episode(1), episode(2)]);
    engine.emit(
      engine.current.copyWith(audioTracks: tracks, selectedAudio: '1'),
    );
    await pumpEventQueue();
    expect(engine.audioSelections, isEmpty, reason: 'nothing chosen yet');
    await rememberSeriesAudio(
      store,
      container.read(queueProvider).current,
      tracks[1],
    );

    await queue.next();
    engine.emit(
      engine.current.copyWith(audioTracks: tracks, selectedAudio: '1'),
    );
    await pumpEventQueue();
    expect(engine.audioSelections, ['2'], reason: 'English again');

    // Another series is not affected; nor a film.
    await queue.playAll([episode(1, series: 'Autre')]);
    engine.emit(
      engine.current.copyWith(audioTracks: tracks, selectedAudio: '1'),
    );
    await pumpEventQueue();
    expect(engine.audioSelections, ['2']);
  });
}
